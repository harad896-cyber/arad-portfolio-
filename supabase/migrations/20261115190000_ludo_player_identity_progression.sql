-- Player identity and server-authoritative Ludo progression.
-- Apply only after reviewing this migration in the target Supabase project.

create schema if not exists ludo_private;
revoke all on schema ludo_private from public, anon, authenticated;

-- Extend the existing catalog for the complete cosmetic loadout.
alter table public.ludo_cosmetic_catalog
  drop constraint if exists ludo_cosmetic_catalog_category_check;
alter table public.ludo_cosmetic_catalog
  add constraint ludo_cosmetic_catalog_category_check
  check (category in (
    'character','face','skin','hat','glasses','outfit','aura',
    'piece_trail','dice_skin','board_theme','frame','win_effect',
    'capture_effect','board','dice','trail','effect','profile_frame'
  ));

-- Initial server catalog entries. items.json is the authoring source for client/server asset metadata.
insert into public.ludo_cosmetic_catalog
  (id,name,category,asset_key,preview,rarity,emoji,color_hex,sort_order,is_active)
values
  ('fox_01','روباه','character','characters/fox/base.riv','characters/fox/preview.webp','common','🦊','#F28A35',10,true),
  ('robot_01','ربات','character','characters/robot/base.riv','characters/robot/preview.webp','rare','🤖','#58B8C9',20,true),
  ('tiger_01','ببر','character','characters/tiger/base.riv','characters/tiger/preview.webp','epic','🐯','#E99A35',30,true),
  ('astronaut_01','فضانورد','character','characters/astronaut/base.riv','characters/astronaut/preview.webp','legendary','🧑‍🚀','#91A9D8',40,true),
  ('cat_01','گربه','character','characters/cat/base.riv','characters/cat/preview.webp','common','🐱','#D5A1A8',50,true),
  ('dragon_01','اژدها','character','characters/dragon/base.riv','characters/dragon/preview.webp','legendary','🐉','#6B70D6',60,true),
  ('panda_01','پاندا','character','characters/panda/base.riv','characters/panda/preview.webp','rare','🐼','#D9E0E8',70,true),
  ('owl_01','جغد','character','characters/owl/base.riv','characters/owl/preview.webp','epic','🦉','#A78BFA',80,true),
  ('face_happy','چهره شاد','face','faces/happy','faces/happy.webp','common','😊',null,100,true),
  ('face_cool','چهره باحال','face','faces/cool','faces/cool.webp','rare','😎',null,110,true),
  ('hat_crown','تاج','hat','hats/crown.webp','hats/crown.webp','legendary','👑',null,120,true),
  ('hat_space','کلاه فضایی','hat','hats/space.webp','hats/space.webp','epic','🪖',null,130,true),
  ('glasses_neon','عینک نئونی','glasses','glasses/neon.webp','glasses/neon.webp','rare','🕶️',null,140,true),
  ('outfit_royal','لباس شاهانه','outfit','outfits/royal.webp','outfits/royal.webp','epic','🥋',null,150,true),
  ('aura_spark','هاله جرقه‌ای','aura','auras/spark.riv','auras/spark.webp','legendary','✨',null,160,true),
  ('trail_comet','رد ستاره دنباله‌دار','piece_trail','trails/comet.riv','trails/comet.webp','epic','☄️',null,170,true),
  ('dice_crystal','تاس کریستالی','dice_skin','dice/crystal.webp','dice/crystal.webp','rare','🎲',null,180,true),
  ('board_midnight','صفحه نیمه‌شب','board_theme','boards/midnight.webp','boards/midnight.webp','epic','🌌',null,190,true),
  ('frame_gold','قاب طلایی','frame','frames/gold.webp','frames/gold.webp','legendary','🏅',null,200,true),
  ('win_fireworks','آتش‌بازی پیروزی','win_effect','effects/fireworks.riv','effects/fireworks.webp','legendary','🎆',null,210,true),
  ('capture_pop','افکت برخورد','capture_effect','effects/pop.riv','effects/pop.webp','rare','💥',null,220,true)
on conflict (id) do update set
  name=excluded.name, category=excluded.category, asset_key=excluded.asset_key,
  preview=excluded.preview, rarity=excluded.rarity, emoji=excluded.emoji,
  color_hex=excluded.color_hex, sort_order=excluded.sort_order, is_active=true;

create table if not exists public.ludo_player_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name_override text check (display_name_override is null or char_length(display_name_override) between 1 and 32),
  title_id text not null default 'title_rookie',
  bio text not null default '' check (char_length(bio) <= 160),
  country_code text check (country_code is null or country_code ~ '^[A-Z]{2}$'),
  level integer not null default 1 check (level between 1 and 100),
  total_xp bigint not null default 0 check (total_xp >= 0),
  xp_into_level integer not null default 0 check (xp_into_level >= 0),
  coins bigint not null default 0 check (coins >= 0),
  gems bigint not null default 0 check (gems >= 0),
  unlocked_titles text[] not null default array['title_rookie']::text[],
  badges_shown text[] not null default '{}'::text[] check (cardinality(badges_shown) <= 3),
  daily_xp integer not null default 0 check (daily_xp between 0 and 500),
  daily_xp_date date not null default (timezone('utc', now())::date),
  privacy_visibility text not null default 'everyone'
    check (privacy_visibility in ('everyone','contacts','nobody')),
  created_at timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ludo_player_loadouts (
  user_id uuid not null references auth.users(id) on delete cascade,
  preset_slot smallint not null check (preset_slot between 1 and 3),
  preset_name text not null default 'ست من',
  character_id text not null references public.ludo_cosmetic_catalog(id),
  face_id text references public.ludo_cosmetic_catalog(id),
  skin_id text references public.ludo_cosmetic_catalog(id),
  hat_id text references public.ludo_cosmetic_catalog(id),
  glasses_id text references public.ludo_cosmetic_catalog(id),
  outfit_id text references public.ludo_cosmetic_catalog(id),
  piece_trail_id text references public.ludo_cosmetic_catalog(id),
  dice_skin_id text references public.ludo_cosmetic_catalog(id),
  board_theme_id text references public.ludo_cosmetic_catalog(id),
  frame_id text references public.ludo_cosmetic_catalog(id),
  win_effect_id text references public.ludo_cosmetic_catalog(id),
  capture_effect_id text references public.ludo_cosmetic_catalog(id),
  aura_id text references public.ludo_cosmetic_catalog(id),
  updated_at timestamptz not null default now(),
  primary key(user_id, preset_slot)
);

create table if not exists public.ludo_inventory (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null references public.ludo_cosmetic_catalog(id),
  acquired_at timestamptz not null default now(),
  source text not null check (source in ('game','purchase','gift','reward','starter')),
  source_ref text,
  primary key(user_id, item_id)
);
create index if not exists ludo_inventory_user_acquired_idx
  on public.ludo_inventory(user_id, acquired_at desc);

create table if not exists public.ludo_player_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  games integer not null default 0 check (games >= 0),
  wins integer not null default 0 check (wins >= 0),
  win_rate numeric(6,5) generated always as
    (case when games = 0 then 0::numeric else wins::numeric / games end) stored,
  top3 integer not null default 0 check (top3 >= 0),
  captures integer not null default 0 check (captures >= 0),
  captured_by integer not null default 0 check (captured_by >= 0),
  sixes integer not null default 0 check (sixes >= 0),
  longest_streak integer not null default 0 check (longest_streak >= 0),
  fastest_win_sec integer check (fastest_win_sec is null or fastest_win_sec > 0),
  favorite_color text,
  updated_at timestamptz not null default now(),
  constraint ludo_stats_wins_lte_games check (wins <= games),
  constraint ludo_stats_top3_lte_games check (top3 <= games)
);

create table if not exists public.ludo_achievement_catalog (
  id text primary key,
  name text not null,
  description text not null default '',
  category text not null check (category in ('victory','captures','friends','persistence','seasonal','secret')),
  target integer not null check (target > 0),
  is_secret boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0
);
create table if not exists public.ludo_player_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null references public.ludo_achievement_catalog(id),
  progress integer not null default 0 check (progress >= 0),
  unlocked_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key(user_id, achievement_id)
);

-- Only trusted backend workers may write match facts or progression ledgers.
create table if not exists public.ludo_match_results (
  match_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  placement smallint not null check (placement between 1 and 4),
  pieces_home smallint not null default 0 check (pieces_home between 0 and 4),
  captures smallint not null default 0 check (captures between 0 and 16),
  is_bot_match boolean not null default false,
  played_with_friend boolean not null default false,
  completed boolean not null default false,
  abandoned boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  primary key(match_id, user_id),
  check (not (completed and abandoned))
);

create table if not exists public.ludo_xp_ledger (
  id bigint generated always as identity primary key,
  match_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  daily_date date not null,
  base_xp integer not null check (base_xp >= 0),
  awarded_xp integer not null check (awarded_xp between 0 and 500),
  level_before integer not null,
  level_after integer not null,
  result_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(match_id, user_id),
  foreign key(match_id, user_id)
    references public.ludo_match_results(match_id, user_id) on delete restrict
);
create index if not exists ludo_xp_ledger_user_date_idx
  on public.ludo_xp_ledger(user_id, daily_date desc);

create table if not exists public.ludo_player_level_rewards (
  user_id uuid not null references auth.users(id) on delete cascade,
  level integer not null check (level between 2 and 100),
  reward_payload jsonb not null,
  granted_at timestamptz not null default now(),
  primary key(user_id, level)
);

-- Publicly readable only to authenticated players when active; private player data stays owner-scoped.
alter table public.ludo_player_profiles enable row level security;
alter table public.ludo_player_loadouts enable row level security;
alter table public.ludo_inventory enable row level security;
alter table public.ludo_player_stats enable row level security;
alter table public.ludo_achievement_catalog enable row level security;
alter table public.ludo_player_achievements enable row level security;
alter table public.ludo_match_results enable row level security;
alter table public.ludo_xp_ledger enable row level security;
alter table public.ludo_player_level_rewards enable row level security;

revoke all on public.ludo_player_profiles, public.ludo_player_loadouts,
  public.ludo_inventory, public.ludo_player_stats, public.ludo_achievement_catalog,
  public.ludo_player_achievements, public.ludo_match_results, public.ludo_xp_ledger,
  public.ludo_player_level_rewards from anon, authenticated;

grant select on public.ludo_player_profiles, public.ludo_player_loadouts,
  public.ludo_inventory, public.ludo_player_stats, public.ludo_player_achievements
  to authenticated;
grant select on public.ludo_achievement_catalog to authenticated;

drop policy if exists ludo_player_profile_read_own on public.ludo_player_profiles;
create policy ludo_player_profile_read_own on public.ludo_player_profiles
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists ludo_player_profile_update_own on public.ludo_player_profiles;
create policy ludo_player_profile_update_own on public.ludo_player_profiles
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
-- Explicit column grants prevent clients from changing XP, level, currency or daily caps.
grant update(display_name_override, title_id, bio, country_code, badges_shown,
  privacy_visibility, last_seen, updated_at)
  on public.ludo_player_profiles to authenticated;

drop policy if exists ludo_loadout_read_own on public.ludo_player_loadouts;
create policy ludo_loadout_read_own on public.ludo_player_loadouts
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists ludo_inventory_read_own on public.ludo_inventory;
create policy ludo_inventory_read_own on public.ludo_inventory
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists ludo_stats_read_own on public.ludo_player_stats;
create policy ludo_stats_read_own on public.ludo_player_stats
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists ludo_achievement_catalog_read_active on public.ludo_achievement_catalog;
create policy ludo_achievement_catalog_read_active on public.ludo_achievement_catalog
  for select to authenticated using (is_active);
drop policy if exists ludo_player_achievements_read_own on public.ludo_player_achievements;
create policy ludo_player_achievements_read_own on public.ludo_player_achievements
  for select to authenticated using ((select auth.uid()) = user_id);

grant all on public.ludo_player_profiles, public.ludo_player_loadouts,
  public.ludo_inventory, public.ludo_player_stats, public.ludo_achievement_catalog,
  public.ludo_player_achievements, public.ludo_match_results, public.ludo_xp_ledger,
  public.ludo_player_level_rewards to service_role;
grant usage, select on sequence public.ludo_xp_ledger_id_seq to service_role;

-- XP thresholds: ceil(100 * level^1.4). Level 100 is the cap.
create or replace function ludo_private.ludo_xp_required(p_level integer)
returns integer
language sql immutable strict
set search_path = ''
as $$
  select case when p_level = 100 then 0
    when p_level between 1 and 99 then ceil(100 * power(p_level::numeric, 1.4))::integer
    else null end;
$$;
revoke all on function ludo_private.ludo_xp_required(integer) from public, anon, authenticated;

-- This is an internal backend-only grant. The caller supplies only match/user IDs;
-- all scoring facts are loaded from the server-written ludo_match_results row.
create or replace function ludo_private.grant_ludo_match_xp(p_match_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_match public.ludo_match_results%rowtype;
  v_profile public.ludo_player_profiles%rowtype;
  v_today date := timezone('utc', now())::date;
  v_base integer;
  v_award integer;
  v_level integer;
  v_xp integer;
  v_total bigint;
  v_daily integer;
  v_before integer;
  v_unlocked integer[] := '{}'::integer[];
  v_reward jsonb;
  v_existing public.ludo_xp_ledger%rowtype;
  v_payload jsonb;
begin
  select * into v_match
    from public.ludo_match_results
    where match_id = p_match_id and user_id = p_user_id
    for update;
  if not found then raise exception 'ludo_match_result_missing' using errcode = 'P0002'; end if;

  if not v_match.completed or v_match.abandoned or v_match.completed_at is null then
    return jsonb_build_object('awardedXp', 0, 'reason', 'match_not_completed');
  end if;

  insert into public.ludo_player_profiles(user_id)
    values (p_user_id) on conflict (user_id) do nothing;
  insert into public.ludo_inventory(user_id,item_id,source)
    values (p_user_id,'fox_01','starter'),(p_user_id,'face_happy','starter')
    on conflict (user_id,item_id) do nothing;
  insert into public.ludo_player_loadouts(user_id,preset_slot,preset_name,character_id,face_id)
    values (p_user_id,1,'اصلی','fox_01','face_happy')
    on conflict (user_id,preset_slot) do nothing;
  select * into v_profile from public.ludo_player_profiles
    where user_id = p_user_id for update;

  select * into v_existing from public.ludo_xp_ledger
    where match_id = p_match_id and user_id = p_user_id;
  if found then return v_existing.result_payload; end if;

  v_base := 50 + (v_match.pieces_home * 10) + (v_match.captures * 15)
    + case v_match.placement when 1 then 150 when 2 then 80 when 3 then 40 else 0 end;
  if v_match.is_bot_match then
    v_base := floor(v_base * 0.25)::integer;
  elsif v_match.played_with_friend then
    v_base := floor(v_base * 1.20)::integer;
  end if;

  v_daily := case when v_profile.daily_xp_date = v_today then v_profile.daily_xp else 0 end;
  v_award := least(v_base, greatest(0, 500 - v_daily));
  v_level := v_profile.level;
  v_before := v_level;
  v_xp := v_profile.xp_into_level; -- daily cap resets; lifetime level progress never does.
  v_total := v_profile.total_xp + v_award;
  v_xp := v_xp + v_award;

  while v_level < 100 loop
    if v_xp < ludo_private.ludo_xp_required(v_level) then exit; end if;
    v_xp := v_xp - private.ludo_xp_required(v_level);
    v_level := v_level + 1;
    v_unlocked := array_append(v_unlocked, v_level);

    if mod(v_level, 10) = 0 then
      v_reward := jsonb_build_object('kind','milestone','coins',250,
        'titleId','title_level_' || v_level);
      update public.ludo_player_profiles
        set coins = coins + 250,
            unlocked_titles = case when ('title_level_' || v_level) = any(unlocked_titles)
              then unlocked_titles else array_append(unlocked_titles, 'title_level_' || v_level) end
        where user_id = p_user_id;
    else
      v_reward := jsonb_build_object('kind','level','coins',25);
      update public.ludo_player_profiles set coins = coins + 25 where user_id = p_user_id;
    end if;

    insert into public.ludo_player_level_rewards(user_id, level, reward_payload)
      values (p_user_id, v_level, v_reward)
      on conflict (user_id, level) do nothing;
  end loop;
  if v_level = 100 then v_xp := 0; end if;

  update public.ludo_player_profiles
    set level = v_level,
        xp_into_level = v_xp,
        total_xp = v_total,
        daily_xp = v_daily + v_award,
        daily_xp_date = v_today,
        last_seen = now(),
        updated_at = now()
    where user_id = p_user_id;

  v_payload := jsonb_build_object(
    'baseXp', v_base, 'awardedXp', v_award, 'newLevel', v_level,
    'xpIntoLevel', v_xp, 'totalXp', v_total, 'unlockedLevels', to_jsonb(v_unlocked)
  );
  insert into public.ludo_xp_ledger(
    match_id,user_id,daily_date,base_xp,awarded_xp,level_before,level_after,result_payload
  ) values (
    p_match_id,p_user_id,v_today,v_base,v_award,v_before,v_level,v_payload
  );
  return v_payload;
end;
$$;

revoke all on function ludo_private.grant_ludo_match_xp(uuid, uuid) from public, anon, authenticated;
grant usage on schema ludo_private to service_role;
grant execute on function private.grant_ludo_match_xp(uuid, uuid) to service_role;

-- Idempotent inventory grant primitive; duplicate delivery is a no-op.
create or replace function ludo_private.grant_cosmetic_item(
  p_user_id uuid, p_item_id text, p_source text, p_source_ref text default null
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_inserted integer;
begin
  if p_source not in ('game','purchase','gift','reward','starter') then
    raise exception 'invalid_cosmetic_source' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.ludo_cosmetic_catalog
    where id = p_item_id and is_active = true
  ) then
    raise exception 'cosmetic_item_unavailable' using errcode = 'P0002';
  end if;
  insert into public.ludo_inventory(user_id,item_id,source,source_ref)
    values (p_user_id,p_item_id,p_source,p_source_ref)
    on conflict (user_id,item_id) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted = 1;
end;
$$;
revoke all on function ludo_private.grant_cosmetic_item(uuid,text,text,text)
  from public, anon, authenticated;
grant execute on function ludo_private.grant_cosmetic_item(uuid,text,text,text)
  to service_role;
