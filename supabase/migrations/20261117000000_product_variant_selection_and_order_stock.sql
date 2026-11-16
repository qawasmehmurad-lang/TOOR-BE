alter table public.product_variants
  add column if not exists color text,
  add column if not exists size text;

create unique index if not exists product_variants_product_color_size_uidx
  on public.product_variants (product_id, coalesce(color, ''), coalesce(size, ''))
  where color is not null or size is not null;

alter table public.order_items
  add column if not exists variant_id uuid references public.product_variants(id) on delete set null;

create or replace function public.place_order(
  p_address_id uuid,
  p_items jsonb,
  p_buyer_note text default null
)
returns table(
  order_id uuid,
  order_number text,
  subtotal_jod numeric,
  delivery_fee_jod numeric,
  total_jod numeric,
  delivery_otp text
)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
  v_address public.addresses%rowtype;
  v_order_id uuid;
  v_order_number text;
  v_subtotal numeric(12,3) := 0;
  v_delivery_fee numeric(12,3) := 2.000;
  v_item jsonb;
  v_product public.products%rowtype;
  v_variant public.product_variants%rowtype;
  v_variant_id uuid;
  v_variant_label text;
  v_qty integer;
  v_otp text := lpad(floor(random()*1000000)::int::text,6,'0');
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Cart is empty';
  end if;

  select * into v_address
  from public.addresses
  where id = p_address_id and user_id = v_user;
  if not found then raise exception 'Delivery address not found'; end if;

  select coalesce((value->>'default_fee_jod')::numeric,2.000)
    into v_delivery_fee
  from public.platform_settings
  where key='delivery';
  v_delivery_fee := coalesce(v_delivery_fee,2.000);

  insert into public.orders(
    buyer_id,address_id,status,payment_method,delivery_fee_jod,buyer_note,delivery_otp_hash
  )
  values(
    v_user,p_address_id,'placed','cash_on_delivery',v_delivery_fee,
    left(p_buyer_note,1000),encode(digest(v_otp,'sha256'),'hex')
  )
  returning id,order_number into v_order_id,v_order_number;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    if (v_item->>'quantity') is null or (v_item->>'quantity') !~ '^[1-9][0-9]{0,3}$' then
      raise exception 'Invalid item quantity';
    end if;
    v_qty := (v_item->>'quantity')::integer;

    select * into v_product
    from public.products
    where id=(v_item->>'product_id')::uuid
    for update;
    if not found or v_product.status <> 'active' then raise exception 'Product is unavailable'; end if;
    if not private.is_active_store(v_product.store_id) then raise exception 'Store is unavailable'; end if;

    v_variant_id := nullif(v_item->>'variant_id','')::uuid;
    v_variant_label := null;
    if v_variant_id is not null then
      select * into v_variant
      from public.product_variants
      where id=v_variant_id and product_id=v_product.id
      for update;
      if not found then raise exception 'Selected product option is unavailable'; end if;
      if v_variant.stock_quantity < v_qty then
        raise exception 'Insufficient stock for selected product option';
      end if;
      update public.product_variants
      set stock_quantity=stock_quantity-v_qty
      where id=v_variant.id;
      v_variant_label := coalesce(
        nullif(concat_ws(' / ', nullif(v_variant.color,''), nullif(v_variant.size,'')),''),
        v_variant.option_value
      );
    elsif exists (
      select 1 from public.product_variants pv
      where pv.product_id=v_product.id and (pv.color is not null or pv.size is not null)
    ) then
      raise exception 'Please select an available product option';
    end if;

    if v_product.stock_quantity < v_qty then
      raise exception 'Insufficient stock for %',v_product.name;
    end if;

    update public.products
    set stock_quantity=stock_quantity-v_qty,
        status=case when stock_quantity-v_qty=0
          then 'out_of_stock'::public.product_status else status end
    where id=v_product.id;

    insert into public.order_items(
      order_id,store_id,product_id,product_name,unit_price_jod,quantity,
      line_total_jod,variant_id,variant_label
    )
    values(
      v_order_id,v_product.store_id,v_product.id,v_product.name,
      v_product.price_jod,v_qty,v_product.price_jod*v_qty,
      v_variant_id,v_variant_label
    );

    v_subtotal:=v_subtotal+(v_product.price_jod*v_qty);
  end loop;

  update public.orders
  set subtotal_jod=v_subtotal,total_jod=v_subtotal+v_delivery_fee
  where id=v_order_id;

  insert into public.shipments(order_id,status)
  values(v_order_id,'awaiting_assignment');

  insert into public.order_events(order_id,actor_id,event_type,description)
  values(v_order_id,v_user,'order_placed','تم استلام الطلب بنجاح');

  return query
  select v_order_id,v_order_number,v_subtotal,v_delivery_fee,
         v_subtotal+v_delivery_fee,v_otp;
end;
$function$;
