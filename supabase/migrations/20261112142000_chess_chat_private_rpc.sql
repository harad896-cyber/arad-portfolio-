create schema if not exists private;
revoke all on schema private from public,anon;
grant usage on schema private to authenticated;

create or replace function private.send_chess_room_message_impl(
  p_room_id uuid, p_kind text, p_body text default null, p_media_path text default null
) returns uuid
language plpgsql security definer set search_path=''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_room public.chess_rooms;
  v_peer uuid;
  v_chat boolean;
  v_quick boolean;
  v_voice boolean;
  v_id uuid;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='28000'; end if;
  select * into v_room from public.chess_rooms where id=p_room_id for update;
  if not found or v_room.status<>'active' then raise exception 'chess_room_not_active' using errcode='55000'; end if;
  if v_uid=v_room.player_white_id then v_peer:=v_room.player_black_id;
  elsif v_uid=v_room.player_black_id then v_peer:=v_room.player_white_id;
  else raise exception 'not_a_chess_participant' using errcode='42501'; end if;
  if v_peer is null then raise exception 'opponent_not_connected' using errcode='55000'; end if;
  if exists(select 1 from public.user_blocks b where
    (b.blocker_id=v_uid and b.blocked_id=v_peer) or (b.blocker_id=v_peer and b.blocked_id=v_uid)) then
    raise exception 'chess_chat_blocked' using errcode='42501';
  end if;
  select coalesce(p.chat_enabled,true),coalesce(p.quick_messages_enabled,true),coalesce(p.voice_enabled,true)
    into v_chat,v_quick,v_voice
    from (select 1) seed
    left join public.chess_room_preferences p on p.room_id=p_room_id and p.user_id=v_peer;
  if not v_chat then raise exception 'opponent_chat_disabled' using errcode='42501'; end if;
  if p_kind is null or p_kind not in ('text','quick','voice') then raise exception 'invalid_chess_message_type' using errcode='22023'; end if;
  if p_kind='text' and (p_body is null or char_length(btrim(p_body)) not between 1 and 500 or p_media_path is not null) then
    raise exception 'invalid_chess_text' using errcode='22023';
  end if;
  if p_kind='quick' and (not v_quick or p_body is null or p_body not in ('سلام! 👋','بازی خوبی داشته باشی!','حرکت جالبی بود!','آفرین!','موفق باشی!','من آماده‌ام.','عجله نکن 🙂','ممنون از بازی!') or p_media_path is not null) then
    raise exception 'quick_message_not_allowed' using errcode='42501';
  end if;
  if p_kind='voice' then
    if not v_voice or p_body is not null or p_media_path is null
      or p_media_path not like p_room_id::text || '/' || v_uid::text || '/%' then
      raise exception 'invalid_chess_voice' using errcode='22023';
    end if;
    if not exists(select 1 from storage.objects o where o.bucket_id='chess-voice'
      and o.name=p_media_path and o.owner_id=v_uid::text) then
      raise exception 'chess_voice_upload_missing' using errcode='22023';
    end if;
  end if;
  if (select count(*) from public.chess_room_messages m
      where m.room_id=p_room_id and m.sender_id=v_uid
      and m.created_at>now()-interval '10 seconds')>=5 then
    raise exception 'chess_chat_rate_limited' using errcode='54000';
  end if;
  insert into public.chess_room_messages(room_id,sender_id,message_type,body,media_path)
  values(p_room_id,v_uid,p_kind,case when p_kind='voice' then null else btrim(p_body) end,p_media_path)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function private.send_chess_room_message_impl(uuid,text,text,text) from public,anon;
grant execute on function private.send_chess_room_message_impl(uuid,text,text,text) to authenticated;

create or replace function public.send_chess_room_message(
  p_room_id uuid, p_kind text, p_body text default null, p_media_path text default null
) returns uuid
language sql security invoker set search_path=''
as $$
  select private.send_chess_room_message_impl(p_room_id,p_kind,p_body,p_media_path);
$$;
revoke all on function public.send_chess_room_message(uuid,text,text,text) from public,anon;
grant execute on function public.send_chess_room_message(uuid,text,text,text) to authenticated;