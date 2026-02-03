# Snaker Elm

## What This Is

A multiplayer snake game built with Elm 0.19.1 supporting two play modes: server-authoritative Phoenix mode via WebSocket, and serverless P2P mode via WebRTC. Players control snakes on a shared grid, collecting apples to grow. Both modes ensure synchronized game state in real-time.

## Core Value

Players can play snake together in real-time without requiring a backend server.

## Current State (v2 shipped 2026-02-03)

**Dual-mode multiplayer:**
- **P2P mode**: Serverless WebRTC via PeerJS, host-authoritative with automatic migration
- **Phoenix mode**: Server-authoritative via WebSocket (preserved from v1)

**Tech stack:**
- Frontend: Elm 0.19.1 with Browser.element, ports-based communication, SVG rendering
- Backend: Phoenix 1.7.21, Elixir 1.15.8 (optional for P2P mode)
- Build: esbuild with TypeScript and esbuild-plugin-elm
- Codebase: ~22,000 lines Elm + ~700 lines TypeScript

**P2P features:**
- 4-letter room codes, QR code sharing, URL links
- Deterministic host election (lowest peer ID)
- Automatic host migration on disconnect
- 30-tick grace period for reconnection

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
- ✓ Multiplayer state sync fixed — v1
- ✓ P2P WebRTC multiplayer mode — v2
- ✓ Game engine ported from Elixir to Elm — v2
- ✓ PeerJS signaling integration — v2
- ✓ Room joining via codes, links, and QR — v2
- ✓ Deterministic host election with migration — v2
- ✓ Mode selection (P2P/Phoenix) with persistence — v2

### Active

(None — ready for v3 planning)

### Deferred

- [ ] WebGL 3D rendering of game board (v3+)
- [ ] 3D snake models (v3+)

### Out of Scope

- Collision detection between snakes — keep game simple
- Persistent game state/rooms — not requested
- Authentication/user accounts — anonymous play works
- Mobile/touch controls — web keyboard controls sufficient
- Sound effects — not requested
- TURN server self-hosting — PeerJS defaults work

## Constraints

- **Stack**: Must remain Elm + Phoenix (no framework changes)
- **Compatibility**: Game should work in modern browsers
- **Version management**: Use mise for Elixir/Erlang (not asdf or other tools)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Server-authoritative (v1) | Root cause of sync bug was client-side simulation | ✓ Good - sync issue resolved |
| Ports-based WebSocket | elm-phoenix-socket incompatible with Elm 0.19 | ✓ Good - clean integration |
| esbuild over Brunch | Brunch deprecated in Phoenix 1.7 | ✓ Good - fast builds |
| 100ms tick interval | Balance smooth gameplay with server load | ✓ Good - responsive multiplayer |
| Full state on join, delta on tick | Simplify initial sync | ✓ Good - reliable sync |
| CSS for visual effects | GPU compositing, separate concerns | ✓ Good - smooth animations |
| Html.Keyed for snake lists | Optimize frequent list updates | ✓ Good - better performance |
| Host-authoritative P2P (v2) | Mirrors Phoenix architecture, simpler than mesh | ✓ Good - consistent model |
| PeerJS for signaling (v2) | Free cloud service, defer self-hosting | ✓ Good - zero infra cost |
| 4-letter room codes (v2) | Human-friendly, sufficient entropy | ✓ Good - easy sharing |
| Deterministic host election (v2) | Lowest peer ID wins, reproducible | ✓ Good - seamless migration |
| localStorage mode persistence (v2) | Remember user preference | ✓ Good - better UX |

## Context

**Known technical debt:**
- `use Mix.Config` deprecated (should migrate to `import Config`)
- `Endpoint.init/2` deprecated (should migrate to `config/runtime.exs`)
- Minor UI polish noted (functional but could be improved)
- Hardcoded 30x40 grid dimensions

---
*Last updated: 2026-02-03 after v2 milestone shipped*
