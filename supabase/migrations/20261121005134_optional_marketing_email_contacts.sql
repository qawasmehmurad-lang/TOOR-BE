create table if not exists public.marketing_contacts (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 email text not null check (length(trim(email)) between 5 and 254),
 email_consent boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.marketing_contacts enable row level security;
drop policy if exists marketing_contacts_owner_select on public.marketing_contacts;
create policy marketing_contacts_owner_select on public.marketing_contacts for select to authenticated using (user_id=(select auth.uid()) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));
drop policy if exists marketing_contacts_owner_insert on public.marketing_contacts;
create policy marketing_contacts_owner_insert on public.marketing_contacts for insert to authenticated with check (user_id=(select auth.uid()) and email_consent=true);
drop policy if exists marketing_contacts_owner_update on public.marketing_contacts;
create policy marketing_contacts_owner_update on public.marketing_contacts for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
revoke all on public.marketing_contacts from anon;
grant select,insert,update on public.marketing_contacts to authenticated;