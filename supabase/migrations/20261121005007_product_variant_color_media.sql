alter table public.product_variants add column if not exists image_url text;
grant update (image_url) on public.product_variants to authenticated;