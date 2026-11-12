-- Persistent, server-authoritative game scores and daily wheel rewards.
create schema if not exists fun_internal;
revoke all on schema fun_internal from public, anon, authenticated;
grant usage on schema fun_internal to authenticated;
-- Competitive points are awarded only after a completed human-vs-human online match.
create table if not exists public.fun_game_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  points integer not null default 0 check (points >= 0),
  rating integer not null default 1000 check (rating >= 0),
  games_played integer not null default 0 check (games_played >= 0),
  wins integer not null default 0 check (wins >= 0),
  draws integer not null default 0 check (draws >= 0),
  losses integer not null default 0 check (losses >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.fun_game_results (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null unique references public.fun_game_rooms(id) on delete cascade,
  game_type text not null,
  player_one_id uuid not null references auth.users(id) on delete cascade,
  player_two_id uuid not null references auth.users(id) on delete cascade,
  winner_id uuid references auth.users(id) on delete set null,
  player_one_points integer not null,
  player_two_points integer not null,
  player_one_rating_change integer not null,
  player_two_rating_change integer not null,
  created_at timestamptz not null default now(),
  constraint fun_game_result_distinct_players check (player_one_id <> player_two_id)
);

create index if not exists fun_game_stats_leaderboard_idx
  on public.fun_game_stats (points desc, rating desc, updated_at asc);

alter table public.fun_game_stats enable row level security;
alter table public.fun_game_results enable row level security;
revoke all on public.fun_game_stats, public.fun_game_results from anon, authenticated;
grant select on public.fun_game_stats to authenticated;
grant select on public.fun_game_results to authenticated;

drop policy if exists fun_game_stats_read on public.fun_game_stats;
create policy fun_game_stats_read on public.fun_game_stats
  for select to authenticated using (true);
drop policy if exists fun_game_results_participant_read on public.fun_game_results;
create policy fun_game_results_participant_read on public.fun_game_results
  for select to authenticated
  using ((select auth.uid()) = player_one_id or (select auth.uid()) = player_two_id);

create or replace function fun_internal.record_fun_game_result()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_score_one numeric;
  v_expected_one numeric;
  v_delta_one integer;
  v_delta_two integer;
  v_points_one integer;
  v_points_two integer;
  v_inserted uuid;
begin
  if old.status = 'finished' or new.status <> 'finished'
     or new.is_bot_game
     or new.player_two_id is null then
    return new;
  end if;

  insert into public.fun_game_stats(user_id)
    values (new.player_one_id), (new.player_two_id)
    on conflict (user_id) do nothing;

  select rating into v_delta_one
    from public.fun_game_stats where user_id = new.player_one_id for update;
  select rating into v_delta_two
    from public.fun_game_stats where user_id = new.player_two_id for update;

  v_score_one := case
    when new.winner_id = new.player_one_id then 1
    when new.winner_id = new.player_two_id then 0
    else 0.5
  end;
  v_expected_one := 1.0 / (1.0 + power(10.0, ((v_delta_two - v_delta_one)::numeric / 400.0)));
  v_delta_one := round(24 * (v_score_one - v_expected_one))::integer;
  v_delta_two := -v_delta_one;

  v_points_one := case
    when new.winner_id = new.player_one_id then 30
    when new.winner_id is null then 10
    else 5
  end;
  v_points_two := case
    when new.winner_id = new.player_two_id then 30
    when new.winner_id is null then 10
    else 5
  end;

  insert into public.fun_game_results(
    room_id, game_type, player_one_id, player_two_id, winner_id,
    player_one_points, player_two_points,
    player_one_rating_change, player_two_rating_change
  ) values (
    new.id, new.game_type, new.player_one_id, new.player_two_id, new.winner_id,
    v_points_one, v_points_two, v_delta_one, v_delta_two
  )
  on conflict (room_id) do nothing
  returning id into v_inserted;

  if v_inserted is null then return new; end if;

  update public.fun_game_stats
    set points = points + v_points_one,
        rating = greatest(0, rating + v_delta_one),
        games_played = games_played + 1,
        wins = wins + case when new.winner_id = new.player_one_id then 1 else 0 end,
        draws = draws + case when new.winner_id is null then 1 else 0 end,
        losses = losses + case when new.winner_id = new.player_two_id then 1 else 0 end,
        updated_at = now()
    where user_id = new.player_one_id;

  update public.fun_game_stats
    set points = points + v_points_two,
        rating = greatest(0, rating + v_delta_two),
        games_played = games_played + 1,
        wins = wins + case when new.winner_id = new.player_two_id then 1 else 0 end,
        draws = draws + case when new.winner_id is null then 1 else 0 end,
        losses = losses + case when new.winner_id = new.player_one_id then 1 else 0 end,
        updated_at = now()
    where user_id = new.player_two_id;

  return new;
end;
$$;

drop trigger if exists fun_game_result_after_finish on public.fun_game_rooms;
create trigger fun_game_result_after_finish
  after update of status on public.fun_game_rooms
  for each row
  when (old.status is distinct from new.status and new.status = 'finished')
  execute function fun_internal.record_fun_game_result();

-- One authenticated wheel spin per account per server-calendar day.
create table if not exists public.fun_wheel_spins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  spin_day date not null default (timezone('utc', now())::date),
  reward_key text not null,
  points_awarded integer not null check (points_awarded > 0),
  created_at timestamptz not null default now(),
  unique (user_id, spin_day)
);
alter table public.fun_wheel_spins enable row level security;
revoke all on public.fun_wheel_spins from anon, authenticated;
grant select on public.fun_wheel_spins to authenticated;
drop policy if exists fun_wheel_spins_own_read on public.fun_wheel_spins;
create policy fun_wheel_spins_own_read on public.fun_wheel_spins
  for select to authenticated using ((select auth.uid()) = user_id);

create or replace function fun_internal.spin_fun_wheel()
returns table (reward_key text, points_awarded integer, total_points integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_roll integer;
  v_reward text;
  v_points integer;
  v_total integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;

  insert into public.fun_game_stats(user_id)
    values (v_uid) on conflict (user_id) do nothing;
  perform 1 from public.fun_game_stats where user_id = v_uid for update;

  if exists (
    select 1 from public.fun_wheel_spins
    where user_id = v_uid and spin_day = timezone('utc', now())::date
  ) then
    raise exception 'wheel_already_spun_today' using errcode = '23505';
  end if;

  v_roll := floor(random() * 100)::integer;
  if v_roll < 45 then v_reward := 'small'; v_points := 5;
  elsif v_roll < 75 then v_reward := 'bright'; v_points := 10;
  elsif v_roll < 90 then v_reward := 'gold'; v_points := 15;
  elsif v_roll < 98 then v_reward := 'grand'; v_points := 25;
  else v_reward := 'jackpot'; v_points := 50;
  end if;

  insert into public.fun_wheel_spins(user_id, spin_day, reward_key, points_awarded)
    values (v_uid, timezone('utc', now())::date, v_reward, v_points);

  update public.fun_game_stats
    set points = points + v_points, updated_at = now()
    where user_id = v_uid
    returning points into v_total;

  return query select v_reward, v_points, v_total;
end;
$$;

revoke all on function fun_internal.record_fun_game_result() from public, anon, authenticated;
revoke all on function fun_internal.spin_fun_wheel() from public, anon;
grant execute on function fun_internal.spin_fun_wheel() to authenticated;

create or replace function public.spin_fun_wheel()
returns table (reward_key text, points_awarded integer, total_points integer)
language sql
security invoker
set search_path = ''
as $function$ select * from fun_internal.spin_fun_wheel(); $function$;
revoke all on function public.spin_fun_wheel() from public, anon;
grant execute on function public.spin_fun_wheel() to authenticated;

comment on table public.fun_game_stats is 'Persistent GapResan game points, ELO-style rating and verified human-match record.';
comment on table public.fun_wheel_spins is 'Server-authoritative daily wheel rewards; one spin per authenticated user per UTC day.';
