drop policy if exists fun_game_voice_broadcast_read on realtime.messages;
create policy fun_game_voice_broadcast_read on realtime.messages for select to authenticated using (
  extension='broadcast' and exists(
    select 1 from public.fun_game_rooms r
    where ('fun-game-voice:'||r.id::text)=realtime.topic()
      and ((select auth.uid())=r.player_one_id or (select auth.uid())=r.player_two_id)
  )
);
drop policy if exists fun_game_voice_broadcast_send on realtime.messages;
create policy fun_game_voice_broadcast_send on realtime.messages for insert to authenticated with check (
  extension='broadcast' and exists(
    select 1 from public.fun_game_rooms r
    where ('fun-game-voice:'||r.id::text)=realtime.topic()
      and ((select auth.uid())=r.player_one_id or (select auth.uid())=r.player_two_id)
  )
);