# Arad Messenger — Product & Engineering Mindset

## Product principle

Arad Messenger is a real messaging product, not a visual mockup. Every visible control must map to a real application state, business rule, or backend operation. No dead buttons, fake success messages, or placeholder capabilities are introduced.

## Product pillars

- Fast private and group messaging
- Real channel publishing permissions
- Reliable media and voice messaging
- Offline-aware sending with visible queue state
- RTL-first Persian/Dari experience with correct mixed-script handling
- Safe Area and keyboard-safe layouts on modern Android/iOS devices
- Clear loading, empty, disabled, validation, permission, offline, and error states
- Consistent dark/light visual system with restrained motion
- Accessibility: readable contrast, large text support, touch targets, and focus/pressed states
- Security enforced in backend policies, not only hidden in the UI

## Core domains

1. Authentication and sessions
2. Conversations and membership
3. Messages and message lifecycle
4. Reactions, replies, forwards, edits, and deletion scopes
5. Voice/media attachments
6. Groups, roles, restrictions, invites, and moderation
7. Channels and admin-only publishing
8. Realtime synchronization
9. Offline queue and retry
10. Notifications
11. Profile and settings
12. Security/RLS and auditability

## Builder workflow

Different tools are used for different jobs; generated projects are references, not competing production backends.

- Figma: visual source of truth and component/layout exploration.
- Lovable: web/full-stack interaction prototype when workspace credits permit.
- InstantSite / InstaSite: rapid visual direction references.
- GitHub + Flutter: canonical production client and release pipeline.
- Supabase: canonical authentication, PostgreSQL, storage, realtime, and authorization.
- GitHub Actions: analyzer, tests, release APK build, and artifact verification.

Do not merge generated code blindly across builders. Preserve one canonical runtime architecture.

## Quality gate

Before a feature is considered complete:

1. UI state exists.
2. User interaction is wired.
3. Backend operation exists where required.
4. Authorization is enforced server-side.
5. Loading/empty/error/disabled states are handled.
6. RTL and Safe Area behavior are checked.
7. Analyze/test passes.
8. Release APK builds successfully.
9. No newly introduced dead controls remain.

## Current visual direction

- Deep charcoal dark surfaces
- One coherent purple/pink accent family
- Own messages use the existing pink/purple identity
- Other messages use neutral dark/gray surfaces
- Blue read indicators
- 16px primary radius
- 4/8/12/16/24 spacing rhythm
- Soft borders and restrained shadows
- Short, purposeful motion
- Persian/Dari-first RTL

This document is a product/engineering contract for the existing Arad Messenger project. It does not add UI by itself.
