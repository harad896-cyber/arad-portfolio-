# Arad Messenger security hardening

Scope: Project 2 Flutter + Supabase only. This work is isolated on
`project2/security-hardening-20261119`; it does not modify the portfolio,
the default branch, or the Ludo prototype branch.

## Implemented in this branch

- Added a database trigger for Secret Chat inserts. The database now independently
  requires an authenticated sender matching `auth.uid()`, a two-member direct
  conversation, an active non-blocked peer, a same-conversation reply target, and
  bounded base64url ciphertext.
- Added validation for the stored X25519 public-key representation.
- The checks run in PostgreSQL, so bypassing Flutter UI validation does not bypass
  these Secret Chat invariants.

Migration:
`supabase/migrations/20261119_harden_secret_chat_database_guards.sql`

## Important risks still open — do not claim complete security

1. **Secret Chat protocol:** the current client uses long-lived X25519 identity keys
   and derives a conversation key with a plain SHA-256 construction. It does not
   provide forward secrecy or a reviewed ratchet protocol, and a displayed
   fingerprint is not automatically verified out-of-band. A malicious or compromised
   backend could substitute public keys. Do not market this implementation as
   Signal-level end-to-end encryption. A protocol migration (for example, a
   reviewed Signal-style X3DH/Double Ratchet implementation) needs a separately
   designed, interoperable upgrade with recovery and multi-device handling.
2. **Device revocation:** the current client heartbeat signs a revoked device out
   after it next contacts the backend, but a copied, still-valid Supabase JWT may
   continue to call APIs until expiry unless every sensitive server-side policy also
   binds authorization to a revocable server-side session. The UI heartbeat alone
   is not immediate token revocation.
3. **Storage policies:** every Storage bucket and object path must be checked for
   per-user or per-conversation authorization. Public buckets must contain only
   deliberately public assets; private chat media must not use public URLs.
4. **Authentication controls:** verify production Supabase Auth settings for MFA on
   privileged accounts, email confirmation, password policy, rate limits, redirect
   allowlists, and leaked-password protection where available.
5. **Secrets and supply chain:** scan the complete repository and Git history for
   credentials; rotate any exposed secret. Keep only the Supabase publishable key
   in the client. Never ship service-role, database-password, OAuth-client-secret,
   or signing secrets in Flutter assets or source.
6. **Release assurance:** run dependency vulnerability scanning, static analysis,
   automated RLS tests, storage authorization tests, and a real-device regression
   pass before release.

## Required validation before production

- Apply the migration to a staging Supabase project first.
- Verify a non-member cannot read or insert Secret Chat messages.
- Verify group conversations and conversations with more or fewer than two members
  cannot accept Secret Chat messages.
- Verify blocked peers cannot exchange Secret Chat messages in either direction.
- Verify a reply cannot reference a message in another conversation.
- Verify existing padded base64url keys and ciphertext continue to work.
- Run `flutter analyze` and `flutter test`, then run the Android build workflow.
- Repeat tests against the deployed Supabase project; a committed migration file
  is not proof that the live database has applied it.

No production Supabase migration has been applied by this branch.
