-- Arad Messenger: end-to-end encrypted Secret Chat foundation.
-- Private X25519 identity keys stay on the device; only public keys are stored here.
create table if not exists public.e2ee_identity_keys (
  user_id uuid primary key references auth.users(id) on delete cascade,
  public_key text not null,
  key_version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.secret_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  ciphertext text not null,
  created_at timestamptz not null default now(),
  reply_to uuid null references public.secret_messages(id) on delete set null
);

alter table public.e2ee_identity_keys enable row level security;
alter table public.secret_messages enable row level security;

revoke all on table public.e2ee_identity_keys from anon;
revoke all on table public.secret_messages from anon;
grant select, insert, update on public.e2ee_identity_keys to authenticated;
grant select, insert on public.secret_messages to authenticated;

drop policy if exists e2ee_identity_select on public.e2ee_identity_keys;
create policy e2ee_identity_select on public.e2ee_identity_keys
for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1 from public.conversation_members mine
    join public.conversation_members peer on peer.conversation_id = mine.conversation_id
    where mine.user_id = (select auth.uid()) and peer.user_id = e2ee_identity_keys.user_id
  )
);

drop policy if exists e2ee_identity_insert on public.e2ee_identity_keys;
create policy e2ee_identity_insert on public.e2ee_identity_keys
for insert to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists e2ee_identity_update on public.e2ee_identity_keys;
create policy e2ee_identity_update on public.e2ee_identity_keys
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists secret_messages_select_member on public.secret_messages;
create policy secret_messages_select_member on public.secret_messages
for select to authenticated
using (exists (select 1 from public.conversation_members cm where cm.conversation_id = secret_messages.conversation_id and cm.user_id = (select auth.uid())));

drop policy if exists secret_messages_insert_member on public.secret_messages;
create policy secret_messages_insert_member on public.secret_messages
for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (select 1 from public.conversation_members cm where cm.conversation_id = secret_messages.conversation_id and cm.user_id = (select auth.uid()))
);

create index if not exists secret_messages_conversation_created_idx on public.secret_messages(conversation_id, created_at);

alter publication supabase_realtime add table public.secret_messages;
