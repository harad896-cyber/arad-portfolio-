create table if not exists public.message_drafts (
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  body text not null default '',
  updated_at timestamptz not null default now(),
  primary key(user_id,conversation_id)
);
alter table public.message_drafts enable row level security;
grant select,insert,update,delete on public.message_drafts to authenticated;
drop policy if exists message_drafts_select_own on public.message_drafts;
create policy message_drafts_select_own on public.message_drafts for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists message_drafts_insert_own on public.message_drafts;
create policy message_drafts_insert_own on public.message_drafts for insert to authenticated with check ((select auth.uid())=user_id and exists(select 1 from public.conversation_members cm where cm.conversation_id=message_drafts.conversation_id and cm.user_id=(select auth.uid())));
drop policy if exists message_drafts_update_own on public.message_drafts;
create policy message_drafts_update_own on public.message_drafts for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id and exists(select 1 from public.conversation_members cm where cm.conversation_id=message_drafts.conversation_id and cm.user_id=(select auth.uid())));
drop policy if exists message_drafts_delete_own on public.message_drafts;
create policy message_drafts_delete_own on public.message_drafts for delete to authenticated using ((select auth.uid())=user_id);
create index if not exists message_drafts_updated_idx on public.message_drafts(user_id,updated_at desc);