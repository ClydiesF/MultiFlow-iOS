-- MultiFlow v2: Offer Tracker MVP

begin;

create table if not exists public.property_offers (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  deal_room_id uuid null,
  title text not null,
  status text not null,
  current_revision_id uuid null,
  client_decision text not null default 'undecided',
  expires_at timestamptz null,
  submitted_at timestamptz null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.offer_revisions (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references public.property_offers(id) on delete cascade,
  revision_number integer not null,
  purchase_price numeric not null,
  earnest_money numeric null,
  down_payment_percent numeric null,
  closing_cost_credit numeric null,
  option_period_days integer null,
  inspection_period_days integer null,
  financing_contingency_days integer null,
  appraisal_contingency boolean not null default false,
  seller_concessions numeric null,
  estimated_close_date timestamptz null,
  notes text null,
  created_by_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.offer_comments (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references public.property_offers(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.offer_activity (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references public.property_offers(id) on delete cascade,
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null,
  metadata jsonb null,
  created_at timestamptz not null default now()
);

create index if not exists idx_property_offers_owner_active_updated
  on public.property_offers(owner_user_id, is_active, updated_at desc);
create index if not exists idx_property_offers_property_updated
  on public.property_offers(property_id, updated_at desc);
create index if not exists idx_offer_revisions_offer_revision
  on public.offer_revisions(offer_id, revision_number desc);
create index if not exists idx_offer_comments_offer_created
  on public.offer_comments(offer_id, created_at desc);
create index if not exists idx_offer_activity_offer_created
  on public.offer_activity(offer_id, created_at desc);

alter table public.property_offers enable row level security;
alter table public.offer_revisions enable row level security;
alter table public.offer_comments enable row level security;
alter table public.offer_activity enable row level security;

drop trigger if exists trg_property_offers_updated_at on public.property_offers;
create trigger trg_property_offers_updated_at
before update on public.property_offers
for each row execute procedure public.touch_updated_at();

drop policy if exists "property_offers_select_own" on public.property_offers;
create policy "property_offers_select_own"
  on public.property_offers for select
  using (auth.uid() = owner_user_id);

drop policy if exists "property_offers_insert_own" on public.property_offers;
create policy "property_offers_insert_own"
  on public.property_offers for insert
  with check (auth.uid() = owner_user_id);

drop policy if exists "property_offers_update_own" on public.property_offers;
create policy "property_offers_update_own"
  on public.property_offers for update
  using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);

drop policy if exists "property_offers_delete_own" on public.property_offers;
create policy "property_offers_delete_own"
  on public.property_offers for delete
  using (auth.uid() = owner_user_id);

drop policy if exists "offer_revisions_select_own" on public.offer_revisions;
create policy "offer_revisions_select_own"
  on public.offer_revisions for select
  using (
    exists (
      select 1 from public.property_offers po
      where po.id = offer_revisions.offer_id
        and po.owner_user_id = auth.uid()
    )
  );

drop policy if exists "offer_revisions_insert_own" on public.offer_revisions;
create policy "offer_revisions_insert_own"
  on public.offer_revisions for insert
  with check (
    created_by_user_id = auth.uid()
    and exists (
      select 1 from public.property_offers po
      where po.id = offer_revisions.offer_id
        and po.owner_user_id = auth.uid()
    )
  );

drop policy if exists "offer_comments_select_own" on public.offer_comments;
create policy "offer_comments_select_own"
  on public.offer_comments for select
  using (
    exists (
      select 1 from public.property_offers po
      where po.id = offer_comments.offer_id
        and po.owner_user_id = auth.uid()
    )
  );

drop policy if exists "offer_comments_insert_own" on public.offer_comments;
create policy "offer_comments_insert_own"
  on public.offer_comments for insert
  with check (
    author_user_id = auth.uid()
    and exists (
      select 1 from public.property_offers po
      where po.id = offer_comments.offer_id
        and po.owner_user_id = auth.uid()
    )
  );

drop policy if exists "offer_comments_delete_own" on public.offer_comments;
create policy "offer_comments_delete_own"
  on public.offer_comments for delete
  using (
    author_user_id = auth.uid()
    and exists (
      select 1 from public.property_offers po
      where po.id = offer_comments.offer_id
        and po.owner_user_id = auth.uid()
    )
  );

drop policy if exists "offer_activity_select_own" on public.offer_activity;
create policy "offer_activity_select_own"
  on public.offer_activity for select
  using (
    exists (
      select 1 from public.property_offers po
      where po.id = offer_activity.offer_id
        and po.owner_user_id = auth.uid()
    )
  );

drop policy if exists "offer_activity_insert_own" on public.offer_activity;
create policy "offer_activity_insert_own"
  on public.offer_activity for insert
  with check (
    actor_user_id = auth.uid()
    and exists (
      select 1 from public.property_offers po
      where po.id = offer_activity.offer_id
        and po.owner_user_id = auth.uid()
    )
  );

commit;
