# Odd or Even - Known Issues & Risk Register

## 1. Active Risks & Mitigations
- **Issue:** Web/Desktop simulated platform limitations with audio playback plugins.
  - **Mitigation:** Wrap audio calls in safe abstractions with graceful fallbacks and silent no-ops if device audio hardware is unavailable.
- **Issue:** Simultaneous RPC submissions on high-latency mobile networks.
  - **Mitigation:** Use PostgreSQL `SELECT FOR UPDATE` on `matches` and unique constraints on `pending_submissions`.
- **Issue:** Supabase credentials unavailable in initial offline development environment.
  - **Mitigation:** Designed completely decoupled domain layer so offline pass-and-play functions with 100% fidelity without any active Supabase connection.

## 2. Unresolved / Future Scope
- Competitive ELO ranking system (deferred to post-V1 release).
- Push notifications for room invitations (V2 scope).
