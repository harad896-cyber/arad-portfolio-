-- The client subscribes to these tables to keep message state live.
do $$
declare
  t text;
begin
  foreach t in array array['message_reactions', 'message_read_receipts', 'message_attachments']
  loop
    if to_regclass('public.' || t) is not null
       and not exists (
         select 1 from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = t
       ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end
$$;
