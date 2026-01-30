# Snaker Elm

## What This Is

A multiplayer snake game built with Elm frontend and Phoenix/Elixir backend. Players connect via WebSocket, each controlling a snake on a shared grid, collecting apples to grow. Currently on legacy versions (Elm 0.18, Phoenix 1.3, Elixir 1.4) with a multiplayer state sync bug.

## Core Value

Players can play snake together in real-time and see each other's snakes in the correct positions.

## Requirements

### Validated

- ✓ Single-page Elm app renders snake game board — existing
- ✓ Player snake moves via arrow keys — existing
- ✓ Snake wraps around board edges — existing
- ✓ Apples spawn randomly and expire after timeout — existing
- ✓ Eating apples grows snake — existing
- ✓ WebSocket connection to Phoenix backend — existing
- ✓ Players can join game and see other players — existing
- ✓ Direction changes broadcast to all players — existing
- ✓ Player leave/disconnect handled — existing

### Active

- [ ] Upgrade Elm from 0.18 to 0.19.1
- [ ] Upgrade Phoenix from 1.3 to latest (1.7.x)
- [ ] Upgrade Elixir from 1.4 to latest
- [ ] Use mise to manage Elixir/Erlang versions
- [ ] Fix multiplayer state sync — players see correct snake positions on join

### Out of Scope

- WebGL/3D rendering — future milestone
- Collision detection between snakes — not in current scope
- Persistent game state/rooms — not requested
- Authentication/user accounts — not requested

## Context

**State sync bug root cause (from architecture analysis):**
The current implementation only broadcasts direction changes and join/leave events. Each client computes snake positions independently based on local tick timing. When a player joins, they don't receive the actual current positions of other snakes — they only know directions, so positions diverge from the start.

**Migration complexity:**
- Elm 0.18 → 0.19 is a major breaking change (different package format, no Native modules, Browser.* API changes)
- elm-phoenix-socket library may not have 0.19 support — will need alternative
- Phoenix 1.3 → 1.7 introduces LiveView, new directory structure, updated channel patterns
- Brunch replaced by esbuild/mix in modern Phoenix

**Existing codebase:**
- Frontend: `assets/elm/` with Main.elm and Data/* modules
- Backend: `lib/snaker_web/` (channels, controllers) and `lib/snaker/` (Worker GenServer)
- Build: Brunch-based asset pipeline

## Constraints

- **Stack**: Must remain Elm + Phoenix (no framework changes)
- **Compatibility**: Game should work in modern browsers
- **Version management**: Use mise for Elixir/Erlang (not asdf or other tools)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Keep event-driven architecture | Proven pattern for real-time games | — Pending |
| Fix sync by sending positions on join | Root cause is missing initial state | — Pending |

---
*Last updated: 2026-01-30 after initialization*
