-- Make unread message state private to each account.
-- message_reads already exists in the live schema; do not create a parallel table.
-- The legacy messages.read_at column is shared and must not drive unread counts.

create or replace function public.get_unread_counts()
returns table(conversation_id uuid, unread_count bigint)
language sql
security definer
set search_path = public, pg_temp
as $function$
  select m.conversation_id, count(*)::bigint
    from public.messages m
    join public.conversation_members cm
      on cm.conversation_id = m.conversation_id
     and cm.user_id = (select auth.uid())
    left join public.message_reads mr
      on mr.message_id = m.id
     and mr.user_id = (select auth.uid())
   where (select auth.uid()) is not null
     and m.sender_id <> (select auth.uid())
     and m.deleted_at is null
     and mr.message_id is null
   group by m.conversation_id;
$function$;

revoke all on function public.get_unread_counts() from public, anon;
grant execute on function public.get_unread_counts() to authenticated;

-- Mark received messages as read only for the current account. This works
-- independently from the optional public message_read_receipts setting.
create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  uid uuid := auth.uid();
  affected integer;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
      from public.conversation_members cm
     where cm.conversation_id = p_conversation_id
       and cm.user_id = uid
  ) then
    raise exception 'Conversation membership required';
  end if;

  insert into public.message_reads (message_id, user_id, read_at)
  select m.id, uid, now()
    from public.messages m
   where m.conversation_id = p_conversation_id
     and m.sender_id <> uid
     and m.deleted_at is null
  on conflict (message_id, user_id) do nothing;

  get diagnostics affected = row_count;
  return affected;
end;
$function$;

revoke all on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- Keep public read receipts separate from private unread state. In particular,
-- do not update messages.read_at globally when just one member opens a chat.
create or replace function public.mark_messages_read(p_conversation_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  uid uuid := auth.uid();
  affected integer;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
      from public.conversation_members cm
     where cm.conversation_id = p_conversation_id
       and cm.user_id = uid
  ) then
    raise exception 'Conversation membership required';
  end if;

  insert into public.message_read_receipts (message_id, reader_id, read_at)
  select m.id, uid, now()
    from public.messages m
   where m.conversation_id = p_conversation_id
     and m.sender_id <> uid
     and m.deleted_at is null
  on conflict (message_id, reader_id) do nothing;

  get diagnostics affected = row_count;
  return affected;
end;
$function$;

revoke all on function public.mark_messages_read(uuid) from public, anon;
grant execute on function public.mark_messages_read(uuid) to authenticated;
