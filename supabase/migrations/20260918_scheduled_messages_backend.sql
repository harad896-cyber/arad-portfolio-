create extension if not exists pg_cron with schema pg_catalog;

create table if not exists public.scheduled_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 10000),
  message_type text not null default 'text' check (message_type = 'text'),
  reply_to uuid null references public.messages(id) on delete set null,
  scheduled_for timestamptz not null,
  status text not null default 'pending' check (status in ('pending','processing','sent','cancelled','failed')),
  sent_message_id uuid null unique references public.messages(id) on delete set null,
  error_message text null,
  created_at timestamptz not null default now(),
  sent_at timestamptz null,
  cancelled_at timestamptz null
);

alter table public.scheduled_messages enable row level security;

grant select, insert, update, delete on public.scheduled_messages to authenticated;

drop policy if exists scheduled_messages_select_own on public.scheduled_messages;
create policy scheduled_messages_select_own
on public.scheduled_messages
for select
to authenticated
using (sender_id = (select auth.uid()));

drop policy if exists scheduled_messages_insert_member on public.scheduled_messages;
create policy scheduled_messages_insert_member
on public.scheduled_messages
for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and scheduled_for > now()
  and exists (
    select 1
    from public.conversation_members cm
    join public.conversations c on c.id = cm.conversation_id
    where cm.conversation_id = scheduled_messages.conversation_id
      and cm.user_id = (select auth.uid())
      and (
        c.type = 'direct'
        or (
          c.type in ('group','channel')
          and (
            c.only_admins_can_post = false
            or c.created_by = (select auth.uid())
            or cm.role = 'admin'
            or exists (
              select 1
              from public.conversation_admins ca
              where ca.conversation_id = c.id
                and ca.user_id = (select auth.uid())
                and ca.role in ('owner','admin')
            )
          )
        )
      )
  )
);

drop policy if exists scheduled_messages_update_own on public.scheduled_messages;
create policy scheduled_messages_update_own
on public.scheduled_messages
for update
to authenticated
using (sender_id = (select auth.uid()))
with check (
  sender_id = (select auth.uid())
  and status in ('pending','cancelled')
);

drop policy if exists scheduled_messages_delete_own on public.scheduled_messages;
create policy scheduled_messages_delete_own
on public.scheduled_messages
for delete
to authenticated
using (sender_id = (select auth.uid()));

create index if not exists scheduled_messages_due_idx
  on public.scheduled_messages(status, scheduled_for);

create index if not exists scheduled_messages_sender_idx
  on public.scheduled_messages(sender_id, scheduled_for);

create index if not exists scheduled_messages_conversation_idx
  on public.scheduled_messages(conversation_id, scheduled_for);

create or replace function private.process_scheduled_messages()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  job record;
  inserted_id uuid;
  processed integer := 0;
  can_send boolean;
begin
  for job in
    select *
    from public.scheduled_messages
    where status = 'pending'
      and scheduled_for <= now()
    order by scheduled_for, created_at
    for update skip locked
    limit 100
  loop
    begin
      update public.scheduled_messages
      set status = 'processing',
          error_message = null
      where id = job.id
        and status = 'pending';

      if not found then
        continue;
      end if;

      select exists (
        select 1
        from public.conversation_members cm
        join public.conversations c on c.id = cm.conversation_id
        where cm.conversation_id = job.conversation_id
          and cm.user_id = job.sender_id
          and (
            c.type = 'direct'
            or (
              c.type in ('group','channel')
              and (
                c.only_admins_can_post = false
                or c.created_by = job.sender_id
                or cm.role = 'admin'
                or exists (
                  select 1
                  from public.conversation_admins ca
                  where ca.conversation_id = c.id
                    and ca.user_id = job.sender_id
                    and ca.role in ('owner','admin')
                )
              )
            )
          )
      ) into can_send;

      if not can_send then
        update public.scheduled_messages
        set status = 'failed',
            error_message = 'فرستنده دیگر اجازه ارسال در این گفتگو را ندارد.'
        where id = job.id;
        continue;
      end if;

      if job.reply_to is not null and not exists (
        select 1
        from public.messages m
        where m.id = job.reply_to
          and m.conversation_id = job.conversation_id
      ) then
        update public.scheduled_messages
        set status = 'failed',
            error_message = 'پیام پاسخ‌داده‌شده دیگر در این گفتگو وجود ندارد.'
        where id = job.id;
        continue;
      end if;

      insert into public.messages (
        conversation_id,
        sender_id,
        body,
        message_type,
        created_at,
        reply_to
      )
      values (
        job.conversation_id,
        job.sender_id,
        job.body,
        'text',
        now(),
        job.reply_to
      )
      returning id into inserted_id;

      update public.scheduled_messages
      set status = 'sent',
          sent_message_id = inserted_id,
          sent_at = now()
      where id = job.id;

      processed := processed + 1;
    exception when others then
      update public.scheduled_messages
      set status = 'failed',
          error_message = left(sqlerrm, 1000)
      where id = job.id;
    end;
  end loop;

  return processed;
end;
$$;

revoke all on function private.process_scheduled_messages() from public, anon, authenticated;

select cron.unschedule(jobid)
from cron.job
where jobname = 'arad-process-scheduled-messages';

select cron.schedule(
  'arad-process-scheduled-messages',
  '* * * * *',
  $$select private.process_scheduled_messages();$$
);
