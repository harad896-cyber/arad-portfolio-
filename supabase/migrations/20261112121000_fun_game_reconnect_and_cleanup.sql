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
  if p_game_type not in ('tic_tac_toe','connect_four') then
    raise exception 'unsupported_game_type' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtext('gapresan_fun_game_queue:' || p_game_type)::bigint);

  update public.fun_game_rooms
    set status='cancelled',updated_at=now()
    where (status='waiting' and created_at<=now()-interval '5 minutes')
       or (status='active' and updated_at<=now()-interval '30 minutes');

  -- Let a player return to an active human match after a temporary disconnect.
  select * into v_room
  from public.fun_game_rooms
  where status='active' and game_type=p_game_type and not is_bot_game
    and (player_one_id=v_uid or player_two_id=v_uid)
  order by updated_at desc limit 1 for update;
  if found then return v_room; end if;

  select * into v_room
  from public.fun_game_rooms
  where status='waiting' and player_two_id is null
    and player_one_id=v_uid and game_type=p_game_type and not is_bot_game
    and created_at>now()-interval '5 minutes'
  order by created_at desc limit 1 for update;
  if found then return v_room; end if;

  select * into v_room
  from public.fun_game_rooms
  where status='waiting' and player_two_id is null
    and player_one_id<>v_uid and game_type=p_game_type and not is_bot_game
    and created_at>now()-interval '5 minutes'
  order by created_at asc limit 1 for update skip locked;
  if found then
    update public.fun_game_rooms set player_two_id=v_uid,status='active',
      turn_user_id=player_one_id,version=version+1,updated_at=now()
      where id=v_room.id returning * into v_room;
    return v_room;
  end if;

  v_board:=case when p_game_type='tic_tac_toe' then '.........' else repeat('0',42) end;
  insert into public.fun_game_rooms(game_type,player_one_id,turn_user_id,board)
    values(p_game_type,v_uid,v_uid,v_board) returning * into v_room;
  return v_room;
end;
$$;

create or replace function public.start_fun_game_bot(p_game_type text)
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
  if p_game_type not in ('tic_tac_toe','connect_four') then
    raise exception 'unsupported_game_type' using errcode = '22023';
  end if;
  update public.fun_game_rooms
    set status='cancelled',updated_at=now()
    where player_one_id=v_uid and game_type=p_game_type
      and is_bot_game and status='active';
  v_board:=case when p_game_type='tic_tac_toe' then '.........' else repeat('0',42) end;
  insert into public.fun_game_rooms(game_type,status,player_one_id,turn_user_id,board,is_bot_game)
    values(p_game_type,'active',v_uid,v_uid,v_board,true)
    returning * into v_room;
  return v_room;
end;
$$;

revoke all on function public.join_fun_game_queue(text) from public,anon;
revoke all on function public.start_fun_game_bot(text) from public,anon;
grant execute on function public.join_fun_game_queue(text) to authenticated;
grant execute on function public.start_fun_game_bot(text) to authenticated;
