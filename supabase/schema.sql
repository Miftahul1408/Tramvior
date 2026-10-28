-- Tramvior Supabase schema
-- Run this in Supabase Dashboard > SQL Editor.

create table if not exists public.student_profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  nama text not null default '',
  jurusan text not null default '',
  kelas text not null default '',
  sekolah text not null default '',
  avatar_path text,
  kartu_path text,
  kartu_verified boolean not null default false,
  kartu_tanggal bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.student_state (
  student_id uuid primary key references auth.users (id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists student_profiles_set_updated_at on public.student_profiles;
create trigger student_profiles_set_updated_at
before update on public.student_profiles
for each row execute function public.set_updated_at();

drop trigger if exists student_state_set_updated_at on public.student_state;
create trigger student_state_set_updated_at
before update on public.student_state
for each row execute function public.set_updated_at();

create or replace function public.handle_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.student_profiles (id, email, nama, jurusan, kelas, sekolah)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'nama', ''),
    coalesce(new.raw_user_meta_data ->> 'jurusan', ''),
    coalesce(new.raw_user_meta_data ->> 'kelas', ''),
    coalesce(new.raw_user_meta_data ->> 'sekolah', '')
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_or_email_changed on auth.users;
create trigger on_auth_user_created_or_email_changed
after insert or update of email on auth.users
for each row execute function public.handle_auth_user();

alter table public.student_profiles enable row level security;
alter table public.student_state enable row level security;

drop policy if exists "Students read own profile" on public.student_profiles;
create policy "Students read own profile"
on public.student_profiles for select to authenticated
using (id = (select auth.uid()));

drop policy if exists "Admins read all profiles" on public.student_profiles;
create policy "Admins read all profiles"
on public.student_profiles for select to authenticated
using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "Students update own profile" on public.student_profiles;
create policy "Students update own profile"
on public.student_profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists "Admins update all profiles" on public.student_profiles;
create policy "Admins update all profiles"
on public.student_profiles for update to authenticated
using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create or replace function public.admin_set_card_verification(
  p_student_id uuid,
  p_verified boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.jwt() -> 'app_metadata' ->> 'role') is distinct from 'admin' then
    raise exception 'Admin role required';
  end if;

  update public.student_profiles
  set kartu_verified = p_verified,
      kartu_tanggal = case when p_verified then (extract(epoch from now()) * 1000)::bigint else null end
  where id = p_student_id;

  if not found then
    raise exception 'Student profile not found';
  end if;
end;
$$;

revoke all on function public.admin_set_card_verification(uuid, boolean) from public, anon;
grant execute on function public.admin_set_card_verification(uuid, boolean) to authenticated;

create or replace function public.admin_delete_student(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.jwt() -> 'app_metadata' ->> 'role') is distinct from 'admin' then
    raise exception 'Admin role required';
  end if;

  delete from auth.users where id = p_student_id;

  if not found then
    raise exception 'Student account not found';
  end if;
end;
$$;

revoke all on function public.admin_delete_student(uuid) from public, anon;
grant execute on function public.admin_delete_student(uuid) to authenticated;

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  delete from auth.users where id = current_user_id;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;

drop policy if exists "Students read own state" on public.student_state;
create policy "Students read own state"
on public.student_state for select to authenticated
using (student_id = (select auth.uid()));

drop policy if exists "Admins read all state" on public.student_state;
create policy "Admins read all state"
on public.student_state for select to authenticated
using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "Students insert own state" on public.student_state;
create policy "Students insert own state"
on public.student_state for insert to authenticated
with check (student_id = (select auth.uid()));

drop policy if exists "Admins insert all state" on public.student_state;
create policy "Admins insert all state"
on public.student_state for insert to authenticated
with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "Students update own state" on public.student_state;
create policy "Students update own state"
on public.student_state for update to authenticated
using (student_id = (select auth.uid()))
with check (student_id = (select auth.uid()));

drop policy if exists "Admins update all state" on public.student_state;
create policy "Admins update all state"
on public.student_state for update to authenticated
using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create table if not exists public.premium_entitlements (
  student_id uuid primary key references public.student_profiles (id) on delete cascade,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null
);

alter table public.premium_entitlements enable row level security;

drop policy if exists "Students read own Premium entitlement" on public.premium_entitlements;
create policy "Students read own Premium entitlement"
on public.premium_entitlements for select to authenticated
using (student_id = (select auth.uid()));

drop policy if exists "Admins read all Premium entitlements" on public.premium_entitlements;
create policy "Admins read all Premium entitlements"
on public.premium_entitlements for select to authenticated
using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

revoke all on public.premium_entitlements from anon, authenticated;
grant select on public.premium_entitlements to authenticated;

-- Preserve still-active Premium grants created by the previous admin dashboard.
insert into public.premium_entitlements (student_id, expires_at)
select student_id,
       to_timestamp(((data #>> '{premium,until}')::numeric / 1000)::double precision)
from public.student_state
where case
  when data #>> '{premium,until}' ~ '^[0-9]+([.][0-9]+)?$'
    then (data #>> '{premium,until}')::numeric > extract(epoch from now()) * 1000
  else false
end
on conflict (student_id) do nothing;

create or replace function public.admin_set_premium(
  p_student_id uuid,
  p_duration_days integer default 30,
  p_revoke boolean default false
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_expires_at timestamptz;
begin
  if (select auth.jwt() -> 'app_metadata' ->> 'role') is distinct from 'admin' then
    raise exception 'Admin role required';
  end if;

  if not exists (select 1 from public.student_profiles where id = p_student_id) then
    raise exception 'Student profile not found';
  end if;

  if p_revoke then
    insert into public.premium_entitlements (student_id, expires_at, updated_by)
    values (p_student_id, now(), (select auth.uid()))
    on conflict (student_id) do update
      set expires_at = now(),
          updated_at = now(),
          updated_by = (select auth.uid())
    returning expires_at into v_expires_at;
    return v_expires_at;
  end if;

  if p_duration_days is null or p_duration_days not in (30, 90, 365) then
    raise exception 'Premium duration must be 30, 90, or 365 days';
  end if;

  insert into public.premium_entitlements (student_id, expires_at, updated_by)
  values (p_student_id, now() + pg_catalog.make_interval(days => p_duration_days), (select auth.uid()))
  on conflict (student_id) do update
    set expires_at = greatest(public.premium_entitlements.expires_at, now())
          + pg_catalog.make_interval(days => p_duration_days),
        updated_at = now(),
        updated_by = (select auth.uid())
  returning expires_at into v_expires_at;

  return v_expires_at;
end;
$$;

revoke all on function public.admin_set_premium(uuid, integer, boolean) from public, anon;
grant execute on function public.admin_set_premium(uuid, integer, boolean) to authenticated;

revoke all on public.student_profiles from anon, authenticated;
grant select on public.student_profiles to authenticated;
revoke update (jurusan) on public.student_profiles from authenticated;
grant update (nama, kelas, sekolah, avatar_path, kartu_path)
on public.student_profiles to authenticated;

revoke all on public.student_state from anon, authenticated;
grant select, insert, update on public.student_state to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'student-docs',
  'student-docs',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Students upload own documents" on storage.objects;
create policy "Students upload own documents"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'student-docs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Students read own documents" on storage.objects;
create policy "Students read own documents"
on storage.objects for select to authenticated
using (
  bucket_id = 'student-docs'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  )
);

drop policy if exists "Students update own documents" on storage.objects;
create policy "Students update own documents"
on storage.objects for update to authenticated
using (
  bucket_id = 'student-docs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'student-docs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Students delete own documents" on storage.objects;
create policy "Students delete own documents"
on storage.objects for delete to authenticated
using (
  bucket_id = 'student-docs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Admins delete student documents" on storage.objects;
create policy "Admins delete student documents"
on storage.objects for delete to authenticated
using (
  bucket_id = 'student-docs'
  and (select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- After creating the admin account in Authentication > Users, assign its role:
-- update auth.users
-- set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
-- where email = 'ADMIN_EMAIL_HERE';
