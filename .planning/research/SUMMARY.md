# Project Research Summary

**Project:** Snaker-Elm Multiplayer Game Upgrade
**Domain:** Real-time multiplayer web game (Elm + Phoenix Channels)
**Researched:** 2026-01-30
**Confidence:** MEDIUM-HIGH

## Executive Summary

This project requires upgrading a multiplayer snake game from Elm 0.18 + Phoenix 1.3 (2017 stack) to Elm 0.19.1 + Phoenix 1.7 (2025/2026 stack) while simultaneously fixing a critical multiplayer state synchronization bug. The upgrade path involves major breaking changes across both frontend and backend, with the WebSocket communication layer requiring complete reimplementation due to Elm 0.19's removal of Native modules.

The recommended approach is to migrate the game from its current event-driven client-side simulation model to a server-authoritative architecture where the server maintains canonical game state and broadcasts full state snapshots. This architectural shift, combined with the stack upgrade, will fix the state sync bug that currently prevents new players from seeing existing snakes at correct positions. The migration must be atomic—both Elm and Phoenix upgrades are coupled through the WebSocket protocol and cannot be deployed independently.

The critical risk is the WebSocket communication rewrite (elm-phoenix-socket → ports-based implementation), which represents the highest-complexity component with no direct migration path. Secondary risks include asset pipeline replacement (Brunch → esbuild) and timing-sensitive multiplayer state synchronization. Success requires sequential migration: environment setup → Phoenix backend → asset pipeline → Elm frontend → WebSocket integration → state sync implementation, with full integration testing at each phase boundary.

## Key Findings

### Recommended Stack

The modern 2025/2026 Elm + Phoenix stack has evolved significantly from the 2017 implementation, with breaking changes across every layer of the stack.

**Core technologies:**
- **Elm 0.19.1**: Latest stable release; major breaking changes from 0.18 (package format, core libraries, no Native modules)
- **Phoenix 1.7.14**: Current stable version; replaced Brunch with esbuild, improved WebSocket performance, modernized directory structure
- **Elixir 1.15.7 + Erlang/OTP 26**: Required for Phoenix 1.7 compatibility, modern language features
- **esbuild**: Asset bundling (replaced Brunch); faster, simpler, but no native Elm support
- **mise**: Version management (project requirement); replaces asdf with better performance
- **Ports-based WebSocket**: Required for Elm 0.19 since elm-phoenix-socket uses forbidden Native modules

**Critical breaking change:**
The `fbonetti/elm-phoenix-socket` package (currently v2.2.0) is incompatible with Elm 0.19 due to Native module removal. Must migrate to either ports + Phoenix JavaScript client (recommended) or `saschatimme/elm-phoenix` package (if 0.19 compatible). This is the highest-risk component of the migration.

### Expected Features

The multiplayer state sync bug fix requires implementing server-authoritative game state, which changes feature behavior significantly.

**Must have (table stakes):**
- Server maintains authoritative game state (snake positions, apples, tick timing)
- Full state broadcast on player join (existing players visible at correct positions)
- Real-time direction changes via Phoenix Channels (existing functionality preserved)
- Client-side prediction for responsive input (optional optimization)
- Consistent apple spawning across all clients (server-generated, not client RNG)

**Should have (competitive):**
- State reconciliation on client (handle network latency gracefully)
- Reconnection handling (Phoenix Channels provides this, must wire up in Elm)
- Smooth visual interpolation (CSS transitions or Elm-based, low priority)

**Defer (v2+):**
- Multiple game rooms (architecture supports via DynamicSupervisor, but implement later)
- Spectator mode (not required for fix)
- Replay/recording (not essential for launch)
- Mobile controls (current game is keyboard-only)

**Anti-features (explicitly avoid):**
- Client-side game simulation (root cause of current bug)
- Event-only synchronization (leads to timing drift)
- Native modules in Elm (forbidden in 0.19)

### Architecture Approach

The fix requires migrating from event-driven client simulation to server-authoritative state synchronization with optional client prediction.

**Major components:**

1. **GameServer (GenServer)** — NEW: Authoritative game loop running 100ms ticks; maintains snakes, apples, collision detection; broadcasts state via PubSub
2. **GameChannel (Phoenix.Channel)** — MODIFIED: WebSocket lifecycle management; forwards inputs to GameServer; receives PubSub broadcasts and pushes to clients
3. **Elm Ports Module** — NEW: Bidirectional communication with Phoenix JavaScript client (replaces elm-phoenix-socket)
4. **Board Reconciliation (Elm)** — MODIFIED: Receive server state snapshots; optional prediction/reconciliation for responsive input
5. **GameSupervisor (Supervisor)** — NEW: Supervise GameServer instances (future-proofs for multiple game rooms)

**Data flow (authoritative server pattern):**
```
Client Input → Port → JavaScript → Channel → GameServer
GameServer Tick (100ms) → PubSub Broadcast → Channel → JavaScript → Port → Elm Update
Elm renders server state (authoritative), optionally predicts next frame
```

**Build order rationale:**
Backend must be authoritative before client can reconcile. Phoenix upgrade enables esbuild. esbuild enables Elm 0.19 compilation. Elm 0.19 enables ports. Ports enable WebSocket. WebSocket enables state sync fix. This creates a strict sequential dependency chain.

### Critical Pitfalls

1. **Native modules forbidden (Elm 0.19)** — elm-phoenix-socket cannot be used; must rewrite WebSocket layer with ports + Phoenix JavaScript client; complete rewrite of socket initialization, message passing, subscriptions; highest risk component.

2. **Brunch removed from Phoenix 1.7** — Asset pipeline completely changed; must configure esbuild + separate Elm compilation step; no automated migration; elm-brunch plugin incompatible; requires custom build scripts.

3. **Client tick timing divergence** — Current bug: clients tick independently at 100ms, positions drift; migration amplifies this if not fixed; MUST implement server-authoritative tick during upgrade, not defer to later phase.

4. **Apple generation on client** — Currently Random.generate per client; each player sees different apples; must move to server-side RNG with broadcast; blocking bug for playability.

5. **Player join without full state** — New players only receive metadata, not snake positions; must implement full state snapshot on join; affects GameChannel.join/3 and GameServer.get_state/0.

6. **Version lock-step requirement** — Cannot upgrade Elm and Phoenix independently; WebSocket protocol couples them; big-bang cutover required; no incremental migration path; must branch and test full stack before merge.

7. **Keyboard module removed (Elm 0.19)** — elm-lang/keyboard deleted; must migrate to Browser.Events.onKeyDown with custom JSON decoders; affects game controls; moderate impact but straightforward fix.

## Implications for Roadmap

Based on research, the migration has a strict dependency chain with minimal parallelization opportunities. Suggested phase structure follows the critical path through breaking changes.

### Phase 1: Environment & Phoenix Backend Upgrade
**Rationale:** Foundation work; Phoenix upgrade is less risky than Elm and enables asset pipeline modernization; establishes server-authoritative architecture before client changes.

**Delivers:**
- mise environment configured (Elixir 1.15, Erlang 26, Node 20)
- Phoenix 1.7.x dependencies updated (mix.exs)
- WebSocket transport configuration migrated (Phoenix.Transports → endpoint socket config)
- Cowboy 1.x → 2.x upgrade
- Poison → Jason JSON library swap
- GameServer GenServer implemented (authoritative game loop)
- GameSupervisor supervision tree
- PubSub integration for state broadcast

**Addresses features:**
- Server-authoritative game state (must-have)
- Full state broadcast infrastructure

**Avoids pitfalls:**
- PITFALL 9: Phoenix.Transports removed (fixed in this phase)
- PITFALL 10: Cowboy 2.x required (fixed in this phase)
- PITFALL 22: GenServer race conditions (addressed during GameServer implementation)

**Testing gate:** Phoenix server runs; GameServer ticks and broadcasts to iex console; channel tests pass.

### Phase 2: Asset Pipeline Migration (Brunch → esbuild)
**Rationale:** Enables Elm 0.19 compilation; decoupled from Phoenix runtime (can test in parallel with Phase 1); required before frontend changes.

**Delivers:**
- Brunch removed (brunch-config.js deleted, npm deps cleaned)
- esbuild configured in config/config.exs
- Elm compilation script (elm make → assets/js/elm.js)
- npm scripts for build:elm + build:js
- Development watcher configured
- Production build tested (mix assets.deploy)

**Addresses features:**
- Build system for Elm 0.19 (prerequisite)

**Avoids pitfalls:**
- PITFALL 11: Brunch deprecated (removed in this phase)
- PITFALL 16: esbuild lacks native Elm support (custom script created)
- PITFALL 17: esbuild explicit imports (app.js updated)
- PITFALL 18: output path conventions (priv/static/assets configured)
- PITFALL 30: npm vs mix workflows (updated for Phoenix 1.7)

**Testing gate:** Assets compile in dev and prod; static files served correctly; no compilation errors.

### Phase 3: Elm 0.19 Core Migration
**Rationale:** Upgrade Elm language and standard library before tackling WebSocket (most complex part); get compiler working with simpler changes first.

**Delivers:**
- elm-package.json → elm.json conversion
- Package namespace updates (elm-lang/* → elm/*)
- Html.program → Browser.element migration
- Keyboard.ups → Browser.Events.onKeyUp migration
- Time.every API updates (Posix-based)
- toString → custom Direction.toString
- JSON decoder updates for Elm 0.19
- Compilation succeeds (elm make runs without errors)

**Addresses features:**
- Keyboard input (table stakes for snake control)

**Avoids pitfalls:**
- PITFALL 1: Package format changed (elm.json created)
- PITFALL 2: Keyboard module removed (Browser.Events implemented)
- PITFALL 3: Html.program removed (Browser.element adopted)
- PITFALL 4: Time.every API changed (Float milliseconds)
- PITFALL 5: toString removed (custom function created)
- PITFALL 7: JSON decoder refinements (tested)

**Testing gate:** Elm compiles; app initializes in browser (even without WebSocket); keyboard events logged.

### Phase 4: WebSocket Layer Replacement (Ports)
**Rationale:** Highest-risk component; requires both frontend and backend working; dependencies on Phase 1 (GameChannel) and Phase 3 (Elm 0.19).

**Delivers:**
- Phoenix JavaScript client integrated (assets/js/socket.js)
- Elm Ports module (sendInput, gameStateReceived, etc.)
- Main.elm refactored to use ports instead of elm-phoenix-socket
- Socket initialization in JavaScript (connection lifecycle)
- Channel join/push/on handlers in JavaScript
- Port subscription handlers in Elm
- Connection state management (Connecting/Connected/Disconnected)
- WebSocket URL parameterized via flags (not hard-coded localhost)

**Addresses features:**
- Real-time communication (table stakes for multiplayer)
- Reconnection handling (should-have)

**Avoids pitfalls:**
- PITFALL 6: Native modules forbidden (ports used instead)
- PITFALL 13: elm-phoenix-socket incompatible (replaced with ports)
- PITFALL 14: Socket initialization pattern changed (ports-based)
- PITFALL 15: Channel join timing race (connection state managed)
- PITFALL 26: Hard-coded localhost (flags-based configuration)

**Testing gate:** Browser connects to Phoenix Channel; JavaScript console shows join success; port messages flow bidirectionally.

### Phase 5: State Sync Implementation
**Rationale:** Core bug fix; requires all infrastructure complete (server authoritative, WebSocket working); final integration phase.

**Delivers:**
- GameChannel.join/3 sends full game state to new player
- Board.fromServerState decoder (server snapshot → Elm model)
- Client removes local apple generation (server-driven)
- Client removes local tick-based position updates for remote players
- Server broadcasts full state every 100ms tick
- Client reconciliation logic (optional prediction + server truth)
- Apple spawn/despawn server events
- Player join/leave with full state synchronization

**Addresses features:**
- Full state on join (must-have, fixes core bug)
- Consistent apple spawning (must-have)
- State reconciliation (should-have for latency handling)

**Avoids pitfalls:**
- PITFALL 19: Client tick timing divergence (server tick authoritative)
- PITFALL 20: Apple generation client-side (moved to server)
- PITFALL 21: Player join without full state (full snapshot sent)
- PITFALL 24: Missing error handling (validation added)
- PITFALL 27: No rollback strategy (message versioning considered)

**Testing gate:** Two browser windows show identical snake positions; new player sees existing players correctly; apples consistent across clients; no position drift over time.

### Phase 6: Integration Testing & Polish
**Rationale:** End-to-end validation; edge case handling; production readiness.

**Delivers:**
- Multi-client integration tests (2+ browsers)
- Network latency testing (Chrome DevTools throttling)
- Rapid join/leave scenario testing
- Error handling for malformed messages
- Graceful disconnect/reconnect
- Production deployment configuration
- Performance validation (asset size, load time)

**Avoids pitfalls:**
- PITFALL 23: broadcast! vs broadcast_from! (refactored if needed)
- PITFALL 25: Version lock-step requirement (deployment strategy)
- PITFALL 28: Testing multiplayer in dev (comprehensive multi-client tests)
- PITFALL 29: Mix deps cache (clean build verified)

**Testing gate:** All multiplayer scenarios pass; no regressions; production build succeeds; deployment tested.

### Phase Ordering Rationale

- **Phases 1-2 can partially overlap:** Phoenix backend and asset pipeline are independent; can develop in parallel and integrate.
- **Phase 3 blocks Phase 4:** Must have Elm 0.19 compiling before implementing ports (language syntax changes).
- **Phase 4 blocks Phase 5:** Cannot fix state sync without working WebSocket layer.
- **Sequential critical path:** 1 → 3 → 4 → 5 → 6 (backend, Elm core, WebSocket, state sync, testing).
- **Parallelization opportunity:** Phase 2 can run alongside Phase 1 since asset builds don't affect Phoenix runtime.

This ordering minimizes risk by:
1. Establishing stable backend foundation first (easier to debug)
2. Deferring highest-risk WebSocket rewrite until prerequisites complete
3. Enabling incremental testing at each phase boundary
4. Avoiding big-bang integration (each phase has independent testing gate)

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 4 (WebSocket):** Complex ports patterns; Phoenix JavaScript client API specifics; connection lifecycle edge cases; may need `/gsd:research-phase` for ports architecture patterns.
- **Phase 5 (State Sync):** Prediction/reconciliation algorithms; client-server timing synchronization; latency compensation techniques; Game Networking research may be helpful.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Phoenix):** Well-documented upgrade path; Phoenix 1.3→1.7 changelog comprehensive; GenServer patterns established.
- **Phase 2 (Asset Pipeline):** esbuild configuration straightforward; Elm compilation simple (elm make); community examples abundant.
- **Phase 3 (Elm Core):** Official Elm 0.18→0.19 upgrade guide covers all changes; compiler errors are helpful; migration well-trodden.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | Elm 0.19.1 and Phoenix 1.7 versions confirmed from official sources; specific patch versions (1.7.14, 1.15.7) inferred from ecosystem trends; mise adoption verified from project requirements |
| Features | HIGH | State sync bug root cause clearly identified from codebase analysis; server-authoritative pattern is industry-standard solution; feature requirements derived from existing game behavior |
| Architecture | MEDIUM-HIGH | Server-authoritative pattern well-documented in game networking literature; ports-based WebSocket approach is standard Elm 0.19 practice; build order dependencies validated through breaking change analysis |
| Pitfalls | HIGH | Breaking changes identified from official Elm 0.19 upgrade docs and Phoenix changelog; elm-phoenix-socket incompatibility confirmed; Brunch deprecation verified; pitfall severity ratings based on impact analysis |

**Overall confidence:** MEDIUM-HIGH

The general migration path is well-established (Elm 0.19 upgrades and Phoenix 1.7 upgrades are common in 2025/2026). The specific combination of simultaneous stack upgrade + architecture refactoring + bug fix adds complexity, but each individual component has proven solutions. The main uncertainty is in timing estimation and integration testing effort.

### Gaps to Address

**Stack verification (low priority):**
- Exact Phoenix 1.7.x patch version (1.7.14 assumed, but check hexdocs.pm for latest stable)
- Elixir 1.15.x vs 1.16.x (1.15.7 assumed based on compatibility, but could use newer)
- Erlang OTP 26 vs 27 availability (26.2.1 assumed, but OTP 27 may be current in 2026)
- Node.js LTS version (20.x assumed, but could verify current LTS)

**Resolution:** Run `mise use` with latest stable versions during Phase 1; minor version differences unlikely to cause issues.

**WebSocket library validation (medium priority):**
- Verify `saschatimme/elm-phoenix` package exists and supports Elm 0.19
- Check if it's actively maintained (commit history, issue tracker)
- Compare API surface to `fbonetti/elm-phoenix-socket` to estimate migration effort
- If package is abandoned, ports approach becomes mandatory (not optional)

**Resolution:** Research during Phase 4 planning; ports approach is fallback and is always viable.

**State sync algorithm details (medium priority):**
- Client prediction implementation specifics (store pending inputs, reapply on reconciliation)
- Server tick rate tuning (100ms may be too slow/fast depending on gameplay feel)
- Interpolation vs CSS transitions for smooth movement (affects visual quality)

**Resolution:** Implement simplest version first (no prediction, just render server state); add prediction in Phase 6 if input feels laggy; CSS transitions likely sufficient for snake game's grid-based movement.

**Production deployment (low priority during migration):**
- Asset CDN configuration (if using)
- WebSocket SSL termination (wss:// in production)
- Database persistence for game state (not in current version, defer to v2)
- Horizontal scaling (single GameServer instance sufficient for MVP)

**Resolution:** Address during Phase 6 deployment configuration; not blocking for development.

## Sources

### Primary (HIGH confidence)
- **Elm 0.19 Upgrade Guide** (https://github.com/elm/compiler/blob/master/upgrade-docs/0.19.md) — Breaking changes, migration patterns
- **Phoenix 1.7 CHANGELOG** (https://github.com/phoenixframework/phoenix/blob/v1.7/CHANGELOG.md) — Deprecations, new features
- **Codebase Analysis** (.planning/codebase/ARCHITECTURE.md, .planning/codebase/CONCERNS.md) — Current implementation details, known bugs

### Secondary (MEDIUM confidence)
- **Elm Package Repository** (package.elm-lang.org) — Package compatibility, available alternatives to elm-phoenix-socket
- **Phoenix Guides** (hexdocs.pm/phoenix) — Channel patterns, WebSocket configuration, asset management
- **Game Networking Patterns** (Gaffer on Games, Source Multiplayer Networking) — Client prediction, server reconciliation

### Tertiary (LOW confidence, needs validation)
- **Community forum posts** — elm-phoenix-socket alternatives, migration experiences
- **Stack version inference** — Latest stable versions based on release cadence, needs verification with live docs

---
*Research completed: 2026-01-30*
*Ready for roadmap: yes*
