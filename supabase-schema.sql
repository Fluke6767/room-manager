-- Room Manager / Supabase schema
-- Run this whole file in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'ห้อง 1/2',
  created_at timestamptz not null default now()
);

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  room_id uuid not null references rooms(id) on delete cascade,
  display_name text not null,
  last_name text,
  number text,
  avatar_url text,
  role text not null default 'student' check (role in ('owner','developer','leader','deputy','student')),
  created_at timestamptz not null default now()
);

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  title text not null,
  description text,
  assigned_to uuid references profiles(id) on delete set null,
  due_date date,
  status text not null default 'open' check (status in ('open','done')),
  created_by uuid references profiles(id) on delete set null,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  reporter_id uuid references profiles(id) on delete set null,
  target_id uuid references profiles(id) on delete set null,
  type text not null,
  title text not null,
  description text,
  status text not null default 'open' check (status in ('open','resolved')),
  resolved_by uuid references profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  member_id uuid not null references profiles(id) on delete cascade,
  amount numeric(12,2) not null check (amount >= 0),
  week_start date not null,
  status text not null default 'unpaid' check (status in ('paid','unpaid')),
  recorded_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

-- Create the room used by the first account.
insert into rooms(name) values ('ห้อง 1/2') on conflict do nothing;

-- New auth users automatically receive a profile.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
declare rid uuid;
begin
  select id into rid from public.rooms order by created_at limit 1;
  insert into public.profiles(id,room_id,display_name,role)
  values(new.id,rid,coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)),'student')
  on conflict(id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- RLS
alter table rooms enable row level security;
alter table profiles enable row level security;
alter table tasks enable row level security;
alter table reports enable row level security;
alter table payments enable row level security;
alter table messages enable row level security;

create or replace function public.my_room()
returns uuid language sql stable security definer set search_path=public
as $$ select room_id from profiles where id=auth.uid() $$;

create or replace function public.is_manager()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from profiles where id=auth.uid() and role in ('owner','developer','leader','deputy')) $$;

create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from profiles where id=auth.uid() and role in ('owner','developer')) $$;

drop policy if exists rooms_read on rooms;
create policy rooms_read on rooms for select using (id=public.my_room());

drop policy if exists profiles_read on profiles;
create policy profiles_read on profiles for select using (room_id=public.my_room());
drop policy if exists profiles_self_update on profiles;
create policy profiles_self_update on profiles for update using (id=auth.uid()) with check (id=auth.uid() and room_id=public.my_room());
drop policy if exists profiles_owner_update on profiles;
create policy profiles_owner_update on profiles for update using (public.is_owner() and room_id=public.my_room()) with check (room_id=public.my_room());

drop policy if exists tasks_read on tasks;
create policy tasks_read on tasks for select using (room_id=public.my_room());
drop policy if exists tasks_manager_insert on tasks;
create policy tasks_manager_insert on tasks for insert with check (public.is_manager() and room_id=public.my_room());
drop policy if exists tasks_update on tasks;
create policy tasks_update on tasks for update using (room_id=public.my_room() and (public.is_manager() or assigned_to=auth.uid())) with check (room_id=public.my_room());

drop policy if exists reports_read on reports;
create policy reports_read on reports for select using (room_id=public.my_room());
drop policy if exists reports_insert on reports;
create policy reports_insert on reports for insert with check (room_id=public.my_room() and reporter_id=auth.uid());
drop policy if exists reports_manager_update on reports;
create policy reports_manager_update on reports for update using (public.is_manager() and room_id=public.my_room()) with check (room_id=public.my_room());

drop policy if exists payments_read on payments;
create policy payments_read on payments for select using (room_id=public.my_room());
drop policy if exists payments_manager_insert on payments;
create policy payments_manager_insert on payments for insert with check (public.is_manager() and room_id=public.my_room());

drop policy if exists messages_read on messages;
create policy messages_read on messages for select using (room_id=public.my_room());
drop policy if exists messages_insert on messages;
create policy messages_insert on messages for insert with check (room_id=public.my_room() and sender_id=auth.uid());

-- Avatar storage
insert into storage.buckets(id,name,public) values('avatars','avatars',true)
on conflict(id) do update set public=true;

drop policy if exists avatar_read on storage.objects;
create policy avatar_read on storage.objects for select using (bucket_id='avatars');

drop policy if exists avatar_upload on storage.objects;
create policy avatar_upload on storage.objects for insert to authenticated
with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists avatar_update on storage.objects;
create policy avatar_update on storage.objects for update to authenticated
using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text)
with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);

-- IMPORTANT:
-- After the first account signs up, promote it manually once:
-- update profiles set role='owner' where id='YOUR_AUTH_USER_UUID';
-- You can find the UUID in Authentication -> Users.
