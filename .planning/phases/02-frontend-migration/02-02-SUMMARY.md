---
phase: 02
plan: 02
subsystem: frontend
tags: [elm, browser.element, ports, keyboard, typescript]
dependency-graph:
  requires: [02-01]
  provides: [elm-0.19.1-application, port-definitions, keyboard-input]
  affects: [02-03]
tech-stack:
  added: ["elm@0.19.1-6"]
  patterns: [browser-element, elm-ports, keyboard-subscriptions]
key-files:
  created:
    - assets/elm.json
    - assets/src/Main.elm
    - assets/src/Ports.elm
    - assets/src/Game.elm
    - assets/src/Snake.elm
    - assets/src/Input.elm
    - assets/js/app.ts
  modified:
    - assets/package.json
decisions:
  - id: elm-npm-dependency
    choice: elm@0.19.1-6 npm package
    rationale: System Elm was 0.18.0, npm package ensures consistent version
metrics:
  duration: 2m 35s
  completed: 2026-01-31
---

# Phase 02 Plan 02: Elm 0.19.1 Application Setup Summary

**One-liner:** Fresh Elm 0.19.1 application with Browser.element, port definitions for WebSocket interop, and keyboard input handling using Browser.Events.

## What Was Built

### Elm Project Structure

Created new Elm 0.19.1 project in `assets/` with:

- **elm.json**: Project configuration targeting Elm 0.19.1 with elm/browser, elm/core, elm/html, elm/json, elm/time
- **src/Main.elm**: Browser.element entry point with game state model, keyboard subscriptions, port wiring
- **src/Ports.elm**: Port module defining all WebSocket communication ports (joinGame, leaveGame, sendDirection, receiveGameState, receiveError, playerJoined, playerLeft, receiveTick)
- **src/Game.elm**: Game state types and JSON decoders (GameState, Apple, Player)
- **src/Snake.elm**: Snake types and JSON decoders (Snake, Position, Direction)
- **src/Input.elm**: Keyboard input handling with Arrow keys and WASD support, repeat event filtering

### TypeScript Integration

Created `js/app.ts` with:
- Elm.Main.init() initialization
- Port type definitions for TypeScript
- Debug logging for port activity

## Key Implementation Details

### Port Architecture

```
Outgoing (Elm -> JS):
- joinGame: JE.Value -> Cmd msg
- leaveGame: () -> Cmd msg
- sendDirection: JE.Value -> Cmd msg

Incoming (JS -> Elm):
- receiveGameState: JD.Value -> msg
- receiveError: String -> msg
- playerJoined: JD.Value -> msg
- playerLeft: JD.Value -> msg
- receiveTick: JD.Value -> msg
```

### Keyboard Handling

```elm
keyDecoder : JD.Decoder (Maybe Direction)
-- Filters repeat events
-- Supports: Arrow keys + WASD (case insensitive)
-- Returns Nothing for non-direction keys
```

### JSON Decoders

Types match server message format from Phase 1:
- GameState: snakes, apples, grid_width, grid_height
- Snake: id, body (List Position), direction, color
- Apple: position

## Verification Results

| Check | Status |
|-------|--------|
| `elm make src/Main.elm` | Pass (compiles 5 modules) |
| `node build.js` | Pass (outputs to priv/static/assets/) |
| elm.json version 0.19.1 | Pass |
| Browser.element in Main.elm | Pass |
| Browser.Events.onKeyDown | Pass |
| port module Ports | Pass |
| Elm.Main.init in app.ts | Pass |

## Commits

| Hash | Description | Files |
|------|-------------|-------|
| e1e247d | Initialize Elm 0.19.1 project | elm.json, Main.elm, package.json |
| e869414 | Create port module and game types | Ports.elm, Game.elm, Snake.elm |
| 6ac64aa | Add keyboard input handling and wire to Main | Input.elm, Main.elm, app.ts |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] System Elm version incompatible**
- **Found during:** Task 1
- **Issue:** System Elm was 0.18.0, not 0.19.1
- **Fix:** Installed elm@0.19.1-6 as npm dev dependency
- **Files modified:** package.json
- **Commit:** e1e247d

## Next Phase Readiness

**Ready for 02-03:** Port-based WebSocket integration

Dependencies provided:
- Elm application with Browser.element entry point
- All ports defined for WebSocket communication
- Keyboard input handling ready to send direction changes
- JSON decoders matching server message format

Next plan will:
1. Wire Phoenix WebSocket to Elm ports
2. Implement channel join/leave
3. Connect direction changes to server
4. Receive and display game state updates
