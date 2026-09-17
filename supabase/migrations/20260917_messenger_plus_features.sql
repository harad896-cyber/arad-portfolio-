-- Messenger Plus: server-side primitives for saved messages, chat settings and media index.
create table if not exists public.saved_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  message_id uuid not null references public.messages(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_id, message_id)
);
alter table public.saved_messages enable row level security;
drop policy if exists saved_messages_owner on public.saved_messages;
create policy saved_messages_owner on public.saved_messages for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.chat_settings (
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  wallpaper text not null default 'پیش‌فرض',
  muted boolean not null default false,
  pinned boolean not null default false,
  archived boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key(user_id, conversation_id)
);
alter table public.chat_settings enable row level security;
drop policy if exists chat_settings_owner on public.chat_settings;
create policy chat_settings_owner on public.chat_settings for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.save_message(p_message_id uuid)
returns void language plpgsql security invoker set search_path=public as $$
begin
  if not exists (select 1 from public.messages m join public.conversation_members cm on cm.conversation_id=m.conversation_id and cm.user_id=auth.uid() where m.id=p_message_id) then raise exception 'message_not_accessible'; end if;
  insert into public.saved_messages(user_id,message_id) values(auth.uid(),p_message_id) on conflict do nothing;
end; $$;

grant execute on function public.save_message(uuid) to authenticated;
