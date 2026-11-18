# Ludo legal moves and automatic turn decisions — Stage 1

This stage adds deterministic movement analysis and a turn-decision policy. It does not add board UI, animations, manual selection UI, networking, or timers.

## Core files

- `lib/ludo_engine.dart`: canonical state transitions and server-style validation.
- `lib/ludo_move_decision.dart`: detailed legal move output, rejection reasons, and automatic decision policy.
- `test/ludo_move_decision_test.dart`: rule matrix and automatic decision tests.
- `test/ludo_engine_test.dart`: no-move transition and 10,000-game simulation coverage.

## Detailed move analysis

Call `getLegalMoveAnalysis(state, dice, rules: ...)` only after a roll is pending. It returns:

- `legalMoves`: stable piece ID, piece index, progress `from/to`, every progress step in `path`, capture targets, `entersHome`, `exits`, and safe-square information.
- `rejectedMoves`: one entry for each unavailable piece, including a machine-readable reason code and Persian explanation.
- `error`: present when the state, phase, or dice value is invalid.

Progress coordinates are `-1` for the yard, `0..51` for the shared route, and `52..57` for the private home lane. A path contains the traversed progress coordinates, including the destination.

## Server-owned rule options

`LudoMoveRules` controls `allowOwnStack` and `allowPassBlockades`. The same flags are accepted by `applyLudoRoll`, `getLegalMoves`, `currentLegalMoves`, `applyLudoMove`, and `applyLudoNoMoveDecision`. The game service must load these flags from trusted room configuration; it must never accept rule flags supplied freely by the client.

A same-colour pair is a blockade. It cannot be landed on. Crossing a blockade is permitted only when `allowPassBlockades` is enabled. A single friendly piece at the destination is allowed only when `allowOwnStack` is enabled. Safe squares do not generate capture targets.

## Automatic decision policy

Call `decideLudoMove(state, analysis, autoMoveSinglePiece: ...)`:

| Situation | Decision | Minimum delay |
| --- | --- | ---: |
| No legal move, die 1–5 | Pass turn | 1 second |
| No legal move, die 6 | Roll again | 1 second |
| Exactly one move | Move automatically by default | 400 ms |
| Exactly one unfinished piece | Always move automatically | 400 ms |
| Multiple pieces with identical full path and destination | Choose the lowest stable piece index | 400 ms |
| Multiple different moves | Ask player | Immediate |
| Single-move auto disabled | Ask player, unless only one unfinished piece remains | Immediate |

The returned delay is a presentation policy. A turn controller should wait for it before invoking the server transition.

## No-move transition

`applyLudoRoll` now leaves a no-move result pending in `awaiting_move`, with an empty legal-move list. This allows the service to return rejection reasons and show the no-move message. After the delay, the service calls `applyLudoNoMoveDecision`:

- On a six, the same player keeps the turn and consecutive-six count.
- On a non-six, the consecutive-six count resets and the next active player receives the turn.
- The transition refuses to pass if a legal move exists.

A third consecutive six is still burned by the existing roll transition before move selection.

## Authority boundary

These are pure deterministic rules and validation functions in the repository. They are suitable to be called by a trusted game service and are tested for server-style validation, but this commit does **not** deploy a Supabase RPC/Edge Function or connect a client to a server endpoint. Until that backend endpoint is deployed, do not treat a client-side call to these Dart functions as a security boundary. The client must eventually send only a move request; the server must recalculate and apply it.

## Validation

```bash
flutter test test/ludo_move_decision_test.dart
flutter test test/ludo_engine_test.dart
```
