-- Enable working story comments with row-level security.
create table if not exists public.story_comments (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 500),
  created_at timestamptz not null default now()
);

create index if not exists story_comments_story_created_idx
  on public.story_comments(story_id, created_at asc);

alter table public.story_comments enable row level security;
grant select, insert, delete on public.story_comments to authenticated;

drop policy if exists story_comments_select_visible_story on public.story_comments;
create policy story_comments_select_visible_story
  on public.story_comments for select to authenticated
  using (exists (
    select 1 from public.stories s
    where s.id = story_comments.story_id and s.expires_at > now()
  ));

drop policy if exists story_comments_insert_visible_story on public.story_comments;
create policy story_comments_insert_visible_story
  on public.story_comments for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and char_length(trim(body)) between 1 and 500
    and exists (
      select 1 from public.stories s
      where s.id = story_comments.story_id and s.expires_at > now()
    )
  );

drop policy if exists story_comments_delete_own on public.story_comments;
create policy story_comments_delete_own
  on public.story_comments for delete to authenticated
  using (user_id = (select auth.uid()));
