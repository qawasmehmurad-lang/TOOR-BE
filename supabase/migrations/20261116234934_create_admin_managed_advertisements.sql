create table if not exists public.ad_banners (
  id uuid primary key default gen_random_uuid(),
  image_url text not null,
  title text not null default '',
  subtitle text not null default '',
  link_url text not null default '#products',
  display_seconds numeric(4,1) not null default 1.2 check (display_seconds >= 1.2 and display_seconds <= 30),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.ad_banners enable row level security;
drop policy if exists "Anyone can view active ad banners" on public.ad_banners;
create policy "Anyone can view active ad banners" on public.ad_banners for select to anon, authenticated using (is_active = true or private.is_admin());
drop policy if exists "Admins manage ad banners" on public.ad_banners;
create policy "Admins manage ad banners" on public.ad_banners for all to authenticated using (private.is_admin()) with check (private.is_admin());
create index if not exists ad_banners_active_sort_idx on public.ad_banners (is_active, sort_order, created_at);
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('ad-media','ad-media',true,10485760,array['image/jpeg','image/png','image/webp','image/avif'])
on conflict (id) do update set public=true, file_size_limit=10485760, allowed_mime_types=array['image/jpeg','image/png','image/webp','image/avif'];
drop policy if exists "Public can view ad media" on storage.objects;
create policy "Public can view ad media" on storage.objects for select to anon, authenticated using (bucket_id='ad-media');
drop policy if exists "Admins upload ad media" on storage.objects;
create policy "Admins upload ad media" on storage.objects for insert to authenticated with check (bucket_id='ad-media' and private.is_admin());
drop policy if exists "Admins update ad media" on storage.objects;
create policy "Admins update ad media" on storage.objects for update to authenticated using (bucket_id='ad-media' and private.is_admin()) with check (bucket_id='ad-media' and private.is_admin());
drop policy if exists "Admins delete ad media" on storage.objects;
create policy "Admins delete ad media" on storage.objects for delete to authenticated using (bucket_id='ad-media' and private.is_admin());
