-- Cosmetic-only Ludo catalog and account appearance for GapResan.
create table if not exists public.ludo_cosmetic_catalog (
  id text primary key,
  name text not null,
  category text not null check (category in ('character','hat','glasses','aura','face','board','dice','trail','effect','profile_frame')),
  asset_key text not null default '',
  preview text not null default '',
  rarity text not null default 'common' check (rarity in ('common','rare','epic','legendary')),
  emoji text,
  color_hex text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create table if not exists public.ludo_player_appearance (
  user_id uuid primary key references auth.users(id) on delete cascade,
  character_id text not null default 'fox_01' references public.ludo_cosmetic_catalog(id),
  face_id text not null default 'happy',
  body_color text not null default '#F28A35',
  hat_id text references public.ludo_cosmetic_catalog(id),
  glasses_id text references public.ludo_cosmetic_catalog(id),
  aura_id text references public.ludo_cosmetic_catalog(id),
  updated_at timestamptz not null default now()
);
create table if not exists public.ludo_owned_cosmetics (
  user_id uuid not null references auth.users(id) on delete cascade,
  cosmetic_id text not null references public.ludo_cosmetic_catalog(id) on delete cascade,
  acquired_at timestamptz not null default now(),
  source text not null default 'starter',
  primary key(user_id,cosmetic_id)
);
alter table public.ludo_cosmetic_catalog enable row level security;
alter table public.ludo_player_appearance enable row level security;
alter table public.ludo_owned_cosmetics enable row level security;
revoke all on public.ludo_cosmetic_catalog,public.ludo_player_appearance,public.ludo_owned_cosmetics from anon,authenticated;
grant select on public.ludo_cosmetic_catalog to authenticated;
grant select,insert,update on public.ludo_player_appearance to authenticated;
grant select on public.ludo_owned_cosmetics to authenticated;
drop policy if exists ludo_catalog_active_read on public.ludo_cosmetic_catalog;
create policy ludo_catalog_active_read on public.ludo_cosmetic_catalog
for select to authenticated using (is_active = true);
drop policy if exists ludo_appearance_read on public.ludo_player_appearance;
create policy ludo_appearance_read on public.ludo_player_appearance
for select to authenticated using (true);
drop policy if exists ludo_appearance_insert_own on public.ludo_player_appearance;
create policy ludo_appearance_insert_own on public.ludo_player_appearance
for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists ludo_appearance_update_own on public.ludo_player_appearance;
create policy ludo_appearance_update_own on public.ludo_player_appearance
for update to authenticated using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
drop policy if exists ludo_owned_read_own on public.ludo_owned_cosmetics;
create policy ludo_owned_read_own on public.ludo_owned_cosmetics
for select to authenticated using ((select auth.uid()) = user_id);

insert into public.ludo_cosmetic_catalog
(id,name,category,asset_key,preview,rarity,emoji,color_hex,sort_order)
values
('fox_01','روباه','character','characters/fox/model.riv','characters/fox/preview.webp','common','🦊','#F28A35',10),
('robot_01','ربات','character','characters/robot/model.riv','characters/robot/preview.webp','rare','🤖','#58B8C9',20),
('tiger_01','ببر','character','characters/tiger/model.riv','characters/tiger/preview.webp','epic','🐯','#E99A35',30),
('astronaut_01','فضانورد','character','characters/astronaut/model.riv','characters/astronaut/preview.webp','legendary','🧑‍🚀','#91A9D8',40),
('space_helmet','کلاه فضایی','hat','items/hats/space_helmet.webp','items/hats/space_helmet.webp','epic','🪖',null,50),
('crown','تاج','hat','items/hats/crown.webp','items/hats/crown.webp','legendary','👑',null,60),
('neon_glasses','عینک نئونی','glasses','items/glasses/neon.webp','items/glasses/neon.webp','rare','🕶️',null,70),
('green_spark','جرقه سبز','aura','items/auras/green_spark.riv','items/auras/green_spark.webp','legendary','✨',null,80)
on conflict(id) do update set name=excluded.name,category=excluded.category,asset_key=excluded.asset_key,
preview=excluded.preview,rarity=excluded.rarity,emoji=excluded.emoji,color_hex=excluded.color_hex,
is_active=true,sort_order=excluded.sort_order;
