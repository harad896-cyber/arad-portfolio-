-- Persistent user blocking for GapResan.
-- Keep block rows private to the account that created them.
create table if not exists public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint user_blocks_no_self check (blocker_id <> blocked_id),
  constraint user_blocks_unique_pair unique (blocker_id, blocked_id)
);
create index if not exists user_blocks_blocked_id_idx on public.user_blocks(blocked_id);
alter table public.user_blocks enable row level security;
drop policy if exists user_blocks_select_own on public.user_blocks;
create policy user_blocks_select_own on public.user_blocks
  for select to authenticated using ((select auth.uid()) = blocker_id);
drop policy if exists user_blocks_insert_own on public.user_blocks;
create policy user_blocks_insert_own on public.user_blocks
  for insert to authenticated
  with check ((select auth.uid()) = blocker_id and blocker_id <> blocked_id);
drop policy if exists user_blocks_delete_own on public.user_blocks;
create policy user_blocks_delete_own on public.user_blocks
  for delete to authenticated using ((select auth.uid()) = blocker_id);
grant select, insert, delete on public.user_blocks to authenticated;
revoke all on public.user_blocks from anon;

-- Reject new friend requests and direct messages when either participant
-- has blocked the other. The trigger runs with a fixed search_path.
create or replace function public.reject_blocked_direct_interactions()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_other_user uuid;
  v_sender uuid;
  v_recipient uuid;
begin
  if tg_table_name = 'friend_requests' then
    v_sender := new.requester_id;
    v_recipient := new.recipient_id;
    if auth.uid() is distinct from v_sender then
      raise exception 'not_authorized';
    end if;
    if exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = v_sender and b.blocked_id = v_recipient)
         or (b.blocker_id = v_recipient and b.blocked_id = v_sender)
    ) then
      raise exception 'interaction_blocked';
    end if;
    return new;
  end if;

  v_sender := new.sender_id;
  if auth.uid() is distinct from v_sender then
    raise exception 'not_authorized';
  end if;
  select cm.user_id into v_other_user
  from public.conversation_members cm
  join public.conversations c on c.id = cm.conversation_id
  where cm.conversation_id = new.conversation_id
    and cm.user_id <> v_sender
    and c.type = 'direct'
  limit 1;
  if v_other_user is not null and exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = v_sender and b.blocked_id = v_other_user)
       or (b.blocker_id = v_other_user and b.blocked_id = v_sender)
  ) then
    raise exception 'interaction_blocked';
  end if;
  return new;
end;
$$;
revoke all on function public.reject_blocked_direct_interactions() from public, anon, authenticated;
drop trigger if exists friend_requests_reject_blocked on public.friend_requests;
create trigger friend_requests_reject_blocked
before insert on public.friend_requests
for each row execute function public.reject_blocked_direct_interactions();
drop trigger if exists messages_reject_blocked_direct on public.messages;
create trigger messages_reject_blocked_direct
before insert on public.messages
for each row execute function public.reject_blocked_direct_interactions();
