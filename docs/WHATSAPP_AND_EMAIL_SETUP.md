# TOOR BE phone verification and email marketing setup

## WhatsApp phone verification (required before production)

The registration UI sends a phone OTP through Supabase Auth using the WhatsApp channel. WhatsApp delivery is supported by Supabase only with Twilio or Twilio Verify.

1. Open Supabase Dashboard for project `reuglumqogdpxsdvaupe`.
2. Go to Authentication -> Sign In / Providers -> Phone and enable Phone.
3. Choose Twilio or Twilio Verify as the phone provider.
4. Configure the Twilio Account SID, Auth Token, and sender/service details in Supabase. For Twilio Verify, use the Verify Service SID and enable WhatsApp in the Verify service. For Programmable Messaging, complete Twilio WhatsApp sender onboarding and register the required WhatsApp content template, then add its Content SID in Supabase.
5. Save the provider settings and test with a phone number in international E.164 format, e.g. `+9627XXXXXXXX`.
6. Configure Auth rate limits and CAPTCHA before public launch. Do not put Twilio credentials in frontend environment variables or commit them to GitHub.

Supabase references:
- https://supabase.com/docs/guides/auth/phone-login
- https://supabase.com/docs/reference/javascript/auth-signinwithotp

The frontend requests WhatsApp OTP and verifies the six-digit code. Until the provider is configured, sending a real WhatsApp code will fail; this is an external account setup, not a frontend code issue.

## Optional marketing email

Users may optionally enter an email address and explicitly consent to receive promotions. The address and consent are saved in `public.marketing_contacts`; email is not used to authenticate the account and is not verified.

Actual campaign delivery still requires an email service/provider and a server-side sender (for example, a Supabase Edge Function with provider credentials stored as Supabase secrets). Never send bulk campaign email from the browser or expose provider API keys.

## Product rotation videos

Merchants may upload an optional MP4/WebM rotation clip while creating a product. The clip is stored in the existing `product-media` bucket and displayed muted, looping, and without controls beside the main product image. The current bucket limit is 5 MB; the UI enforces a 4.8 MB maximum. A real 360-degree presentation requires the merchant to upload a clip that was actually filmed around the product. The platform does not synthesize a 360-degree video from one still image.
