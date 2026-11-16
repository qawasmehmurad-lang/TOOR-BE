# Supabase project

Project: TOOR-BE (Frankfurt, eu-central-1)

Applied hosted migrations:
- `initial_marketplace_schema`
- `secure_profile_roles_and_indexes`
- `secure_checkout_rpc`
- `merchant_onboarding_and_order_timeline`
- `enforce_marketplace_privacy_and_workflow`
- `grant_private_policy_helpers`
- `create_marketplace_storage_buckets`
- `courier_delivery_workflow`
- `delivery_otp_confirmation`
- `merchant_approval_workflow`
- `returns_window_and_weekly_settlements`
- `index_audit_actor_columns`

The live database contains the schema and policies listed in the project README. Pull the hosted schema into versioned local SQL migrations with the Supabase CLI before making schema changes from a second environment. Never put database passwords or service-role/secret keys in this repository.
