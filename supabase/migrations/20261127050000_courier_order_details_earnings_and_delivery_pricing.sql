-- Courier order detail, delivery pricing, and courier-owned delivery earnings.
-- Existing order and shipment rows are preserved.

alter table public.orders
  add column if not exists delivery_speed text not null default 'standard';

alter table public.orders
  drop constraint if exists orders_delivery_speed_check;
alter table public.orders
  add constraint orders_delivery_speed_check
  check (delivery_speed in ('standard','express'));

-- Standard delivery is JOD 3 throughout Jordan. Express is JOD 6.
update public.platform_settings
set value = jsonb_set(coalesce(value, '{}'::jsonb), '{default_fee_jod}', '3'::jsonb, true)
where key = 'delivery';

insert into public.platform_settings(key, value)
values ('delivery_options', jsonb_build_object(
  'standard_fee_jod', 3,
  'express_fee_jod', 6,
  'express_business_days', 1,
  'country', 'JO'
))
on conflict (key) do update
set value = jsonb_set(
  jsonb_set(
    jsonb_set(coalesce(public.platform_settings.value, '{}'::jsonb), '{standard_fee_jod}', '3'::jsonb, true),
    '{express_fee_jod}', '6'::jsonb, true
  ),
  '{express_business_days}', '1'::jsonb, true
);

create table if not exists public.courier_earnings (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null unique references public.shipments(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  courier_id uuid not null references public.profiles(id) on delete restrict,
  amount_jod numeric(12,3) not null check (amount_jod >= 0),
  status text not null default 'pending' check (status in ('pending','paid')),
  earned_at timestamptz not null default now(),
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists courier_earnings_courier_earned_idx
  on public.courier_earnings(courier_id, earned_at desc);

alter table public.courier_earnings enable row level security;

drop policy if exists "Couriers view their own delivery earnings" on public.courier_earnings;
create policy "Couriers view their own delivery earnings"
on public.courier_earnings for select to authenticated
using (courier_id = (select auth.uid()));

drop policy if exists "Admins view all delivery earnings" on public.courier_earnings;
create policy "Admins view all delivery earnings"
on public.courier_earnings for select to authenticated
using (private.is_admin());

revoke all on public.courier_earnings from anon, authenticated;
grant select on public.courier_earnings to authenticated;

-- The courier receives the full delivery fee. This ledger entry is created only
-- after successful OTP-verified delivery and is idempotent per shipment.
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
  v_courier uuid;
  v_delivery_fee numeric(12,3);
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'courier' and p.is_blocked = false
  ) then
    raise exception 'Courier access required';
  end if;

  select order_id, status, courier_id into v_order, v_old_status, v_courier
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
    select delivery_otp_hash, delivery_fee_jod
    into v_otp_hash, v_delivery_fee
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
  elsif p_new_status = 'out_for_delivery' then
    update public.orders set status = 'out_for_delivery' where id = v_order;
  elsif p_new_status = 'delivered' then
    update public.orders set status = 'delivered', delivered_at = now() where id = v_order;

    insert into public.courier_earnings(shipment_id, order_id, courier_id, amount_jod)
    values (p_shipment_id, v_order, v_courier, coalesce(v_delivery_fee, 0))
    on conflict (shipment_id) do nothing;
  end if;

  insert into public.order_events(order_id, actor_id, event_type, description)
  values (
    v_order,
    auth.uid(),
    'shipment_' || p_new_status,
    case
      when p_new_status = 'delivered'
        then 'تم تسليم الطلب للعميل واستلام المبلغ النقدي منه بعد التحقق من رمز الاستلام. وتم تسجيل كامل رسوم التوصيل مستحقاً للمندوب.'
      else 'تم تحديث حالة التوصيل'
    end
  );

  return true;
end;
$function$;

revoke all on function public.courier_update_shipment(uuid,text,text,text) from public;
grant execute on function public.courier_update_shipment(uuid,text,text,text) to authenticated;

-- Replace the limited courier feed with a complete, persistent delivery history.
drop function if exists public.get_my_deliveries();

create function public.get_my_deliveries()
returns table (
  shipment_id uuid,
  order_id uuid,
  order_number text,
  shipment_status text,
  order_status public.order_status,
  total_jod numeric,
  subtotal_jod numeric,
  discount_jod numeric,
  delivery_fee_jod numeric,
  delivery_speed text,
  created_at timestamptz,
  picked_up_at timestamptz,
  hub_received_at timestamptz,
  delivered_at timestamptz,
  recipient_name text,
  recipient_phone text,
  city text,
  area text,
  street text,
  building text,
  delivery_notes text,
  latitude double precision,
  longitude double precision,
  buyer_name text,
  buyer_phone text,
  items jsonb,
  stores jsonb,
  courier_earning_jod numeric
)
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'courier' and p.is_blocked = false
  ) then
    raise exception 'Courier access required';
  end if;

  return query
  select
    sh.id,
    o.id,
    o.order_number,
    sh.status,
    o.status,
    o.total_jod,
    o.subtotal_jod,
    o.discount_jod,
    o.delivery_fee_jod,
    o.delivery_speed,
    o.created_at,
    sh.picked_up_at,
    sh.hub_received_at,
    sh.delivered_at,
    a.recipient_name,
    a.phone,
    a.city,
    a.area,
    a.street,
    a.building,
    a.notes,
    a.latitude,
    a.longitude,
    coalesce(nullif(b.full_name,''), a.recipient_name),
    coalesce(b.phone, a.phone),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', oi.id,
        'product_name', oi.product_name,
        'product_image_url', oi.product_image_url,
        'quantity', oi.quantity,
        'unit_price_jod', oi.unit_price_jod,
        'line_total_jod', oi.line_total_jod,
        'variant_label', oi.variant_label,
        'color', pv.color,
        'size', pv.size,
        'store_id', st.id,
        'store_name', st.name,
        'store_phone', st.contact_phone,
        'store_address', st.address,
        'store_city', st.city,
        'store_latitude', st.latitude,
        'store_longitude', st.longitude
      ) order by oi.id)
      from public.order_items oi
      left join public.product_variants pv on pv.id = oi.variant_id
      join public.stores st on st.id = oi.store_id
      where oi.order_id = o.id
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(distinct jsonb_build_object(
        'id', st.id,
        'name', st.name,
        'phone', st.contact_phone,
        'address', st.address,
        'city', st.city,
        'latitude', st.latitude,
        'longitude', st.longitude
      ))
      from public.order_items oi
      join public.stores st on st.id = oi.store_id
      where oi.order_id = o.id
    ), '[]'::jsonb),
    coalesce(ce.amount_jod, o.delivery_fee_jod)
  from public.shipments sh
  join public.orders o on o.id = sh.order_id
  left join public.addresses a on a.id = o.address_id
  left join public.profiles b on b.id = o.buyer_id
  left join public.courier_earnings ce on ce.shipment_id = sh.id
  where sh.courier_id = auth.uid()
  order by sh.created_at desc;
end;
$function$;

revoke all on function public.get_my_deliveries() from public;
grant execute on function public.get_my_deliveries() to authenticated;
