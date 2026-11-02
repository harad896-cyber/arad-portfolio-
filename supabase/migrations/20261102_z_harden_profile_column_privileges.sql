-- Restrict profile table writes to safe self-service fields.
-- Privileged flags and contact/location fields must never be writable by client roles.
REVOKE ALL PRIVILEGES ON TABLE public.profiles FROM anon, authenticated;
REVOKE ALL PRIVILEGES (id, username, display_name, avatar_url, bio, is_online, last_seen, created_at, phone, country, is_verified, is_owner, joined_at) ON TABLE public.profiles FROM anon, authenticated;
GRANT SELECT (id, username, display_name, avatar_url, bio, is_online, last_seen, created_at, is_verified, joined_at) ON TABLE public.profiles TO authenticated;
GRANT INSERT (id, username, display_name, avatar_url, bio, is_online, last_seen) ON TABLE public.profiles TO authenticated;
GRANT UPDATE (username, display_name, avatar_url, bio, is_online, last_seen) ON TABLE public.profiles TO authenticated;
