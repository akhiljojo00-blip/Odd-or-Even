# Odd or Even - Mobile Multiplayer Game

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2?logo=dart)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase)](https://supabase.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A competitive two-player hand-cricket mobile game built with Flutter, Riverpod, and Supabase. Players simultaneously submit numbers from `1` through `10`. Includes pass-and-play offline multiplayer with screen privacy handoff and server-authoritative online multiplayer.

## Documentation Index
- [Project Overview](docs/PROJECT_OVERVIEW.md)
- [System Architecture](docs/ARCHITECTURE.md)
- [Canonical Game Rules](docs/GAME_RULES.md)
- [Game State Machine](docs/GAME_STATE_MACHINE.md)
- [Match Configuration](docs/MATCH_CONFIGURATION.md)
- [Database Schema](docs/DATABASE_SCHEMA.md)
- [Security & Anti-Cheat](docs/SECURITY.md)
- [Realtime & Networking](docs/REALTIME_AND_NETWORKING.md)
- [UI/UX Design System](docs/UI_UX_DESIGN_SYSTEM.md)
- [Implementation Roadmap](docs/IMPLEMENTATION_ROADMAP.md)
- [Testing Strategy](docs/TESTING_STRATEGY.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Architecture Decisions](docs/DECISIONS.md)
- [Known Issues & Risks](docs/KNOWN_ISSUES.md)

## Quick Start
```bash
# Get dependencies
dart pub get

# Run tests
flutter test --no-version-check --suppress-analytics

# Run app
flutter run
```
