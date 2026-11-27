-- Let the authenticated buyer recover a delivery code without storing it in plaintext.
create or replace function public.regenerate_delivery_otp(p_order_id uuid)
returns text
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_otp text := lpad(floor(random() * 1000000)::int::text, 6, '0');
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.orders
  set delivery_otp_hash = encode(extensions.digest(v_otp, 'sha256'), 'hex')
  where id = p_order_id
    and buyer_id = auth.uid()
    and status in ('placed', 'confirmed', 'at_hub', 'out_for_delivery')
    and exists (
      select 1
      from public.shipments sh
      where sh.order_id = public.orders.id
        and sh.status <> 'delivered'
    );

  if not found then
    raise exception 'Order not found or delivery code is no longer available';
  end if;

  return v_otp;
end;
$function$;

revoke all on function public.regenerate_delivery_otp(uuid) from public;
grant execute on function public.regenerate_delivery_otp(uuid) to authenticated;
