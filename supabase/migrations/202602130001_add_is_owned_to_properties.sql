alter table public.properties
add column if not exists is_owned boolean not null default false;
