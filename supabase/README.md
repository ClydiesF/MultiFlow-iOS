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
