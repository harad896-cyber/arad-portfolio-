create or replace function public.delete_group(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare uid uuid := auth.uid(); gid uuid;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select created_by into gid from public.conversations where id=p_conversation_id and type='group';
  if gid is null then raise exception 'group_not_found'; end if;
  if gid <> uid and not exists (select 1 from public.conversation_members where conversation_id=p_conversation_id and user_id=uid and role in ('owner','admin')) then raise exception 'not_group_admin'; end if;
  delete from public.support_reports where conversation_id=p_conversation_id or message_id in (select id from public.messages where conversation_id=p_conversation_id);
  delete from public.saved_messages where source_message_id in (select id from public.messages where conversation_id=p_conversation_id);
  update public.messages set reply_to=null where conversation_id=p_conversation_id;
  delete from public.message_attachments where message_id in (select id from public.messages where conversation_id=p_conversation_id);
  delete from public.message_reactions where message_id in (select id from public.messages where conversation_id=p_conversation_id);
  delete from public.message_reads where message_id in (select id from public.messages where conversation_id=p_conversation_id);
  delete from public.message_reports where message_id in (select id from public.messages where conversation_id=p_conversation_id);
  delete from public.message_user_deletions where message_id in (select id from public.messages where conversation_id=p_conversation_id);
  delete from public.messages where conversation_id=p_conversation_id;
  delete from public.group_audit_logs where conversation_id=p_conversation_id;
  delete from public.group_admin_permissions where conversation_id=p_conversation_id;
  delete from public.group_banned_members where conversation_id=p_conversation_id;
  delete from public.group_invites where conversation_id=p_conversation_id;
  delete from public.group_member_restrictions where conversation_id=p_conversation_id;
  delete from public.conversation_admins where conversation_id=p_conversation_id;
  delete from public.conversation_members where conversation_id=p_conversation_id;
  delete from public.conversations where id=p_conversation_id and type='group';
end;
$$;
grant execute on function public.delete_group(uuid) to authenticated;

create or replace function public.leave_group(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare uid uuid:=auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists(select 1 from public.conversations where id=p_conversation_id and type='group') then raise exception 'group_not_found'; end if;
  if exists(select 1 from public.conversations where id=p_conversation_id and created_by=uid) then raise exception 'owner_cannot_leave'; end if;
  delete from public.conversation_admins where conversation_id=p_conversation_id and user_id=uid;
  delete from public.conversation_members where conversation_id=p_conversation_id and user_id=uid;
end;
$$;
grant execute on function public.leave_group(uuid) to authenticated;
