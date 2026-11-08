-- Private, per-account self-chat for GapResan.
alter table public.conversations
  drop constraint if exists conversations_type_check;
alter table public.conversations
  add constraint conversations_type_check
  check (type = any (array['direct'::text, 'group'::text, 'channel'::text, 'saved'::text]));

create unique index if not exists conversations_one_saved_chat_per_user
  on public.conversations (created_by)
  where type = 'saved';

create table if not exists public.saved_chat_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  conversation_id uuid not null unique references public.conversations(id) on delete cascade,
  display_name text not null default 'پیام‌های ذخیره‌شده',
  avatar_path text,
  updated_at timestamptz not null default now()
);

alter table public.saved_chat_settings enable row level security;
revoke all on public.saved_chat_settings from anon;
grant select, insert, update, delete on public.saved_chat_settings to authenticated;

drop policy if exists saved_chat_settings_select_own on public.saved_chat_settings;
create policy saved_chat_settings_select_own
  on public.saved_chat_settings for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists saved_chat_settings_insert_own on public.saved_chat_settings;
create policy saved_chat_settings_insert_own
  on public.saved_chat_settings for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists saved_chat_settings_update_own on public.saved_chat_settings;
create policy saved_chat_settings_update_own
  on public.saved_chat_settings for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists saved_chat_settings_delete_own on public.saved_chat_settings;
create policy saved_chat_settings_delete_own
  on public.saved_chat_settings for delete to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.get_or_create_saved_messages()
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_conversation_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select c.id into v_conversation_id
  from public.conversations c
  where c.type = 'saved' and c.created_by = v_user_id
  limit 1;

  if v_conversation_id is null then
    insert into public.conversations (type, title, created_by, is_public)
    values ('saved', 'پیام‌های ذخیره‌شده', v_user_id, false)
    on conflict (created_by) where type = 'saved' do nothing
    returning id into v_conversation_id;

    if v_conversation_id is null then
      select c.id into v_conversation_id
      from public.conversations c
      where c.type = 'saved' and c.created_by = v_user_id
      limit 1;
    end if;
  end if;

  if v_conversation_id is null then
    raise exception 'Unable to create saved conversation';
  end if;

  insert into public.conversation_members (conversation_id, user_id, role)
  values (v_conversation_id, v_user_id, 'member')
  on conflict (conversation_id, user_id) do nothing;

  insert into public.saved_chat_settings (user_id, conversation_id)
  values (v_user_id, v_conversation_id)
  on conflict (user_id) do nothing;

  return v_conversation_id;
end;
$$;

revoke all on function public.get_or_create_saved_messages() from public, anon;
grant execute on function public.get_or_create_saved_messages() to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'saved-messages',
  'saved-messages',
  false,
  104857600,
  array[
    'image/*','video/*','audio/*','application/pdf',
    'text/plain','application/zip','application/octet-stream',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists saved_messages_storage_select_own on storage.objects;
create policy saved_messages_storage_select_own
  on storage.objects for select to authenticated
  using (
    bucket_id = 'saved-messages'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists saved_messages_storage_insert_own on storage.objects;
create policy saved_messages_storage_insert_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'saved-messages'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists saved_messages_storage_update_own on storage.objects;
create policy saved_messages_storage_update_own
  on storage.objects for update to authenticated
  using (
    bucket_id = 'saved-messages'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'saved-messages'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists saved_messages_storage_delete_own on storage.objects;
create policy saved_messages_storage_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'saved-messages'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
