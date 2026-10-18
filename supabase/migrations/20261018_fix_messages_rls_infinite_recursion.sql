-- Fix infinite RLS recursion: a restrictive messages INSERT policy must not query messages directly.
create or replace function private.conversation_has_prior_messages(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $function$
  select exists (
    select 1
    from public.messages m
    where m.conversation_id = p_conversation_id
  );
$function$;

revoke all on function private.conversation_has_prior_messages(uuid) from public, anon;
grant execute on function private.conversation_has_prior_messages(uuid) to authenticated;

drop policy if exists direct_messages_require_friendship on public.messages;
create policy direct_messages_require_friendship
on public.messages as restrictive
for insert to authenticated
with check (
  exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and (
        c.type <> 'direct'
        or exists (
          select 1
          from public.conversation_members peer
          join public.friend_requests fr
            on fr.status = 'accepted'
           and (
             (fr.requester_id = (select auth.uid()) and fr.recipient_id = peer.user_id)
             or (fr.requester_id = peer.user_id and fr.recipient_id = (select auth.uid()))
           )
          where peer.conversation_id = c.id
            and peer.user_id <> (select auth.uid())
        )
        or private.conversation_has_prior_messages(c.id)
      )
  )
);
