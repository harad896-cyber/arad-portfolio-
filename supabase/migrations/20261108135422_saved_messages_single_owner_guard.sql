-- Enforce that a Saved Messages conversation can never gain another member.
alter table public.conversations
  drop constraint if exists conversations_saved_private_only;
alter table public.conversations
  add constraint conversations_saved_private_only
  check (type <> 'saved' or (is_public = false and invite_code is null));

create or replace function private.enforce_saved_chat_single_owner()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_type text;
  v_owner uuid;
begin
  select c.type, c.created_by
    into v_type, v_owner
  from public.conversations c
  where c.id = new.conversation_id;

  if v_type = 'saved' then
    if v_owner is null or new.user_id is distinct from v_owner or new.role <> 'member' then
      raise exception 'Saved Messages is private to its owner'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_saved_chat_single_owner() from public, anon, authenticated;

drop trigger if exists enforce_saved_chat_single_owner on public.conversation_members;
create trigger enforce_saved_chat_single_owner
  before insert or update on public.conversation_members
  for each row execute function private.enforce_saved_chat_single_owner();

create or replace function public.get_or_create_saved_messages()
returns uuid
language plpgsql
security invoker
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
    insert into public.conversations (type, title, created_by, is_public, invite_code)
    values ('saved', 'پیام‌های ذخیره‌شده', v_user_id, false, null)
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
