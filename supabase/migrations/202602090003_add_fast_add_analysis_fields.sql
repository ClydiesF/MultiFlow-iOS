alter table public.properties
  add column if not exists analysis_completeness text,
  add column if not exists missing_analysis_inputs jsonb,
  add column if not exists capex_items jsonb,
  add column if not exists reno_budget numeric;
