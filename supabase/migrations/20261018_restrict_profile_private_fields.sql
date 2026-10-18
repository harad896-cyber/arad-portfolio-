-- Keep profile discovery useful while preventing exposure of private profile fields.
-- Phone, country, and owner flags remain unavailable through public profile reads.
revoke select on table public.profiles from anon, authenticated;
grant select (
  id,
  username,
  display_name,
  avatar_url,
  bio,
  is_online,
  last_seen,
  created_at,
  is_verified,
  joined_at
) on table public.profiles to authenticated;
drop policy if exists profiles_select_anon_public on public.profiles;
