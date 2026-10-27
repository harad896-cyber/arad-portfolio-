-- Enforce the existing "admins only can post" group setting on the server.
-- The trigger already exists on public.messages; replacing its function extends
-- the same rule to groups while preserving channel behavior.
create or replace function public.enforce_channel_admin_posting()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
declare
  v_type text;
begin
  select c.type into v_type
    from public.conversations c
   where c.id = new.conversation_id
     and c.only_admins_can_post = true;

  if v_type in ('channel','group') and not public.is_group_admin(new.conversation_id) then
    if v_type = 'group' then
      raise exception 'group_admins_only';
    else
      raise exception 'channel_admins_only';
    end if;
  end if;

  return new;
end;
$function$;
