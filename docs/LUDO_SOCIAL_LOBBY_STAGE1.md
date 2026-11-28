# GapResan Ludo social lobby — Stage 1

This stage covers room creation, invitations, lobby presence, readiness, and quick matchmaking. It does not start the game or add WebSocket gameplay, voice chat, push delivery, or board effects.

## Included

- Create a 2–4 player room, private by default, with a six-digit room code and a ten-minute lobby expiry.
- Create a shareable `arad://ludo?token=…&code=…` invite link handled by the app's existing `AppLinks` route.
- Post an invitation card in the originating chat and invite members of a group conversation in batches of at most 20.
- Invite selected contacts from the lobby.
- Join by invite token or room code.
- Live lobby player seats, profile names/avatars, and a ready/unready toggle.
- Public Quick Match RPC that allocates a seat while locking the room row to avoid overfilling.
- Classic and one-piece room modes; host option to mark a room for bot fill (actual bot insertion is a later game-start step).

## Database migration

Apply migrations in timestamp order, including:

- `supabase/migrations/20261115120000_ludo_social_lobby_invites.sql`
- `supabase/migrations/20261115170000_ludo_quick_match.sql`

For a linked Supabase project, review the migration diff and then run:

```bash
supabase db push
```

Do not run the quick-match UI against a database until both migrations are applied. The RPCs require an authenticated Supabase user.

## Run the app

```bash
flutter pub get
flutter run
```

Open a direct chat or group chat, open the attachment menu, and select **بازی منچ**. The profile page also exposes **دعوت به بازی منچ**.

## Manual integration test

Use two or more authenticated test accounts:

1. From a chat, create a private room for 2 players.
2. Confirm the chat receives a Ludo invite card.
3. Copy/share the invite link and open it on the second account; verify it opens the Ludo lobby and joins the invited room.
4. Join using the six-digit code from an account that has permission (private rooms must reject non-invitees).
5. Toggle ready/unready and verify the other account sees the update without reopening the page.
6. Invite multiple contacts and verify the invitation inbox lists pending invitations.
7. In a group chat, create a room and verify all group invite RPC calls are batched while the card is still posted if a batch fails.
8. Tap Quick Match from two accounts using the same mode; verify both are seated in a public lobby and no room exceeds its capacity.
9. Wait more than ten minutes and verify expired invitations cannot be joined.

## Current boundary / known follow-up

- The invitation inbox and chat card are in-app notifications. OS push delivery is not wired because this repository does not currently include a configured FCM/APNs push sender.
- Quick Match creates or joins a public lobby; the game does not auto-start yet.
- Bot fill is stored as a host preference; actual bot seats are added at the later game-start stage.
- SQL migrations must be applied to the connected Supabase database separately from committing files to GitHub.
- Flutter unit tests cover the pure game engine. Lobby RPC and realtime behavior still require the two-account integration test above.
