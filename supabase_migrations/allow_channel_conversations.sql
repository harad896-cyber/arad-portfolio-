-- Allow channels as a conversation type.
alter table public.conversations drop constraint if exists conversations_type_check;
alter table public.conversations add constraint conversations_type_check
  check (type = any (array['direct'::text, 'group'::text, 'channel'::text]));

-- Let the conversation creator register themselves as owner.
drop policy if exists conversation_admins_insert_owner on public.conversation_admins;
create policy conversation_admins_insert_owner on public.conversation_admins
for insert to authenticated
with check (
  (
    user_id = (select c.created_by from public.conversations c where c.id = conversation_admins.conversation_id)
    and role = 'owner'
  )
  or
  (
    role = 'admin'
    and user_id <> (select c.created_by from public.conversations c where c.id = conversation_admins.conversation_id)
    and (select private.is_group_admin(conversation_admins.conversation_id, (select auth.uid())))
  )
);
