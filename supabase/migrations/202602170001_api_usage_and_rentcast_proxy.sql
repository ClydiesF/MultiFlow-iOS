-- Track monthly API credit usage per user.
create table if not exists public.api_usage_monthly (
  user_id uuid not null references auth.users(id) on delete cascade,
  month_key text not null,
  used_credits integer not null default 0,
  quota_credits integer not null default 25,
  updated_at timestamptz not null default now(),
  primary key (user_id, month_key)
);

alter table public.api_usage_monthly enable row level security;

drop policy if exists "api usage select own" on public.api_usage_monthly;
create policy "api usage select own"
on public.api_usage_monthly
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "api usage update own" on public.api_usage_monthly;
create policy "api usage update own"
on public.api_usage_monthly
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "api usage insert own" on public.api_usage_monthly;
create policy "api usage insert own"
on public.api_usage_monthly
for insert
to authenticated
with check (auth.uid() = user_id);

create or replace function public.consume_api_credits(
  p_user_id uuid,
  p_month_key text,
  p_cost integer,
  p_default_quota integer default 25
)
returns table(
  allowed boolean,
  used_credits integer,
  remaining_credits integer,
  quota_credits integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_used integer;
  v_quota integer;
begin
  insert into public.api_usage_monthly (user_id, month_key, used_credits, quota_credits, updated_at)
  values (p_user_id, p_month_key, 0, p_default_quota, now())
  on conflict (user_id, month_key) do nothing;

  select a.used_credits, a.quota_credits
    into v_used, v_quota
  from public.api_usage_monthly a
  where a.user_id = p_user_id and a.month_key = p_month_key
  for update;

  if coalesce(v_used, 0) + p_cost > coalesce(v_quota, p_default_quota) then
    return query
    select false, coalesce(v_used, 0), greatest(coalesce(v_quota, p_default_quota) - coalesce(v_used, 0), 0), coalesce(v_quota, p_default_quota);
    return;
  end if;

  update public.api_usage_monthly
  set used_credits = coalesce(v_used, 0) + p_cost,
      updated_at = now()
  where user_id = p_user_id and month_key = p_month_key;

  return query
  select true,
         coalesce(v_used, 0) + p_cost,
         greatest(coalesce(v_quota, p_default_quota) - (coalesce(v_used, 0) + p_cost), 0),
         coalesce(v_quota, p_default_quota);
end;
$$;

create or replace function public.refund_api_credits(
  p_user_id uuid,
  p_month_key text,
  p_cost integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.api_usage_monthly
  set used_credits = greatest(used_credits - p_cost, 0),
      updated_at = now()
  where user_id = p_user_id and month_key = p_month_key;
end;
$$;

grant execute on function public.consume_api_credits(uuid, text, integer, integer) to authenticated, service_role;
grant execute on function public.refund_api_credits(uuid, text, integer) to authenticated, service_role;
