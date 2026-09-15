create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  link_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists announcements_active_created_idx on public.announcements(is_active, created_at desc);

alter table public.announcements enable row level security;

drop policy if exists announcements_select_authenticated on public.announcements;
create policy announcements_select_authenticated
on public.announcements for select to authenticated
using (is_active = true);

create or replace function public.owner_create_announcement(
  p_title text,
  p_body text,
  p_link_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  aid uuid;
begin
  if uid is null or not exists (select 1 from public.admin_users where user_id = uid) then
    raise exception 'Not authorized';
  end if;
  insert into public.announcements(created_by, title, body, link_url)
  values (uid, trim(p_title), trim(p_body), nullif(trim(coalesce(p_link_url,'')), ''))
  returning id into aid;
  return aid;
end;
$$;

grant execute on function public.owner_create_announcement(text,text,text) to authenticated;

create or replace function public.owner_set_announcement_active(p_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not exists (select 1 from public.admin_users where user_id = auth.uid()) then
    raise exception 'Not authorized';
  end if;
  update public.announcements set is_active = p_active where id = p_id;
end;
$$;

grant execute on function public.owner_set_announcement_active(uuid,boolean) to authenticated;
