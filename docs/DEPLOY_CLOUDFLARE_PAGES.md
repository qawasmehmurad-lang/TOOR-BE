# Deploy TOOR BE to Cloudflare Pages

## Project settings
- Connect GitHub repository: `qawasmehmurad-lang/TOOR-BE`
- Production branch: `main`
- Framework preset: Vite
- Build command: `npm install && npm run build`
- Build output directory: `dist`
- Root directory: `/`
- Node.js compatibility: 24

## Required environment variables
Set these for Production and Preview:
- `VITE_SUPABASE_URL`: `https://reuglumqogdpxsdvaupe.supabase.co`
- `VITE_SUPABASE_PUBLISHABLE_KEY`: the project's publishable key from Supabase Dashboard → Project Settings → API Keys.

Never set a Supabase service-role key in Pages environment variables exposed to the Vite client.

## SPA routing and response headers
The `public/_redirects` file routes client-side paths to `index.html`. The `public/_headers` file adds baseline browser security headers and immutable caching for Vite's hashed assets.

## Before production
1. Verify the first Pages preview URL loads the storefront and client-side routes refresh correctly.
2. Test Supabase sign-in, merchant application, product loading, checkout and admin dashboard.
3. Confirm Supabase Auth email delivery and redirect URLs include the Pages preview and final custom domain.
4. Add the final custom domain in Cloudflare Pages and configure the corresponding Supabase Auth redirect URLs.
5. Keep online card payments disabled for the initial cash-on-delivery release.

## Budget notes
Cloudflare Pages currently offers a Free tier with up to 500 builds per month and up to 20,000 files per site. Static asset requests are free; Pages Functions have separate Workers quotas. Supabase Free includes 500 MB database, 1 GB file storage and 5 GB egress, but projects can pause after one week of inactivity and automated backups are not included. These limits are suitable for preview/testing, not a substitute for a production backup plan.
