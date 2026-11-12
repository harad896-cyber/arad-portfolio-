-- In-match chat and private voice notes for authenticated game-room participants.
create table if not exists public.fun_game_room_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.fun_game_rooms(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  message_type text not null check (message_type in ('text','voice')),
  body text,
  media_path text,
  created_at timestamptz not null default now(),
  constraint fun_game_message_payload check (
    (message_type='text' and body is not null and char_length(btrim(body)) between 1 and 500 and media_path is null)
    or (message_type='voice' and body is null and media_path is not null and char_length(media_path) between 1 and 500)
  )
);
create index if not exists fun_game_room_messages_room_time_idx
  on public.fun_game_room_messages(room_id,created_at desc);
alter table public.fun_game_room_messages enable row level security;
revoke all on public.fun_game_room_messages from anon,authenticated;
grant select on public.fun_game_room_messages to authenticated;
drop policy if exists fun_game_room_messages_participant_read on public.fun_game_room_messages;
create policy fun_game_room_messages_participant_read on public.fun_game_room_messages
for select to authenticated using (
  exists(select 1 from public.fun_game_rooms r
    where r.id=room_id and
      ((select auth.uid())=r.player_one_id or (select auth.uid())=r.player_two_id))
);

create or replace function public.send_fun_game_room_message(
  p_room_id uuid, p_kind text, p_body text default null, p_media_path text default null
) returns uuid
language plpgsql security definer set search_path=''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_room public.fun_game_rooms;
  v_peer uuid;
  v_id uuid;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='28000'; end if;
  select * into v_room from public.fun_game_rooms where id=p_room_id for update;
  if not found or v_room.status not in ('active','finished') then
    raise exception 'game_room_not_available' using errcode='55000';
  end if;
  if v_uid=v_room.player_one_id then v_peer:=v_room.player_two_id;
  elsif v_uid=v_room.player_two_id then v_peer:=v_room.player_one_id;
  else raise exception 'not_a_game_participant' using errcode='42501'; end if;
  if v_peer is null then raise exception 'opponent_not_connected' using errcode='55000'; end if;
  if p_kind not in ('text','voice') then raise exception 'invalid_message_type' using errcode='22023'; end if;
  if p_kind='text' and (p_body is null or char_length(btrim(p_body)) not between 1 and 500 or p_media_path is not null) then
    raise exception 'invalid_game_text' using errcode='22023';
  end if;
  if p_kind='voice' then
    if p_body is not null or p_media_path is null
      or p_media_path not like p_room_id::text || '/' || v_uid::text || '/%' then
      raise exception 'invalid_game_voice' using errcode='22023';
    end if;
    if not exists(select 1 from storage.objects o where o.bucket_id='fun-game-voice'
      and o.name=p_media_path and o.owner_id=v_uid::text) then
      raise exception 'game_voice_upload_missing' using errcode='22023';
    end if;
  end if;
  if (select count(*) from public.fun_game_room_messages m
      where m.room_id=p_room_id and m.sender_id=v_uid
      and m.created_at>now()-interval '10 seconds')>=6 then
    raise exception 'game_chat_rate_limited' using errcode='54000';
  end if;
  insert into public.fun_game_room_messages(room_id,sender_id,message_type,body,media_path)
  values(p_room_id,v_uid,p_kind,case when p_kind='voice' then null else btrim(p_body) end,p_media_path)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.send_fun_game_room_message(uuid,text,text,text) from public,anon;
grant execute on function public.send_fun_game_room_message(uuid,text,text,text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('fun-game-voice','fun-game-voice',false,2097152,array['audio/mp4','audio/webm','audio/aac','audio/m4a'])
on conflict(id) do update set public=false,file_size_limit=2097152,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists fun_game_voice_participant_insert on storage.objects;
create policy fun_game_voice_participant_insert on storage.objects for insert to authenticated
with check (bucket_id='fun-game-voice' and owner_id=(select auth.uid())::text
  and (storage.foldername(name))[2]=(select auth.uid())::text
  and case when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then exists(select 1 from public.fun_game_rooms r where r.id=((storage.foldername(name))[1])::uuid
      and ((select auth.uid())=r.player_one_id or (select auth.uid())=r.player_two_id))
    else false end);
drop policy if exists fun_game_voice_participant_read on storage.objects;
create policy fun_game_voice_participant_read on storage.objects for select to authenticated
using (bucket_id='fun-game-voice' and case when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  then exists(select 1 from public.fun_game_rooms r where r.id=((storage.foldername(name))[1])::uuid
    and ((select auth.uid())=r.player_one_id or (select auth.uid())=r.player_two_id))
  else false end);
drop policy if exists fun_game_voice_owner_delete on storage.objects;
create policy fun_game_voice_owner_delete on storage.objects for delete to authenticated
using (bucket_id='fun-game-voice' and owner_id=(select auth.uid())::text
  and (storage.foldername(name))[2]=(select auth.uid())::text);

do $$
begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
    and schemaname='public' and tablename='fun_game_room_messages') then
    alter publication supabase_realtime add table public.fun_game_room_messages;
  end if;
end;
$$;
