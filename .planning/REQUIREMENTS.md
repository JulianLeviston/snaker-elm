# Requirements: Snaker Elm Upgrade

**Defined:** 2026-01-30
**Core Value:** Players can play snake together in real-time and see each other's snakes in the correct positions

## v1 Requirements

Requirements for this milestone. Each maps to roadmap phases.

### Environment Setup

- [x] **ENV-01**: mise manages Elixir, Erlang, and Node versions
- [x] **ENV-02**: `.mise.toml` committed with version pins

### Phoenix Upgrade

- [x] **PHX-01**: Phoenix upgraded to 1.7.x
- [x] **PHX-02**: Elixir upgraded to 1.15+
- [x] **PHX-03**: WebSocket transport configured for Phoenix 1.7
- [x] **PHX-04**: JSON encoding uses Jason (replaces Poison)

### Asset Pipeline

- [x] **AST-01**: Brunch removed, esbuild configured
- [x] **AST-02**: Elm compilation integrated with asset pipeline
- [x] **AST-03**: Development watchers work (auto-rebuild on change)

### Elm Upgrade

- [x] **ELM-01**: Elm upgraded to 0.19.1
- [x] **ELM-02**: elm.json replaces elm-package.json
- [x] **ELM-03**: Html.program migrated to Browser.element
- [x] **ELM-04**: Keyboard input uses Browser.Events (not removed Keyboard module)
- [x] **ELM-05**: All Elm code compiles without errors

### WebSocket/Channels

- [x] **WS-01**: Phoenix Channels communication via ports (replaces elm-phoenix-socket)
- [x] **WS-02**: Player can join game channel
- [x] **WS-03**: Direction changes sent to server and broadcast to other players

### State Sync Fix

- [x] **SYNC-01**: Server maintains authoritative game state (snakes, apples)
- [ ] **SYNC-02**: Server broadcasts full state on player join
- [ ] **SYNC-03**: When any player joins, all connected players (n > 1) see each other's snakes in correct positions immediately

## v2 Requirements

Deferred to future milestone. Tracked but not in current roadmap.

### Visual Enhancements

- **VIS-01**: WebGL 3D rendering of game board
- **VIS-02**: 3D snake models

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Collision detection between snakes | Not requested, keep game simple for now |
| Persistent game state/rooms | Not requested |
| Authentication/user accounts | Not requested, anonymous play works |
| Mobile/touch controls | Web keyboard controls sufficient |
| Sound effects | Not requested |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ENV-01 | Phase 1 | Complete |
| ENV-02 | Phase 1 | Complete |
| PHX-01 | Phase 1 | Complete |
| PHX-02 | Phase 1 | Complete |
| PHX-03 | Phase 1 | Complete |
| PHX-04 | Phase 1 | Complete |
| SYNC-01 | Phase 1 | Complete |
| AST-01 | Phase 2 | Complete |
| AST-02 | Phase 2 | Complete |
| AST-03 | Phase 2 | Complete |
| ELM-01 | Phase 2 | Complete |
| ELM-02 | Phase 2 | Complete |
| ELM-03 | Phase 2 | Complete |
| ELM-04 | Phase 2 | Complete |
| ELM-05 | Phase 2 | Complete |
| WS-01 | Phase 2 | Complete |
| WS-02 | Phase 2 | Complete |
| WS-03 | Phase 2 | Complete |
| SYNC-02 | Phase 3 | Pending |
| SYNC-03 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 20 total
- Mapped to phases: 20
- Unmapped: 0

**Phase Distribution:**
- Phase 1 (Backend Modernization): 7 requirements
- Phase 2 (Frontend Migration): 11 requirements
- Phase 3 (Integration & Sync): 2 requirements

---
*Requirements defined: 2026-01-30*
*Last updated: 2026-01-31 after Phase 2 completion*
