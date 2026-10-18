-- Run in Supabase SQL Editor as project owner.
create table if not exists public.map_state (
  id integer primary key check (id = 1),
  revision bigint not null default 0,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
insert into public.map_state(id,revision,data) values (1,0,'{}'::jsonb) on conflict (id) do nothing;
create table if not exists public.map_admins (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.map_state enable row level security;
alter table public.map_admins enable row level security;
drop policy if exists "public map read" on public.map_state;
create policy "public map read" on public.map_state for select to anon,authenticated using (true);
drop policy if exists "admin can see own role" on public.map_admins;
create policy "admin can see own role" on public.map_admins for select to authenticated using (user_id = (select auth.uid()));
-- No direct insert/update/delete permissions granted through RLS.
create or replace function public.save_map_state(new_data jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare new_revision bigint;
begin
 if auth.uid() is null or not exists(select 1 from public.map_admins where user_id=auth.uid()) then
   raise exception 'Not an administrator' using errcode='42501';
 end if;
 if jsonb_typeof(new_data) <> 'object' or pg_catalog.octet_length(new_data::text)>2000000 then
   raise exception 'Invalid or too large map data';
 end if;
 update public.map_state set data = new_data, revision=revision+1, updated_at=now() where id=1 returning revision into new_revision;
 return new_revision;
end $$;
revoke all on function public.save_map_state(jsonb) from public;
grant execute on function public.save_map_state(jsonb) to authenticated;
