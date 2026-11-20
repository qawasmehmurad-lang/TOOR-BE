# TOOR BE — تور بي

Jordan-first multi-vendor marketplace. Arabic RTL, JOD currency, royal gold / black / white identity.

## Stack
- React + Vite + TypeScript
- Supabase Auth, PostgreSQL, Storage and Row Level Security
- Cash on delivery at launch

## Local development
1. Run `npm install`.
2. Copy `.env.example` to `.env`.
3. Add the Supabase publishable key to `.env` (never use a service-role key in the browser).
4. Run `npm run dev -- --host 0.0.0.0`.
5. Run `npm run build` to verify the production bundle.

## Marketplace rules
- Roles: buyer, merchant, courier and admin.
- Merchant accounts are free.
- Merchants can access only their own catalogue and order line items; buyer addresses and contact details are not exposed to merchants.
- Multi-store orders are consolidated through the platform hub.
- Target delivery: 3 business days; weekly merchant settlements.
- Standard return request window: 6 hours after delivery; exceptional damaged/wrong-item claims are handled separately.
- Cash on delivery for initial release.

## Security
- Frontend uses only the Supabase publishable key.
- Never commit `.env`, access tokens, service-role keys, or database passwords.
- Keep RLS enabled on every exposed public-schema table.


## Project and release documents
- Approved requirements: [docs/PRODUCT_BASELINE.md](docs/PRODUCT_BASELINE.md)
- Security and release audit: [docs/SECURITY_AND_RELEASE_AUDIT.md](docs/SECURITY_AND_RELEASE_AUDIT.md)
- Cloudflare Pages deployment: [docs/DEPLOY_CLOUDFLARE_PAGES.md](docs/DEPLOY_CLOUDFLARE_PAGES.md)
- Merchant agreement version 1.2 includes the fixed 10% platform commission.
