alter table public.message_attachments
  add column if not exists bucket_id text not null default 'chat-media';

alter table public.message_attachments
  drop constraint if exists message_attachments_bucket_id_check;
alter table public.message_attachments
  add constraint message_attachments_bucket_id_check
  check (bucket_id in ('chat-media', 'saved-messages'));
