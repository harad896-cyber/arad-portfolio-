create or replace function public.is_conversation_admin(p_conversation_id uuid)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare uid uuid:=auth.uid();
begin
  if uid is null then return false; end if;
  return exists(select 1 from public.conversations c where c.id=p_conversation_id and c.type in ('group','channel') and (c.created_by=uid or exists(select 1 from public.conversation_members m where m.conversation_id=c.id and m.user_id=uid and m.role in ('owner','admin'))));
end;
$$;
grant execute on function public.is_conversation_admin(uuid) to authenticated;

create or replace function public.create_conversation_invite(p_conversation_id uuid,p_max_uses integer default 0,p_expires_at timestamptz default null,p_requires_approval boolean default false)
returns text
language plpgsql
security definer
set search_path=public
as $$
declare v_code text;
begin
  if not public.is_conversation_admin(p_conversation_id) then raise exception 'not_conversation_admin'; end if;
  if not exists(select 1 from public.conversations where id=p_conversation_id and type in ('group','channel')) then raise exception 'conversation_not_found'; end if;
  update public.group_invites set revoked_at=now() where conversation_id=p_conversation_id and revoked_at is null;
  v_code := 'ARAD-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,20));
  insert into public.group_invites(conversation_id,code,created_by,max_uses,expires_at,requires_approval)
  values(p_conversation_id,v_code,auth.uid(),nullif(p_max_uses,0),p_expires_at,coalesce(p_requires_approval,false));
  update public.conversations set invite_code=v_code where id=p_conversation_id;
  return v_code;
end;
$$;
grant execute on function public.create_conversation_invite(uuid,integer,timestamptz,boolean) to authenticated;

create or replace function public.revoke_conversation_invite(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.is_conversation_admin(p_conversation_id) then raise exception 'not_conversation_admin'; end if;
  update public.group_invites set revoked_at=now() where conversation_id=p_conversation_id and revoked_at is null;
  update public.conversations set invite_code=null where id=p_conversation_id and type in ('group','channel');
end;
$$;
grant execute on function public.revoke_conversation_invite(uuid) to authenticated;

create or replace function public.delete_channel(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare uid uuid:=auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists(select 1 from public.conversations c where c.id=p_conversation_id and c.type='channel' and (c.created_by=uid or exists(select 1 from public.conversation_members m where m.conversation_id=c.id and m.user_id=uid and m.role in ('owner','admin')))) then raise exception 'not_channel_admin'; end if;
  delete from public.support_reports where conversation_id=p_conversation_id or message_id in(select id from public.messages where conversation_id=p_conversation_id);
  delete from public.message_attachments where message_id in(select id from public.messages where conversation_id=p_conversation_id);
  delete from public.message_reactions where message_id in(select id from public.messages where conversation_id=p_conversation_id);
  delete from public.message_reads where message_id in(select id from public.messages where conversation_id=p_conversation_id);
  delete from public.message_reports where message_id in(select id from public.messages where conversation_id=p_conversation_id);
  delete from public.message_user_deletions where message_id in(select id from public.messages where conversation_id=p_conversation_id);
  delete from public.messages where conversation_id=p_conversation_id;
  delete from public.group_invites where conversation_id=p_conversation_id;
  delete from public.conversation_admins where conversation_id=p_conversation_id;
  delete from public.conversation_members where conversation_id=p_conversation_id;
  delete from public.conversations where id=p_conversation_id and type='channel';
end;
$$;
grant execute on function public.delete_channel(uuid) to authenticated;
