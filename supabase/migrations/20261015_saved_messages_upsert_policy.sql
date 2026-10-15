-- Upsert is used to make saving the same message idempotent.
-- PostgreSQL checks UPDATE privileges and UPDATE RLS policy when a conflict
-- hits an existing row; SELECT/INSERT policies alone are not sufficient.
alter table public.saved_messages enable row level security;

drop policy if exists "saved_messages_update_own" on public.saved_messages;
create policy "saved_messages_update_own" on public.saved_messages
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

grant select, insert, update, delete on public.saved_messages to authenticated;
