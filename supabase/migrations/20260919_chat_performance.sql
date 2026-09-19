create or replace function public.mark_conversation_read(p_conversation_id uuid) returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;
begin
 update public.messages m set read_at=now()
 where m.conversation_id=p_conversation_id
   and m.sender_id <> auth.uid()
   and m.read_at is null
   and exists(select 1 from public.conversation_members cm where cm.conversation_id=p_conversation_id and cm.user_id=auth.uid());
 get diagnostics n=row_count;
 return n;
end $$;
revoke all on function public.mark_conversation_read(uuid) from public,anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;