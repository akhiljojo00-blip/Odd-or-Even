# Odd or Even - System Architecture

## 1. High-Level Architecture

The Odd or Even architecture separates client presentation from domain game logic. A core pure-Dart game engine executes identically offline and online for optimistic UI rendering, while an authoritative PostgreSQL backend governs official online matches.

```
+-------------------------------------------------------------+
|                      Flutter Client                         |
|  +--------------------+  +-------------------------------+  |
|  |     UI Layer       |  |       Riverpod Providers      |  |
|  | (Screens, Widgets) |  | (MatchState, Offline, Online) |  |
|  +--------------------+  +-------------------------------+  |
|             \                       /                       |
|              v                     v                        |
|        +-----------------------------------------+          |
|        |       Shared Dart Game Engine           |          |
|        | (Domain Models, Rules, State Machine)   |          |
|        +-----------------------------------------+          |
+-------------------------------------------------------------+
          | (Offline: Pure local)        | (Online: Supabase)
          v                              v
    +-------------+         +----------------------------+
    | Local Store |         |       Supabase Backend     |
    | (Prefs/RAM) |         | - Auth (JWT / Guest)       |
    +-------------+         | - Private Submissions (RLS)|
                            | - RPC Engine (PostgreSQL)  |
                            | - Realtime Broadcast / Snap|
                            +----------------------------+
```

## 2. Directory Layout
```
lib/
├── app/                  # App initialization, router, theme
├── core/
│   ├── config/           # App config, Supabase constants
│   ├── errors/           # Failure models & error handling
│   ├── theme/            # Color palette, typography, shapes
│   └── utils/            # Haptics, timer utils, sound fx
├── features/
│   ├── auth/             # Anonymous and Supabase authentication
│   ├── home/             # Main menu and navigation hub
│   ├── game/             # Shared Game Domain Engine & models
│   ├── offline/          # Pass-and-play local game flow
│   ├── online/           # Online gameplay, sync, realtime handler
│   ├── rooms/            # Room creation, joining, lobby agreement
│   ├── matchmaking/      # 1v1 quick match queue
│   ├── history/          # Match history & scorecards
│   ├── profile/          # Player profile & statistics
│   └── settings/         # Audio, haptic, theme, gameplay prefs
└── shared/
    ├── widgets/          # Reusable UI cards, buttons, badges
    └── animations/       # Toss coin, score reveal, wicket FX
```

## 3. Pure-Dart Shared Game Engine
The domain engine located in `lib/features/game/domain/` has zero Flutter dependencies (`dart:ui` free). This ensures:
- 100% unit testability without widget overhead.
- Identical logic offline and in client-side online prediction.
- Symmetric parity calculation with PostgreSQL RPC functions.

## 4. State Management (Riverpod)
- State is modeled with immutable data classes (`GameMatchState`, `InningsState`, `BallEvent`, `MatchConfig`).
- `Notifier` / `StateNotifier` patterns control match state transitions.
- Offline engine updates state synchronously on user actions.
- Online engine reflects Supabase Realtime broadcast snapshots, fetching recovery state via RPC on connection drops.

## 5. Security & Isolation Boundaries
1. **Private Submissions Table:** Client insert permissions only write to a private staging table. RLS forbids `SELECT *` from opponents.
2. **Atomic RPCs:** `submit_turn()` and `resolve_ball()` run in `SERIALIZABLE` or `FOR UPDATE` transactions to eliminate race conditions.
3. **Snapshot Verification:** Client never sends run totals or wicket updates; the backend computes runs and transitions innings.
