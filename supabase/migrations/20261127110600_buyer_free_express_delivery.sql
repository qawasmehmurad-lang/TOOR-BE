create or replace function public.buyer_set_order_delivery_speed(p_order_id uuid, p_delivery_speed text)
returns table(delivery_speed text, delivery_fee_jod numeric, total_jod numeric)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_order public.orders%rowtype;
  v_fee numeric(12,3);
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_delivery_speed not in ('standard','express') then
    raise exception 'Invalid delivery speed';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id and buyer_id = auth.uid()
  for update;

  if not found then
    raise exception 'Order not found';
  end if;
  if v_order.status <> 'placed' then
    raise exception 'Delivery option can only be changed before order confirmation';
  end if;
  if exists (
    select 1 from public.shipments sh
    where sh.order_id = p_order_id and sh.status <> 'awaiting_assignment'
  ) then
    raise exception 'Delivery option can no longer be changed';
  end if;

  if v_order.delivery_fee_jod = 0 then
    v_fee := 0.000;
  elsif p_delivery_speed = 'express' then
    v_fee := 6.000;
  else
    v_fee := 3.000;
  end if;

  update public.orders
  set delivery_speed = p_delivery_speed,
      delivery_fee_jod = v_fee,
      total_jod = greatest(0, subtotal_jod - discount_jod + v_fee)
  where id = p_order_id;

  return query
  select p_delivery_speed, v_fee, greatest(0, v_order.subtotal_jod - v_order.discount_jod + v_fee);
end;
$function$;