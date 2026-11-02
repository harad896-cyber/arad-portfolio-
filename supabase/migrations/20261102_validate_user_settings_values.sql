do $$
begin
  if not exists (select 1 from pg_constraint where conname='user_settings_phone_visibility_check') then
    alter table public.user_settings add constraint user_settings_phone_visibility_check check (phone_visibility in ('everybody','contacts','nobody'));
  end if;
  if not exists (select 1 from pg_constraint where conname='user_settings_last_seen_visibility_check') then
    alter table public.user_settings add constraint user_settings_last_seen_visibility_check check (last_seen_visibility in ('everybody','contacts','nobody'));
  end if;
  if not exists (select 1 from pg_constraint where conname='user_settings_profile_photo_visibility_check') then
    alter table public.user_settings add constraint user_settings_profile_photo_visibility_check check (profile_photo_visibility in ('everybody','contacts','nobody'));
  end if;
  if not exists (select 1 from pg_constraint where conname='user_settings_bio_visibility_check') then
    alter table public.user_settings add constraint user_settings_bio_visibility_check check (bio_visibility in ('everybody','contacts','nobody'));
  end if;
  if not exists (select 1 from pg_constraint where conname='user_settings_forwards_visibility_check') then
    alter table public.user_settings add constraint user_settings_forwards_visibility_check check (forwards_visibility in ('everybody','contacts','nobody'));
  end if;
  if not exists (select 1 from pg_constraint where conname='user_settings_calls_visibility_check') then
    alter table public.user_settings add constraint user_settings_calls_visibility_check check (calls_visibility in ('everybody','contacts','nobody'));
  end if;
  if not exists (select 1 from pg_constraint where conname='user_settings_groups_visibility_check') then
    alter table public.user_settings add constraint user_settings_groups_visibility_check check (groups_visibility in ('everybody','contacts','nobody'));
  end if;
  if not exists (select 1 from pg_constraint where conname='user_settings_voice_messages_visibility_check') then
    alter table public.user_settings add constraint user_settings_voice_messages_visibility_check check (voice_messages_visibility in ('everybody','contacts','nobody'));
  end if;
  if not exists (select 1 from pg_constraint where conname='user_settings_p2p_visibility_check') then
    alter table public.user_settings add constraint user_settings_p2p_visibility_check check (p2p_visibility in ('everybody','contacts','nobody'));
  end if;
  if not exists (select 1 from pg_constraint where conname='user_settings_theme_mode_check') then
    alter table public.user_settings add constraint user_settings_theme_mode_check check (theme_mode in ('dark','light'));
  end if;
  if not exists (select 1 from pg_constraint where conname='user_settings_language_code_check') then
    alter table public.user_settings add constraint user_settings_language_code_check check (language_code in ('fa','prs','haz','ps','en','ar','tr','fr','de','ur','hi','es','ru','zh','it','pt','id','ja','ko','bn'));
  end if;
end $$;
