-- Securely expose only coupon discounts attached to shipments assigned to the signed-in courier.
-- The SECURITY DEFINER implementation stays in the non-exposed private schema.
create or replace function private.get_my_delivery_discounts_internal()
returns table(order_number text, discount_jod numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select o.order_number, coalesce(o.discount_jod, 0)::numeric
  from public.shipments s
  join public.orders o on o.id = s.order_id
  where s.courier_id = (select auth.uid())
    and (select auth.uid()) is not null;
$$;

revoke all on function private.get_my_delivery_discounts_internal() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.get_my_delivery_discounts_internal() to authenticated;

create or replace function public.get_my_delivery_discounts()
returns table(order_number text, discount_jod numeric)
language sql
stable
security invoker
set search_path = public, private, pg_temp
as $$
  select * from private.get_my_delivery_discounts_internal();
$$;

revoke all on function public.get_my_delivery_discounts() from public, anon;
grant execute on function public.get_my_delivery_discounts() to authenticated;
