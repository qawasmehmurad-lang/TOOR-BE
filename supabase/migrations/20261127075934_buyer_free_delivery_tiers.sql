CREATE OR REPLACE FUNCTION public.place_order(p_address_id uuid, p_items jsonb, p_buyer_note text DEFAULT NULL::text, p_coupon_code text DEFAULT NULL::text)
 RETURNS TABLE(order_id uuid, order_number text, subtotal_jod numeric, delivery_fee_jod numeric, total_jod numeric, delivery_otp text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_user uuid:=auth.uid(); v_address public.addresses%rowtype; v_order_id uuid; v_order_number text;
 v_subtotal numeric(12,3):=0; v_delivery_fee numeric(12,3):=2.000; v_discount numeric(12,3):=0; v_eligible numeric(12,3):=0;
 v_item jsonb; v_product public.products%rowtype; v_variant public.product_variants%rowtype; v_coupon public.coupons%rowtype;
 v_variant_id uuid; v_variant_label text; v_qty integer; v_used_count integer; v_user_used_count integer;
 v_otp text:=lpad(floor(random()*1000000)::int::text,6,'0'); v_first_order boolean:=false; v_has_previous_order boolean:=false;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Cart is empty'; end if;
 select * into v_address from public.addresses where id=p_address_id and user_id=v_user;
 if not found then raise exception 'Delivery address not found'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));
 select exists(select 1 from public.orders where buyer_id=v_user and status not in ('cancelled','returned')) into v_has_previous_order;
 select exists(select 1 from auth.users au where au.id=v_user and au.created_at>=now()-interval '7 days') and not v_has_previous_order into v_first_order;
 select coalesce((value->>'default_fee_jod')::numeric,2.000) into v_delivery_fee from public.platform_settings where key='delivery';
 v_delivery_fee:=coalesce(v_delivery_fee,2.000);
 if nullif(trim(p_coupon_code),'') is not null then
  select * into v_coupon from public.coupons where upper(code)=upper(trim(p_coupon_code)) and is_active and starts_at<=now() and expires_at>now() for update;
  if not found then raise exception 'كود الخصم غير صالح أو انتهت صلاحيته'; end if;
  select count(*) into v_used_count from public.coupon_redemptions where coupon_id=v_coupon.id;
  if v_coupon.usage_limit is not null and v_used_count>=v_coupon.usage_limit then raise exception 'تم استنفاد عدد استخدامات هذا الكوبون'; end if;
  select count(*) into v_user_used_count from public.coupon_redemptions where coupon_id=v_coupon.id and user_id=v_user;
  if v_user_used_count>=v_coupon.per_user_limit then raise exception 'وصلت إلى الحد المسموح لاستخدام هذا الكوبون'; end if;
  if exists(select 1 from public.coupon_assignments ca where ca.coupon_id=v_coupon.id) and not exists(select 1 from public.coupon_assignments ca where ca.coupon_id=v_coupon.id and ca.user_id=v_user) then raise exception 'هذا الكوبون مخصص لمستخدمين محددين'; end if;
 end if;
 insert into public.orders as inserted_order(buyer_id,address_id,status,payment_method,delivery_fee_jod,buyer_note,delivery_otp_hash)
 values(v_user,p_address_id,'placed','cash_on_delivery',v_delivery_fee,left(p_buyer_note,1000),encode(extensions.digest(v_otp,'sha256'),'hex')) returning inserted_order.id,inserted_order.order_number into v_order_id,v_order_number;
 for v_item in select value from jsonb_array_elements(p_items) loop
  if (v_item->>'quantity') is null or (v_item->>'quantity') !~ '^[1-9][0-9]{0,3}$' then raise exception 'Invalid item quantity'; end if;
  v_qty:=(v_item->>'quantity')::integer;
  select * into v_product from public.products where id=(v_item->>'product_id')::uuid for update;
  if not found or v_product.status<>'active' then raise exception 'Product is unavailable'; end if;
  if not private.is_active_store(v_product.store_id) then raise exception 'Store is unavailable'; end if;
  v_variant_id:=nullif(v_item->>'variant_id','')::uuid; v_variant_label:=null;
  if v_variant_id is not null then
   select * into v_variant from public.product_variants where id=v_variant_id and product_id=v_product.id for update;
   if not found then raise exception 'Selected product option is unavailable'; end if;
   if v_variant.stock_quantity<v_qty then raise exception 'Insufficient stock for selected product option'; end if;
   update public.product_variants set stock_quantity=stock_quantity-v_qty where id=v_variant.id;
   v_variant_label:=coalesce(nullif(concat_ws(' / ',nullif(v_variant.color,''),nullif(v_variant.size,'')),''),v_variant.option_value);
  elsif exists(select 1 from public.product_variants pv where pv.product_id=v_product.id and (pv.color is not null or pv.size is not null)) then raise exception 'Please select an available product option';
  end if;
  if v_product.stock_quantity<v_qty then raise exception 'Insufficient stock for %',v_product.name; end if;
  update public.products set stock_quantity=stock_quantity-v_qty,status=case when stock_quantity-v_qty=0 then 'out_of_stock'::public.product_status else status end where id=v_product.id;
  insert into public.order_items(order_id,store_id,product_id,product_name,unit_price_jod,quantity,line_total_jod,variant_id,variant_label)
  values(v_order_id,v_product.store_id,v_product.id,v_product.name,v_product.price_jod,v_qty,v_product.price_jod*v_qty,v_variant_id,v_variant_label);
  v_subtotal:=v_subtotal+(v_product.price_jod*v_qty);
 end loop;
 if (v_first_order and v_subtotal>=20) or (v_has_previous_order and v_subtotal>=50) then
  v_delivery_fee:=0;
  update public.orders set delivery_fee_jod=0 where id=v_order_id;
 end if;
 if nullif(trim(p_coupon_code),'') is not null then
  if v_coupon.scope='cart' then
   if v_subtotal<v_coupon.minimum_cart_jod then raise exception 'الحد الأدنى للشراء لاستخدام الكوبون هو % دينار',v_coupon.minimum_cart_jod; end if;
   v_eligible:=v_subtotal;
  else
   select coalesce(sum(oi.line_total_jod),0) into v_eligible from public.order_items oi join public.coupon_products cp on cp.product_id=oi.product_id and cp.coupon_id=v_coupon.id where oi.order_id=v_order_id;
   if v_eligible<=0 then raise exception 'لا يحتوي الطلب على منتجات مشمولة بهذا الكوبون'; end if;
   if exists(select 1 from public.order_items oi join public.coupon_products cp on cp.product_id=oi.product_id and cp.coupon_id=v_coupon.id join public.stores st on st.id=oi.store_id left join public.merchant_program_acceptances ma on ma.store_id=st.id where oi.order_id=v_order_id and coalesce(ma.coupons_accepted,false)=false) then raise exception 'أحد المتاجر لم يوافق بعد على شروط حملات الخصم'; end if;
  end if;
  if v_coupon.discount_type='percent' then v_discount:=round(v_eligible*v_coupon.discount_value/100,3); else v_discount:=least(v_coupon.discount_value,v_eligible); end if;
  if v_coupon.max_discount_jod is not null then v_discount:=least(v_discount,v_coupon.max_discount_jod); end if;
  v_discount:=least(v_discount,v_subtotal);
  if v_discount<=0 then raise exception 'قيمة الخصم غير صالحة لهذا الطلب'; end if;
  update public.orders set coupon_id=v_coupon.id,discount_jod=v_discount,total_jod=v_subtotal+v_delivery_fee-v_discount where id=v_order_id;
  insert into public.coupon_redemptions(coupon_id,user_id,order_id,discount_jod) values(v_coupon.id,v_user,v_order_id,v_discount);
  insert into public.notifications(user_id,title,body,kind,data) values(v_user,'تم تطبيق كوبون الخصم','تم خصم '||v_discount||' دينار من طلبك','coupon_used',jsonb_build_object('coupon_id',v_coupon.id,'order_id',v_order_id));
 else update public.orders set subtotal_jod=v_subtotal,total_jod=v_subtotal+v_delivery_fee where id=v_order_id;
 end if;
 insert into public.shipments(order_id,status) values(v_order_id,'awaiting_assignment');
 insert into public.order_events(order_id,actor_id,event_type,description) values(v_order_id,v_user,'order_placed','تم استلام الطلب بنجاح');
 return query select v_order_id,v_order_number,v_subtotal,v_delivery_fee,v_subtotal+v_delivery_fee-v_discount,v_otp;
end; $function$

