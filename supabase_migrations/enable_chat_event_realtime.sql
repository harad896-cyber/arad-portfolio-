-- Enable the realtime events that the chat UI subscribes to.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'group_audit_logs'
  ) then
    execute 'alter publication supabase_realtime add table public.group_audit_logs';
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'message_user_deletions'
  ) then
    execute 'alter publication supabase_realtime add table public.message_user_deletions';
  end if;
end
$$;
