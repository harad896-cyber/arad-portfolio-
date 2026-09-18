create table if not exists public.chat_mutes (
 user_id uuid not null references auth.users(id) on delete cascade,
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 muted_until timestamptz,
 created_at timestamptz not null default now(),
 primary key(user_id,conversation_id)
);
alter table public.chat_mutes enable row level security;
grant select,insert,update,delete on public.chat_mutes to authenticated;
drop policy if exists chat_mutes_select_own on public.chat_mutes;
create policy chat_mutes_select_own on public.chat_mutes for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists chat_mutes_insert_own on public.chat_mutes;
create policy chat_mutes_insert_own on public.chat_mutes for insert to authenticated with check ((select auth.uid())=user_id and exists(select 1 from public.conversation_members cm where cm.conversation_id=chat_mutes.conversation_id and cm.user_id=(select auth.uid())));
drop policy if exists chat_mutes_update_own on public.chat_mutes;
create policy chat_mutes_update_own on public.chat_mutes for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
drop policy if exists chat_mutes_delete_own on public.chat_mutes;
create policy chat_mutes_delete_own on public.chat_mutes for delete to authenticated using ((select auth.uid())=user_id);