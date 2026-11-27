-- Buyer-selectable standard/express delivery at checkout.
-- Standard keeps the applicable normal fee (including any existing eligible free-shipping promotion).
-- Express always charges JOD 6.

create or replace function public.buyer_set_order_delivery_speed(
  p_order_id uuid,
  p_delivery_speed text
)
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

  if p_delivery_speed = 'express' then
    v_fee := 6.000;
  elsif v_order.delivery_fee_jod = 0 then
    v_fee := 0;
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

revoke all on function public.buyer_set_order_delivery_speed(uuid,text) from public;
grant execute on function public.buyer_set_order_delivery_speed(uuid,text) to authenticated;

-- Backfill the courier ledger for deliveries completed before this feature.
insert into public.courier_earnings(shipment_id, order_id, courier_id, amount_jod, earned_at)
select sh.id, sh.order_id, sh.courier_id, o.delivery_fee_jod,
       coalesce(sh.delivered_at, o.delivered_at, sh.created_at)
from public.shipments sh
join public.orders o on o.id = sh.order_id
where sh.status = 'delivered'
  and sh.courier_id is not null
on conflict (shipment_id) do nothing;
