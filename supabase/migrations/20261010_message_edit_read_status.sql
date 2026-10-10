alter table public.messages
  add column if not exists edited_at timestamptz,
  add column if not exists read_at timestamptz;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  affected integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.messages as m
     set read_at = now()
   where m.conversation_id = p_conversation_id
     and m.sender_id <> auth.uid()
     and m.read_at is null
     and exists (
       select 1
         from public.conversation_members as cm
        where cm.conversation_id = p_conversation_id
          and cm.user_id = auth.uid()
     );

  get diagnostics affected = row_count;
  return affected;
end;
$$;

revoke all on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
