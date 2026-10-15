create table if not exists public.device_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null check (char_length(device_id) between 16 and 128),
  device_name text not null default 'دستگاه',
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (user_id, device_id)
);

alter table public.device_sessions enable row level security;
revoke all on public.device_sessions from anon, authenticated;
grant select on public.device_sessions to authenticated;

drop policy if exists device_sessions_select_own on public.device_sessions;
create policy device_sessions_select_own on public.device_sessions
for select to authenticated using (user_id = (select auth.uid()));

create index if not exists device_sessions_user_last_seen_idx
on public.device_sessions(user_id, last_seen_at desc);

create or replace function public.register_device_session(p_device_id text, p_device_name text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_rows integer;
begin
  if v_user_id is null
     or p_device_id is null
     or char_length(p_device_id) < 16
     or char_length(p_device_id) > 128 then
    return false;
  end if;

  insert into public.device_sessions(user_id, device_id, device_name)
  values (v_user_id, p_device_id, left(coalesce(nullif(trim(p_device_name), ''), 'دستگاه'), 100))
  on conflict (user_id, device_id) do update
    set device_name = excluded.device_name,
        last_seen_at = now()
    where public.device_sessions.revoked_at is null;

  get diagnostics v_rows = row_count;
  return v_rows > 0;
end;
$$;

create or replace function public.is_device_session_active(p_device_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.device_sessions ds
    where ds.user_id = auth.uid()
      and ds.device_id = p_device_id
      and ds.revoked_at is null
  );
$$;

create or replace function public.revoke_device_session(p_device_id text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_rows integer;
begin
  if v_user_id is null or p_device_id is null then return false; end if;
  update public.device_sessions
     set revoked_at = coalesce(revoked_at, now())
   where user_id = v_user_id
     and device_id = p_device_id
     and revoked_at is null;
  get diagnostics v_rows = row_count;
  return v_rows > 0;
end;
$$;

revoke all on function public.register_device_session(text, text) from public, anon;
revoke all on function public.is_device_session_active(text) from public, anon;
revoke all on function public.revoke_device_session(text) from public, anon;
grant execute on function public.register_device_session(text, text) to authenticated;
grant execute on function public.is_device_session_active(text) to authenticated;
grant execute on function public.revoke_device_session(text) to authenticated;