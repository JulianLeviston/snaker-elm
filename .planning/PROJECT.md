# Snaker Elm

## What This Is

A multiplayer snake game built with Elm 0.19.1 frontend and Phoenix 1.7/Elixir 1.15 backend. Players connect via WebSocket, each controlling a snake on a shared grid, collecting apples to grow. Server-authoritative architecture ensures all players see synchronized game state in real-time.

## Core Value

Players can play snake together in real-time and see each other's snakes in the correct positions.

## Requirements

### Validated

- ✓ Single-page Elm app renders snake game board — v1
- ✓ Player snake moves via arrow keys — v1
- ✓ Snake wraps around board edges — v1
- ✓ Apples spawn randomly and expire after timeout — v1
- ✓ Eating apples grows snake — v1
- ✓ WebSocket connection to Phoenix backend — v1
- ✓ Players can join game and see other players — v1
- ✓ Direction changes broadcast to all players — v1
- ✓ Player leave/disconnect handled — v1
- ✓ Elm upgraded from 0.18 to 0.19.1 — v1
- ✓ Phoenix upgraded from 1.3 to 1.7.x — v1
- ✓ Elixir upgraded from 1.4 to 1.15+ — v1
- ✓ mise manages Elixir/Erlang/Node versions — v1
- ✓ Multiplayer state sync fixed — players see correct snake positions on join — v1

### Active

- [ ] WebGL 3D rendering of game board (v2)
- [ ] 3D snake models (v2)

### Out of Scope

- Collision detection between snakes — not in current scope, keep game simple
- Persistent game state/rooms — not requested
- Authentication/user accounts — not requested, anonymous play works
- Mobile/touch controls — web keyboard controls sufficient
- Sound effects — not requested

## Context

**Current State (v1 shipped 2026-02-02):**
- Frontend: Elm 0.19.1 with Browser.element, ports-based WebSocket, SVG rendering
- Backend: Phoenix 1.7.21, Elixir 1.15.8, GameServer GenServer with 100ms tick loop
- Build: esbuild with TypeScript and esbuild-plugin-elm
- Codebase: ~12,000 lines across Elm, Elixir, TypeScript

**Architecture:**
- Server-authoritative: GameServer maintains all game state (snakes, apples, collisions)
- Tick-based updates: 100ms intervals, server broadcasts state to all clients
- Full state on join: New players receive complete game state immediately
- Input buffering: Server rate-limits direction changes to first per tick

**Known technical debt:**
- `use Mix.Config` deprecated (should migrate to `import Config`)
- `Endpoint.init/2` deprecated (should migrate to `config/runtime.exs`)

## Constraints

- **Stack**: Must remain Elm + Phoenix (no framework changes)
- **Compatibility**: Game should work in modern browsers
- **Version management**: Use mise for Elixir/Erlang (not asdf or other tools)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Server-authoritative architecture | Root cause of sync bug was client-side simulation | ✓ Good - sync issue resolved |
| Ports-based WebSocket | elm-phoenix-socket incompatible with Elm 0.19 | ✓ Good - clean integration |
| esbuild over Brunch | Brunch deprecated in Phoenix 1.7 | ✓ Good - fast builds |
| 100ms tick interval | Balance smooth gameplay with server load | ✓ Good - responsive multiplayer |
| Full state on join, delta on tick | Simplify initial sync | ✓ Good - reliable sync |
| CSS for visual effects | GPU compositing, separate concerns | ✓ Good - smooth animations |
| Html.Keyed for snake lists | Optimize frequent list updates | ✓ Good - better performance |

---
*Last updated: 2026-02-02 after v1 milestone*
