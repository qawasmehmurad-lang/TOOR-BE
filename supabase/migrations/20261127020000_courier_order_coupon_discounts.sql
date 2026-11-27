-- Securely expose only coupon discounts attached to shipments assigned to the signed-in courier.
create or replace function public.get_my_delivery_discounts()
returns table(order_number text, discount_jod numeric)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select o.order_number, coalesce(o.discount_jod, 0)::numeric
  from public.shipments s
  join public.orders o on o.id = s.order_id
  where s.courier_id = (select auth.uid())
    and (select auth.uid()) is not null;
$$;

revoke all on function public.get_my_delivery_discounts() from public, anon;
grant execute on function public.get_my_delivery_discounts() to authenticated;
