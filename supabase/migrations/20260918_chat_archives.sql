-- Arad Messenger: per-user chat archive
create table if not exists public.chat_archives (
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  archived_at timestamptz not null default now(),
  primary key (user_id, conversation_id)
);
alter table public.chat_archives enable row level security;
grant select, insert, delete on public.chat_archives to authenticated;
create policy "chat_archives_select_own" on public.chat_archives for select to authenticated using ((select auth.uid())=user_id);
create policy "chat_archives_insert_own" on public.chat_archives for insert to authenticated with check ((select auth.uid())=user_id and exists(select 1 from public.conversation_members cm where cm.conversation_id=chat_archives.conversation_id and cm.user_id=(select auth.uid())));
create policy "chat_archives_delete_own" on public.chat_archives for delete to authenticated using ((select auth.uid())=user_id);
create index if not exists chat_archives_conversation_idx on public.chat_archives(conversation_id);