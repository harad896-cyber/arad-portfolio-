-- The profile bootstrap function is invoked only by the auth.users trigger.
-- It must not be callable as an exposed PostgREST RPC by anonymous or signed-in clients.
revoke execute on function public.handle_new_user_profile() from public, anon, authenticated;
