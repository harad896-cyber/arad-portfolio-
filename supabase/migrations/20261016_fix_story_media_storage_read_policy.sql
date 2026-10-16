-- Allow authenticated users to read story media only when the matching story row is visible to them.
-- The stories table's RLS policy remains the source of truth for audience and expiry.
drop policy if exists stories_storage_select on storage.objects;

create policy stories_storage_select on storage.objects
for select to authenticated
using (
  bucket_id = 'stories'
  and (
    (storage.foldername(name))[1] = (select auth.uid()::text)
    or exists (
      select 1
      from public.stories s
      where s.media_path = storage.objects.name
        and s.expires_at > now()
    )
  )
);
