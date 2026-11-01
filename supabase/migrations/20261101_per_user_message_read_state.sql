-- Keep each member's unread state independent. The legacy messages.read_at
-- column is shared by all members and cannot represent per-account reads.
create table if not exists public.message_user_reads (
  user_id uuid not null references auth.users(id) on delete cascade,
  message_id uuid not null references public.messages(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (user_id, message_id)
);

create index if not exists message_user_reads_user_message_idx
  on public.message_user_reads (user_id, message_id);

alter table public.message_user_reads enable row level security;

drop policy if exists message_user_reads_select_own on public.message_user_reads;
create policy message_user_reads_select_own
  on public.message_user_reads
  for select
  to authenticated
  using (user_id = (select auth.uid()));

revoke all on table public.message_user_reads from anon, authenticated;
grant select on table public.message_user_reads to authenticated;

-- Called whenever the current user opens a conversation. This marks only
-- messages received by that user, regardless of the public read-receipt setting.
create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  uid uuid := auth.uid();
  affected integer;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
      from public.conversation_members cm
     where cm.conversation_id = p_conversation_id
       and cm.user_id = uid
  ) then
    raise exception 'Conversation membership required';
  end if;

  insert into public.message_user_reads (user_id, message_id)
  select uid, m.id
    from public.messages m
   where m.conversation_id = p_conversation_id
     and m.sender_id <> uid
     and m.deleted_at is null
  on conflict (user_id, message_id) do nothing;

  get diagnostics affected = row_count;
  return affected;
end;
$$;

revoke all on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
