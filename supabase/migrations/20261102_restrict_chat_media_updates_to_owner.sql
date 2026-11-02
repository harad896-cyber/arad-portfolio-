drop policy if exists chat_media_insert_member on storage.objects;
create policy chat_media_insert_member
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'chat-media'
  and owner_id = (select auth.uid())::text
  and split_part(name, '/', 1) <> ''
  and exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = nullif(split_part(name, '/', 1), '')::uuid
      and cm.user_id = (select auth.uid())
  )
);

drop policy if exists chat_media_update_member on storage.objects;
create policy chat_media_update_owner
on storage.objects
for update
to authenticated
using (
  bucket_id = 'chat-media'
  and owner_id = (select auth.uid())::text
  and exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = nullif(split_part(name, '/', 1), '')::uuid
      and cm.user_id = (select auth.uid())
  )
)
with check (
  bucket_id = 'chat-media'
  and owner_id = (select auth.uid())::text
  and exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = nullif(split_part(name, '/', 1), '')::uuid
      and cm.user_id = (select auth.uid())
  )
);
