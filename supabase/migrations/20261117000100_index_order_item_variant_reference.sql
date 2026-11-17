create index if not exists idx_order_items_variant_id on public.order_items(variant_id) where variant_id is not null;
