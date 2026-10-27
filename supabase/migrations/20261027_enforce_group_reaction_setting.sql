-- Enforce group message/reaction settings on the database, not only in the UI.
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

create or replace function public.enforce_group_reactions_enabled()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_enabled boolean;
  v_type text;
begin
  select c.allow_reactions, c.type
    into v_enabled, v_type
    from public.messages m
    join public.conversations c on c.id = m.conversation_id
   where m.id = new.message_id;

  if v_type = 'group' and coalesce(v_enabled, true) = false then
    raise exception 'group_reactions_disabled';
  end if;

  return new;
end;
$function$;

drop trigger if exists message_reactions_group_setting on public.message_reactions;
create trigger message_reactions_group_setting
before insert or update on public.message_reactions
for each row execute function public.enforce_group_reactions_enabled();

revoke all on function public.enforce_group_reactions_enabled() from public, anon, authenticated;
