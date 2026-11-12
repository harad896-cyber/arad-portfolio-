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
    set status='cancelled',updated_at=now()
    where id=p_room_id
      and (player_one_id=v_uid or player_two_id=v_uid)
      and status in ('waiting','active');
  return found;
end;
$$;
revoke all on function public.cancel_fun_game_queue(uuid) from public,anon;
grant execute on function public.cancel_fun_game_queue(uuid) to authenticated;
