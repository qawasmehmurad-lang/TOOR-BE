# Initial administrator setup

1. Create the first account in the storefront after setting the local Supabase environment.
2. Open Supabase Dashboard → SQL Editor for TOOR-BE.
3. Replace the email below with the exact email used for the first account, then run it once:

```sql
update public.profiles
set role = 'admin'
where id = (select id from auth.users where lower(email) = lower('YOUR_LOGIN_EMAIL'));
```

4. Sign out and sign in again so the browser refreshes the role information.

Do not expose a service-role key in the browser. To add a courier, first let that person create a normal buyer account, then open the admin dashboard and use “إضافة مندوب توصيل”; this calls the admin-only `admin_assign_courier` RPC. Direct client updates to `profiles.role` are intentionally blocked. Merchant applications are submitted by users and approved through the admin-only `approve_merchant_application` RPC.
