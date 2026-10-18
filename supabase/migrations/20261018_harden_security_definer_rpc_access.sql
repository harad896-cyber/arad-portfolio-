-- Restrict exposed SECURITY DEFINER RPCs to signed-in users by default.
-- Trigger functions continue to run through their triggers; direct RPC execution is not needed.
-- The public-conversation search is intentionally kept available to anonymous clients.
-- Scheduled-message processing must only run through the private pg_cron worker.

do $$
declare
  fn record;
  signature text;
begin
  for fn in
    select p.oid, p.proname, p.prorettype
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
  loop
    signature := fn.oid::regprocedure::text;
    execute format('revoke execute on function %s from public, anon, authenticated', signature);

    if fn.prorettype = 'trigger'::regtype then
      -- Trigger invocation does not require callers to hold EXECUTE.
      continue;
    end if;

    if fn.proname = 'process_scheduled_messages' then
      -- The public duplicate is not the cron worker; never expose its bulk-send operation.
      continue;
    end if;

    execute format('grant execute on function %s to authenticated', signature);
  end loop;
end
$$;

grant execute on function public.search_public_conversations(text) to anon, authenticated;
