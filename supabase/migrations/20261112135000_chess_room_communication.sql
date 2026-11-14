-- Secure live communication for future online GapResan chess rooms.
create table if not exists public.chess_rooms (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'waiting' check (status in ('waiting','active','finished','cancelled')),
  player_white_id uuid not null references auth.users(id) on delete cascade,
  player_black_id uuid references auth.users(id) on delete set null,
  fen text not null default 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  turn_user_id uuid references auth.users(id) on delete set null,
  version integer not null default 0 check (version >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  finished_at timestamptz,
  constraint chess_room_not_self check (player_black_id is null or player_black_id <> player_white_id)
);
create index if not exists chess_rooms_players_idx on public.chess_rooms(player_white_id,player_black_id,updated_at desc);
alter table public.chess_rooms enable row level security;
revoke all on public.chess_rooms from anon,authenticated;
grant select on public.chess_rooms to authenticated;
drop policy if exists chess_room_participant_read on public.chess_rooms;
create policy chess_room_participant_read on public.chess_rooms for select to authenticated
using ((select auth.uid())=player_white_id or (select auth.uid())=player_black_id);

create table if not exists public.chess_room_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.chess_rooms(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  message_type text not null check (message_type in ('text','quick','voice')),
  body text,
  media_path text,
  created_at timestamptz not null default now(),
  constraint chess_room_message_payload check (
    (message_type in ('text','quick') and body is not null and char_length(btrim(body)) between 1 and 500 and media_path is null)
    or (message_type='voice' and body is null and media_path is not null and char_length(media_path) between 1 and 500)
  )
);
create index if not exists chess_room_messages_room_time_idx on public.chess_room_messages(room_id,created_at desc);
alter table public.chess_room_messages enable row level security;
revoke all on public.chess_room_messages from anon,authenticated;
grant select on public.chess_room_messages to authenticated;
drop policy if exists chess_room_message_participant_read on public.chess_room_messages;
create policy chess_room_message_participant_read on public.chess_room_messages for select to authenticated
using (exists (
  select 1 from public.chess_rooms r
  where r.id=room_id and ((select auth.uid())=r.player_white_id or (select auth.uid())=r.player_black_id)
));

create table if not exists public.chess_room_preferences (
  room_id uuid not null references public.chess_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  chat_enabled boolean not null default true,
  quick_messages_enabled boolean not null default true,
  voice_enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key(room_id,user_id)
);
alter table public.chess_room_preferences enable row level security;
revoke all on public.chess_room_preferences from anon,authenticated;
grant select,insert,update on public.chess_room_preferences to authenticated;
drop policy if exists chess_room_preferences_own_read on public.chess_room_preferences;
create policy chess_room_preferences_own_read on public.chess_room_preferences for select to authenticated
using (user_id=(select auth.uid()) and exists (
  select 1 from public.chess_rooms r where r.id=room_id
  and ((select auth.uid())=r.player_white_id or (select auth.uid())=r.player_black_id)
));
drop policy if exists chess_room_preferences_own_insert on public.chess_room_preferences;
create policy chess_room_preferences_own_insert on public.chess_room_preferences for insert to authenticated
with check (user_id=(select auth.uid()) and exists (
  select 1 from public.chess_rooms r where r.id=room_id
  and ((select auth.uid())=r.player_white_id or (select auth.uid())=r.player_black_id)
));
drop policy if exists chess_room_preferences_own_update on public.chess_room_preferences;
create policy chess_room_preferences_own_update on public.chess_room_preferences for update to authenticated
using (user_id=(select auth.uid()) and exists (
  select 1 from public.chess_rooms r where r.id=room_id
  and ((select auth.uid())=r.player_white_id or (select auth.uid())=r.player_black_id)
))
with check (user_id=(select auth.uid()) and exists (
  select 1 from public.chess_rooms r where r.id=room_id
  and ((select auth.uid())=r.player_white_id or (select auth.uid())=r.player_black_id)
));

create table if not exists public.chess_room_reports (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.chess_rooms(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason in ('abuse','spam','inappropriate_voice','cheating','other')),
  details text check (details is null or char_length(details)<=500),
  created_at timestamptz not null default now(),
  constraint chess_report_not_self check (reporter_id<>reported_user_id)
);
alter table public.chess_room_reports enable row level security;
revoke all on public.chess_room_reports from anon,authenticated;
grant select,insert on public.chess_room_reports to authenticated;
drop policy if exists chess_room_report_own_read on public.chess_room_reports;
create policy chess_room_report_own_read on public.chess_room_reports for select to authenticated
using (reporter_id=(select auth.uid()));
drop policy if exists chess_room_report_participant_insert on public.chess_room_reports;
create policy chess_room_report_participant_insert on public.chess_room_reports for insert to authenticated
with check (reporter_id=(select auth.uid()) and exists (
  select 1 from public.chess_rooms r where r.id=room_id
  and ((r.player_white_id=(select auth.uid()) and r.player_black_id=reported_user_id)
    or (r.player_black_id=(select auth.uid()) and r.player_white_id=reported_user_id))
));

create or replace function public.send_chess_room_message(
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
revoke all on function public.send_chess_room_message(uuid,text,text,text) from public,anon;
grant execute on function public.send_chess_room_message(uuid,text,text,text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('chess-voice','chess-voice',false,2097152,array['audio/mp4','audio/webm','audio/aac','audio/m4a'])
on conflict(id) do update set public=false,file_size_limit=2097152,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists chess_voice_participant_insert on storage.objects;
create policy chess_voice_participant_insert on storage.objects for insert to authenticated
with check (bucket_id='chess-voice' and owner_id=(select auth.uid())::text
  and (storage.foldername(name))[2]=(select auth.uid())::text
  and case when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then exists(select 1 from public.chess_rooms r where r.id=((storage.foldername(name))[1])::uuid
      and ((select auth.uid())=r.player_white_id or (select auth.uid())=r.player_black_id))
    else false end);
drop policy if exists chess_voice_participant_read on storage.objects;
create policy chess_voice_participant_read on storage.objects for select to authenticated
using (bucket_id='chess-voice' and case when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  then exists(select 1 from public.chess_rooms r where r.id=((storage.foldername(name))[1])::uuid
    and ((select auth.uid())=r.player_white_id or (select auth.uid())=r.player_black_id))
  else false end);
drop policy if exists chess_voice_owner_delete on storage.objects;
create policy chess_voice_owner_delete on storage.objects for delete to authenticated
using (bucket_id='chess-voice' and owner_id=(select auth.uid())::text
  and (storage.foldername(name))[2]=(select auth.uid())::text);

do $$
begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
    and schemaname='public' and tablename='chess_room_messages') then
    alter publication supabase_realtime add table public.chess_room_messages;
  end if;
end;
$$;

comment on table public.chess_room_messages is 'Private in-match chess chat. Messages are inserted only through a participant-checked RPC.';
comment on table public.chess_room_preferences is 'Per-player chat, quick-message and voice preferences for a chess room.';
