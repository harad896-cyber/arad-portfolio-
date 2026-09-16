create table if not exists public.saved_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_message_id uuid null,
  body text,
  message_type text not null default 'text',
  created_at timestamptz not null default now(),
  unique(user_id, source_message_id)
);

alter table public.saved_messages enable row level security;

drop policy if exists "saved_messages_select_own" on public.saved_messages;
create policy "saved_messages_select_own" on public.saved_messages
for select using (auth.uid() = user_id);

drop policy if exists "saved_messages_insert_own" on public.saved_messages;
create policy "saved_messages_insert_own" on public.saved_messages
for insert with check (auth.uid() = user_id);

drop policy if exists "saved_messages_delete_own" on public.saved_messages;
create policy "saved_messages_delete_own" on public.saved_messages
for delete using (auth.uid() = user_id);
