-- Prevent self-enrollment into arbitrary private chats.
-- Direct conversations are created atomically through a guarded RPC.
create or replace function public.create_direct_conversation(p_peer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare
  uid uuid := auth.uid();
  cid uuid;
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_peer_id is null or p_peer_id = uid then
    raise exception 'invalid_peer';
  end if;
  if not exists (select 1 from auth.users where id = p_peer_id) then
    raise exception 'user_not_found';
  end if;

  select c.id into cid
  from public.conversations c
  where c.type = 'direct'
    and exists (
      select 1 from public.conversation_members cm
      where cm.conversation_id = c.id and cm.user_id = uid
    )
    and exists (
      select 1 from public.conversation_members cm
      where cm.conversation_id = c.id and cm.user_id = p_peer_id
    )
    and (
      select count(*) from public.conversation_members cm
      where cm.conversation_id = c.id
    ) = 2
  order by c.created_at desc
  limit 1;

  if cid is not null then
    return cid;
  end if;

  insert into public.conversations(type, created_by)
  values ('direct', uid)
  returning id into cid;

  insert into public.conversation_members(conversation_id, user_id, role)
  values (cid, uid, 'member'), (cid, p_peer_id, 'member');

  return cid;
end;
$function$;

revoke all on function public.create_direct_conversation(uuid) from public, anon;
grant execute on function public.create_direct_conversation(uuid) to authenticated;

drop policy if exists members_insert_self_or_creator on public.conversation_members;
drop policy if exists members_insert_creator_or_group_admin on public.conversation_members;
create policy members_insert_creator_or_group_admin
on public.conversation_members
for insert to authenticated
with check (
  exists (
    select 1
    from public.conversations c
    where c.id = conversation_members.conversation_id
      and c.created_by = (select auth.uid())
      and c.type in ('group', 'channel')
  )
  or private.is_group_admin(conversation_members.conversation_id, (select auth.uid()))
);

-- Message updates are limited to fields used by the client; IDs, sender, and conversation
-- membership cannot be rewritten by a client to move messages into another chat.
drop policy if exists messages_sender_update on public.messages;
create policy messages_sender_update
on public.messages
for update to authenticated
using (
  sender_id = (select auth.uid())
  and deleted_at is null
  and exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = messages.conversation_id
      and cm.user_id = (select auth.uid())
  )
)
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = messages.conversation_id
      and cm.user_id = (select auth.uid())
  )
  and (deleted_at is null or body is null)
);
revoke update on table public.messages from authenticated;
grant update (body, edited_at, deleted_at) on table public.messages to authenticated;

-- Call participants and conversation identity must be immutable after call creation.
drop policy if exists call_sessions_update_participant on public.call_sessions;
create policy call_sessions_update_participant
on public.call_sessions
for update to authenticated
using (
  caller_id = (select auth.uid())
  or callee_id = (select auth.uid())
)
with check (
  caller_id = (select auth.uid())
  or callee_id = (select auth.uid())
);
revoke update on table public.call_sessions from authenticated;
grant update (status, accepted_at, ended_at, offer_sdp) on table public.call_sessions to authenticated;
