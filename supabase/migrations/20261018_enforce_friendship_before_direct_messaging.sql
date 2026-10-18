-- Friend requests gate new direct conversations and first direct messages/calls.
-- Existing direct conversations with message history remain usable for backward compatibility.
create or replace function public.create_direct_conversation(p_peer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare
  uid uuid := auth.uid();
  cid uuid;
  friendship_accepted boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_peer_id is null or p_peer_id = uid then raise exception 'invalid_peer'; end if;
  if not exists (select 1 from auth.users where id = p_peer_id) then raise exception 'user_not_found'; end if;

  select c.id into cid
  from public.conversations c
  where c.type = 'direct'
    and exists (select 1 from public.conversation_members cm where cm.conversation_id=c.id and cm.user_id=uid)
    and exists (select 1 from public.conversation_members cm where cm.conversation_id=c.id and cm.user_id=p_peer_id)
    and (select count(*) from public.conversation_members cm where cm.conversation_id=c.id)=2
    and exists (select 1 from public.messages m where m.conversation_id=c.id)
  order by c.created_at desc
  limit 1;
  if cid is not null then return cid; end if;

  select exists (
    select 1 from public.friend_requests fr
    where fr.status='accepted'
      and ((fr.requester_id=uid and fr.recipient_id=p_peer_id)
        or (fr.requester_id=p_peer_id and fr.recipient_id=uid))
  ) into friendship_accepted;
  if not friendship_accepted then
    raise exception 'friend_request_required';
  end if;

  select c.id into cid
  from public.conversations c
  where c.type='direct'
    and exists (select 1 from public.conversation_members cm where cm.conversation_id=c.id and cm.user_id=uid)
    and exists (select 1 from public.conversation_members cm where cm.conversation_id=c.id and cm.user_id=p_peer_id)
    and (select count(*) from public.conversation_members cm where cm.conversation_id=c.id)=2
  order by c.created_at desc
  limit 1;
  if cid is not null then return cid; end if;

  insert into public.conversations(type, created_by)
  values ('direct', uid)
  returning id into cid;
  insert into public.conversation_members(conversation_id,user_id,role)
  values (cid,uid,'member'),(cid,p_peer_id,'member');
  return cid;
end;
$function$;

revoke all on function public.create_direct_conversation(uuid) from public, anon;
grant execute on function public.create_direct_conversation(uuid) to authenticated;

drop policy if exists direct_messages_require_friendship on public.messages;
create policy direct_messages_require_friendship
on public.messages as restrictive
for insert to authenticated
with check (
  exists (
    select 1 from public.conversations c
    where c.id = messages.conversation_id
      and (
        c.type <> 'direct'
        or exists (
          select 1
          from public.conversation_members peer
          join public.friend_requests fr
            on fr.status='accepted'
           and (
             (fr.requester_id=(select auth.uid()) and fr.recipient_id=peer.user_id)
             or (fr.requester_id=peer.user_id and fr.recipient_id=(select auth.uid()))
           )
          where peer.conversation_id=c.id
            and peer.user_id <> (select auth.uid())
        )
        or exists (
          select 1 from public.messages prior
          where prior.conversation_id=c.id
        )
      )
  )
);

drop policy if exists direct_calls_require_friendship on public.call_sessions;
create policy direct_calls_require_friendship
on public.call_sessions as restrictive
for insert to authenticated
with check (
  exists (
    select 1 from public.conversations c
    where c.id=call_sessions.conversation_id
      and (
        c.type <> 'direct'
        or exists (
          select 1 from public.friend_requests fr
          where fr.status='accepted'
            and (
              (fr.requester_id=call_sessions.caller_id and fr.recipient_id=call_sessions.callee_id)
              or (fr.requester_id=call_sessions.callee_id and fr.recipient_id=call_sessions.caller_id)
            )
        )
        or exists (
          select 1 from public.messages prior
          where prior.conversation_id=c.id
        )
      )
  )
);
