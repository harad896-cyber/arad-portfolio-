-- Support both object paths and legacy signed/public URLs in stories.media_path.
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
      where s.expires_at > now()
        and (
          s.media_path = storage.objects.name
          or regexp_replace(
            split_part(coalesce(s.media_path, ''), '?', 1),
            '^https?://[^/]+/storage/v1/object/(sign|public)/stories/',
            ''
          ) = storage.objects.name
          or regexp_replace(coalesce(s.media_path, ''), '^/+', '') = storage.objects.name
        )
    )
  )
);
