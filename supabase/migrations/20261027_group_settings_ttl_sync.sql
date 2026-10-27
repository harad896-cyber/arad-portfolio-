-- Keep the group's auto-delete setting connected to the TTL table used by
-- the messages_apply_ttl trigger and the scheduled expired-message cleanup.
create or replace function public.update_group_settings(
  p_conversation_id uuid,
  p_title text,
  p_description text,
  p_avatar_url text,
  p_is_public boolean,
  p_username text,
  p_join_approval boolean,
  p_only_admins_can_post boolean,
  p_only_admins_can_add boolean,
  p_auto_delete_seconds integer,
  p_allow_reactions boolean
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  uid uuid := auth.uid();
  v_type text;
  v_auto_delete_seconds integer;
  clean_username text := nullif(lower(trim(coalesce(p_username,''))), '');
begin
  if uid is null then raise exception 'not_authenticated'; end if;

  select type into v_type from public.conversations where id=p_conversation_id;
  if v_type='group' then
    if not public.has_group_admin_permission(p_conversation_id,'can_edit_group') then
      raise exception 'edit_group_not_permitted';
    end if;
  elsif v_type='channel' then
    if not public.is_conversation_admin(p_conversation_id) then
      raise exception 'not_conversation_admin';
    end if;
  else
    raise exception 'conversation_not_found';
  end if;

  if p_auto_delete_seconds is not null
     and p_auto_delete_seconds not in (0,86400,604800,2592000) then
    raise exception 'invalid_auto_delete_seconds';
  end if;

  if coalesce(p_is_public, false) and clean_username is null then
    raise exception 'public_conversation_requires_username';
  end if;
  if clean_username is not null and clean_username !~ '^[a-z0-9_]{3,32}$' then
    raise exception 'invalid_conversation_username';
  end if;
  if clean_username is not null and exists (
    select 1 from public.conversations
    where lower(username)=clean_username and id<>p_conversation_id
  ) then raise exception 'username_taken'; end if;

  update public.conversations set
    title=coalesce(nullif(trim(p_title),''),title),
    description=coalesce(p_description,description),
    avatar_url=coalesce(p_avatar_url,avatar_url),
    is_public=coalesce(p_is_public,is_public),
    username=case when p_username is null then username else clean_username end,
    join_approval=coalesce(p_join_approval,join_approval),
    only_admins_can_post=coalesce(p_only_admins_can_post,only_admins_can_post),
    only_admins_can_add=coalesce(p_only_admins_can_add,only_admins_can_add),
    auto_delete_seconds=coalesce(p_auto_delete_seconds,auto_delete_seconds),
    allow_reactions=coalesce(p_allow_reactions,allow_reactions)
  where id=p_conversation_id;

  if v_type='group' and p_auto_delete_seconds is not null then
    select auto_delete_seconds into v_auto_delete_seconds
      from public.conversations where id=p_conversation_id;
    if coalesce(v_auto_delete_seconds,0)=0 then
      delete from public.message_ttl where conversation_id=p_conversation_id;
    else
      insert into public.message_ttl(conversation_id,ttl_seconds,enabled_by,updated_at)
      values(p_conversation_id,v_auto_delete_seconds,uid,now())
      on conflict(conversation_id) do update
        set ttl_seconds=excluded.ttl_seconds,
            enabled_by=excluded.enabled_by,
            updated_at=now();
    end if;
  end if;

  insert into public.group_audit_logs(conversation_id,actor_id,action,details)
  values(p_conversation_id,uid,'settings_updated',jsonb_build_object(
    'is_public',p_is_public,'username',clean_username,'join_approval',p_join_approval,
    'only_admins_can_post',p_only_admins_can_post,'only_admins_can_add',p_only_admins_can_add,
    'auto_delete_seconds',p_auto_delete_seconds,'allow_reactions',p_allow_reactions));
end;
$function$;
