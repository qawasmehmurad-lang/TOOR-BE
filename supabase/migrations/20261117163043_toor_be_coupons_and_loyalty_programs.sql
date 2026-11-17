-- TOOR BE coupons, merchant participation, loyalty balances and rewards.
create table if not exists public.merchant_program_acceptances (
 store_id uuid primary key references public.stores(id) on delete cascade,
 owner_id uuid not null references public.profiles(id) on delete cascade,
 coupons_accepted boolean not null default false, loyalty_accepted boolean not null default false,
 terms_version text not null, accepted_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.coupons (
 id uuid primary key default gen_random_uuid(), code text not null unique, title text not null, description text,
 discount_type text not null check(discount_type in ('percent','fixed')), discount_value numeric(12,3) not null check(discount_value>0),
 scope text not null check(scope in ('products','cart')), minimum_cart_jod numeric(12,3) not null default 0 check(minimum_cart_jod>=0),
 max_discount_jod numeric(12,3), usage_limit integer check(usage_limit is null or usage_limit>0),
 per_user_limit integer not null default 1 check(per_user_limit>0), starts_at timestamptz not null default now(),
 expires_at timestamptz not null, is_active boolean not null default true, created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(), check(expires_at>starts_at), check(discount_type<>'percent' or discount_value<=100)
);
create table if not exists public.coupon_products(coupon_id uuid not null references public.coupons(id) on delete cascade,product_id uuid not null references public.products(id) on delete cascade,primary key(coupon_id,product_id));
create table if not exists public.coupon_assignments(coupon_id uuid not null references public.coupons(id) on delete cascade,user_id uuid not null references public.profiles(id) on delete cascade,assigned_at timestamptz not null default now(),primary key(coupon_id,user_id));
create table if not exists public.coupon_redemptions(id uuid primary key default gen_random_uuid(),coupon_id uuid not null references public.coupons(id),user_id uuid not null references public.profiles(id),order_id uuid not null unique references public.orders(id),discount_jod numeric(12,3) not null check(discount_jod>0),redeemed_at timestamptz not null default now());
alter table public.orders add column if not exists coupon_id uuid references public.coupons(id);
create table if not exists public.loyalty_accounts(user_id uuid primary key references public.profiles(id) on delete cascade,balance integer not null default 0 check(balance>=0),lifetime_earned integer not null default 0 check(lifetime_earned>=0),updated_at timestamptz not null default now());
create table if not exists public.loyalty_transactions(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,order_id uuid references public.orders(id),points_change integer not null check(points_change<>0),kind text not null check(kind in ('earn','redeem','adjust','reverse')),description text,created_at timestamptz not null default now());
create unique index if not exists loyalty_earn_once_per_order on public.loyalty_transactions(order_id) where kind='earn' and order_id is not null;
create table if not exists public.loyalty_rewards(id uuid primary key default gen_random_uuid(),product_id uuid not null unique references public.products(id),store_id uuid not null references public.stores(id),points_cost integer not null default 1000 check(points_cost>0),reward_value_jod numeric(12,3) not null default 5.000 check(reward_value_jod=5.000),is_active boolean not null default false,created_at timestamptz not null default now());
create table if not exists public.loyalty_redemptions(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id),reward_id uuid not null references public.loyalty_rewards(id),points_spent integer not null check(points_spent>0),status text not null default 'pending' check(status in ('pending','accepted','rejected','fulfilled','cancelled')),merchant_note text,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
alter table public.loyalty_redemptions add column if not exists order_id uuid references public.orders(id);
alter table public.orders add column if not exists coupon_id uuid references public.coupons(id);
create index if not exists coupons_active_expiry_idx on public.coupons(is_active,expires_at);
create index if not exists coupon_products_product_idx on public.coupon_products(product_id);
create index if not exists coupon_assignments_user_idx on public.coupon_assignments(user_id);
create index if not exists coupon_redemptions_coupon_idx on public.coupon_redemptions(coupon_id);
create index if not exists coupon_redemptions_user_idx on public.coupon_redemptions(user_id);
create index if not exists coupons_created_by_idx on public.coupons(created_by);
create index if not exists loyalty_transactions_user_idx on public.loyalty_transactions(user_id,created_at desc);
create index if not exists loyalty_redemptions_store_idx on public.loyalty_redemptions(reward_id,status);
create index if not exists loyalty_redemptions_order_idx on public.loyalty_redemptions(order_id);
create index if not exists loyalty_redemptions_user_idx on public.loyalty_redemptions(user_id);
create index if not exists loyalty_rewards_store_idx on public.loyalty_rewards(store_id);
create index if not exists merchant_program_acceptances_owner_idx on public.merchant_program_acceptances(owner_id);
create index if not exists orders_coupon_idx on public.orders(coupon_id);
alter table public.merchant_program_acceptances enable row level security;
alter table public.coupons enable row level security;
alter table public.coupon_products enable row level security;
alter table public.coupon_assignments enable row level security;
alter table public.coupon_redemptions enable row level security;
alter table public.loyalty_accounts enable row level security;
alter table public.loyalty_transactions enable row level security;
alter table public.loyalty_rewards enable row level security;
alter table public.loyalty_redemptions enable row level security;
grant select,insert,update on public.merchant_program_acceptances to authenticated;
grant select,insert,update,delete on public.coupons,public.coupon_products,public.coupon_assignments,public.loyalty_rewards to authenticated;
grant select on public.coupon_redemptions,public.loyalty_accounts,public.loyalty_transactions,public.loyalty_redemptions to authenticated;
grant select on public.coupons,public.coupon_products,public.loyalty_rewards to anon;
grant all on public.merchant_program_acceptances,public.coupons,public.coupon_products,public.coupon_assignments,public.coupon_redemptions,public.loyalty_accounts,public.loyalty_transactions,public.loyalty_rewards,public.loyalty_redemptions to service_role;
drop policy if exists merchant_program_owner_read on public.merchant_program_acceptances;
create policy merchant_program_owner_read on public.merchant_program_acceptances for select to authenticated using(owner_id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists merchant_program_owner_write on public.merchant_program_acceptances;
create policy merchant_program_owner_write on public.merchant_program_acceptances for insert to authenticated with check(owner_id=(select auth.uid()) and exists(select 1 from public.stores s where s.id=store_id and s.owner_id=(select auth.uid())));
drop policy if exists merchant_program_owner_update on public.merchant_program_acceptances;
create policy merchant_program_owner_update on public.merchant_program_acceptances for update to authenticated using(owner_id=(select auth.uid()) or (select private.is_admin())) with check(owner_id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists coupons_admin_manage on public.coupons;
create policy coupons_admin_manage on public.coupons for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
drop policy if exists coupons_public_active_read on public.coupons;
create policy coupons_public_active_read on public.coupons for select to anon,authenticated using(is_active=true and starts_at<=now() and expires_at>now());
drop policy if exists coupon_products_read on public.coupon_products;
create policy coupon_products_read on public.coupon_products for select to anon,authenticated using(true);
drop policy if exists coupon_products_admin_manage on public.coupon_products;
create policy coupon_products_admin_manage on public.coupon_products for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
drop policy if exists coupon_assignments_owner_read on public.coupon_assignments;
create policy coupon_assignments_owner_read on public.coupon_assignments for select to authenticated using(user_id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists coupon_assignments_admin_manage on public.coupon_assignments;
create policy coupon_assignments_admin_manage on public.coupon_assignments for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
drop policy if exists coupon_redemptions_owner_read on public.coupon_redemptions;
create policy coupon_redemptions_owner_read on public.coupon_redemptions for select to authenticated using(user_id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists loyalty_accounts_owner_read on public.loyalty_accounts;
create policy loyalty_accounts_owner_read on public.loyalty_accounts for select to authenticated using(user_id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists loyalty_transactions_owner_read on public.loyalty_transactions;
create policy loyalty_transactions_owner_read on public.loyalty_transactions for select to authenticated using(user_id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists loyalty_rewards_public_read on public.loyalty_rewards;
create policy loyalty_rewards_public_read on public.loyalty_rewards for select to anon,authenticated using(is_active=true);
drop policy if exists loyalty_rewards_admin_manage on public.loyalty_rewards;
create policy loyalty_rewards_admin_manage on public.loyalty_rewards for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
drop policy if exists loyalty_redemptions_owner_read on public.loyalty_redemptions;
create policy loyalty_redemptions_owner_read on public.loyalty_redemptions for select to authenticated using(user_id=(select auth.uid()) or (select private.is_admin()) or exists(select 1 from public.loyalty_rewards r join public.stores s on s.id=r.store_id where r.id=reward_id and s.owner_id=(select auth.uid())));
-- The remaining functions are installed by this migration to keep all checkout and redemption rules server-enforced.
