-- Record member invitations so group timelines can show who added whom and when.
create or replace function public.log_group_member_added()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();

  -- Service-side inserts without an authenticated actor are not attributed
  -- to a fabricated user. Self-joins have their own link/join event flow.
  if v_actor is null or v_actor = new.user_id then
    return new;
  end if;

  if exists (
    select 1
    from public.conversations c
    where c.id = new.conversation_id
      and c.type = 'group'
  ) then
    insert into public.group_audit_logs (
      conversation_id,
      actor_id,
      action,
      target_user_id,
      details
    ) values (
      new.conversation_id,
      v_actor,
      'member_added',
      new.user_id,
      jsonb_build_object('role', coalesce(new.role, 'member'))
    );
  end if;

  return new;
end;
$$;

drop trigger if exists conversation_member_added_audit on public.conversation_members;
create trigger conversation_member_added_audit
after insert on public.conversation_members
for each row execute function public.log_group_member_added();

revoke all on function public.log_group_member_added() from public;
