# Mafia Engine — Stage 1

This is a pure Dart rules engine for the GapResan Mafia game. It is not yet a realtime server.

## Trust boundary
- Run the engine only in a trusted server process.
- Keep `MafiaGame`, `secretRole`, submitted actions, votes and the event log private.
- Broadcast only `MafiaEngine.publicSnapshot`.
- Send `privateSnapshot` and `NightResolution.privateResults[playerId]` only to the authenticated player matching that ID.
- Client requests must be authenticated and mapped to the server-side player ID before calling the engine. Never accept a client-supplied role, winner, phase, timestamp or resolved result.

## Phase sequence
`lobby → roleDistribution → night → dawn → day → voting → defense → finalVote → execution → night`.
A terminal win moves to `finished`. The server owns the clock and calls phase methods when its deadline expires; the engine never trusts a client clock.

## Night resolution order
1. Collect valid actions; omitted actions are treated as pass.
2. Apply doctor protection.
3. Resolve mafia and sniper attacks; protected targets survive.
4. Resolve veteran alert retaliation.
5. Calculate detective/interrogator results as private per-player results.
6. Apply eliminations and evaluate win conditions.

## Voting
The first vote creates the defense candidate set (all players tied at the highest vote count). Final vote executes only a unique top candidate; a tie or empty ballot executes nobody. Mayor votes have weight two.

## Role notes
Base roles are mafia, citizen, doctor and detective. Optional roles are mafia boss, sniper, veteran, mayor, interrogator, madman and joker. Role assignment is randomized on the server. Eight-player defaults are 2 mafia, 1 doctor, 1 detective and 4 citizens.

Some special-role win/ability semantics need product decisions before production: this first engine stage defines their teams and the core actions, but does not yet implement a distinct solo victory condition for madman/joker or special mafia-boss powers. Those must be specified and tested before enabling those roles in public matches.

## Timers and reconnect
Durations are configuration values. Persist server deadlines, not client countdown values. A disconnected player has 60 seconds to reconnect; after expiry the engine marks them eliminated.

## Replay and audit
The event list is append-only within this in-memory engine and intentionally excludes secret role/action targets from public event payloads. Production replay must persist a server-signed, access-controlled event stream with private event partitions; never publish the raw log to all players.
