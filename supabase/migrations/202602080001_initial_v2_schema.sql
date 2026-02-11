-- MultiFlow v2 initial schema (fresh-start users + data)

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  weight_cash_on_cash numeric not null,
  weight_dcr numeric not null,
  weight_cap_rate numeric not null,
  weight_cash_flow numeric not null,
  weight_equity_gain numeric not null,
  color_hex text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_defaults (
  user_id uuid primary key references auth.users(id) on delete cascade,
  default_profile_id uuid null references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  address text not null,
  city text,
  state text,
  zip_code text,
  image_path text,
  purchase_price numeric not null,
  rent_roll jsonb not null default '[]'::jsonb,
  use_standard_operating_expense boolean,
  operating_expense_rate numeric,
  operating_expenses jsonb,
  annual_taxes numeric,
  annual_insurance numeric,
  annual_taxes_insurance numeric,
  loan_term_years integer,
  down_payment_percent numeric,
  interest_rate numeric,
  appreciation_rate numeric,
  marginal_tax_rate numeric,
  land_value_percent numeric,
  grade_profile_id uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_profile_defaults_updated_at on public.profile_defaults;
create trigger trg_profile_defaults_updated_at
before update on public.profile_defaults
for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_properties_updated_at on public.properties;
create trigger trg_properties_updated_at
before update on public.properties
for each row execute procedure public.touch_updated_at();

alter table public.profiles enable row level security;
alter table public.profile_defaults enable row level security;
alter table public.properties enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = user_id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = user_id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
  on public.profiles for delete
  using (auth.uid() = user_id);

drop policy if exists "profile_defaults_select_own" on public.profile_defaults;
create policy "profile_defaults_select_own"
  on public.profile_defaults for select
  using (auth.uid() = user_id);

drop policy if exists "profile_defaults_insert_own" on public.profile_defaults;
create policy "profile_defaults_insert_own"
  on public.profile_defaults for insert
  with check (auth.uid() = user_id);

drop policy if exists "profile_defaults_update_own" on public.profile_defaults;
create policy "profile_defaults_update_own"
  on public.profile_defaults for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "profile_defaults_delete_own" on public.profile_defaults;
create policy "profile_defaults_delete_own"
  on public.profile_defaults for delete
  using (auth.uid() = user_id);

drop policy if exists "properties_select_own" on public.properties;
create policy "properties_select_own"
  on public.properties for select
  using (auth.uid() = user_id);

drop policy if exists "properties_insert_own" on public.properties;
create policy "properties_insert_own"
  on public.properties for insert
  with check (auth.uid() = user_id);

drop policy if exists "properties_update_own" on public.properties;
create policy "properties_update_own"
  on public.properties for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "properties_delete_own" on public.properties;
create policy "properties_delete_own"
  on public.properties for delete
  using (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values ('property-images', 'property-images', false)
on conflict (id) do nothing;

drop policy if exists "property_images_read_own" on storage.objects;
create policy "property_images_read_own"
  on storage.objects
  for select
  using (
    bucket_id = 'property-images'
    and split_part(name, '/', 1) = auth.uid()::text
  );

drop policy if exists "property_images_insert_own" on storage.objects;
create policy "property_images_insert_own"
  on storage.objects
  for insert
  with check (
    bucket_id = 'property-images'
    and split_part(name, '/', 1) = auth.uid()::text
  );

drop policy if exists "property_images_update_own" on storage.objects;
create policy "property_images_update_own"
  on storage.objects
  for update
  using (
    bucket_id = 'property-images'
    and split_part(name, '/', 1) = auth.uid()::text
  )
  with check (
    bucket_id = 'property-images'
    and split_part(name, '/', 1) = auth.uid()::text
  );

drop policy if exists "property_images_delete_own" on storage.objects;
create policy "property_images_delete_own"
  on storage.objects
  for delete
  using (
    bucket_id = 'property-images'
    and split_part(name, '/', 1) = auth.uid()::text
  );
