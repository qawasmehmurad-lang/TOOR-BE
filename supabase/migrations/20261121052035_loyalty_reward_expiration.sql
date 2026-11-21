alter table public.loyalty_rewards
  add column if not exists expires_at timestamptz not null default (now() + interval '30 days');

create or replace function public.enforce_loyalty_reward_expiry()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  if not exists (
    select 1 from public.loyalty_rewards
    where id = new.reward_id and is_active = true and expires_at > now()
  ) then
    raise exception 'Reward is unavailable or expired';
  end if;
  return new;
end;
$function$;

drop trigger if exists loyalty_reward_expiry_guard on public.loyalty_redemptions;
create trigger loyalty_reward_expiry_guard
before insert on public.loyalty_redemptions
for each row execute function public.enforce_loyalty_reward_expiry();

revoke execute on function public.enforce_loyalty_reward_expiry() from public, anon, authenticated;