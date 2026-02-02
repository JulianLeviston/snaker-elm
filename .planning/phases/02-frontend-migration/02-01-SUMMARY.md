---
phase: 02-frontend-migration
plan: 01
subsystem: build
tags: [esbuild, typescript, elm, phoenix, asset-pipeline]

# Dependency graph
requires:
  - phase: 01-backend-modernization
    provides: Phoenix 1.7.21 with mise environment
provides:
  - esbuild asset bundler with TypeScript support
  - esbuild-plugin-elm for Elm compilation
  - Phoenix watcher integration for live reload
affects: [02-02, 02-03, frontend-development]

# Tech tracking
tech-stack:
  added: [esbuild@0.20.2, typescript@5.9.3, esbuild-plugin-elm@0.0.12]
  patterns: [esbuild context API with watch mode]

key-files:
  created: [assets/build.js, assets/tsconfig.json, assets/.gitignore]
  modified: [assets/package.json, config/dev.exs]

key-decisions:
  - "Used esbuild context API for watch mode (not deprecated build())"
  - "Strict TypeScript mode enabled per user preference"
  - "esbuild-plugin-elm v0.0.12 (latest available version)"

patterns-established:
  - "Build script: node build.js with --watch flag for development"
  - "Phoenix watcher: node process in assets directory"

# Metrics
duration: 2min
completed: 2026-01-31
---

# Phase 02 Plan 01: esbuild Migration Summary

**Replaced Brunch with esbuild bundler including TypeScript and Elm plugin support, configured Phoenix watcher integration**

## Performance

- **Duration:** 2 min
- **Started:** 2026-01-31T09:31:31Z
- **Completed:** 2026-01-31T09:33:30Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Removed legacy Brunch build system
- Installed esbuild, TypeScript, and esbuild-plugin-elm
- Created build.js with watch mode and production optimizations
- Configured tsconfig.json with strict mode
- Updated Phoenix watcher to use new build system

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove Brunch and install esbuild toolchain** - `d962099` (chore)
2. **Task 2: Create esbuild configuration with Elm plugin** - `e049a33` (feat)
3. **Task 3: Configure Phoenix watcher for esbuild** - `3358513` (feat)

## Files Created/Modified
- `assets/package.json` - Updated dependencies: esbuild, typescript, esbuild-plugin-elm
- `assets/build.js` - esbuild configuration with Elm plugin and watch mode
- `assets/tsconfig.json` - TypeScript strict mode configuration
- `assets/.gitignore` - Ignore node_modules
- `config/dev.exs` - Phoenix watcher pointing to build.js

## Decisions Made
- **esbuild-plugin-elm version:** Used v0.0.12 (plan specified v0.4.0 which doesn't exist)
- **TypeScript strict mode:** Enabled per accumulated project decisions

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed incorrect esbuild-plugin-elm version**
- **Found during:** Task 1 (npm install)
- **Issue:** Plan specified esbuild-plugin-elm@^0.4.0 which does not exist (latest is 0.0.12)
- **Fix:** Changed package.json to use ^0.0.12
- **Files modified:** assets/package.json
- **Verification:** npm install succeeds, npm ls shows 0.0.12
- **Committed in:** d962099 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Version correction required for npm install to succeed. No scope creep.

## Issues Encountered
- **Elm plugin requires elm.json:** When running build.js, the Elm plugin fails because elm.json doesn't exist yet. This is expected - elm.json will be created in Plan 02-02 when upgrading Elm from 0.18 to 0.19.1. The build.js JavaScript syntax itself is valid.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Build toolchain ready for TypeScript and Elm compilation
- Phoenix watcher will auto-rebuild on file changes
- **Blocker for full build:** Need elm.json (created in 02-02) and app.ts entry point (created in 02-02/02-03)
- System Elm is still 0.18.0 - upgrade to 0.19.1 required in 02-02

---
*Phase: 02-frontend-migration*
*Completed: 2026-01-31*
