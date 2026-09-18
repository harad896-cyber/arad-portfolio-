-- Self-destruct / auto-delete messages.
-- The trigger applies the selected TTL to every newly inserted message.
alter table public.messages add column if not exists expires_at timestamptz;

create table if not exists public.message_ttl (
  conversation_id uuid primary key references public.conversations(id) on delete cascade,
  ttl_seconds integer not null check (ttl_seconds in (0,86400,604800,2592000)),
  enabled_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now()
);

alter table public.message_ttl enable row level security;
grant select,insert,update,delete on public.message_ttl to authenticated;

drop policy if exists message_ttl_member on public.message_ttl;
create policy message_ttl_member on public.message_ttl
for all to authenticated
using (exists(select 1 from public.conversation_members cm where cm.conversation_id=message_ttl.conversation_id and cm.user_id=(select auth.uid())))
with check (enabled_by=(select auth.uid()) and exists(select 1 from public.conversation_members cm where cm.conversation_id=message_ttl.conversation_id and cm.user_id=(select auth.uid())));

create index if not exists messages_expires_at_idx on public.messages(expires_at) where expires_at is not null;

create or replace function public.apply_message_ttl() returns trigger
language plpgsql
as $$
declare ttl integer;
begin
  if new.expires_at is null then
    select ttl_seconds into ttl from public.message_ttl where conversation_id=new.conversation_id;
    if ttl is not null and ttl > 0 then
      new.expires_at := coalesce(new.created_at, now()) + make_interval(secs => ttl);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists messages_apply_ttl on public.messages;
create trigger messages_apply_ttl before insert on public.messages
for each row execute function public.apply_message_ttl();

create or replace function private.delete_expired_messages() returns integer
language plpgsql
as $$
declare n integer;
begin
  delete from public.messages where expires_at is not null and expires_at <= now();
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function private.delete_expired_messages() from public,anon,authenticated;

create extension if not exists pg_cron with schema pg_catalog;
do $$
begin
  if not exists(select 1 from cron.job where jobname='arad-delete-expired-messages') then
    perform cron.schedule('arad-delete-expired-messages','* * * * *','select private.delete_expired_messages()');
  end if;
end $$;
