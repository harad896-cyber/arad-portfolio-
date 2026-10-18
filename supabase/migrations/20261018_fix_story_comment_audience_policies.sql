-- Remove permissive duplicate policies that bypass story audience checks.
-- Keep story_comments_select_visible and story_comments_insert_self, which enforce
-- the parent story's audience, expiry, and ownership rules.
drop policy if exists story_comments_select_visible_story on public.story_comments;
drop policy if exists story_comments_insert_visible_story on public.story_comments;
drop policy if exists story_comments_delete_self on public.story_comments;
