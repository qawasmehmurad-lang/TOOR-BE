create table if not exists public.ad_video_settings (
  id boolean primary key default true check (id = true),
  video_url text,
  storage_path text,
  is_active boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table public.ad_video_settings enable row level security;
drop policy if exists "Public can view active video ad" on public.ad_video_settings;
create policy "Public can view active video ad"
on public.ad_video_settings for select to anon, authenticated
using (is_active = true or private.is_admin());
drop policy if exists "Admins manage video ad" on public.ad_video_settings;
create policy "Admins manage video ad"
on public.ad_video_settings for all to authenticated
using (private.is_admin())
with check (private.is_admin());
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ad-media',
  'ad-media',
  true,
  104857600,
  array['image/jpeg','image/png','image/webp','image/avif','video/mp4','video/webm','video/ogg']
)
on conflict (id) do update
set public = true,
    file_size_limit = 104857600,
    allowed_mime_types = array['image/jpeg','image/png','image/webp','image/avif','video/mp4','video/webm','video/ogg'];
