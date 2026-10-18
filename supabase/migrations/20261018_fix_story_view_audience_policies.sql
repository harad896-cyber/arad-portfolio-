-- A user may only create/update a story-view record for a story they were allowed to see.
-- This prevents forging views on expired or private stories to inflate view counts.
drop policy if exists story_views_insert_self on public.story_views;
create policy story_views_insert_self
on public.story_views
for insert to authenticated
with check (
  viewer_id = (select auth.uid())
  and exists (
    select 1
    from public.stories s
    where s.id = story_views.story_id
      and s.expires_at > now()
      and s.user_id <> (select auth.uid())
      and (
        s.audience = 'everyone'
        or (
          s.audience = 'contacts'
          and (
            exists (
              select 1 from public.contacts c
              where c.user_id = (select auth.uid()) and c.contact_id = s.user_id
            )
            or exists (
              select 1 from public.contacts c
              where c.user_id = s.user_id and c.contact_id = (select auth.uid())
            )
            or exists (
              select 1 from public.conversation_members cm
              where cm.user_id = (select auth.uid())
                and exists (
                  select 1 from public.conversation_members cm2
                  where cm2.conversation_id = cm.conversation_id
                    and cm2.user_id = s.user_id
                )
            )
          )
        )
      )
  )
);

drop policy if exists story_views_update_self on public.story_views;
create policy story_views_update_self
on public.story_views
for update to authenticated
using (
  viewer_id = (select auth.uid())
  and exists (
    select 1 from public.stories s
    where s.id = story_views.story_id
      and s.expires_at > now()
      and (
        s.audience = 'everyone'
        or (
          s.audience = 'contacts'
          and (
            exists (select 1 from public.contacts c where c.user_id = (select auth.uid()) and c.contact_id = s.user_id)
            or exists (select 1 from public.contacts c where c.user_id = s.user_id and c.contact_id = (select auth.uid()))
            or exists (
              select 1 from public.conversation_members cm
              where cm.user_id = (select auth.uid())
                and exists (select 1 from public.conversation_members cm2 where cm2.conversation_id = cm.conversation_id and cm2.user_id = s.user_id)
            )
          )
        )
      )
  )
)
with check (
  viewer_id = (select auth.uid())
  and exists (
    select 1 from public.stories s
    where s.id = story_views.story_id
      and s.expires_at > now()
      and s.user_id <> (select auth.uid())
      and (
        s.audience = 'everyone'
        or (
          s.audience = 'contacts'
          and (
            exists (select 1 from public.contacts c where c.user_id = (select auth.uid()) and c.contact_id = s.user_id)
            or exists (select 1 from public.contacts c where c.user_id = s.user_id and c.contact_id = (select auth.uid()))
            or exists (
              select 1 from public.conversation_members cm
              where cm.user_id = (select auth.uid())
                and exists (select 1 from public.conversation_members cm2 where cm2.conversation_id = cm.conversation_id and cm2.user_id = s.user_id)
            )
          )
        )
      )
  )
);
