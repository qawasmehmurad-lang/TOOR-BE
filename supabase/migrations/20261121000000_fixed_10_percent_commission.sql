-- TOOR BE fixed platform commission policy: 10% of each delivered item sale.
-- Additive-only migration: preserves existing orders, stores, products and user data.

alter table public.stores
  alter column commission_percent set default 10.00;

update public.stores
set commission_percent = 10.00
where commission_percent is distinct from 10.00;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'stores_fixed_platform_commission_10'
      and conrelid = 'public.stores'::regclass
  ) then
    alter table public.stores
      add constraint stores_fixed_platform_commission_10
      check (commission_percent = 10.00);
  end if;
end
$$;

alter table public.order_items
  add column if not exists commission_percent numeric(5,2) not null default 10.00,
  add column if not exists commission_jod numeric(12,3) not null default 0.000;

update public.order_items
set commission_percent = 10.00,
    commission_jod = round(line_total_jod * 0.10, 3);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'order_items_fixed_platform_commission_10'
      and conrelid = 'public.order_items'::regclass
  ) then
    alter table public.order_items
      add constraint order_items_fixed_platform_commission_10
      check (commission_percent = 10.00);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'order_items_commission_amount_valid'
      and conrelid = 'public.order_items'::regclass
  ) then
    alter table public.order_items
      add constraint order_items_commission_amount_valid
      check (commission_jod >= 0 AND commission_jod <= line_total_jod);
  end if;
end
$$;

create or replace function public.set_order_item_platform_commission()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.commission_percent := 10.00;
  new.commission_jod := round(coalesce(new.line_total_jod, 0) * 0.10, 3);
  return new;
end;
$$;

revoke all on function public.set_order_item_platform_commission() from public, anon, authenticated;

drop trigger if exists set_order_item_platform_commission on public.order_items;
create trigger set_order_item_platform_commission
before insert or update on public.order_items
for each row
execute function public.set_order_item_platform_commission();

create or replace function public.create_weekly_store_settlement(
  p_store_id uuid,
  p_period_start date,
  p_period_end date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_gross numeric(12,3);
  v_commission numeric(12,3);
  v_id uuid;
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Administrator access required';
  end if;

  if p_period_end < p_period_start then
    raise exception 'Invalid settlement period';
  end if;

  if not exists (select 1 from public.stores where id = p_store_id) then
    raise exception 'Store not found';
  end if;

  select
    coalesce(sum(oi.line_total_jod), 0),
    coalesce(sum(oi.commission_jod), 0)
  into v_gross, v_commission
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  where oi.store_id = p_store_id
    and o.status = 'delivered'
    and o.delivered_at::date between p_period_start and p_period_end;

  insert into public.settlements(
    store_id, period_start, period_end, gross_jod,
    commission_jod, net_jod, status
  )
  values (
    p_store_id, p_period_start, p_period_end, v_gross,
    v_commission, v_gross - v_commission, 'pending'
  )
  on conflict (store_id, period_start, period_end)
  do update set
    gross_jod = excluded.gross_jod,
    commission_jod = excluded.commission_jod,
    net_jod = excluded.net_jod
  returning id into v_id;

  return v_id;
end;
$$;
