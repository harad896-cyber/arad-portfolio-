create table if not exists public.app_banned_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  banned_by uuid not null references auth.users(id),
  reason text,
  created_at timestamptz not null default now()
);

alter table public.app_banned_users enable row level security;
drop policy if exists app_ban_select_self on public.app_banned_users;
create policy app_ban_select_self on public.app_banned_users for select to authenticated using ((select auth.uid()) = user_id);

create or replace function public.owner_set_verification(p_user_id uuid, p_verified boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if lower(coalesce(auth.email(), '')) <> lower('harad896@gmail.com') then raise exception 'owner_only'; end if;
  if p_user_id is null then raise exception 'user_required'; end if;
  update public.profiles set is_verified = p_verified where id = p_user_id;
  if not found then raise exception 'user_not_found'; end if;
  update public.verification_requests
     set status = case when p_verified then 'approved' else 'rejected' end
   where user_id = p_user_id and status = 'pending';
end;
$$;

create or replace function public.owner_set_app_ban(p_user_id uuid, p_banned boolean, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if lower(coalesce(auth.email(), '')) <> lower('harad896@gmail.com') then raise exception 'owner_only'; end if;
  if p_user_id is null then raise exception 'user_required'; end if;
  if p_user_id = auth.uid() then raise exception 'owner_cannot_ban_self'; end if;
  if p_banned then
    insert into public.app_banned_users(user_id,banned_by,reason)
    values (p_user_id,auth.uid(),nullif(trim(p_reason),''))
    on conflict (user_id) do update set banned_by=excluded.banned_by,reason=excluded.reason,created_at=now();
  else
    delete from public.app_banned_users where user_id=p_user_id;
  end if;
end;
$$;

create or replace function public.owner_list_app_bans()
returns table(user_id uuid,banned_by uuid,reason text,created_at timestamptz)
language plpgsql security definer set search_path=public as $$
begin
  if lower(coalesce(auth.email(), '')) <> lower('harad896@gmail.com') then raise exception 'owner_only'; end if;
  return query select b.user_id,b.banned_by,b.reason,b.created_at from public.app_banned_users b order by b.created_at desc;
end;
$$;

create or replace function public.is_current_user_app_banned()
returns boolean language sql stable security invoker set search_path=public as $$
  select exists(select 1 from public.app_banned_users b where b.user_id=auth.uid());
$$;

revoke all on function public.owner_set_verification(uuid,boolean) from public;
revoke all on function public.owner_set_app_ban(uuid,boolean,text) from public;
revoke all on function public.owner_list_app_bans() from public;
revoke all on function public.is_current_user_app_banned() from public;
grant execute on function public.owner_set_verification(uuid,boolean) to authenticated;
grant execute on function public.owner_set_app_ban(uuid,boolean,text) to authenticated;
grant execute on function public.owner_list_app_bans() to authenticated;
grant execute on function public.is_current_user_app_banned() to authenticated;

create or replace function public.protect_owner_control_fields()
returns trigger language plpgsql security invoker set search_path = public as $$
begin
  if (new.is_owner is distinct from old.is_owner or new.is_verified is distinct from old.is_verified)
     and lower(coalesce(auth.email(), '')) <> lower('harad896@gmail.com') then
    raise exception 'owner_controls_are_owner_only';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_owner_control_guard on public.profiles;
create trigger profiles_owner_control_guard before update on public.profiles
for each row execute function public.protect_owner_control_fields();

update public.profiles p
set is_owner = true, is_verified = true
from auth.users u
where p.id = u.id and lower(coalesce(u.email,'')) = lower('harad896@gmail.com');
