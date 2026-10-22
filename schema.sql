-- Bot Constellation — Supabase schema
-- Run this once in the Supabase SQL editor.

create extension if not exists pgcrypto;

-- ───────────── check-ins: one row per attendee ─────────────
create table if not exists public.checkins (
  id           uuid primary key default gen_random_uuid(),
  x_handle     text unique not null,
  display_name text not null,
  bot_name     text,
  building     text,
  skills       text[] not null default '{}',
  track        text,
  fun_fact     text,
  linkedin_url text,
  created_at   timestamptz not null default now(),

  constraint x_handle_format   check (x_handle ~ '^[A-Za-z0-9_]{1,15}$'),
  constraint display_name_len  check (char_length(display_name) between 1 and 60),
  constraint bot_name_len      check (bot_name is null or char_length(bot_name) <= 40),
  constraint building_len      check (building is null or char_length(building) <= 140),
  constraint skills_count      check (cardinality(skills) <= 6),
  constraint skills_len        check (char_length(array_to_string(skills, ',')) <= 200),
  constraint fun_fact_len      check (fun_fact is null or char_length(fun_fact) <= 80),
  constraint linkedin_url_format check (linkedin_url is null or linkedin_url ~ '^https://([a-z]{2,3}\.)?linkedin\.com/in/[A-Za-z0-9_%-]{2,100}/?$'),
  constraint track_valid       check (track is null or track in (
    'gatekeeper', 'know-your-members', 'event-autopilot',
    'open-venue-db', 'front-desk-revenue', 'weird-stuff'
  ))
);

-- ───────────── progress updates posted during the night ─────────────
create table if not exists public.updates (
  id         uuid primary key default gen_random_uuid(),
  x_handle   text not null references public.checkins (x_handle) on delete cascade,
  text       text not null,
  created_at timestamptz not null default now(),

  constraint update_text_len check (char_length(text) between 1 and 120)
);
create index if not exists updates_handle_idx on public.updates (x_handle, created_at desc);

-- ───────────── row level security: anon may INSERT and SELECT only ─────────────
alter table public.checkins enable row level security;
alter table public.updates  enable row level security;

drop policy if exists "anon read checkins"   on public.checkins;
drop policy if exists "anon insert checkins" on public.checkins;
drop policy if exists "anon read updates"    on public.updates;
drop policy if exists "anon insert updates"  on public.updates;

create policy "anon read checkins"   on public.checkins for select to anon, authenticated using (true);
create policy "anon insert checkins" on public.checkins for insert to anon, authenticated with check (true);
create policy "anon read updates"    on public.updates  for select to anon, authenticated using (true);
create policy "anon insert updates"  on public.updates  for insert to anon, authenticated with check (true);

-- No update/delete for clients (no policies + revoked grants).
revoke update, delete, truncate on public.checkins from anon, authenticated;
revoke update, delete, truncate on public.updates  from anon, authenticated;
grant select, insert on public.checkins to anon, authenticated;
grant select, insert on public.updates  to anon, authenticated;

-- ───────────── realtime ─────────────
do $$
begin
  begin alter publication supabase_realtime add table public.checkins; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.updates;  exception when duplicate_object then null; end;
end $$;
