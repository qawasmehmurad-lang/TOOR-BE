-- Avoid creating zero-value settlement records when a store has no delivered sales in the chosen period.
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

  if v_gross <= 0 then
    raise exception 'No delivered sales in the selected period';
  end if;

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
