-- Prevent starting unsupported lobby variants and keep active matches alive for reconnects.
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
  if v_room.game_mode <> 'standard' then
    raise exception 'ludo_game_mode_not_supported';
  end if;
  if v_room.fill_with_bots then
    raise exception 'ludo_bots_not_supported';
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
      expires_at = now() + interval '2 hours',
      updated_at = now()
  where id = p_room_id
  returning * into v_room;

  return v_room;
end;
$$;

revoke all on function public.start_ludo_match(uuid) from public, anon;
grant execute on function public.start_ludo_match(uuid) to authenticated;
