# GapResan Dice — independent 3D prototype

This is a browser-only prototype for the first dice milestone. It is deliberately separate from the production Ludo UI and does not change Project 1 or the app runtime.

## Run
Open `index.html` in a modern browser with internet access (Three.js is loaded from jsDelivr). For local module restrictions, run a static server from this directory, e.g. `python -m http.server 8080`, then open `http://localhost:8080`.

## Try it
1. Enter a target result from 1 to 6.
2. Press the die or the large roll surface.
3. The cube launches immediately, spins, then eases into the precomputed orientation for the requested face.

## Fairness boundary
The input is a **simulation control**, not a random result source. In production, replace `getDemoResult()` with the authenticated server response. The client animation must never decide the game result. The quaternion table in `dice-logic.mjs` maps each face normal to world-up; the final 30% of the visible animation slerps toward that exact orientation.

## Scope
Included: one WebGL die, six high-contrast pip faces, target input, click-to-roll, motion arc, floor shadow, locked input during roll, reduced-motion fallback, and deterministic orientation tests.

Not included yet: tray walls/collisions, server request lifecycle, multiplayer rollId/seed synchronization, sound/haptics, skins, swipe/shake/auto-roll, or production integration.

## Tests
Run `node --test dice-logic.test.mjs` from this directory.
