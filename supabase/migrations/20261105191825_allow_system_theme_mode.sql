-- Allow users to follow the operating system appearance in GapResan.
-- Existing dark/light values remain valid and unchanged.
alter table public.user_settings
  drop constraint if exists user_settings_theme_mode_check;

alter table public.user_settings
  add constraint user_settings_theme_mode_check
  check (theme_mode in ('dark', 'light', 'system'));
