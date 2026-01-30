# Requirements: Snaker Elm Upgrade

**Defined:** 2026-01-30
**Core Value:** Players can play snake together in real-time and see each other's snakes in the correct positions

## v1 Requirements

Requirements for this milestone. Each maps to roadmap phases.

### Environment Setup

- [ ] **ENV-01**: mise manages Elixir, Erlang, and Node versions
- [ ] **ENV-02**: `.mise.toml` committed with version pins

### Phoenix Upgrade

- [ ] **PHX-01**: Phoenix upgraded to 1.7.x
- [ ] **PHX-02**: Elixir upgraded to 1.15+
- [ ] **PHX-03**: WebSocket transport configured for Phoenix 1.7
- [ ] **PHX-04**: JSON encoding uses Jason (replaces Poison)

### Asset Pipeline

- [ ] **AST-01**: Brunch removed, esbuild configured
- [ ] **AST-02**: Elm compilation integrated with asset pipeline
- [ ] **AST-03**: Development watchers work (auto-rebuild on change)

### Elm Upgrade

- [ ] **ELM-01**: Elm upgraded to 0.19.1
- [ ] **ELM-02**: elm.json replaces elm-package.json
- [ ] **ELM-03**: Html.program migrated to Browser.element
- [ ] **ELM-04**: Keyboard input uses Browser.Events (not removed Keyboard module)
- [ ] **ELM-05**: All Elm code compiles without errors

### WebSocket/Channels

- [ ] **WS-01**: Phoenix Channels communication via ports (replaces elm-phoenix-socket)
- [ ] **WS-02**: Player can join game channel
- [ ] **WS-03**: Direction changes sent to server and broadcast to other players

### State Sync Fix

- [ ] **SYNC-01**: Server maintains authoritative game state (snakes, apples)
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
| ENV-01 | TBD | Pending |
| ENV-02 | TBD | Pending |
| PHX-01 | TBD | Pending |
| PHX-02 | TBD | Pending |
| PHX-03 | TBD | Pending |
| PHX-04 | TBD | Pending |
| AST-01 | TBD | Pending |
| AST-02 | TBD | Pending |
| AST-03 | TBD | Pending |
| ELM-01 | TBD | Pending |
| ELM-02 | TBD | Pending |
| ELM-03 | TBD | Pending |
| ELM-04 | TBD | Pending |
| ELM-05 | TBD | Pending |
| WS-01 | TBD | Pending |
| WS-02 | TBD | Pending |
| WS-03 | TBD | Pending |
| SYNC-01 | TBD | Pending |
| SYNC-02 | TBD | Pending |
| SYNC-03 | TBD | Pending |

**Coverage:**
- v1 requirements: 20 total
- Mapped to phases: 0
- Unmapped: 20 (pending roadmap creation)

---
*Requirements defined: 2026-01-30*
*Last updated: 2026-01-30 after initial definition*
