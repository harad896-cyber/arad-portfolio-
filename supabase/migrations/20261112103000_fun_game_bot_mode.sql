alter table public.fun_game_rooms
  add column if not exists is_bot_game boolean not null default false,
  add column if not exists winner_mark text check (winner_mark in ('X','O'));

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
  v_board := case when p_game_type = 'tic_tac_toe' then '.........' else repeat('0',42) end;
  insert into public.fun_game_rooms(game_type,status,player_one_id,turn_user_id,board,is_bot_game)
    values(p_game_type,'active',v_uid,v_uid,v_board,true)
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
  if v_room.is_bot_game then
    if v_uid <> v_room.player_one_id or v_room.turn_user_id <> v_uid then
      raise exception 'not_your_turn' using errcode = '55000';
    end if;
    v_mark := case when mod(v_room.version,2)=0 then 'X' else 'O' end;
    v_next := v_uid;
  else
    if v_room.turn_user_id <> v_uid then raise exception 'not_your_turn' using errcode = '55000'; end if;
    v_mark := case when v_uid = v_room.player_one_id then 'X' else 'O' end;
    v_next := case when v_uid = v_room.player_one_id then v_room.player_two_id else v_room.player_one_id end;
  end if;
  if v_room.version <> p_expected_version then raise exception 'stale_game_version' using errcode = '40001'; end if;

  v_board := v_room.board;
  if v_room.game_type = 'tic_tac_toe' then
    if p_move < 0 or p_move > 8 then raise exception 'invalid_move' using errcode = '22023'; end if;
    if substr(v_board,p_move+1,1) <> '.' then raise exception 'cell_occupied' using errcode = '22023'; end if;
    v_board := overlay(v_board placing v_mark from p_move+1 for 1);
    v_won :=
      (substr(v_board,1,1)=v_mark and substr(v_board,2,1)=v_mark and substr(v_board,3,1)=v_mark) or
      (substr(v_board,4,1)=v_mark and substr(v_board,5,1)=v_mark and substr(v_board,6,1)=v_mark) or
      (substr(v_board,7,1)=v_mark and substr(v_board,8,1)=v_mark and substr(v_board,9,1)=v_mark) or
      (substr(v_board,1,1)=v_mark and substr(v_board,4,1)=v_mark and substr(v_board,7,1)=v_mark) or
      (substr(v_board,2,1)=v_mark and substr(v_board,5,1)=v_mark and substr(v_board,8,1)=v_mark) or
      (substr(v_board,3,1)=v_mark and substr(v_board,6,1)=v_mark and substr(v_board,9,1)=v_mark) or
      (substr(v_board,1,1)=v_mark and substr(v_board,5,1)=v_mark and substr(v_board,9,1)=v_mark) or
      (substr(v_board,3,1)=v_mark and substr(v_board,5,1)=v_mark and substr(v_board,7,1)=v_mark);
    v_draw := not v_won and position('.' in v_board)=0;
  else
    if p_move < 0 or p_move > 6 then raise exception 'invalid_move' using errcode = '22023'; end if;
    v_pos := 0;
    for v_row in reverse 5..0 loop
      v_pos := v_row*7+p_move+1;
      if substr(v_board,v_pos,1)='0' then exit; end if;
      v_pos := 0;
    end loop;
    if v_pos=0 then raise exception 'column_full' using errcode = '22023'; end if;
    v_board := overlay(v_board placing (case when v_mark='X' then '1' else '2' end) from v_pos for 1);
    v_row := (v_pos-1)/7;
    v_col := (v_pos-1)%7;
    -- Horizontal and vertical lines.
    foreach v_dr in array array[0,1] loop
      v_dc := case when v_dr=0 then 1 else 0 end;
      v_count := 1;
      for v_sign in -1..1 loop
        if v_sign=0 then continue; end if;
        v_r := v_row+v_dr*v_sign;
        v_c := v_col+v_dc*v_sign;
        while v_r between 0 and 5 and v_c between 0 and 6
          and substr(v_board,v_r*7+v_c+1,1)=case when v_mark='X' then '1' else '2' end
        loop
          v_count:=v_count+1;v_r:=v_r+v_dr*v_sign;v_c:=v_c+v_dc*v_sign;
        end loop;
      end loop;
      if v_count>=4 then v_won:=true;end if;
    end loop;
    -- Both diagonal directions.
    foreach v_dc in array array[1,-1] loop
      v_count:=1;
      for v_sign in -1..1 loop
        if v_sign=0 then continue;end if;
        v_r:=v_row+v_sign;v_c:=v_col+v_dc*v_sign;
        while v_r between 0 and 5 and v_c between 0 and 6
          and substr(v_board,v_r*7+v_c+1,1)=case when v_mark='X' then '1' else '2' end
        loop
          v_count:=v_count+1;v_r:=v_r+v_sign;v_c:=v_c+v_dc*v_sign;
        end loop;
      end loop;
      if v_count>=4 then v_won:=true;end if;
    end loop;
    v_draw:=not v_won and position('0' in v_board)=0;
  end if;

  update public.fun_game_rooms
    set board=v_board,
        status=case when v_won or v_draw then 'finished' else 'active' end,
        winner_id=case when v_won and (not v_room.is_bot_game or v_mark='X') then v_uid else null end,
        winner_mark=case when v_won then v_mark else null end,
        turn_user_id=case when v_won or v_draw then null else v_next end,
        version=version+1,updated_at=now(),
        finished_at=case when v_won or v_draw then now() else null end
    where id=p_room_id returning * into v_room;
  return v_room;
end;
$$;

revoke all on function public.start_fun_game_bot(text) from public,anon;
grant execute on function public.start_fun_game_bot(text) to authenticated;
revoke all on function public.submit_fun_game_move(uuid,integer,integer) from public,anon;
grant execute on function public.submit_fun_game_move(uuid,integer,integer) to authenticated;
