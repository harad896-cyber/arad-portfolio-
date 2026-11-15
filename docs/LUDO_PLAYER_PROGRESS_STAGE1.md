# GapResan Ludo — Player identity and progression (Stage 1)

This stage adds the data contract and server-authoritative XP/level rules only.
It does not add profile screens, store flows, leaderboards, Elo, badges UI, or game animations.

## Files

- `supabase/migrations/20261115190000_ludo_player_identity_progression.sql` — player identity, progression profile, loadout presets, inventory, stats, achievement progress, server match facts, XP ledger, reward claims, RLS and private RPCs.
- `supabase/seed/ludo_items.json` — the canonical item/character metadata file, including eight character definitions, four visual states, personalities, rarity glow colors, cosmetic slots and level reward metadata.
- `lib/ludo_xp_service.dart` — pure Dart mirror of XP formulas for deterministic unit tests and UI projections. It is not a client-side grant API.
- `test/ludo_xp_service_test.dart` — XP curve, placement, friend/bot multipliers, abandonment, daily cap, level-up and boundary tests.
- `supabase/tests/ludo_progression_contract.sql` — transactional database contract test. Run against a disposable local Supabase database after applying the migration.

## Security and transaction model

1. The game server writes the authoritative row to `public.ludo_match_results`. The mobile client must never write this table.
2. A trusted backend worker calls `ludo_private.grant_ludo_match_xp(match_id, user_id)` through a server-only database connection. The `ludo_private` schema is deliberately not exposed through the Data API; execute permission is granted only to `service_role`. The function accepts identifiers, not client-supplied XP or counters.
3. The function locks the match row and the player's progression row, checks the unique XP ledger, applies the UTC daily cap (500), carries lifetime level progress across day boundaries, and grants level rewards in the same database transaction.
4. Repeating the same grant returns the stored result and cannot add XP twice. Inventory items use a unique (user_id,item_id) key and an idempotent server-only grant function.
5. Authenticated clients can read their own profile/loadouts/inventory/stats. They cannot update XP, level, coins, gems, stats, inventory or server match facts. The messenger avatar is joined from `public.profiles`; it is not copied into Ludo.

## XP rules

- Participation: 50 XP.
- Each piece reaching home: 10 XP.
- Each capture: 15 XP.
- Placements: 1st 150, 2nd 80, 3rd 40, 4th 0.
- Human friend match: +20%.
- Bot match: 25% of base XP; friend bonus is not stacked onto bot games.
- Abandoned/incomplete match: 0 XP.
- UTC daily cap: 500 XP.
- Required XP to advance from level n: `ceil(100 * n^1.4)`, levels 1–99; level 100 is the cap.
- Every level grants 25 coins; every tenth level grants 250 coins and unlocks a title identifier.

## Apply and verify

The migration is committed but has **not** been applied to the user's hosted Supabase project. Supabase's 2026 Data API exposure defaults can also require explicit schema exposure/grants for future REST endpoints; do not expose `ludo_private` to clients. Review it first, then apply through the project's approved migration workflow. Run the SQL contract test on a disposable local database. The GitHub Actions workflow runs Flutter tests; it does not execute the SQL contract test or verify hosted Supabase state.

The JSON references asset keys; the corresponding Rive/Spine/preview files are not part of this stage. No APK or installable build is produced here.
