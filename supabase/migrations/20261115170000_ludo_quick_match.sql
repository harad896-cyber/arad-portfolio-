-- Atomic public Ludo quick-match queue.
-- A room row is locked while a seat is allocated so concurrent joiners cannot
-- overbook the same room. Public rooms are visible only through the RPC path.
create or replace function public.quick_match_ludo_room(p_game_mode text default 'standard')
returns public.ludo_rooms
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_room public.ludo_rooms;
  v_seat integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='28000';
  end if;
  if p_game_mode not in ('standard','one_piece') then
    raise exception 'invalid_game_mode' using errcode='22023';
  end if;

  select r.* into v_room
  from public.ludo_rooms r
  where r.status='lobby'
    and r.is_private=false
    and r.game_mode=p_game_mode
    and r.expires_at>now()
    and r.host_id<>v_uid
    and not exists (
      select 1 from public.ludo_room_players mine
      where mine.room_id=r.id and mine.user_id=v_uid
    )
    and (select count(*) from public.ludo_room_players p where p.room_id=r.id)<r.max_players
  order by r.created_at asc
  limit 1
  for update skip locked;

  if not found then
    return public.create_ludo_room(4::smallint,false,p_game_mode,false);
  end if;

  select seat_no into v_seat
  from generate_series(0,(v_room.max_players-1)::integer) as seat_no
  where not exists (
    select 1 from public.ludo_room_players p
    where p.room_id=v_room.id and p.seat=seat_no
  )
  order by seat_no
  limit 1;

  if v_seat is null then
    raise exception 'ludo_room_full' using errcode='55000';
  end if;

  insert into public.ludo_room_players(room_id,user_id,seat,color)
  values (
    v_room.id,
    v_uid,
    v_seat,
    case v_seat when 0 then 'red' when 1 then 'blue' when 2 then 'yellow' else 'green' end
  );

  update public.ludo_rooms set updated_at=now() where id=v_room.id returning * into v_room;
  return v_room;
end;
$$;

revoke all on function public.quick_match_ludo_room(text) from public,anon;
grant execute on function public.quick_match_ludo_room(text) to authenticated;
