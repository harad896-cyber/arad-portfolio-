-- Runtime hardening for reliable group member management.
create or replace function public.add_group_members(p_conversation_id uuid, p_user_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  added integer := 0;
  target uuid;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.conversations where id = p_conversation_id and type = 'group') then
    raise exception 'not_group';
  end if;
  if not public.is_group_admin(p_conversation_id) then
    raise exception 'not_group_admin';
  end if;
  foreach target in array coalesce(p_user_ids, array[]::uuid[]) loop
    if target is null or target = uid then continue; end if;
    if not exists (select 1 from auth.users where id = target) then continue; end if;
    if exists (select 1 from public.group_banned_members where conversation_id = p_conversation_id and user_id = target) then continue; end if;
    insert into public.conversation_members(conversation_id, user_id, role)
    values (p_conversation_id, target, 'member')
    on conflict (conversation_id, user_id) do nothing;
    if found then
      added := added + 1;
      begin
        insert into public.group_audit_logs(conversation_id, actor_id, action, target_user_id)
        values (p_conversation_id, uid, 'member_added', target);
      exception when undefined_table or undefined_column then null;
      end;
    end if;
  end loop;
  return added;
end;
$$;

revoke all on function public.add_group_members(uuid, uuid[]) from public;
revoke all on function public.add_group_members(uuid, uuid[]) from anon;
grant execute on function public.add_group_members(uuid, uuid[]) to authenticated;

revoke all on function public.remove_group_member(uuid, uuid) from public;
revoke all on function public.remove_group_member(uuid, uuid) from anon;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;
