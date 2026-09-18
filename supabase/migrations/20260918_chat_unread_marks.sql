create table if not exists public.chat_unread_marks (user_id uuid not null references auth.users(id) on delete cascade, conversation_id uuid not null references public.conversations(id) on delete cascade, marked_at timestamptz not null default now(), primary key(user_id,conversation_id));
alter table public.chat_unread_marks enable row level security;
grant select,insert,delete on public.chat_unread_marks to authenticated;
create policy "chat_unread_select_own" on public.chat_unread_marks for select to authenticated using ((select auth.uid())=user_id);
create policy "chat_unread_insert_own" on public.chat_unread_marks for insert to authenticated with check ((select auth.uid())=user_id and exists(select 1 from public.conversation_members cm where cm.conversation_id=chat_unread_marks.conversation_id and cm.user_id=(select auth.uid())));
create policy "chat_unread_delete_own" on public.chat_unread_marks for delete to authenticated using ((select auth.uid())=user_id);
