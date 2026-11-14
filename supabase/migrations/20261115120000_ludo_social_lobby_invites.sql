-- Social Ludo lobby and invite foundation (phase 1).
create table if not exists public.ludo_rooms (
  id uuid primary key default gen_random_uuid(),
  room_code text not null unique,
  invite_token uuid not null default gen_random_uuid() unique,
  host_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'lobby' check (status in ('lobby','playing','cancelled','expired')),
  max_players smallint not null default 4 check (max_players between 2 and 4),
  is_private boolean not null default true,
  game_mode text not null default 'standard' check (game_mode in ('standard','one_piece')),
  fill_with_bots boolean not null default false,
  expires_at timestamptz not null default (now() + interval '10 minutes'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ludo_rooms_lobby_expiry_idx on public.ludo_rooms(status,expires_at);
create table if not exists public.ludo_room_players (
  room_id uuid not null references public.ludo_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  seat smallint not null check (seat between 0 and 3),
  color text not null check (color in ('red','blue','yellow','green')),
  is_host boolean not null default false,
  is_ready boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key(room_id,user_id),
  unique(room_id,seat),
  unique(room_id,color)
);
create table if not exists public.ludo_room_invites (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.ludo_rooms(id) on delete cascade,
  invited_by uuid not null references auth.users(id) on delete cascade,
  invited_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique(room_id,invited_user_id),
  check(invited_by <> invited_user_id)
);
create index if not exists ludo_room_invites_inbox_idx on public.ludo_room_invites(invited_user_id,status,created_at desc);
alter table public.ludo_rooms enable row level security;
alter table public.ludo_room_players enable row level security;
alter table public.ludo_room_invites enable row level security;
revoke all on public.ludo_rooms,public.ludo_room_players,public.ludo_room_invites from anon,authenticated;
grant select on public.ludo_rooms,public.ludo_room_players,public.ludo_room_invites to authenticated;
create or replace function public.is_ludo_room_member(p_room_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
  select exists(select 1 from public.ludo_room_players p
    where p.room_id=p_room_id and p.user_id=(select auth.uid()));
$$;
revoke all on function public.is_ludo_room_member(uuid) from public,anon;
grant execute on function public.is_ludo_room_member(uuid) to authenticated;
drop policy if exists ludo_rooms_visible_to_members_or_invitees on public.ludo_rooms;
create policy ludo_rooms_visible_to_members_or_invitees on public.ludo_rooms for select to authenticated
using (
  public.is_ludo_room_member(id)
  or exists(select 1 from public.ludo_room_invites i where i.room_id=id and i.invited_user_id=(select auth.uid()) and i.status='pending' and i.expires_at>now())
);
drop policy if exists ludo_room_players_visible_to_room on public.ludo_room_players;
create policy ludo_room_players_visible_to_room on public.ludo_room_players for select to authenticated
using (
  public.is_ludo_room_member(room_id)
  or exists(select 1 from public.ludo_room_invites i where i.room_id=room_id and i.invited_user_id=(select auth.uid()) and i.status='pending' and i.expires_at>now())
);
drop policy if exists ludo_room_invites_visible_to_parties on public.ludo_room_invites;
create policy ludo_room_invites_visible_to_parties on public.ludo_room_invites for select to authenticated
using (invited_user_id=(select auth.uid()) or invited_by=(select auth.uid()));

create or replace function public.create_ludo_room(
  p_max_players smallint default 4,
  p_is_private boolean default true,
  p_game_mode text default 'standard',
  p_fill_with_bots boolean default false
) returns public.ludo_rooms
language plpgsql security definer set search_path=''
as $$
declare v_uid uuid := (select auth.uid()); v_room public.ludo_rooms; v_code text;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='28000'; end if;
  if p_max_players not between 2 and 4 then raise exception 'invalid_player_count' using errcode='22023'; end if;
  if p_game_mode not in ('standard','one_piece') then raise exception 'invalid_game_mode' using errcode='22023'; end if;
  -- Random code comes from pgcrypto; retries on the unique constraint are handled by caller.
  v_code := lpad((floor(random()*1000000))::bigint::text,6,'0');
  insert into public.ludo_rooms(room_code,host_id,max_players,is_private,game_mode,fill_with_bots)
  values(v_code,v_uid,p_max_players,p_is_private,p_game_mode,p_fill_with_bots)
  returning * into v_room;
  insert into public.ludo_room_players(room_id,user_id,seat,color,is_host,is_ready)
  values(v_room.id,v_uid,0,'red',true,true);
  return v_room;
end;
$$;

create or replace function public.invite_ludo_players(p_room_id uuid,p_user_ids uuid[])
returns integer language plpgsql security definer set search_path=''
as $$
declare v_uid uuid := (select auth.uid()); v_room public.ludo_rooms; v_target uuid; v_count integer:=0;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='28000'; end if;
  select * into v_room from public.ludo_rooms where id=p_room_id for update;
  if not found or v_room.host_id<>v_uid or v_room.status<>'lobby' or v_room.expires_at<=now() then
    raise exception 'ludo_room_not_invitable' using errcode='42501';
  end if;
  if coalesce(array_length(p_user_ids,1),0)>20 then raise exception 'too_many_invites' using errcode='22023'; end if;
  foreach v_target in array coalesce(p_user_ids,'{}'::uuid[]) loop
    if v_target=v_uid then continue; end if;
    if exists(select 1 from public.ludo_room_players where room_id=p_room_id and user_id=v_target) then continue; end if;
    insert into public.ludo_room_invites(room_id,invited_by,invited_user_id,expires_at)
      values(p_room_id,v_uid,v_target,least(v_room.expires_at,now()+interval '10 minutes'))
      on conflict(room_id,invited_user_id) do update set invited_by=excluded.invited_by,status='pending',created_at=now(),expires_at=excluded.expires_at;
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.join_ludo_room(p_room_code text default null,p_invite_token uuid default null)
returns public.ludo_rooms language plpgsql security definer set search_path=''
as $$
declare v_uid uuid := (select auth.uid()); v_room public.ludo_rooms; v_seat integer; v_color text;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='28000'; end if;
  select * into v_room from public.ludo_rooms
  where ((p_room_code is not null and room_code=p_room_code) or (p_invite_token is not null and invite_token=p_invite_token))
    and status='lobby' and expires_at>now()
  limit 1 for update;
  if not found then raise exception 'ludo_room_expired_or_missing' using errcode='P0002'; end if;
  if v_room.is_private and not exists(select 1 from public.ludo_room_invites i where i.room_id=v_room.id and i.invited_user_id=v_uid and i.status='pending' and i.expires_at>now())
     and v_room.host_id<>v_uid then raise exception 'ludo_invite_required' using errcode='42501'; end if;
  if exists(select 1 from public.ludo_room_players p where p.room_id=v_room.id and p.user_id=v_uid) then return v_room; end if;
  select coalesce(max(seat),-1)+1 into v_seat from public.ludo_room_players where room_id=v_room.id;
  if v_seat>=v_room.max_players then raise exception 'ludo_room_full' using errcode='55000'; end if;
  v_color:=case v_seat when 0 then 'red' when 1 then 'blue' when 2 then 'yellow' else 'green' end;
  insert into public.ludo_room_players(room_id,user_id,seat,color) values(v_room.id,v_uid,v_seat,v_color);
  update public.ludo_room_invites set status='accepted' where room_id=v_room.id and invited_user_id=v_uid and status='pending';
  update public.ludo_rooms set updated_at=now() where id=v_room.id;
  return v_room;
end;
$$;

create or replace function public.set_ludo_ready(p_room_id uuid,p_ready boolean)
returns boolean language plpgsql security definer set search_path=''
as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='28000'; end if;
  update public.ludo_room_players p set is_ready=p_ready
  where p.room_id=p_room_id and p.user_id=v_uid
    and exists(select 1 from public.ludo_rooms r where r.id=p_room_id and r.status='lobby' and r.expires_at>now());
  return found;
end;
$$;

create or replace function public.get_my_ludo_invites()
returns table(invite_id uuid,room_id uuid,room_code text,invite_token uuid,host_id uuid,host_name text,host_avatar text,game_mode text,max_players smallint,expires_at timestamptz)
language sql security definer set search_path=''
as $$
  select i.id,r.id,r.room_code,r.invite_token,r.host_id,
    coalesce(p.display_name,p.username,'بازیکن')::text,p.avatar_url,r.game_mode,r.max_players,i.expires_at
  from public.ludo_room_invites i join public.ludo_rooms r on r.id=i.room_id
  left join public.profiles p on p.id=r.host_id
  where i.invited_user_id=(select auth.uid()) and i.status='pending' and i.expires_at>now() and r.status='lobby'
  order by i.created_at desc limit 50;
$$;

revoke all on function public.create_ludo_room(smallint,boolean,text,boolean) from public,anon;
revoke all on function public.invite_ludo_players(uuid,uuid[]) from public,anon;
revoke all on function public.join_ludo_room(text,uuid) from public,anon;
revoke all on function public.set_ludo_ready(uuid,boolean) from public,anon;
revoke all on function public.get_my_ludo_invites() from public,anon;
grant execute on function public.create_ludo_room(smallint,boolean,text,boolean) to authenticated;
grant execute on function public.invite_ludo_players(uuid,uuid[]) to authenticated;
grant execute on function public.join_ludo_room(text,uuid) to authenticated;
grant execute on function public.set_ludo_ready(uuid,boolean) to authenticated;
grant execute on function public.get_my_ludo_invites() to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.ludo_rooms;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.ludo_room_players;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.ludo_room_invites;
exception when duplicate_object then null; when undefined_object then null; end $$;
