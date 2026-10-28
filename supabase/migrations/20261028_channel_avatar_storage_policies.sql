-- Allow channel owners/admins to upload and replace channel avatars.
-- Keep the path scoped to channels/<conversation UUID>/... and verify admin rights server-side.
drop policy if exists channel_avatar_admin_insert on storage.objects;
create policy channel_avatar_admin_insert
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = 'channels'
  and case
    when (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.is_conversation_admin(((storage.foldername(name))[2])::uuid)
    else false
  end
);

drop policy if exists channel_avatar_admin_update on storage.objects;
create policy channel_avatar_admin_update
on storage.objects
for update to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = 'channels'
  and case
    when (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.is_conversation_admin(((storage.foldername(name))[2])::uuid)
    else false
  end
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = 'channels'
  and case
    when (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.is_conversation_admin(((storage.foldername(name))[2])::uuid)
    else false
  end
);

drop policy if exists channel_avatar_admin_delete on storage.objects;
create policy channel_avatar_admin_delete
on storage.objects
for delete to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = 'channels'
  and case
    when (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.is_conversation_admin(((storage.foldername(name))[2])::uuid)
    else false
  end
);
