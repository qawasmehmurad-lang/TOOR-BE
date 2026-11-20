# TOOR BE — Acceptance Test Plan

Use test accounts and test products only. Do not use real customer addresses or phone numbers during initial testing.

## A. Public storefront
- Open the Cloudflare Pages preview URL on an Android phone.
- Confirm Arabic RTL layout, royal-gold identity, navigation, categories and product cards.
- Open each active product and verify complete images, product details, price, color/size variants and available stock.
- Refresh a product URL directly; it must return to the correct page rather than a 404.
- Confirm no demo/sample products appear when the live database is empty.

## B. Buyer journey
- Register and sign in with a test buyer account.
- Add a delivery address using test details.
- Add products from one store and from two stores to the cart.
- Select COD; confirm no online card payment option is visible.
- Place a test order and verify the order number, total and delivery OTP.
- Confirm stock decreases correctly and the order appears in buyer order history.
- Confirm a buyer cannot read another buyer's address or order.

## C. Merchant journey
- Submit a merchant application from a normal buyer account.
- Confirm the application remains pending and the account cannot publish products.
- Approve it from the admin dashboard and confirm the merchant role/store are created.
- Sign in as that merchant and accept the current version 1.2 platform terms (10% commission).
- Add a product with images, price, stock, colors and sizes.
- Confirm only that merchant can edit the product and its own order items.
- Confirm the merchant cannot change store ownership, commission, order amount or buyer address.

## D. Courier journey
- Create a normal buyer test account for the courier.
- In the admin dashboard, activate that buyer as a courier.
- Assign a ready-to-pick-up shipment to the courier.
- Sign in as the courier and confirm only assigned deliveries are visible.
- Advance delivery status and complete the delivery with the buyer OTP.
- Confirm the order becomes delivered and its item appears in settlement calculations.

## E. Commission and settlement
- For a delivered item with a merchandise line value of 50.000 JOD, verify commission is 5.000 JOD.
- Verify delivery fees are excluded from commission.
- Verify commission is stored on each order item and cannot be changed by the merchant.
- Create a settlement for the delivery date in Jordan local time.
- Verify gross, 10% commission and merchant net.
- Mark the pending settlement paid and verify the merchant sees the paid status.
- Confirm a paid settlement cannot be recalculated and a period with no delivered sales cannot create a settlement.

## F. Security checks
- Confirm authenticated users cannot update `profiles.role` or `profiles.is_blocked`.
- Confirm authenticated users cannot TRUNCATE public tables.
- Confirm anonymous users cannot insert, update or delete marketplace data.
- Confirm merchants can update only their own product fields and order fulfillment status.
- Confirm admin-only RPCs reject non-admin users.

## G. Release gate
Do not open public registration until all critical buyer, merchant, courier, COD, OTP, commission and settlement tests pass. Confirm Auth email delivery, password leak protection, backup plan, delivery fee and return policy before production.
