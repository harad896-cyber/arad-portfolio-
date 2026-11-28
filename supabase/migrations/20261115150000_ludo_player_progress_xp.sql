-- Player identity progression and server-authoritative Ludo XP.
-- Cosmetic progression only: this schema never participates in dice or movement rules.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists public.ludo_player_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  level integer not null default 1 check (level between 1 and 100),
  xp integer not null default 0 check (xp >= 0),
  total_xp bigint not null default 0 check (total_xp >= 0),
  daily_xp integer not null default 0 check (daily_xp >= 0),
  daily_xp_date date not null default (timezone('utc', now())::date),
  updated_at timestamptz not null default now(),
  constraint ludo_progress_xp_level_cap check (level < 100 or xp = 0)
);

create table if not exists public.ludo_xp_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  room_id uuid not null references public.ludo_rooms(id) on delete cascade,
  base_xp integer not null check (base_xp >= 0),
  awarded_xp integer not null check (awarded_xp >= 0),
  is_bot_match boolean not null default false,
  is_friend_match boolean not null default false,
  created_at timestamptz not null default now(),
  unique(user_id, room_id)
);
create index if not exists ludo_xp_ledger_user_date_idx
  on public.ludo_xp_ledger(user_id, created_at desc);

create table if not exists public.ludo_level_reward_definitions (
  level integer primary key check (level between 2 and 100),
  reward_payload jsonb not null,
  created_at timestamptz not null default now()
);
insert into public.ludo_level_reward_definitions(level, reward_payload)
select n,
  case when n % 10 = 0
    then jsonb_build_object('kind','milestone','level',n,'title_unlocked',true)
    else jsonb_build_object('kind','standard','level',n)
  end
from generate_series(2,100) as n
on conflict(level) do nothing;

create table if not exists public.ludo_player_reward_claims (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  level integer not null references public.ludo_level_reward_definitions(level),
  reward_payload jsonb not null,
  granted_at timestamptz not null default now(),
  unique(user_id, level)
);

alter table public.ludo_player_progress enable row level security;
alter table public.ludo_xp_ledger enable row level security;
alter table public.ludo_level_reward_definitions enable row level security;
alter table public.ludo_player_reward_claims enable row level security;

revoke all on public.ludo_player_progress, public.ludo_xp_ledger,
  public.ludo_level_reward_definitions, public.ludo_player_reward_claims
from anon, authenticated;
grant select on public.ludo_player_progress, public.ludo_level_reward_definitions
to authenticated;
grant select on public.ludo_xp_ledger, public.ludo_player_reward_claims
to authenticated;

drop policy if exists ludo_progress_read_own on public.ludo_player_progress;
create policy ludo_progress_read_own on public.ludo_player_progress
for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists ludo_xp_ledger_read_own on public.ludo_xp_ledger;
create policy ludo_xp_ledger_read_own on public.ludo_xp_ledger
for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists ludo_level_rewards_read on public.ludo_level_reward_definitions;
create policy ludo_level_rewards_read on public.ludo_level_reward_definitions
for select to authenticated using (true);
drop policy if exists ludo_reward_claims_read_own on public.ludo_player_reward_claims;
create policy ludo_reward_claims_read_own on public.ludo_player_reward_claims
for select to authenticated using ((select auth.uid()) = user_id);

create or replace function private.ludo_xp_required_for_level(p_level integer)
returns integer
language sql immutable strict
set search_path = ''
as $$
  select case when p_level between 1 and 99
    then ceil(100 * power(p_level::numeric, 1.4))::integer
    else 0 end;
$$;

create or replace function private.ludo_calculate_game_xp(
  p_placement integer,
  p_pieces_home integer,
  p_captures integer,
  p_is_friend_match boolean,
  p_is_bot_match boolean
) returns integer
language plpgsql immutable
set search_path = ''
as $$
declare
  v_xp integer;
begin
  if p_placement not between 1 and 4
     or p_pieces_home not between 0 and 4
     or p_captures not between 0 and 16 then
    raise exception 'invalid_ludo_xp_result' using errcode = '22023';
  end if;

  v_xp := 50 + (p_pieces_home * 10) + (p_captures * 15)
    + case p_placement when 1 then 150 when 2 then 80 when 3 then 40 else 0 end;

  if p_is_bot_match then
    v_xp := floor(v_xp * 0.25)::integer;
  end if;
  if p_is_friend_match then
    v_xp := floor(v_xp * 1.20)::integer;
  end if;
  return v_xp;
end;
$$;

create or replace function public.grant_ludo_game_xp(
  p_user_id uuid,
  p_room_id uuid,
  p_placement integer,
  p_pieces_home integer,
  p_captures integer,
  p_is_friend_match boolean default false,
  p_is_bot_match boolean default false,
  p_was_abandoned boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_progress public.ludo_player_progress;
  v_base_xp integer := 0;
  v_award integer := 0;
  v_remaining integer := 0;
  v_required integer := 0;
  v_old_level integer;
  v_new_level integer;
  v_unlocked jsonb := '[]'::jsonb;
  v_reward record;
  v_today date := timezone('utc', now())::date;
begin
  -- This function is an internal server endpoint. Never grant it to app users.
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
    raise exception 'server_role_required' using errcode = '42501';
  end if;
  if p_user_id is null or p_room_id is null then
    raise exception 'missing_game_identity' using errcode = '22023';
  end if;
  if p_was_abandoned then
    raise exception 'abandoned_games_receive_no_xp' using errcode = '22023';
  end if;

  v_base_xp := private.ludo_calculate_game_xp(
    p_placement, p_pieces_home, p_captures, p_is_friend_match, p_is_bot_match
  );

  insert into public.ludo_player_progress(user_id)
  values (p_user_id) on conflict(user_id) do nothing;

  select * into v_progress
  from public.ludo_player_progress
  where user_id = p_user_id
  for update;

  if v_progress.daily_xp_date <> v_today then
    update public.ludo_player_progress
      set daily_xp = 0, daily_xp_date = v_today
    where user_id = p_user_id
    returning * into v_progress;
  end if;

  v_award := least(v_base_xp, greatest(0, 500 - v_progress.daily_xp));

  insert into public.ludo_xp_ledger(
    user_id, room_id, base_xp, awarded_xp, is_bot_match, is_friend_match
  ) values (
    p_user_id, p_room_id, v_base_xp, v_award, p_is_bot_match, p_is_friend_match
  );

  v_old_level := v_progress.level;
  v_new_level := v_progress.level;
  v_remaining := v_progress.xp + v_award;

  while v_new_level < 100 loop
    v_required := private.ludo_xp_required_for_level(v_new_level);
    exit when v_remaining < v_required;
    v_remaining := v_remaining - v_required;
    v_new_level := v_new_level + 1;
  end loop;
  if v_new_level = 100 then v_remaining := 0; end if;

  update public.ludo_player_progress
    set level = v_new_level,
        xp = v_remaining,
        total_xp = total_xp + v_award,
        daily_xp = daily_xp + v_award,
        updated_at = now()
  where user_id = p_user_id;

  if v_new_level > v_old_level then
    for v_reward in
      select level, reward_payload
      from public.ludo_level_reward_definitions
      where level > v_old_level and level <= v_new_level
      order by level
    loop
      insert into public.ludo_player_reward_claims(user_id, level, reward_payload)
      values (p_user_id, v_reward.level, v_reward.reward_payload)
      on conflict(user_id, level) do nothing;
      if found then
        v_unlocked := v_unlocked || jsonb_build_array(
          jsonb_build_object('level',v_reward.level,'reward',v_reward.reward_payload)
        );
      end if;
    end loop;
  end if;

  return jsonb_build_object(
    'base_xp', v_base_xp,
    'awarded_xp', v_award,
    'daily_xp', v_progress.daily_xp + v_award,
    'daily_cap', 500,
    'old_level', v_old_level,
    'level', v_new_level,
    'xp', v_remaining,
    'total_xp', v_progress.total_xp + v_award,
    'unlocked_rewards', v_unlocked
  );
end;
$$;

revoke all on function private.ludo_xp_required_for_level(integer) from public, anon, authenticated;
revoke all on function private.ludo_calculate_game_xp(integer,integer,integer,boolean,boolean) from public, anon, authenticated;
revoke all on function public.grant_ludo_game_xp(uuid,uuid,integer,integer,integer,boolean,boolean,boolean)
  from public, anon, authenticated;
grant execute on function public.grant_ludo_game_xp(uuid,uuid,integer,integer,integer,boolean,boolean,boolean)
  to service_role;

grant select on public.ludo_player_progress, public.ludo_xp_ledger,
  public.ludo_level_reward_definitions, public.ludo_player_reward_claims to service_role;
