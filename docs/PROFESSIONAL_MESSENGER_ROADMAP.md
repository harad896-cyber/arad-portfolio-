# Arad Messenger — Professional Product & Reliability Roadmap

Scope: Project 2 only (Flutter + Supabase). Keep this work on
`project2/security-hardening-20261119`; never modify the portfolio/default branch
or the separate Ludo prototype.

This roadmap defines the product direction. It is not a claim that every item is
already implemented or production-tested.

## Product promise

Arad Messenger should be a dependable, maintainable messaging product—not a demo.
Every visible action must have a real backend result, a clear failure state, and
a recoverable path. Never use fake users, placeholder conversations, or silent
success messages in production.

## 1. Account, session, and device control

- Account lifecycle: verified sign-in, recovery, profile, sign-out, account deletion
  flow, and clear session-expiry handling.
- Device/session center: show known sessions with device label, last activity,
  and current-session marker; let the account owner revoke a session.
- Enforce revocation server-side for sensitive operations; do not rely only on a
  client heartbeat or a hidden UI state.
- Protect privileged owner/admin actions with server authorization, audit events,
  and optional MFA. Never grant admin rights from a client-supplied role field.
- Apply rate limits and abuse controls to login, verification, invitations, and
  message/report endpoints.

## 2. Messaging that works end-to-end

- Direct conversations, groups, and channels with membership and permission rules.
- Text, reply, edit, delete-for-me/delete-for-everyone (with explicit policy),
  forward, reactions, pinned messages, search, unread counts, and Saved Messages.
- Attachments: images, video, audio, documents; upload progress, retry, size/type
  validation, private storage, and expiring or authorized access URLs.
- Voice notes with playback speed, seek, waveform, and reliable recording lifecycle.
- Calls only when signaling, permission handling, network recovery, and real-device
  audio tests pass; otherwise clearly mark the feature unavailable rather than fake it.
- Offline-first UX: cached conversations and drafts, queued sends with status,
  reconnect indicator, conflict-safe refresh, and no blank-screen startup.

## 3. Privacy and security architecture

- RLS is the primary database boundary: test every table for owner, member,
  outsider, blocked-user, and revoked-session cases.
- Keep private media in private buckets; verify object path ownership and access.
- Store device secrets in platform secure storage; never in plain preferences.
- Define a reviewed E2EE protocol and key lifecycle before calling Secret Chat
  secure: identity verification, key change warnings, multi-device behavior,
  backup/recovery tradeoffs, and forward secrecy/ratchet requirements.
- Threat-model push notifications, logs, analytics, backups, and crash reports;
  avoid logging message bodies, tokens, or private file URLs.
- Keep secrets out of the app bundle and Git history; rotate exposed credentials.
- Add security regression tests and dependency scanning to CI.

## 4. Moderation and owner controls — with boundaries

- Server-authorized owner/admin roles, scoped group/channel permissions, invite
  controls, member removal, mute/ban, reports, and an auditable moderation log.
- Role changes and destructive actions require confirmation and are checked by the
  backend—not merely hidden from ordinary users in Flutter.
- Admin tools must not expose private messages indiscriminately. Any moderation
  access must follow a clearly documented privacy policy and legal basis.
- Provide users block, report, privacy settings, and account/session controls.

## 5. Professional UX and accessibility

- Consistent design system, light/dark/system themes, responsive layouts, and
  accessible contrast, text scaling, and touch targets.
- Stable navigation and loading/empty/error states; no white flash or indefinite
  spinner. Preserve drafts and unsent content across app restarts.
- Message composer, attachment picker, profile, group management, and settings
  share predictable interaction patterns.
- Localization-ready strings and Afghan Dari/Persian wording where appropriate;
  avoid hard-coded text scattered across widgets.

## 6. Reliability, data durability, and release discipline

- Database migrations are versioned, reviewed, reversible where feasible, and
  applied to staging before production. Back up before destructive migrations.
- Define backup/restore and account/data export behavior; test restoration, not
  just backup creation.
- Add crash/error telemetry with privacy-safe redaction, performance budgets,
  and monitoring for auth, messaging, upload, and realtime failures.
- CI gates: format, analyze, unit/widget tests, RLS/storage integration tests,
  Android build, artifact checksum, and release notes.
- Release checklist: staging smoke test, supported Android versions, install/
  upgrade test, offline test, two-account test, and rollback plan.
- Pin the exact source commit and publish the SHA-256 of the final APK. Never
  substitute an older artifact or call an untested build device-verified.

## Delivery order

1. **Stability first:** inventory existing flows, reproduce crashes/white screens,
   preserve working features, add regression tests.
2. **Authorization foundation:** audit schema, RLS, storage, admin roles, and
   revocable sessions; close high-risk server-side gaps.
3. **Core messaging:** verify direct/group/channel lifecycle, delivery states,
   media retry, Saved Messages, and offline queue.
4. **Privacy protocol:** design and review Secret Chat/key migration before
   implementation or security claims.
5. **Polish and release:** accessibility, localization, performance, monitoring,
   backup/restore, and signed reproducible release process.

## Definition of done

A feature is complete only when its UI, backend authorization, persistence,
error/retry behavior, automated tests, and release documentation agree. A
successful build alone is not proof of runtime correctness or production security.
