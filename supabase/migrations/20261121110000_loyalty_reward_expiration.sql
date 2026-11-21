alter table public.loyalty_rewards
  add column if not exists expires_at timestamptz;
