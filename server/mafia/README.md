# GapResan Mafia Engine — Stage 1

The authoritative engine is Node.js and belongs in the trusted server runtime, not in Flutter/mobile code. It has no WebSocket, Redis, database or UI dependency yet.

## Run tests
`node --test server/mafia/mafia-engine.test.mjs`

## Security boundary
- Keep the engine instance, role assignments, actions, votes and raw replay log on the server.
- Broadcast only `publicSnapshot()`.
- Send `privateSnapshot(authenticatedPlayerId)` and `resolveNight().privateResults[playerId]` only to the authenticated player.
- Derive player IDs from the authenticated session. Never trust client-supplied roles, winners, phase transitions, time, or resolved outcomes.
- Raw replay data is moderator-only. Public event payloads intentionally omit secret role and action targets.

## State machine
`lobby → roleDistribution → night → dawn → day → voting → defense → finalVote → execution → night`; terminal conditions move to `finished`. The server owns deadlines and invokes transitions after timers expire.

## Night order
1. Validate and collect actions; missing action is pass.
2. Resolve doctor protection.
3. Resolve the shared mafia ballot (unique plurality only) and sniper attack.
4. Apply veteran retaliation.
5. Compute detective/interrogator results privately.
6. Apply eliminations and check win conditions.

## Voting
First vote advances every tied top candidate to defense. Final vote executes only a unique top candidate; a tie or empty ballot executes nobody. Mayor vote weight is two.

## Scope / known decisions
Eight players produce exactly 2 mafia, doctor, detective and 4 citizens. Optional roles are represented in the catalog and default balancing. The initial engine defines mafia boss as a mafia-aligned killer, sniper as a one-use night shooter, veteran as a visitor retaliator, mayor as a double-weight voter, and interrogator as an alignment investigator. Madman and joker are catalogued as neutral but their special solo-win triggers are intentionally not enabled until their exact rules are agreed. They should not be enabled in production matches yet.

WebRTC, SFU, Redis room orchestration, PostgreSQL persistence, role-specific event routing, host narrator, bot narrator, AFK bot replacement, screenshot detection, penalty scoring, achievements and UI are later stages.
