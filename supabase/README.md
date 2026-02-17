# Supabase Setup (MultiFlow v2)

1. Create separate Supabase projects for `dev` and `prod`.
2. Enable providers in Auth:
   - Email/Password
   - Apple
3. Apply SQL migration(s) from `supabase/migrations` to each project.
4. Set iOS build settings values:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
5. Verify RLS and Storage policies with cross-user negative tests.

## RentCast proxy (recommended)

To keep `RENTCAST_API_KEY` off-device, deploy the edge function proxy:

1. Apply migration:
   - `supabase/migrations/202602170001_api_usage_and_rentcast_proxy.sql`
2. Set secrets:
   - `supabase secrets set RENTCAST_API_KEY=YOUR_KEY`
3. Deploy function:
   - `supabase functions deploy rentcast-proxy`

Function path:
- `/functions/v1/rentcast-proxy`
