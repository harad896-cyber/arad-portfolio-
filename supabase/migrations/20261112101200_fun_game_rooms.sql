-- Online turn-based games for GapResan.
-- All matchmaking and moves are validated atomically in Postgres.
create table if not exists public.fun_game_rooms (
  id uuid primary key default gen_random_uuid(),
  game_type text not null check (game_type in ('tic_tac_toe', 'connect_four')),
  status text not null default 'waiting' check (status in ('waiting', 'active', 'finished', 'cancelled')),
  player_one_id uuid not null references auth.users(id) on delete cascade,
  player_two_id uuid references auth.users(id) on delete set null,
  turn_user_id uuid references auth.users(id) on delete set null,
  board text not null,
  winner_id uuid references auth.users(id) on delete set null,
  version integer not null default 0 check (version >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  finished_at timestamptz,
  constraint fun_game_room_not_self check (player_two_id is null or player_two_id <> player_one_id),
  constraint fun_game_board_length check (
    (game_type = 'tic_tac_toe' and char_length(board) = 9)
    or (game_type = 'connect_four' and char_length(board) = 42)
  )
);

create index if not exists fun_game_waiting_match_idx
  on public.fun_game_rooms (game_type, created_at)
  where status = 'waiting' and player_two_id is null;
create index if not exists fun_game_players_idx
  on public.fun_game_rooms (player_one_id, player_two_id, updated_at desc);

alter table public.fun_game_rooms enable row level security;
revoke all on public.fun_game_rooms from anon, authenticated;
grant select on public.fun_game_rooms to authenticated;
drop policy if exists fun_game_room_participant_read on public.fun_game_rooms;
create policy fun_game_room_participant_read
  on public.fun_game_rooms for select to authenticated
  using ((select auth.uid()) = player_one_id or (select auth.uid()) = player_two_id);

create or replace function public.join_fun_game_queue(p_game_type text)
returns public.fun_game_rooms
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_room public.fun_game_rooms;
  v_board text;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode = '28000'; end if;
  if p_game_type not in ('tic_tac_toe', 'connect_four') then
    raise exception 'unsupported_game_type' using errcode = '22023';
  end if;

  -- Reuse this user's still-open queue ticket rather than creating duplicates.
  select * into v_room
  from public.fun_game_rooms
  where status = 'waiting' and player_two_id is null
    and player_one_id = v_uid and game_type = p_game_type
    and created_at > now() - interval '5 minutes'
  order by created_at desc
  limit 1
  for update;

  if found then return v_room; end if;

  -- Claim one compatible waiting room atomically; concurrent joins skip locked rows.
  select * into v_room
  from public.fun_game_rooms
  where status = 'waiting' and player_two_id is null
    and player_one_id <> v_uid and game_type = p_game_type
    and created_at > now() - interval '5 minutes'
  order by created_at asc
  limit 1
  for update skip locked;

  if found then
    update public.fun_game_rooms
      set player_two_id = v_uid, status = 'active',
          turn_user_id = player_one_id, version = version + 1, updated_at = now()
      where id = v_room.id
      returning * into v_room;
    return v_room;
  end if;

  v_board := case when p_game_type = 'tic_tac_toe' then '.........' else repeat('0', 42) end;
  insert into public.fun_game_rooms(game_type, player_one_id, turn_user_id, board)
    values (p_game_type, v_uid, v_uid, v_board)
    returning * into v_room;
  return v_room;
end;
$$;

create or replace function public.submit_fun_game_move(
  p_room_id uuid,
  p_expected_version integer,
  p_move integer
)
returns public.fun_game_rooms
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_room public.fun_game_rooms;
  v_board text;
  v_mark text;
  v_next uuid;
  v_won boolean := false;
  v_draw boolean := false;
  v_row integer;
  v_col integer;
  v_pos integer;
  v_dr integer;
  v_dc integer;
  v_sign integer;
  v_r integer;
  v_c integer;
  v_count integer;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode = '28000'; end if;
  select * into v_room from public.fun_game_rooms where id = p_room_id for update;
  if not found then raise exception 'game_room_not_found' using errcode = 'P0002'; end if;
  if v_uid <> v_room.player_one_id and v_uid is distinct from v_room.player_two_id then
    raise exception 'not_a_game_participant' using errcode = '42501';
  end if;
  if v_room.status <> 'active' then raise exception 'game_not_active' using errcode = '55000'; end if;
  if v_room.turn_user_id <> v_uid then raise exception 'not_your_turn' using errcode = '55000'; end if;
  if v_room.version <> p_expected_version then raise exception 'stale_game_version' using errcode = '40001'; end if;

  v_mark := case when v_uid = v_room.player_one_id then 'X' else 'O' end;
  v_board := v_room.board;

  if v_room.game_type = 'tic_tac_toe' then
    if p_move < 0 or p_move > 8 then raise exception 'invalid_move' using errcode = '22023'; end if;
    if substr(v_board, p_move + 1, 1) <> '.' then raise exception 'cell_occupied' using errcode = '22023'; end if;
    v_board := overlay(v_board placing v_mark from p_move + 1 for 1);
    v_won :=
      (substr(v_board,1,1)=v_mark and substr(v_board,2,1)=v_mark and substr(v_board,3,1)=v_mark) or
      (substr(v_board,4,1)=v_mark and substr(v_board,5,1)=v_mark and substr(v_board,6,1)=v_mark) or
      (substr(v_board,7,1)=v_mark and substr(v_board,8,1)=v_mark and substr(v_board,9,1)=v_mark) or
      (substr(v_board,1,1)=v_mark and substr(v_board,4,1)=v_mark and substr(v_board,7,1)=v_mark) or
      (substr(v_board,2,1)=v_mark and substr(v_board,5,1)=v_mark and substr(v_board,8,1)=v_mark) or
      (substr(v_board,3,1)=v_mark and substr(v_board,6,1)=v_mark and substr(v_board,9,1)=v_mark) or
      (substr(v_board,1,1)=v_mark and substr(v_board,5,1)=v_mark and substr(v_board,9,1)=v_mark) or
      (substr(v_board,3,1)=v_mark and substr(v_board,5,1)=v_mark and substr(v_board,7,1)=v_mark);
    v_draw := not v_won and position('.' in v_board) = 0;
  else
    if p_move < 0 or p_move > 6 then raise exception 'invalid_move' using errcode = '22023'; end if;
    v_pos := 0;
    for v_row in reverse 5..0 loop
      v_pos := v_row * 7 + p_move + 1;
      if substr(v_board, v_pos, 1) = '0' then exit; end if;
      v_pos := 0;
    end loop;
    if v_pos = 0 then raise exception 'column_full' using errcode = '22023'; end if;
    v_board := overlay(v_board placing case when v_mark = 'X' then '1' else '2' end from v_pos for 1);
    v_row := (v_pos - 1) / 7;
    v_col := (v_pos - 1) % 7;
    foreach v_dr in array array[0,1,1,1] loop
      if v_dr = 0 then v_dc := 1;
      elsif v_dr = 1 then
        -- Evaluate vertical and both diagonal directions in separate passes below.
        v_dc := 0;
      end if;
      for v_sign in -1..1 loop
        if v_sign = 0 then continue; end if;
        v_count := 1;
        v_r := v_row + v_dr * v_sign;
        v_c := v_col + v_dc * v_sign;
        while v_r between 0 and 5 and v_c between 0 and 6
          and substr(v_board, v_r * 7 + v_c + 1, 1) = case when v_mark = 'X' then '1' else '2' end
        loop
          v_count := v_count + 1;
          v_r := v_r + v_dr * v_sign;
          v_c := v_c + v_dc * v_sign;
        end loop;
        if v_count >= 4 then v_won := true; end if;
      end loop;
    end loop;
    -- Diagonal (1,1) and (1,-1) win checks.
    foreach v_dc in array array[1,-1] loop
      v_count := 1;
      for v_sign in -1..1 loop
        if v_sign = 0 then continue; end if;
        v_r := v_row + v_sign;
        v_c := v_col + v_dc * v_sign;
        while v_r between 0 and 5 and v_c between 0 and 6
          and substr(v_board, v_r * 7 + v_c + 1, 1) = case when v_mark = 'X' then '1' else '2' end
        loop
          v_count := v_count + 1;
          v_r := v_r + v_sign;
          v_c := v_c + v_dc * v_sign;
        end loop;
      end loop;
      if v_count >= 4 then v_won := true; end if;
    end loop;
    v_draw := not v_won and position('0' in v_board) = 0;
  end if;

  v_next := case when v_uid = v_room.player_one_id then v_room.player_two_id else v_room.player_one_id end;
  update public.fun_game_rooms
    set board = v_board,
        status = case when v_won or v_draw then 'finished' else 'active' end,
        winner_id = case when v_won then v_uid else null end,
        turn_user_id = case when v_won or v_draw then null else v_next end,
        version = version + 1,
        updated_at = now(),
        finished_at = case when v_won or v_draw then now() else null end
    where id = p_room_id
    returning * into v_room;
  return v_room;
end;
$$;

create or replace function public.cancel_fun_game_queue(p_room_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'authentication_required' using errcode = '28000'; end if;
  update public.fun_game_rooms
    set status = 'cancelled', updated_at = now()
    where id = p_room_id and player_one_id = v_uid
      and status = 'waiting' and player_two_id is null;
  return found;
end;
$$;

revoke all on function public.join_fun_game_queue(text) from public, anon;
revoke all on function public.submit_fun_game_move(uuid, integer, integer) from public, anon;
revoke all on function public.cancel_fun_game_queue(uuid) from public, anon;
grant execute on function public.join_fun_game_queue(text) to authenticated;
grant execute on function public.submit_fun_game_move(uuid, integer, integer) to authenticated;
grant execute on function public.cancel_fun_game_queue(uuid) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'fun_game_rooms'
  ) then
    alter publication supabase_realtime add table public.fun_game_rooms;
  end if;
end;
$$;

comment on table public.fun_game_rooms is 'Private, turn-based GapResan game rooms. Only participants can read; moves are validated through RPC.';
