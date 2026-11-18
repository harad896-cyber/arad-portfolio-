-- Add covering indexes for Ludo foreign keys reported by Supabase performance advisor.
-- Keep these indexes separate from the existing owner/room composite indexes.
create index if not exists ludo_owned_cosmetics_cosmetic_id_idx
  on public.ludo_owned_cosmetics (cosmetic_id);
create index if not exists ludo_player_appearance_aura_id_idx
  on public.ludo_player_appearance (aura_id);
create index if not exists ludo_player_appearance_character_id_idx
  on public.ludo_player_appearance (character_id);
create index if not exists ludo_player_appearance_glasses_id_idx
  on public.ludo_player_appearance (glasses_id);
create index if not exists ludo_player_appearance_hat_id_idx
  on public.ludo_player_appearance (hat_id);
create index if not exists ludo_player_reward_claims_level_idx
  on public.ludo_player_reward_claims (level);
create index if not exists ludo_room_invites_invited_by_idx
  on public.ludo_room_invites (invited_by);
create index if not exists ludo_room_players_user_id_idx
  on public.ludo_room_players (user_id);
create index if not exists ludo_rooms_host_id_idx
  on public.ludo_rooms (host_id);
create index if not exists ludo_xp_ledger_room_id_idx
  on public.ludo_xp_ledger (room_id);
