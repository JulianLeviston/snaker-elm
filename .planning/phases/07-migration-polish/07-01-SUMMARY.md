---
# Frontmatter - machine-readable execution metadata
phase: "07"
plan: "01"
subsystem: ui-routing
tags: [mode-selection, localStorage, flags, routing, settings]

dependency-graph:
  requires: [phase-06]
  provides: [mode-selection-screen, mode-persistence, settings-screen]
  affects: []

tech-stack:
  added: []
  patterns: [Elm-flags-for-localStorage, screen-based-routing]

key-files:
  created:
    - assets/src/View/ModeSelection.elm
  modified:
    - assets/js/app.ts
    - assets/src/Ports.elm
    - assets/src/Main.elm

decisions:
  - "Mode selection screen on first visit with P2P primary"
  - "localStorage key 'snaker-mode' stores 'p2p' or 'phoenix'"
  - "Settings accessible via button in game header"
  - "Screen enum routes view: ModeSelectionScreen, GameScreen, SettingsScreen"

metrics:
  duration: "3 min"
  completed: "2026-02-03"
---

# Phase 7 Plan 1: Mode Selection Summary

**One-liner:** Mode selection screen with localStorage persistence via Elm flags; P2P primary, Phoenix secondary, settings override.

## What Was Built

### Task 1: localStorage Mode Persistence via Elm Flags
- **app.ts** reads `snaker-mode` from localStorage before Elm init
- Passes `savedMode` (string or null) to Elm via flags object
- Subscribes to `saveMode` port to write mode back to localStorage
- **Ports.elm** exports new `saveMode : String -> Cmd msg` port

### Task 2: ModeSelection View Component
- Created `View.ModeSelection` module with:
  - `Mode` type: `P2PMode | PhoenixMode`
  - `modeToString`/`modeFromString` for localStorage conversion
  - `view` function rendering two mode buttons
- P2P button styled as primary (larger), Phoenix as secondary (smaller)
- Each button shows title and description text

### Task 3: Main.elm Wiring
- **Flags type** with `savedMode : Maybe String`
- **Screen type** for routing: `ModeSelectionScreen | GameScreen | SettingsScreen`
- **SelectedMode type**: `P2PSelected | PhoenixSelected`
- **init** function:
  - First visit (no savedMode): shows ModeSelectionScreen
  - Returning P2P visitor: skips to GameScreen with P2P connection UI
  - Returning Phoenix visitor: skips to GameScreen and joins online game
- **SelectMode** message: saves mode via port, transitions to GameScreen
- **Settings screen**: shows current mode, allows changing with immediate effect
- **Game header**: includes Settings button for mode switching

## Files Changed

| File | Changes |
|------|---------|
| `assets/js/app.ts` | Read savedMode, pass in flags, subscribe to saveMode port |
| `assets/src/Ports.elm` | Add saveMode outgoing port |
| `assets/src/View/ModeSelection.elm` | New module with Mode type and view |
| `assets/src/Main.elm` | Flags, Screen, routing, settings, mode messages |

## Verification

- [x] TypeScript compiles: `npm run build` succeeds
- [x] Elm compiles: `npx elm make src/Main.elm` succeeds
- [x] Mode selection screen architecture in place
- [x] localStorage integration via flags and ports
- [x] Settings screen with mode change capability

## Deviations from Plan

None - plan executed exactly as written.

## Technical Notes

**Elm Flags Pattern:**
```elm
type alias Flags = { savedMode : Maybe String }

init : Flags -> ( Model, Cmd Msg )
init flags =
    case flags.savedMode |> Maybe.andThen ModeSelection.modeFromString of
        Just ModeSelection.P2PMode -> initWithMode P2PSelected
        Just ModeSelection.PhoenixMode -> initWithMode PhoenixSelected
        Nothing -> initModeSelection
```

**Screen-based Routing:**
```elm
view model =
    case model.screen of
        ModeSelectionScreen -> viewModeSelectionScreen
        SettingsScreen -> viewSettingsScreen model
        GameScreen -> viewGameScreen model
```

## Next Phase Readiness

Ready for 07-02 (UI styling and visual polish). The mode selection infrastructure is complete:
- First-visit flow shows mode selection
- Mode persists across sessions
- Settings allow mode changes
- P2P and Phoenix modes have distinct initialization paths

CSS styling for mode buttons and settings screen would enhance the visual presentation.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | d39f26b | Add localStorage mode persistence via Elm flags |
| 2 | 2b8ce9a | Create ModeSelection view component |
| 3 | 07be8f2 | Wire mode selection into Main.elm with settings |
