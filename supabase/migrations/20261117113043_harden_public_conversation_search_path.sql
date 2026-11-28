-- Harden the intentionally public conversation discovery RPC.
-- It returns only explicitly public groups/channels and has no unqualified relation references.
create or replace function public.search_public_conversations(p_query text default ''::text)
returns table(
  id uuid,
  type text,
  title text,
  username text,
  description text,
  avatar_url text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $function$
  select c.id, c.type, c.title, c.username, c.description, c.avatar_url, c.created_at
  from public.conversations c
  where c.is_public = true
    and c.type in ('group','channel')
    and nullif(trim(c.username), '') is not null
    and (
      nullif(trim(p_query), '') is null
      or c.title ilike '%' || trim(p_query) || '%'
      or c.username ilike replace(trim(p_query), '@', '') || '%'
      or coalesce(c.description, '') ilike '%' || trim(p_query) || '%'
    )
  order by c.title asc
  limit 50;
$function$;

revoke all on function public.search_public_conversations(text) from public;
revoke all on function public.search_public_conversations(text) from anon;
grant execute on function public.search_public_conversations(text) to anon, authenticated;
