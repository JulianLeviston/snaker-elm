# Roadmap: Snaker Elm Upgrade

**Project:** Snaker-Elm Multiplayer Game Upgrade
**Core Value:** Players can play snake together in real-time and see each other's snakes in the correct positions
**Depth:** Quick (3 phases)
**Created:** 2026-01-30

## Overview

Upgrade from legacy stack (Elm 0.18 + Phoenix 1.3) to modern stack (Elm 0.19.1 + Phoenix 1.7) while fixing the multiplayer state synchronization bug. The migration follows a strict dependency chain: backend modernization enables server-authoritative game state, frontend migration enables ports-based WebSocket communication, and full integration delivers the sync fix.

## Phases

### Phase 1: Backend Modernization

**Goal:** Server maintains authoritative game state and provides modern Phoenix 1.7 infrastructure

**Dependencies:** None (foundation phase)

**Plans:** 3 plans

Plans:
- [x] 01-01-PLAN.md — Environment setup with mise version pins
- [x] 01-02-PLAN.md — Phoenix 1.3 to 1.7 upgrade with Jason/PubSub
- [x] 01-03-PLAN.md — GameServer with authoritative state and tick loop

**Requirements:**
- ENV-01: mise manages Elixir, Erlang, and Node versions
- ENV-02: `.mise.toml` committed with version pins
- PHX-01: Phoenix upgraded to 1.7.x
- PHX-02: Elixir upgraded to 1.15+
- PHX-03: WebSocket transport configured for Phoenix 1.7
- PHX-04: JSON encoding uses Jason (replaces Poison)
- SYNC-01: Server maintains authoritative game state (snakes, apples)

**Success Criteria:**
1. Developer can activate mise environment with single command and all versions match pins
2. Phoenix server runs on 1.7.x with WebSocket transport accepting connections
3. Server maintains game state and broadcasts tick events to console every 100ms
4. All mix dependencies resolve and compile without errors

---

### Phase 2: Frontend Migration

**Goal:** Elm 0.19.1 application communicates with Phoenix 1.7 via ports-based WebSocket

**Dependencies:** Phase 1 (requires Phoenix 1.7 WebSocket transport)

**Plans:** 3 plans

Plans:
- [x] 02-01-PLAN.md — Replace Brunch with esbuild asset pipeline
- [x] 02-02-PLAN.md — Fresh Elm 0.19.1 project with ports and keyboard input
- [x] 02-03-PLAN.md — WebSocket integration with Phoenix Channels

**Requirements:**
- AST-01: Brunch removed, esbuild configured
- AST-02: Elm compilation integrated with asset pipeline
- AST-03: Development watchers work (auto-rebuild on change)
- ELM-01: Elm upgraded to 0.19.1
- ELM-02: elm.json replaces elm-package.json
- ELM-03: Html.program migrated to Browser.element
- ELM-04: Keyboard input uses Browser.Events (not removed Keyboard module)
- ELM-05: All Elm code compiles without errors
- WS-01: Phoenix Channels communication via ports (replaces elm-phoenix-socket)
- WS-02: Player can join game channel
- WS-03: Direction changes sent to server and broadcast to other players

**Success Criteria:**
1. Assets compile in development and production mode with auto-rebuild on file changes
2. Elm application initializes in browser with 0.19.1 and renders game board
3. Player can use arrow keys to change snake direction (keyboard input works)
4. Browser console shows successful WebSocket connection and channel join
5. Direction changes flow bidirectionally through ports (JavaScript logs show messages)

---

### Phase 3: Integration & Sync

**Goal:** All players see identical, synchronized game state in real-time

**Dependencies:** Phase 2 (requires working WebSocket communication)

**Plans:** 3 plans

Plans:
- [ ] 03-01-PLAN.md — Backend serialization and CSS animations
- [ ] 03-02-PLAN.md — SVG game board rendering
- [ ] 03-03-PLAN.md — UI components and multiplayer sync verification

**Requirements:**
- SYNC-02: Server broadcasts full state on player join
- SYNC-03: When any player joins, all connected players (n > 1) see each other's snakes in correct positions immediately

**Success Criteria:**
1. New player joining sees all existing players' snakes at their current positions within one tick
2. Two browser windows show identical snake positions with no drift over 60 seconds of gameplay
3. Apples appear at identical positions and times across all connected clients
4. Player disconnect removes their snake from all other clients' views immediately

---

## Progress

| Phase | Status | Requirements | Completion |
|-------|--------|--------------|------------|
| 1 - Backend Modernization | Complete | 7/7 | 100% |
| 2 - Frontend Migration | Complete | 11/11 | 100% |
| 3 - Integration & Sync | In Progress | 0/2 | 0% |

**Overall:** 18/20 requirements complete (90%)

---

## Phase Sequencing

**Critical path:** 1 -> 2 -> 3 (strictly sequential)

**Rationale:**
- Phase 1 establishes server-authoritative architecture foundation (GameServer, authoritative state)
- Phase 2 requires Phoenix 1.7 WebSocket transport (from Phase 1) to test ports integration
- Phase 3 requires working WebSocket communication (from Phase 2) to implement state sync

**No parallelization:** Phases are tightly coupled through breaking changes in WebSocket protocol and architectural shift from client-driven to server-authoritative game state.

---

## Key Decisions

| Decision | Phase | Rationale |
|----------|-------|-----------|
| Server-authoritative architecture | 1 | Root cause of sync bug is client-side simulation; server must be source of truth |
| Ports-based WebSocket | 2 | elm-phoenix-socket incompatible with Elm 0.19 (Native modules removed) |
| esbuild over Brunch | 2 | Brunch deprecated in Phoenix 1.7, esbuild is official replacement |
| Quick depth (3 phases) | All | Compress related work for faster delivery; minimal viable phase boundaries |

---

*Last updated: 2026-02-01*
