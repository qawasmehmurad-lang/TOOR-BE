# TOOR BE — Security and Release Audit

Audit date: 2026-11-21  
Project: existing Supabase project `reuglumqogdpxsdvaupe` (Frankfurt / eu-central-1)

## Confirmed current data state
- 30 public tables; RLS is enabled on all 30.
- 1 active store and 1 merchant profile.
- 2 active products across 11 active categories.
- 0 orders and 0 order items so far.
- 0 active courier accounts.
- Owner/admin account is already marked as an active administrator.

## Changes applied
1. Added immutable 10% commission snapshots to each order item.
2. Locked store commission configuration to exactly 10%.
3. Settlement totals use delivered order lines only, exclude delivery fees, and use Jordan local dates.
4. Paid settlements cannot be recalculated; empty settlement periods are rejected.
5. Merchants must accept agreement version 1.2 (including the 10% commission) before new order lines can be created.
6. Added admin-only RPCs to mark settlements paid and activate an existing buyer as a courier.
7. Removed anonymous write privileges from public tables and removed TRUNCATE/REFERENCES/TRIGGER privileges from client roles.
8. Restricted client column updates: profiles cannot change role or blocked status; stores cannot change owner/status/commission; products cannot change store ownership or featured status; order items can only update merchant fulfillment status.
9. Added GitHub Actions build and quality checks; Supabase TypeScript types regenerated from the live schema.
10. Production catalogue no longer falls back to sample products when the connected database contains no active products.

## Remaining security / release work
- Supabase Auth leaked-password protection is still disabled. Enable it in Supabase Dashboard → Authentication → Settings / Password Security.
- The live Supabase migration history contains the initial schema and security migrations, but the repository currently lacks the first 12 historical migration files. Do not run `supabase db reset` or recreate the project from repository migrations until a baseline schema snapshot or the missing migrations are restored.
- End-to-end checkout, courier OTP delivery, returns and settlement payout still require real test accounts and test orders.
- One active merchant acceptance for version 1.2 is currently recorded. Confirm the intended merchant account can sign in and that its own store is active before the first order.
- One active courier account is currently recorded. Confirm the intended courier can sign in, receive an assigned test shipment and complete delivery with the buyer OTP.
- There are no orders or order items yet. A customer test order and courier OTP handoff are still required.
- Confirm the delivery fee and courier coverage/operating policy before public launch.
- Configure production hosting, environment variables, domain and transactional email delivery after the owner completes the required account steps.

## Safety
- No existing orders, products, users, stores or storage objects were deleted by this audit.
- Do not expose Supabase service-role keys in the browser or mobile application.
- All schema changes in this audit were additive or privilege-restricting.

## Follow-up verification — 2026-11-26

- The live project now has 33 public tables; Row Level Security is enabled on all 33.
- Added indexes for all five foreign-key columns identified as missing by the performance advisor on support reports and support messages.
- The signed-in buyer favorites interface now reads and writes the existing `favorites` table using stable product UUIDs; the table's owner-only RLS policy remains in force.
- Added a database-level `BEFORE INSERT` guard on `orders`: a buyer must have an existing, unblocked profile, and an authenticated caller cannot create an order for another user's profile. This also protects order creation through security-definer RPCs.
- GitHub Actions run 125 passed both the TypeScript/production build and lint checks for the favorites change. Run 126 (including the order guard migration) is still being checked at the time of this update.
- Security advisor still reports nine authenticated-callable `SECURITY DEFINER` functions. Their current definitions were inspected: each enforces the relevant administrator, courier, buyer, or ownership check internally; do not revoke their execute grants without replacing the application workflows.
- Security advisor still reports leaked-password protection disabled. This remains a required dashboard-side action before public launch.
- Performance advisor reports unused indexes and multiple permissive read/admin policies. These are not removed automatically: the project has almost no production traffic, and several policies intentionally allow public active-catalogue reads alongside administrator management.
- No live customer order was created as part of these checks; checkout, courier OTP, return handling and settlements still need an end-to-end test with dedicated test accounts.
- Added the buyer-side return request form to delivered orders. It uses the existing database trigger that validates order ownership, delivered status, the six-hour standard return window, and exceptional damaged/wrong-item claims.


## Follow-up verification — 2026-11-27

- Read-only live database counts: 0 orders, 0 order items, 1 active courier, 1 merchant acceptance on terms version 1.2, and 0 pending merchant applications.
- The admin ad-media bucket accepts JPEG/PNG/WebP/AVIF images and MP4/WebM/OGG video, with a 100 MB upload limit. The storefront upload controls now match those supported video MIME types and validate external ad links as HTTP(S).
- Added the in-app notification inbox, unread indicator, read-one/read-all actions and admin role-targeted announcements. External browser/mobile push delivery is not configured and remains dependent on a push provider and credentials.
- Latest GitHub Actions run for the current branch passed TypeScript/production build and lint after correcting the announcement role-array type.
- Checkout, delivery OTP, returns and settlement still require an end-to-end test order; do not treat zero test orders as a verified buyer-to-courier workflow.
