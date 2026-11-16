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

Do not expose a service-role key in the browser. Additional courier accounts can be assigned by an administrator through the protected profile role update. Merchant applications are submitted by users and approved through the admin-only `approve_merchant_application` RPC.
