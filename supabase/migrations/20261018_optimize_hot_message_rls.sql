-- Cache auth.uid() as an init plan instead of evaluating it for every row on hot chat paths.
drop policy if exists messages_select_member on public.messages;
create policy messages_select_member
on public.messages
for select to authenticated
using (
  exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = messages.conversation_id
      and cm.user_id = (select auth.uid())
  )
);

drop policy if exists messages_insert_member on public.messages;
create policy messages_insert_member
on public.messages
for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1
    from public.conversation_members cm
    join public.conversations c on c.id = cm.conversation_id
    where cm.conversation_id = messages.conversation_id
      and cm.user_id = (select auth.uid())
      and (
        c.type <> 'channel'
        or c.only_admins_can_post = false
        or c.created_by = (select auth.uid())
        or cm.role = 'admin'
      )
      and (
        c.type <> 'group'
        or c.only_admins_can_post = false
        or c.created_by = (select auth.uid())
        or cm.role = any (array['admin'::text, 'owner'::text])
      )
      and not exists (
        select 1
        from public.group_member_restrictions r
        where r.conversation_id = messages.conversation_id
          and r.user_id = (select auth.uid())
          and (r.expires_at is null or r.expires_at > now())
          and (
            coalesce(r.can_send_messages, true) = false
            or (
              coalesce(r.can_send_media, true) = false
              and lower(coalesce(messages.message_type, 'text'::text)) = any (
                array['image','video','audio','voice','file','document','sticker','gif','media']::text[]
              )
            )
            or (
              coalesce(r.can_send_links, true) = false
              and coalesce(messages.body, ''::text) ~* '(https?://|www\.)'
            )
          )
      )
  )
);

drop policy if exists reactions_insert_self on public.message_reactions;
create policy reactions_insert_self
on public.message_reactions
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.messages m
    join public.conversation_members cm on cm.conversation_id = m.conversation_id
    join public.conversations c on c.id = m.conversation_id
    where m.id = message_reactions.message_id
      and cm.user_id = (select auth.uid())
      and coalesce(c.allow_reactions, true) = true
  )
);
