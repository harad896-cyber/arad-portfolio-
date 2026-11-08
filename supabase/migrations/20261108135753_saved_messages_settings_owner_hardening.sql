-- Ensure customization rows can only point to the signed-in user's own saved conversation.
alter table public.conversations
  drop constraint if exists conversations_saved_private_only;
alter table public.conversations
  add constraint conversations_saved_private_only
  check (
    type <> 'saved'
    or (created_by is not null and is_public = false and invite_code is null)
  );

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
    if v_owner is null
       or new.user_id is distinct from v_owner
       or new.role is distinct from 'member' then
      raise exception 'Saved Messages is private to its owner'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_saved_chat_single_owner() from public, anon, authenticated;

drop policy if exists saved_chat_settings_select_own on public.saved_chat_settings;
create policy saved_chat_settings_select_own
  on public.saved_chat_settings for select to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.conversations c
      where c.id = saved_chat_settings.conversation_id
        and c.type = 'saved'
        and c.created_by = (select auth.uid())
    )
  );

drop policy if exists saved_chat_settings_insert_own on public.saved_chat_settings;
create policy saved_chat_settings_insert_own
  on public.saved_chat_settings for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.conversations c
      where c.id = saved_chat_settings.conversation_id
        and c.type = 'saved'
        and c.created_by = (select auth.uid())
    )
  );

drop policy if exists saved_chat_settings_update_own on public.saved_chat_settings;
create policy saved_chat_settings_update_own
  on public.saved_chat_settings for update to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.conversations c
      where c.id = saved_chat_settings.conversation_id
        and c.type = 'saved'
        and c.created_by = (select auth.uid())
    )
  )
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.conversations c
      where c.id = saved_chat_settings.conversation_id
        and c.type = 'saved'
        and c.created_by = (select auth.uid())
    )
  );

drop policy if exists saved_chat_settings_delete_own on public.saved_chat_settings;
create policy saved_chat_settings_delete_own
  on public.saved_chat_settings for delete to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.conversations c
      where c.id = saved_chat_settings.conversation_id
        and c.type = 'saved'
        and c.created_by = (select auth.uid())
    )
  );
