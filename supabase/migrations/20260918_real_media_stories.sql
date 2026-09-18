-- Real media stories: image/video, 24h expiry, views, realtime, and protected Storage.
create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  media_path text,
  media_type text not null default 'text' check (media_type in ('text','image','video')),
  caption text,
  text text,
  background text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

alter table public.stories alter column text drop not null;
alter table public.stories alter column background drop not null;
alter table public.stories add column if not exists media_path text;
alter table public.stories add column if not exists media_type text not null default 'text';
alter table public.stories add column if not exists caption text;
alter table public.stories drop constraint if exists stories_media_type_check;
alter table public.stories add constraint stories_media_type_check check (media_type in ('text','image','video'));

create table if not exists public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

alter table public.stories enable row level security;
alter table public.story_views enable row level security;
grant select, insert, update, delete on public.stories to authenticated;
grant select, insert, update, delete on public.story_views to authenticated;

drop policy if exists stories_select_authenticated on public.stories;
create policy stories_select_authenticated on public.stories for select to authenticated
using (expires_at > now() and (user_id = (select auth.uid()) or exists (
  select 1 from public.conversation_members cm
  where cm.user_id = (select auth.uid())
    and exists (select 1 from public.conversation_members cm2 where cm2.conversation_id=cm.conversation_id and cm2.user_id=stories.user_id)
)));

drop policy if exists stories_insert_own on public.stories;
create policy stories_insert_own on public.stories for insert to authenticated
with check (user_id = (select auth.uid()) and expires_at > now() and expires_at <= now() + interval '24 hours');

drop policy if exists stories_update_own on public.stories;
create policy stories_update_own on public.stories for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists stories_delete_own on public.stories;
create policy stories_delete_own on public.stories for delete to authenticated
using (user_id = (select auth.uid()));

drop policy if exists story_views_select_relevant on public.story_views;
create policy story_views_select_relevant on public.story_views for select to authenticated
using (viewer_id = (select auth.uid()) or exists (select 1 from public.stories s where s.id=story_views.story_id and s.user_id=(select auth.uid())));

drop policy if exists story_views_insert_self on public.story_views;
create policy story_views_insert_self on public.story_views for insert to authenticated
with check (viewer_id=(select auth.uid()) and exists (select 1 from public.stories s where s.id=story_views.story_id and s.expires_at > now()));

drop policy if exists story_views_update_self on public.story_views;
create policy story_views_update_self on public.story_views for update to authenticated
using (viewer_id=(select auth.uid())) with check (viewer_id=(select auth.uid()));

drop policy if exists story_views_delete_self on public.story_views;
create policy story_views_delete_self on public.story_views for delete to authenticated
using (viewer_id=(select auth.uid()));

create index if not exists stories_user_expiry_idx on public.stories(user_id, expires_at desc);
create index if not exists story_views_story_idx on public.story_views(story_id, viewed_at desc);

alter publication supabase_realtime add table public.stories;
alter publication supabase_realtime add table public.story_views;

insert into storage.buckets (id,name,public,file_size_limit)
select 'stories','stories',false,52428800
where not exists (select 1 from storage.buckets where id='stories');

drop policy if exists stories_storage_insert on storage.objects;
create policy stories_storage_insert on storage.objects for insert to authenticated
with check (bucket_id='stories' and (storage.foldername(name))[1]=(select auth.uid()::text));

drop policy if exists stories_storage_select on storage.objects;
create policy stories_storage_select on storage.objects for select to authenticated
using (bucket_id='stories' and storage.allow_any_operation(array['object.get_authenticated']));

drop policy if exists stories_storage_update on storage.objects;
create policy stories_storage_update on storage.objects for update to authenticated
using (bucket_id='stories' and (storage.foldername(name))[1]=(select auth.uid()::text))
with check (bucket_id='stories' and (storage.foldername(name))[1]=(select auth.uid()::text));

drop policy if exists stories_storage_delete on storage.objects;
create policy stories_storage_delete on storage.objects for delete to authenticated
using (bucket_id='stories' and (storage.foldername(name))[1]=(select auth.uid()::text));