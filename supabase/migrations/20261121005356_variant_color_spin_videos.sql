alter table public.product_variants add column if not exists spin_video_url text;
grant update (spin_video_url) on public.product_variants to authenticated;