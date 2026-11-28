drop policy if exists chess_voice_participant_insert on storage.objects;
create policy chess_voice_participant_insert on storage.objects for insert to authenticated
with check (
  bucket_id='chess-voice'
  and owner_id=(select auth.uid())::text
  and (storage.foldername(name))[2]=(select auth.uid())::text
  and case
    when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then exists (
      select 1 from public.chess_rooms r
      where r.id=((storage.foldername(name))[1])::uuid
        and ((select auth.uid())=r.player_white_id or (select auth.uid())=r.player_black_id)
    )
    else false
  end
);
drop policy if exists chess_voice_participant_read on storage.objects;
create policy chess_voice_participant_read on storage.objects for select to authenticated
using (
  bucket_id='chess-voice'
  and case
    when (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then exists (
      select 1 from public.chess_rooms r
      where r.id=((storage.foldername(name))[1])::uuid
        and ((select auth.uid())=r.player_white_id or (select auth.uid())=r.player_black_id)
    )
    else false
  end
);