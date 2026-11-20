-- Lock down direct client privileges while preserving the RLS-based marketplace workflows.
-- RLS remains enabled; this migration removes dangerous SQL privileges that RLS does not cover.

-- Anonymous visitors must never mutate marketplace data. Public read access remains unchanged.
revoke insert, update, delete, truncate, references, trigger
on all tables in schema public from public, anon;

-- TRUNCATE bypasses row-level security, so authenticated users must not hold it either.
revoke truncate, references, trigger
on all tables in schema public from authenticated;

-- Profiles: prevent self-promotion, self-unblocking and changes to protected identity fields.
revoke insert, update, delete on table public.profiles from authenticated;
revoke update (id, full_name, phone, role, avatar_url, country, city, is_blocked, created_at, updated_at)
on table public.profiles from public, anon, authenticated;
grant update (full_name, phone, avatar_url, country, city, updated_at)
on table public.profiles to authenticated;

-- Store owners can edit public store details and location, but not ownership, activation or commission.
revoke insert, update, delete on table public.stores from authenticated;
revoke update (id, owner_id, name, slug, description, logo_url, contact_phone, city, address, latitude, longitude, status, commission_percent, created_at, updated_at)
on table public.stores from public, anon, authenticated;
grant update (name, description, logo_url, contact_phone, city, address, latitude, longitude, updated_at)
on table public.stores to authenticated;

-- Merchants can edit their own product details, but cannot move products between stores or feature them.
revoke update on table public.products from authenticated;
revoke update (id, store_id, category_id, name, slug, description, sku, price_jod, compare_at_price_jod, stock_quantity, status, is_featured, created_at, updated_at)
on table public.products from public, anon, authenticated;
grant update (category_id, name, slug, description, sku, price_jod, compare_at_price_jod, stock_quantity, status, updated_at)
on table public.products to authenticated;

-- A merchant may update only their own order line's fulfillment status, never its price or ownership.
revoke insert, update, delete on table public.order_items from authenticated;
revoke update (id, order_id, store_id, product_id, product_name, product_image_url, variant_id, variant_label, unit_price_jod, quantity, line_total_jod, merchant_status, commission_percent, commission_jod)
on table public.order_items from public, anon, authenticated;
grant update (merchant_status) on table public.order_items to authenticated;

-- Merchant applications are submitted by users and reviewed only through the admin-checked RPC.
revoke update, delete on table public.merchant_applications from authenticated;
revoke update (id, user_id, proposed_store_name, contact_phone, city, business_description, status, admin_note, reviewed_by, reviewed_at, created_at)
on table public.merchant_applications from public, anon, authenticated;

-- Orders, shipments, events and settlements are changed through guarded RPCs or narrowly scoped admin actions.
revoke insert, update, delete on table public.orders from authenticated;
revoke update (id, order_number, buyer_id, address_id, status, payment_method, subtotal_jod, delivery_fee_jod, discount_jod, total_jod, buyer_note, delivery_otp_hash, placed_at, delivered_at, created_at, coupon_id)
on table public.orders from public, anon, authenticated;

revoke insert, update, delete on table public.order_events from authenticated;
revoke insert, update, delete on table public.settlements from authenticated;
revoke update (id, store_id, period_start, period_end, gross_jod, commission_jod, adjustments_jod, net_jod, status, paid_at, created_at)
on table public.settlements from public, anon, authenticated;

-- Only administrators assign couriers; delivery status transitions remain in courier_update_shipment().
revoke update on table public.shipments from authenticated;
revoke update (id, order_id, courier_id, status, hub_received_at, picked_up_at, delivered_at, delivery_proof_url, created_at)
on table public.shipments from public, anon, authenticated;
grant update (courier_id, status) on table public.shipments to authenticated;

-- Financial and sales ledgers are written only by their guarded database functions/triggers.
revoke insert, update, delete on table public.coupon_redemptions from authenticated;
revoke insert, update, delete on table public.loyalty_accounts from authenticated;
revoke insert, update, delete on table public.loyalty_transactions from authenticated;
revoke insert, update, delete on table public.loyalty_redemptions from authenticated;
revoke insert, update, delete on table public.product_sales_metrics from authenticated;

-- The database functions remain the only write path for checkout, stock, OTP, commission and settlements.
