# Ludo 3D Dice Demo (Standalone)

This is an isolated Flutter prototype. It is deliberately not connected to the Ludo board, turn engine, Supabase, or multiplayer flow yet.

## What it does

- Accepts a requested final face from 1 to 6.
- Rejects blank, non-numeric, and out-of-range input.
- Animates a cube using quaternion rotations around all three axes.
- Projects all six cube faces with perspective, draws the pips on their actual 3D faces, and depth-sorts the visible faces.
- Uses the standard opposite-face pairs 1/6, 2/5, and 3/4.
- Computes a final orientation that places the requested face upward.
- Locks the input and button while the animation is running.
- Uses no random number generator and does not alter game state.

## Files

- `lib/dice_3d_math.dart`: vector, quaternion, and target-face orientation math.
- `lib/ludo_dice_demo.dart`: standalone UI, animation controller, perspective projection, cube faces, and pips.
- `test/ludo_dice_demo_test.dart`: all six orientation mappings, opposite-face layout, invalid input, interaction locking, and all six outcomes.

## Run locally

```bash
flutter test test/ludo_dice_demo_test.dart
flutter run
```

To preview the widget in an app shell, temporarily use:

```dart
MaterialApp(
  debugShowCheckedModeBanner: false,
  home: DiceRollDemo(),
)
```

## Deliberate limits of this stage

The cube is rendered in 3D with quaternion orientation and perspective projection, but the motion is still a controlled animation—not a rigid-body physics simulation. It does not yet simulate table contact, wall collisions, friction, or a tray. There is no sound, haptic feedback, multiplayer synchronization, or server-authoritative result. Those should be separate stages after the standalone interaction is visually reviewed.
