-- Reliable group membership RPCs.
drop function if exists public.remove_group_member(uuid,uuid);

create or replace function public.add_group_members(p_conversation_id uuid, p_user_ids uuid[])
returns integer
language plpgsql security definer set search_path=public
as $$
declare uid uuid := auth.uid(); added integer := 0;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not private.is_group_admin(p_conversation_id,uid) then raise exception 'not_group_admin'; end if;
  if not exists(select 1 from conversations where id=p_conversation_id and type='group') then raise exception 'not_group'; end if;
  insert into conversation_members(conversation_id,user_id,role)
  select p_conversation_id,x,'member'
  from unnest(coalesce(p_user_ids,array[]::uuid[])) x
  where x<>uid
  on conflict(conversation_id,user_id) do nothing;
  get diagnostics added=row_count;
  return added;
end $$;

revoke all on function public.add_group_members(uuid,uuid[]) from public;
grant execute on function public.add_group_members(uuid,uuid[]) to authenticated;

create function public.remove_group_member(p_conversationId uuid,p_user_id uuid)
returns boolean
language plpgsql security definer set search_path=public
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not private.is_group_admin(p_conversationId,uid) then raise exception 'not_group_admin'; end if;
  if exists(select 1 from conversations where id=p_conversationId and created_by=p_user_id) then raise exception 'cannot_remove_owner'; end if;
  delete from conversation_members where conversation_id=p_conversationId and user_id=p_user_id;
  return found;
end $$;

revoke all on function public.remove_group_member(uuid,uuid) from public;
grant execute on function public.remove_group_member(uuid,uuid) to authenticated;
