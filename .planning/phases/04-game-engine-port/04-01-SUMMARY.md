---
phase: 04-game-engine-port
plan: 01
subsystem: game-engine
tags: [elm, game-loop, tick, collision, grid-wrap, random]

# Dependency graph
requires:
  - phase: none (first game engine plan)
    provides: none
provides:
  - Engine/Grid.elm with wrapPosition and nextPosition
  - Engine/Collision.elm with collidesWithSelf and collidesWithOther
  - LocalGame.elm with tick loop, movement, collision detection
  - Time.every 100ms tick subscription in Main.elm
  - LocalMode/OnlineMode game mode switching
affects: [04-02 (apple spawning), 05 (P2P layer), 06 (host/client integration)]

# Tech tracking
tech-stack:
  added: [elm/random]
  patterns: [Elm game loop via Time.every, input buffering for rate limiting, invincibility ticks]

key-files:
  created:
    - assets/src/Engine/Grid.elm
    - assets/src/Engine/Collision.elm
    - assets/src/LocalGame.elm
  modified:
    - assets/src/Main.elm
    - assets/src/Snake.elm
    - assets/elm.json

key-decisions:
  - "LocalMode runs entirely in Elm without server; OnlineMode preserved for future"
  - "Tick order matches Elixir: applyInput -> move -> collisions"
  - "Input buffer rate-limits to one direction change per tick"
  - "Invincibility tracked as tick count rather than time-based"

patterns-established:
  - "Engine/ directory for pure game logic modules"
  - "LocalGameState separate from GameState for local vs online"
  - "toGameState converter for rendering local state with existing Board.view"

# Metrics
duration: 3min
completed: 2026-02-02
---

# Phase 4 Plan 1: Core Engine Summary

**Elm game loop with 100ms tick, edge wrapping via modBy, self-collision respawn with 15-tick invincibility**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-02T15:18:32Z
- **Completed:** 2026-02-02T15:21:53Z
- **Tasks:** 2/2
- **Files modified:** 5 (+ 1 elm.json)

## Accomplishments

- Created Engine/Grid.elm and Engine/Collision.elm modules mirroring Elixir game logic
- Implemented LocalGame.elm with full tick cycle: input -> move -> collision detection
- Wired 100ms Time.every tick subscription in Main.elm
- Snake moves continuously, wraps at edges, respawns on self-collision

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Engine modules (Grid, Collision)** - `1753619` (feat)
2. **Task 2: Implement LocalGame module and wire tick loop** - `fde38d3` (feat)

## Files Created/Modified

- `assets/src/Engine/Grid.elm` - wrapPosition (modBy for negative handling), nextPosition, defaultDimensions
- `assets/src/Engine/Collision.elm` - collidesWithSelf (head in tail), collidesWithOther (for future multi-snake)
- `assets/src/LocalGame.elm` - LocalGameState, init (Random.Generator), tick, changeDirection, toGameState
- `assets/src/Main.elm` - Added LocalMode/OnlineMode, Tick msg, Time.every 100 subscription
- `assets/src/Snake.elm` - Added pendingGrowth field, isOppositeDirection, validDirectionChange, defaultSnake
- `assets/elm.json` - Added elm/random dependency

## Decisions Made

- **LocalMode default:** App starts in LocalMode by default (OnlineMode preserved for phase 7 migration)
- **Tick order:** Follows Elixir GameServer exactly: applyInput -> move -> collisions
- **Invincibility as tick count:** Used `invincibleUntilTick` instead of time-based, simpler and deterministic
- **needsRespawn flag:** Collision sets flag, Main.elm generates random position, avoids Random in pure function

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- **Elm record update syntax:** `{ state.snake | field = value }` invalid - needed intermediate `let snake = state.snake`
- **elm/random not installed:** Added via `elm install elm/random`

Both were straightforward fixes discovered during compilation.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Core engine ready for apple spawning (Plan 04-02)
- LocalGame.toGameState converter enables Board.view reuse
- Snake.pendingGrowth ready for apple eating to increment

---
*Phase: 04-game-engine-port*
*Completed: 2026-02-02*
