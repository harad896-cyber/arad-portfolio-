-- Make multi-member group adding follow the same real backend rules as single-member adding.
create or replace function public.add_group_members(p_conversation_id uuid, p_user_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = public
as $function$
declare
  uid uuid := auth.uid();
  added integer := 0;
  target uuid;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not public.is_group_admin(p_conversation_id) then raise exception 'not_group_admin'; end if;
  if not exists(select 1 from public.conversations where id=p_conversation_id and type='group') then raise exception 'not_group'; end if;
  if exists(select 1 from public.conversations where id=p_conversation_id and only_admins_can_add)
     and not exists(select 1 from public.conversation_members cm where cm.conversation_id=p_conversation_id and cm.user_id=uid and cm.role in ('admin','owner'))
     and (select created_by from public.conversations where id=p_conversation_id) <> uid then
    raise exception 'add_members_disabled';
  end if;
  foreach target in array coalesce(p_user_ids,array[]::uuid[]) loop
    if target is null or target=uid then continue; end if;
    if not exists(select 1 from auth.users where id=target) then continue; end if;
    if exists(select 1 from public.group_banned_members where conversation_id=p_conversation_id and user_id=target) then continue; end if;
    insert into public.conversation_members(conversation_id,user_id,role)
    values(p_conversation_id,target,'member')
    on conflict(conversation_id,user_id) do nothing;
    if found then
      added := added + 1;
      insert into public.group_audit_logs(conversation_id,actor_id,action,target_user_id)
      values(p_conversation_id,uid,'member_added',target);
    end if;
  end loop;
  return added;
end
$function$;
