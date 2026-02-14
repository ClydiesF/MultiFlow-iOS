-- Add NOI criterion and per-criterion enable flags to grade profiles.

alter table public.profiles
  add column if not exists weight_noi numeric not null default 10;

alter table public.profiles
  add column if not exists enabled_cash_on_cash boolean not null default true;

alter table public.profiles
  add column if not exists enabled_dcr boolean not null default true;

alter table public.profiles
  add column if not exists enabled_cap_rate boolean not null default true;

alter table public.profiles
  add column if not exists enabled_cash_flow boolean not null default true;

alter table public.profiles
  add column if not exists enabled_equity_gain boolean not null default true;

alter table public.profiles
  add column if not exists enabled_noi boolean not null default true;
