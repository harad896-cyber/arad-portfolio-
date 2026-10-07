create table if not exists public.call_sessions (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  caller_id uuid not null references auth.users(id) on delete cascade,
  callee_id uuid not null references auth.users(id) on delete cascade,
  call_type text not null default 'voice' check (call_type in ('voice','video')),
  status text not null default 'ringing' check (status in ('ringing','accepted','rejected','ended','missed','cancelled','failed')),
  started_at timestamptz not null default now(),
  accepted_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  offer_sdp text,
  answer_sdp text,
  constraint call_sessions_users_different check (caller_id <> callee_id)
);

alter table public.call_sessions enable row level security;
grant select, insert, update on public.call_sessions to authenticated;

drop policy if exists call_sessions_select_member on public.call_sessions;
create policy call_sessions_select_member on public.call_sessions
for select to authenticated
using (caller_id = (select auth.uid()) or callee_id = (select auth.uid()));

drop policy if exists call_sessions_insert_member on public.call_sessions;
create policy call_sessions_insert_member on public.call_sessions
for insert to authenticated
with check (
  caller_id = (select auth.uid())
  and exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = call_sessions.conversation_id
      and cm.user_id = (select auth.uid())
  )
  and exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = call_sessions.conversation_id
      and cm.user_id = call_sessions.callee_id
  )
);

drop policy if exists call_sessions_update_participant on public.call_sessions;
create policy call_sessions_update_participant on public.call_sessions
for update to authenticated
using (caller_id = (select auth.uid()) or callee_id = (select auth.uid()))
with check (caller_id = call_sessions.caller_id and callee_id = call_sessions.callee_id);

create index if not exists call_sessions_participant_idx
on public.call_sessions(caller_id, callee_id, created_at desc);

create index if not exists call_sessions_conversation_idx
on public.call_sessions(conversation_id, created_at desc);

alter publication supabase_realtime add table public.call_sessions;


drop policy if exists call_sessions_broadcast_read on realtime.messages;
create policy call_sessions_broadcast_read
on realtime.messages
for select to authenticated
using (
  extension in ('broadcast')
  and exists (
    select 1 from public.call_sessions cs
    where ('call:' || cs.id::text) = realtime.topic()
      and (cs.caller_id = (select auth.uid()) or cs.callee_id = (select auth.uid()))
  )
);

drop policy if exists call_sessions_broadcast_send on realtime.messages;
create policy call_sessions_broadcast_send
on realtime.messages
for insert to authenticated
with check (
  extension in ('broadcast')
  and exists (
    select 1 from public.call_sessions cs
    where ('call:' || cs.id::text) = realtime.topic()
      and (cs.caller_id = (select auth.uid()) or cs.callee_id = (select auth.uid()))
  )
);


-- Keep the call log useful: when an unanswered incoming call is cancelled by
-- the caller, store it as a missed call instead of a generic cancellation.
create or replace function public.mark_cancelled_call_as_missed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'ringing' and new.status = 'cancelled' then
    new.status := 'missed';
  end if;
  return new;
end;
$$;

drop trigger if exists call_sessions_mark_missed on public.call_sessions;
create trigger call_sessions_mark_missed
before update of status on public.call_sessions
for each row execute function public.mark_cancelled_call_as_missed();

grant execute on function public.mark_cancelled_call_as_missed() to authenticated;
