create table if not exists public.chat_pins (
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  pinned_at timestamptz not null default now(),
  primary key(user_id,conversation_id)
);
alter table public.chat_pins enable row level security;
grant select,insert,delete on public.chat_pins to authenticated;
drop policy if exists "chat_pins_select_own" on public.chat_pins;
create policy "chat_pins_select_own" on public.chat_pins for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists "chat_pins_insert_own" on public.chat_pins;
create policy "chat_pins_insert_own" on public.chat_pins for insert to authenticated with check ((select auth.uid())=user_id and exists(select 1 from public.conversation_members cm where cm.conversation_id=chat_pins.conversation_id and cm.user_id=(select auth.uid())));
drop policy if exists "chat_pins_delete_own" on public.chat_pins;
create policy "chat_pins_delete_own" on public.chat_pins for delete to authenticated using ((select auth.uid())=user_id);

-- CI verification trigger: keep schema unchanged.
