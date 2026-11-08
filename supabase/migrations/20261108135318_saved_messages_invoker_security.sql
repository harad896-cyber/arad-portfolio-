-- Restrict Saved Messages membership creation to the owner and avoid a SECURITY DEFINER RPC.
drop policy if exists members_insert_creator_or_group_admin on public.conversation_members;
create policy members_insert_creator_or_group_admin
  on public.conversation_members
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.conversations c
      where c.id = conversation_members.conversation_id
        and c.created_by = (select auth.uid())
        and (
          c.type = any (array['group'::text, 'channel'::text])
          or (c.type = 'saved' and conversation_members.user_id = (select auth.uid()))
        )
    )
    or private.is_group_admin(conversation_id, (select auth.uid()))
  );

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
