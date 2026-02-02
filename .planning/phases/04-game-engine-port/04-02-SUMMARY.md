---
phase: 04
plan: 02
subsystem: game-engine
tags: [elm, apple, scoring, random, expiration]
dependency-graph:
  requires: [04-01]
  provides: [apple-system, score-tracking, growth-mechanics]
  affects: [05-01, 05-02]
tech-stack:
  added: []
  patterns: [TickResult-pattern, pendingSpawns-tracking]
key-files:
  created:
    - assets/src/Engine/Apple.elm
  modified:
    - assets/src/LocalGame.elm
    - assets/src/Main.elm
decisions:
  - key: apple-expiry-ticks
    choice: 100 ticks (10 seconds)
    reason: Reasonable timeout for gameplay without being too aggressive
  - key: pending-spawn-tracking
    choice: Track in-flight Random.generate calls
    reason: Prevents race conditions when multiple spawns requested rapidly
metrics:
  duration: 2m 31s
  completed: 2026-02-02
---

# Phase 4 Plan 2: Apple System Summary

**Apple spawning, eating, growth (3 segments), score tracking, and 10-second expiration - fully playable single-player snake**

## Accomplishments

- Created Engine/Apple.elm module with pure apple logic (no side effects)
- Implemented apple eating detection via position matching
- Snake grows by 3 segments when eating apple (pendingGrowth pattern)
- Score increments by 1 on each apple eaten
- Minimum 3 apples always maintained on board
- Apple expiration after 100 ticks (10 seconds) triggers respawn
- Race condition prevention via pendingAppleSpawns counter

## Task Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create Engine/Apple module | 1e10b9d | Engine/Apple.elm |
| 2 | Wire apple system into LocalGame and Main | fbc4abb | LocalGame.elm, Main.elm |

## Files Created/Modified

**Created:**
- `assets/src/Engine/Apple.elm` - Apple type, checkEaten, tickExpiredApples, spawnIfNeeded, randomSafePosition

**Modified:**
- `assets/src/LocalGame.elm` - Changed tick to return TickResult, added checkAppleEating, addApple, getOccupiedPositions
- `assets/src/Main.elm` - Added pendingAppleSpawns, NewApplePosition msg, apple spawn commands, score display

## Patterns Established

### TickResult Pattern
LocalGame.tick now returns a record with:
- `state`: Updated LocalGameState
- `needsAppleSpawn`: Number of apples needed
- `expiredApples`: List of expired apples for respawn

This allows Main.elm to handle random generation while keeping LocalGame pure.

### Pending Spawn Tracking
Model tracks `pendingAppleSpawns` count to prevent over-spawning when multiple Random.generate commands are in flight. Each NewApplePosition decrements the counter.

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Apple expiry time | 100 ticks (10s) | Balance: long enough to reach, short enough to keep gameplay dynamic |
| Pending spawn tracking | Counter in Model | Prevents race condition where tick requests spawns while previous spawn commands in flight |
| Safe position retry | 100 attempts max | Prevents infinite loop on full board while ensuring high success rate |

## Deviations from Plan

None - plan executed exactly as written.

## Requirements Satisfied

- [x] ENG-03: Snake grows when eating apple (3 segments via pendingGrowth)
- [x] ENG-04: Apple spawns at random position when eaten
- [x] ENG-05: Apple expires after timeout (10s) and respawns
- [x] ENG-06: Score increments when apple eaten
- [x] Minimum 3 apples always on board
- [x] No race conditions in apple spawning
- [x] Score displayed in UI
- [x] All Elm files compile without errors

## Test Coverage

Manual verification:
- App compiles and runs
- 3 apples visible at game start
- Snake grows when eating apple
- Score increments on eat
- Apple respawns at new position when eaten
- Apple expiration triggers respawn after 10 seconds

## Next Phase Readiness

Phase 4 (Game Engine Port) is now complete:
- Plan 01: Core engine (movement, collision, respawn)
- Plan 02: Apple system (eating, growth, score, expiration)

Ready to proceed to Phase 5 (P2P Connection Layer):
- Game engine runs entirely in Elm
- All game logic is pure and deterministic
- State can be serialized for network transmission
