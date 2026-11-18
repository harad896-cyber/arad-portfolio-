-- Server-authoritative Ludo match lifecycle and turn actions.
alter table public.ludo_rooms
  add column if not exists game_state jsonb,
  add column if not exists state_version bigint not null default 0,
  add column if not exists started_at timestamptz,
  add column if not exists finished_at timestamptz,
  add column if not exists last_action_at timestamptz;

create or replace function private.ludo_room_legal_moves(p_state jsonb, p_dice integer)
returns integer[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_players integer := jsonb_array_length(p_state->'players');
  v_turn integer := (p_state->>'turn')::integer;
  v_offset integer;
  v_owner_offset integer;
  v_current integer;
  v_destination integer;
  v_square integer;
  v_count integer;
  v_piece integer;
  v_owner integer;
  v_other_piece integer;
  v_progress integer;
  v_step integer;
  v_start integer;
  v_end integer;
  v_blocked boolean;
  v_legal integer[] := array[]::integer[];
begin
  if p_dice < 1 or p_dice > 6 or v_players < 2 or v_players > 4
     or v_turn < 0 or v_turn >= v_players then
    raise exception 'invalid_ludo_state' using errcode = '22023';
  end if;

  v_offset := case
    when v_players = 2 and v_turn = 1 then 26
    else (array[0,39,26,13])[v_turn + 1]
  end;

  for v_piece in 0..3 loop
    v_current := (p_state->'pieces'->v_turn->>v_piece)::integer;
    if v_current = 57 then continue; end if;
    if v_current = -1 and p_dice <> 6 then continue; end if;
    if v_current >= 0 and v_current + p_dice > 57 then continue; end if;

    v_start := case when v_current = -1 then 0 else v_current + 1 end;
    v_end := case when v_current = -1 then 0 else v_current + p_dice end;
    v_blocked := false;

    for v_step in v_start..v_end loop
      if v_step < 0 or v_step > 50 then continue; end if;
      v_square := mod(v_offset + v_step, 52);

      for v_owner in 0..v_players - 1 loop
        v_owner_offset := case
          when v_players = 2 and v_owner = 1 then 26
          else (array[0,39,26,13])[v_owner + 1]
        end;
        v_count := 0;
        for v_other_piece in 0..3 loop
          v_progress := (p_state->'pieces'->v_owner->>v_other_piece)::integer;
          if v_progress between 0 and 50
             and mod(v_owner_offset + v_progress, 52) = v_square then
            v_count := v_count + 1;
          end if;
        end loop;
        if v_count >= 2 then
          v_blocked := true;
          exit;
        end if;
      end loop;
      if v_blocked then exit; end if;
    end loop;

    if v_blocked then continue; end if;

    v_destination := case when v_current = -1 then 0 else v_current + p_dice end;
    if v_destination between 0 and 50 then
      v_square := mod(v_offset + v_destination, 52);
      v_count := 0;
      for v_other_piece in 0..3 loop
        if v_other_piece = v_piece then continue; end if;
        v_progress := (p_state->'pieces'->v_turn->>v_other_piece)::integer;
        if v_progress between 0 and 50
           and mod(v_offset + v_progress, 52) = v_square then
          v_count := v_count + 1;
        end if;
      end loop;
      if v_count > 0 then continue; end if;
    end if;

    v_legal := array_append(v_legal, v_piece);
  end loop;

  return v_legal;
end;
$$;

create or replace function private.ludo_next_active_seat(p_state jsonb, p_from integer)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_count integer := jsonb_array_length(p_state->'players');
  v_candidate integer;
  v_step integer;
  v_winners jsonb := coalesce(p_state->'winners', '[]'::jsonb);
begin
  for v_step in 1..v_count loop
    v_candidate := mod(p_from + v_step, v_count);
    if not exists (
      select 1
      from jsonb_array_elements_text(v_winners) as w(value)
      where w.value::integer = v_candidate
    ) then
      return v_candidate;
    end if;
  end loop;
  return p_from;
end;
$$;

create or replace function public.start_ludo_match(p_room_id uuid)
returns public.ludo_rooms
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_room public.ludo_rooms;
  v_player_count integer;
  v_ready_count integer;
  v_players jsonb;
  v_pieces jsonb;
  v_state jsonb;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;

  select * into v_room
  from public.ludo_rooms
  where id = p_room_id
  for update;

  if not found then raise exception 'ludo_room_expired_or_missing'; end if;
  if v_room.host_id <> v_uid then raise exception 'ludo_host_only_start'; end if;
  if v_room.status <> 'lobby' or v_room.expires_at <= now() then
    raise exception 'ludo_room_not_startable';
  end if;

  select count(*)::integer, count(*) filter (where is_ready)::integer
    into v_player_count, v_ready_count
  from public.ludo_room_players
  where room_id = p_room_id;

  if v_player_count < 2 then raise exception 'ludo_need_two_players'; end if;
  if v_player_count > v_room.max_players then raise exception 'ludo_room_full'; end if;
  if v_ready_count <> v_player_count then raise exception 'ludo_players_not_ready'; end if;

  select
    jsonb_agg(jsonb_build_object('id', user_id::text, 'seat', seat) order by seat),
    jsonb_agg(jsonb_build_array(-1, -1, -1, -1) order by seat)
  into v_players, v_pieces
  from public.ludo_room_players
  where room_id = p_room_id;

  v_state := jsonb_build_object(
    'players', v_players,
    'pieces', v_pieces,
    'turn', 0,
    'dice', null,
    'phase', 'awaiting_roll',
    'sixStreak', 0,
    'winners', '[]'::jsonb
  );

  update public.ludo_rooms
  set status = 'playing',
      game_state = v_state,
      state_version = 1,
      started_at = now(),
      finished_at = null,
      last_action_at = now(),
      updated_at = now()
  where id = p_room_id
  returning * into v_room;

  return v_room;
end;
$$;

create or replace function public.roll_ludo_dice(p_room_id uuid, p_expected_version bigint)
returns public.ludo_rooms
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_room public.ludo_rooms;
  v_state jsonb;
  v_turn integer;
  v_players integer;
  v_dice integer;
  v_streak integer;
  v_legal integer[];
  v_next integer;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode = '28000'; end if;

  select * into v_room from public.ludo_rooms where id = p_room_id for update;
  if not found or v_room.status <> 'playing' or v_room.game_state is null then
    raise exception 'ludo_match_not_active';
  end if;
  if not public.is_ludo_room_member(p_room_id) then raise exception 'ludo_room_member_required'; end if;
  if v_room.state_version <> p_expected_version then raise exception 'ludo_stale_state' using errcode = '40001'; end if;

  v_state := v_room.game_state;
  v_players := jsonb_array_length(v_state->'players');
  v_turn := (v_state->>'turn')::integer;
  if v_state->>'phase' <> 'awaiting_roll' then raise exception 'ludo_roll_not_allowed'; end if;
  if v_state->'players'->v_turn->>'id' <> v_uid::text then raise exception 'ludo_not_your_turn'; end if;

  v_dice := floor(random() * 6)::integer + 1;
  v_streak := coalesce((v_state->>'sixStreak')::integer, 0);

  if v_dice = 6 and v_streak >= 2 then
    v_next := private.ludo_next_active_seat(v_state, v_turn);
    v_state := jsonb_set(v_state, '{turn}', to_jsonb(v_next), true);
    v_state := jsonb_set(v_state, '{sixStreak}', '0'::jsonb, true);
    v_state := jsonb_set(v_state, '{dice}', jsonb_build_object(
      'value', 6, 'legalMoves', '[]'::jsonb, 'burned', true, 'reason', 'three_sixes'
    ), true);
    v_state := jsonb_set(v_state, '{phase}', to_jsonb('awaiting_roll'::text), true);
  else
    v_streak := case when v_dice = 6 then v_streak + 1 else 0 end;
    v_legal := private.ludo_room_legal_moves(v_state, v_dice);
    v_state := jsonb_set(v_state, '{sixStreak}', to_jsonb(v_streak), true);

    if cardinality(v_legal) = 0 then
      if v_dice <> 6 then
        v_next := private.ludo_next_active_seat(v_state, v_turn);
        v_state := jsonb_set(v_state, '{turn}', to_jsonb(v_next), true);
        v_state := jsonb_set(v_state, '{sixStreak}', '0'::jsonb, true);
      end if;
      v_state := jsonb_set(v_state, '{dice}', jsonb_build_object(
        'value', v_dice,
        'legalMoves', '[]'::jsonb,
        'burned', false,
        'reason', 'no_legal_move',
        'resolvedNoMove', true,
        'extraRoll', (v_dice = 6)
      ), true);
      v_state := jsonb_set(v_state, '{phase}', to_jsonb('awaiting_roll'::text), true);
    else
      v_state := jsonb_set(v_state, '{dice}', jsonb_build_object(
        'value', v_dice,
        'legalMoves', to_jsonb(v_legal),
        'burned', false
      ), true);
      v_state := jsonb_set(v_state, '{phase}', to_jsonb('awaiting_move'::text), true);
    end if;
  end if;

  update public.ludo_rooms
  set game_state = v_state,
      state_version = state_version + 1,
      last_action_at = now(),
      updated_at = now()
  where id = p_room_id
  returning * into v_room;

  return v_room;
end;
$$;

create or replace function public.move_ludo_piece(p_room_id uuid, p_piece_index integer, p_expected_version bigint)
returns public.ludo_rooms
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_room public.ludo_rooms;
  v_state jsonb;
  v_pieces jsonb;
  v_turn integer;
  v_players integer;
  v_dice integer;
  v_current integer;
  v_destination integer;
  v_offset integer;
  v_owner_offset integer;
  v_square integer;
  v_owner integer;
  v_piece integer;
  v_progress integer;
  v_legal integer[];
  v_captured jsonb := '[]'::jsonb;
  v_winners jsonb;
  v_player_finished boolean := true;
  v_match_finished boolean;
  v_next integer;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode = '28000'; end if;
  if p_piece_index < 0 or p_piece_index > 3 then raise exception 'invalid_ludo_piece' using errcode = '22023'; end if;

  select * into v_room from public.ludo_rooms where id = p_room_id for update;
  if not found or v_room.status <> 'playing' or v_room.game_state is null then
    raise exception 'ludo_match_not_active';
  end if;
  if not public.is_ludo_room_member(p_room_id) then raise exception 'ludo_room_member_required'; end if;
  if v_room.state_version <> p_expected_version then raise exception 'ludo_stale_state' using errcode = '40001'; end if;

  v_state := v_room.game_state;
  v_players := jsonb_array_length(v_state->'players');
  v_turn := (v_state->>'turn')::integer;
  if v_state->>'phase' <> 'awaiting_move' then raise exception 'ludo_move_not_allowed'; end if;
  if v_state->'players'->v_turn->>'id' <> v_uid::text then raise exception 'ludo_not_your_turn'; end if;

  v_dice := (v_state->'dice'->>'value')::integer;
  v_legal := private.ludo_room_legal_moves(v_state, v_dice);
  if not p_piece_index = any(v_legal) then raise exception 'ludo_illegal_move'; end if;

  v_current := (v_state->'pieces'->v_turn->>p_piece_index)::integer;
  v_destination := case when v_current = -1 then 0 else v_current + v_dice end;
  v_pieces := v_state->'pieces';
  v_pieces := jsonb_set(v_pieces, array[v_turn::text, p_piece_index::text], to_jsonb(v_destination), true);

  v_offset := case
    when v_players = 2 and v_turn = 1 then 26
    else (array[0,39,26,13])[v_turn + 1]
  end;

  if v_destination between 0 and 50 then
    v_square := mod(v_offset + v_destination, 52);
    if v_square <> all(array[0,8,13,21,26,34,39,47]) then
      for v_owner in 0..v_players - 1 loop
        if v_owner = v_turn then continue; end if;
        v_owner_offset := case
          when v_players = 2 and v_owner = 1 then 26
          else (array[0,39,26,13])[v_owner + 1]
        end;
        for v_piece in 0..3 loop
          v_progress := (v_pieces->v_owner->>v_piece)::integer;
          if v_progress between 0 and 50 and mod(v_owner_offset + v_progress, 52) = v_square then
            v_pieces := jsonb_set(v_pieces, array[v_owner::text, v_piece::text], to_jsonb(-1), true);
            v_captured := v_captured || jsonb_build_array(jsonb_build_object('player', v_owner, 'piece', v_piece));
          end if;
        end loop;
      end loop;
    end if;
  end if;

  v_state := jsonb_set(v_state, '{pieces}', v_pieces, true);
  v_winners := coalesce(v_state->'winners', '[]'::jsonb);
  for v_piece in 0..3 loop
    if (v_pieces->v_turn->>v_piece)::integer <> 57 then
      v_player_finished := false;
      exit;
    end if;
  end loop;

  if v_player_finished and not exists (
    select 1 from jsonb_array_elements_text(v_winners) as w(value)
    where w.value::integer = v_turn
  ) then
    v_winners := v_winners || to_jsonb(v_turn);
  end if;
  v_state := jsonb_set(v_state, '{winners}', v_winners, true);
  v_match_finished := jsonb_array_length(v_winners) >= v_players - 1;

  if v_match_finished then
    v_state := jsonb_set(v_state, '{phase}', to_jsonb('finished'::text), true);
    v_state := jsonb_set(v_state, '{dice}', 'null'::jsonb, true);
    v_state := jsonb_set(v_state, '{sixStreak}', '0'::jsonb, true);
    update public.ludo_rooms
    set game_state = v_state,
        state_version = state_version + 1,
        last_action_at = now(),
        finished_at = now(),
        updated_at = now()
    where id = p_room_id
    returning * into v_room;
    return v_room;
  end if;

  if v_player_finished then
    v_next := private.ludo_next_active_seat(v_state, v_turn);
    v_state := jsonb_set(v_state, '{turn}', to_jsonb(v_next), true);
    v_state := jsonb_set(v_state, '{sixStreak}', '0'::jsonb, true);
    v_state := jsonb_set(v_state, '{dice}', 'null'::jsonb, true);
  elsif v_dice = 6 or jsonb_array_length(v_captured) > 0 then
    v_state := jsonb_set(v_state, '{dice}', jsonb_build_object(
      'value', v_dice,
      'legalMoves', to_jsonb(v_legal),
      'captured', v_captured,
      'movedPiece', p_piece_index,
      'burned', false
    ), true);
  else
    v_next := private.ludo_next_active_seat(v_state, v_turn);
    v_state := jsonb_set(v_state, '{turn}', to_jsonb(v_next), true);
    v_state := jsonb_set(v_state, '{sixStreak}', '0'::jsonb, true);
    v_state := jsonb_set(v_state, '{dice}', 'null'::jsonb, true);
  end if;

  v_state := jsonb_set(v_state, '{phase}', to_jsonb('awaiting_roll'::text), true);
  update public.ludo_rooms
  set game_state = v_state,
      state_version = state_version + 1,
      last_action_at = now(),
      updated_at = now()
  where id = p_room_id
  returning * into v_room;

  return v_room;
end;
$$;

revoke all on function public.start_ludo_match(uuid) from public, anon;
revoke all on function public.roll_ludo_dice(uuid, bigint) from public, anon;
revoke all on function public.move_ludo_piece(uuid, integer, bigint) from public, anon;
grant execute on function public.start_ludo_match(uuid) to authenticated;
grant execute on function public.roll_ludo_dice(uuid, bigint) to authenticated;
grant execute on function public.move_ludo_piece(uuid, integer, bigint) to authenticated;
revoke all on function private.ludo_room_legal_moves(jsonb, integer) from public, anon, authenticated;
revoke all on function private.ludo_next_active_seat(jsonb, integer) from public, anon, authenticated;
