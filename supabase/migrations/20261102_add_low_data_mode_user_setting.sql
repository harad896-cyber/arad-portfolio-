alter table public.user_settings
  add column if not exists low_data_mode boolean not null default false;
