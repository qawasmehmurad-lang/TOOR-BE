# TOOR BE — Product and Delivery Baseline

## Approved business rules
- Jordan-first, Arabic RTL marketplace with JOD currency.
- Multi-vendor marketplace; one customer-facing website remains available when native apps are released.
- A single backend and API serve the website and the future shared Android/iOS app.
- Customer and merchant experiences share one mobile app initially; role-based screens and permissions.
- Platform commission is fixed at 10% of each sold item's merchandise line value.
- Cash on delivery only for the initial release. Do not expose card or online payment options.
- Merchant registration is open. Applications remain pending until an administrator approves them.
- No merchant can publish products or accept orders before approval.
- Existing buyer, merchant, courier and admin roles remain supported.
- Preserve existing records and storage objects. No destructive schema or data changes without explicit approval.

## Current architecture
- Web: React 19, Vite, TypeScript.
- Backend: Supabase Auth, PostgreSQL, Storage, RLS and RPC functions.
- Current source of truth: this repository and the existing Supabase project in Frankfurt.
- Future mobile app: React Native + Expo, consuming authenticated server-side APIs/RPCs.
- Do not introduce WordPress, WooCommerce or Dokan into this existing project.

## Financial accounting
- Commission is recorded per order item at checkout as an immutable 10% snapshot.
- Commission and merchant net are calculated from delivered line items for settlement.
- Delivery fees are not included in the commission base.
- Platform-funded coupon discounts remain separate from merchant commission calculations unless a future approved policy changes this.
- Cancelled, returned or undelivered orders must not be treated as delivered sales for merchant settlement.

## Delivery sequence
1. Audit existing code, schema, RLS policies, RPCs and deployment configuration.
2. Fix critical correctness/security issues while preserving current data.
3. Complete customer, merchant, courier and admin workflows.
4. Verify commission, COD, inventory, variants, multi-store orders and settlement.
5. Establish repeatable CI build/lint checks.
6. Deploy the website and connect a custom domain after owner account actions.
7. Build the shared Android/iOS app only after the web/API contracts are stable.

## Budget and operational constraints
- Target recurring infrastructure spend: at or below USD 10/month where practical.
- Do not purchase paid plugins or subscriptions without prior approval.
- Free hosting plans must be checked for commercial-use restrictions before production use.
- Do not place service-role keys, database passwords or private tokens in browser/mobile code.
