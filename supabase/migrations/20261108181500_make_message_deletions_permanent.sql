-- Make both deletion modes irreversible.
alter table public.message_user_deletions enable row level security;

-- A per-user deletion is an append-only tombstone. Clients may create/read
-- their own markers, but must never be able to remove or rewrite them.
drop policy if exists message_user_deletions_delete_own
  on public.message_user_deletions;

create or replace function public.prevent_message_deletion_rollback()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if old.deleted_at is not null and new.deleted_at is null then
    raise exception 'Message deletion is permanent'
      using errcode = '23514';
  end if;

  if new.deleted_at is not null then
    new.body := null;
  end if;

  return new;
end;
$$;

drop trigger if exists messages_prevent_deleted_message_restore
  on public.messages;

create trigger messages_prevent_deleted_message_restore
before update of deleted_at, body on public.messages
for each row
execute function public.prevent_message_deletion_rollback();
