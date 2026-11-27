alter table public.merchant_applications
  add column if not exists alternate_phone text,
  add column if not exists street_address text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists logo_url text,
  add column if not exists license_document_url text,
  add column if not exists category_id uuid references public.categories(id);

create table if not exists public.courier_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  alternate_phone text,
  vehicle_type text not null,
  vehicle_plate text not null,
  city text not null,
  license_front_url text not null,
  license_back_url text not null,
  vehicle_registration_front_url text not null,
  vehicle_registration_back_url text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  admin_note text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.courier_applications enable row level security;
drop policy if exists "courier application owner submit" on public.courier_applications;
create policy "courier application owner submit" on public.courier_applications
  for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists "courier application owner read" on public.courier_applications;
create policy "courier application owner read" on public.courier_applications
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_admin());
drop policy if exists "courier application admin review" on public.courier_applications;
create policy "courier application admin review" on public.courier_applications
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

create unique index if not exists profiles_full_name_ci_unique
  on public.profiles (lower(btrim(full_name)))
  where nullif(btrim(full_name),'') is not null;
create unique index if not exists stores_name_ci_unique
  on public.stores (lower(btrim(name)));
create unique index if not exists merchant_applications_pending_store_name_ci_unique
  on public.merchant_applications (lower(btrim(proposed_store_name)))
  where status = 'pending';

create or replace function public.reject_duplicate_merchant_application_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.stores s
    where lower(btrim(s.name)) = lower(btrim(new.proposed_store_name))
  ) then
    raise exception 'اسم المتجر مستخدم بالفعل، اختر اسماً آخر';
  end if;
  if exists (
    select 1 from public.merchant_applications a
    where a.id is distinct from new.id
      and a.status = 'pending'
      and lower(btrim(a.proposed_store_name)) = lower(btrim(new.proposed_store_name))
  ) then
    raise exception 'اسم المتجر مستخدم بالفعل، اختر اسماً آخر';
  end if;
  return new;
end;
$$;
drop trigger if exists merchant_application_unique_name on public.merchant_applications;
create trigger merchant_application_unique_name
before insert or update of proposed_store_name on public.merchant_applications
for each row execute function public.reject_duplicate_merchant_application_name();
revoke all on function public.reject_duplicate_merchant_application_name() from public, anon, authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id, full_name, phone, role)
  values (
    new.id,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'),''),''),
    nullif(btrim(new.raw_user_meta_data ->> 'phone'),''),
    'buyer'
  );
  return new;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('onboarding-documents','onboarding-documents',false,10485760,
  array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "onboarding documents owner upload" on storage.objects;
create policy "onboarding documents owner upload" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'onboarding-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
drop policy if exists "onboarding documents owner read" on storage.objects;
create policy "onboarding documents owner read" on storage.objects
for select to authenticated
using (
  bucket_id = 'onboarding-documents'
  and ((storage.foldername(name))[1] = (select auth.uid())::text or private.is_admin())
);
