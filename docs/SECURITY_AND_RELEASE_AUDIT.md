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
- Confirm merchant terms version 1.2 has been accepted by every active merchant before launch.
- Confirm the delivery fee and courier coverage/operating policy before public launch.
- Configure production hosting, environment variables, domain and transactional email delivery after the owner completes the required account steps.

## Safety
- No existing orders, products, users, stores or storage objects were deleted by this audit.
- Do not expose Supabase service-role keys in the browser or mobile application.
- All schema changes in this audit were additive or privilege-restricting.
