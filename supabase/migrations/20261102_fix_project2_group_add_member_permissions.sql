-- Align the server-side add_group_members authorization with the Project 2 UI.
-- When only_admins_can_add is off, regular group members may add users.
-- Admins still obey their per-admin can_add_members permission.
create or replace function public.add_group_members(p_conversation_id uuid, p_user_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = public
as $function$
declare
  uid uuid := auth.uid();
  group_owner uuid;
  admins_only boolean;
  member_role text;
  is_admin boolean := false;
  can_add boolean := true;
  added integer := 0;
  target uuid;
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  select c.created_by, coalesce(c.only_admins_can_add, false)
    into group_owner, admins_only
  from public.conversations c
  where c.id = p_conversation_id
    and c.type = 'group';

  if not found then
    raise exception 'not_group';
  end if;

  if group_owner = uid then
    is_admin := true;
  else
    select cm.role into member_role
    from public.conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = uid;

    if not found then
      raise exception 'not_group_member';
    end if;

    is_admin := coalesce(member_role in ('admin', 'owner'), false)
      or exists (
        select 1
        from public.conversation_admins ca
        where ca.conversation_id = p_conversation_id
          and ca.user_id = uid
          and ca.role in ('admin', 'owner')
      );

    if is_admin then
      select gap.can_add_members into can_add
      from public.group_admin_permissions gap
      where gap.conversation_id = p_conversation_id
        and gap.user_id = uid;

      -- An absent permissions row keeps the existing default: admins can add.
      if not coalesce(can_add, true) then
        raise exception 'admin_add_members_disabled';
      end if;
    elsif admins_only then
      raise exception 'add_members_disabled';
    end if;
  end if;

  foreach target in array coalesce(p_user_ids, array[]::uuid[]) loop
    if target is null or target = uid then
      continue;
    end if;

    if not exists (select 1 from auth.users u where u.id = target) then
      continue;
    end if;

    if exists (
      select 1
      from public.group_banned_members b
      where b.conversation_id = p_conversation_id
        and b.user_id = target
    ) then
      continue;
    end if;

    insert into public.conversation_members(conversation_id, user_id, role)
    values (p_conversation_id, target, 'member')
    on conflict (conversation_id, user_id) do nothing;

    if found then
      added := added + 1;
      begin
        insert into public.group_audit_logs(conversation_id, actor_id, action, target_user_id)
        values (p_conversation_id, uid, 'member_added', target);
      exception
        when undefined_table or undefined_column then
          null;
      end;
    end if;
  end loop;

  return added;
end;
$function$;

revoke all on function public.add_group_members(uuid, uuid[]) from public, anon;
grant execute on function public.add_group_members(uuid, uuid[]) to authenticated;
