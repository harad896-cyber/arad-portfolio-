-- Arad Messenger security hardening (Project 2 only).
-- Enforce Secret Chat invariants at the database boundary; UI checks are not authorization.

create or replace function public.enforce_secret_message_security()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_type text;
  v_member_count integer;
  v_sender_is_member boolean;
  v_peer_id uuid;
begin
  if auth.uid() is null or new.sender_id is distinct from auth.uid() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select c.type,
         count(cm.user_id)::integer,
         coalesce(bool_or(cm.user_id = new.sender_id), false)
    into v_type, v_member_count, v_sender_is_member
    from public.conversations c
    left join public.conversation_members cm on cm.conversation_id = c.id
   where c.id = new.conversation_id
   group by c.id, c.type;

  select cm.user_id into v_peer_id
    from public.conversation_members cm
   where cm.conversation_id = new.conversation_id
     and cm.user_id <> new.sender_id
   limit 1;

  if v_type is distinct from 'direct'
     or v_member_count <> 2
     or not v_sender_is_member
     or v_peer_id is null then
    raise exception 'secret_chat_requires_two_person_conversation'
      using errcode = '23514';
  end if;

  -- Blocking must be enforced for Secret Chat just like ordinary direct messages.
  if exists (
    select 1
      from public.user_blocks b
     where (b.blocker_id = new.sender_id and b.blocked_id = v_peer_id)
        or (b.blocker_id = v_peer_id and b.blocked_id = new.sender_id)
  ) then
    raise exception 'interaction_blocked' using errcode = '42501';
  end if;

  -- A reply reference must belong to this same conversation.
  if new.reply_to is not null and not exists (
    select 1
      from public.secret_messages parent
     where parent.id = new.reply_to
       and parent.conversation_id = new.conversation_id
  ) then
    raise exception 'invalid_secret_reply_reference' using errcode = '23503';
  end if;

  -- Dart base64UrlEncode emits optional '=' padding; preserve compatibility.
  if new.ciphertext is null
     or char_length(new.ciphertext) < 38
     or char_length(new.ciphertext) > 262144
     or new.ciphertext !~ '^[A-Za-z0-9_-]+={0,2}$' then
    raise exception 'invalid_secret_ciphertext' using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_secret_message_security() from public, anon, authenticated;

drop trigger if exists secret_messages_security_guard on public.secret_messages;
create trigger secret_messages_security_guard
before insert on public.secret_messages
for each row execute function public.enforce_secret_message_security();

-- X25519 public keys are 32 bytes, represented as base64url with optional padding.
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'public.e2ee_identity_keys'::regclass
       and conname = 'e2ee_identity_public_key_format'
  ) then
    alter table public.e2ee_identity_keys
      add constraint e2ee_identity_public_key_format
      check (public_key ~ '^[A-Za-z0-9_-]{43}=?$') not valid;
  end if;
end
$$;

alter table public.e2ee_identity_keys
  validate constraint e2ee_identity_public_key_format;
