-- Channels are broadcast-style: only the channel owner/admins may publish.
create or replace function public.enforce_channel_admin_posting()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if exists (
    select 1 from public.conversations c
    where c.id = new.conversation_id
      and c.type = 'channel'
      and c.only_admins_can_post = true
  ) and not public.is_group_admin(new.conversation_id) then
    raise exception 'channel_admins_only';
  end if;
  return new;
end;
$$;

drop trigger if exists messages_channel_admin_only on public.messages;
create trigger messages_channel_admin_only
before insert on public.messages
for each row execute function public.enforce_channel_admin_posting();

grant execute on function public.enforce_channel_admin_posting() to authenticated;

-- Existing channels are also switched to admin-only publishing.
update public.conversations
set only_admins_can_post = true
where type = 'channel';
