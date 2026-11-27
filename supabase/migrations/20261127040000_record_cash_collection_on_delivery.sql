-- Record the courier's cash-collection attestation when OTP-verified delivery completes.
-- The successful six-digit delivery OTP is the courier's confirmation that the customer
-- received the order and paid the cash-on-delivery amount.
create or replace function public.courier_update_shipment(
  p_shipment_id uuid,
  p_new_status text,
  p_proof_url text default null,
  p_delivery_otp text default null
)
returns boolean
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_order uuid;
  v_old_status text;
  v_otp_hash text;
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'courier' and p.is_blocked = false
  ) then
    raise exception 'Courier access required';
  end if;

  select order_id, status into v_order, v_old_status
  from public.shipments
  where id = p_shipment_id and courier_id = auth.uid()
  for update;

  if not found then
    raise exception 'Delivery assignment not found';
  end if;

  if not (
    (v_old_status = 'assigned' and p_new_status = 'collecting') or
    (v_old_status = 'collecting' and p_new_status = 'at_hub') or
    (v_old_status = 'at_hub' and p_new_status = 'out_for_delivery') or
    (v_old_status = 'out_for_delivery' and p_new_status = 'delivered') or
    (v_old_status = p_new_status)
  ) then
    raise exception 'Invalid delivery status transition';
  end if;

  if p_new_status = 'delivered' then
    select delivery_otp_hash into v_otp_hash
    from public.orders where id = v_order;

    if p_delivery_otp is null
       or encode(extensions.digest(p_delivery_otp, 'sha256'), 'hex') is distinct from v_otp_hash then
      raise exception 'Invalid delivery confirmation code';
    end if;
  end if;

  update public.shipments
  set status = p_new_status,
      picked_up_at = case when p_new_status = 'collecting' then coalesce(picked_up_at, now()) else picked_up_at end,
      hub_received_at = case when p_new_status = 'at_hub' then coalesce(hub_received_at, now()) else hub_received_at end,
      delivered_at = case when p_new_status = 'delivered' then now() else delivered_at end,
      delivery_proof_url = coalesce(p_proof_url, delivery_proof_url)
  where id = p_shipment_id;

  if p_new_status = 'at_hub' then
    update public.orders set status = 'at_hub' where id = v_order;
  end if;
  if p_new_status = 'out_for_delivery' then
    update public.orders set status = 'out_for_delivery' where id = v_order;
  end if;
  if p_new_status = 'delivered' then
    update public.orders set status = 'delivered', delivered_at = now() where id = v_order;
  end if;

  insert into public.order_events(order_id, actor_id, event_type, description)
  values (
    v_order,
    auth.uid(),
    'shipment_' || p_new_status,
    case
      when p_new_status = 'delivered'
        then 'تم تسليم الطلب للعميل واستلام المبلغ النقدي منه بعد التحقق من رمز الاستلام.'
      else 'تم تحديث حالة التوصيل'
    end
  );

  return true;
end;
$function$;
