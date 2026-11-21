alter table public.products add column if not exists spin_video_url text;
grant update (spin_video_url) on public.products to authenticated;