# Chat Games SDK — Stage 1

This folder contains a server-side, UI-independent game SDK and the first registered game module: XO (دوز).

## Contract
Every game module exposes:
- `id`
- `init(players, options)`
- `getLegalMoves(state, playerId)`
- `applyMove(state, playerId, move)`
- `getResult(state)`
- `serialize(state)` / `deserialize(payload)`

The registry rejects duplicate IDs and malformed modules. Add a new game by implementing this contract and registering it; existing modules do not need to be changed.

## XO rules
- `classic`: 3×3, three marks in a row.
- `five`: 5×5 bonus mode, four consecutive marks in a row.
- Rows, columns, both diagonal directions are checked.
- Invalid moves throw and never mutate the previous state.
- `version` increments once per accepted move.
- The serialized JSON is checked against a strict limit of less than 2,048 UTF-8 bytes.

## Server authority
This module is pure game logic, not a transport or security boundary by itself. The trusted server must authenticate the player ID, load the current state, call `applyMove`, and persist the returned state with an atomic version check. Do not accept client-supplied winner, board, turn, or role fields. WebSocket, PostgreSQL persistence, idempotency keys, chat cards, push notifications and UI are later stages.

## Tests
`node --test server/games/*.test.mjs`

The test suite includes rule edge cases, invalid moves, serialization integrity, registry behavior and 10,000 deterministic bot-vs-bot simulations.
