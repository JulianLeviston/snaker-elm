---
created: 2026-02-05T10:15
title: Move npm commands to top level directory
area: tooling
files:
  - assets/package.json
  - README.md
---

## Problem

Currently npm commands must be run from the `assets/` directory (e.g., `cd assets && npm run build:static`). This is inconvenient - users expect to run commands from the project root.

The project structure has:
- `assets/package.json` - npm scripts for building
- `assets/build.js`, `assets/build-static.js` - build scripts
- Root level has no package.json

## Solution

TBD - Options to consider:
1. Move package.json to root, update build script paths
2. Create root package.json that delegates to assets/
3. Add npm scripts at root that cd into assets

Also need to update:
- README.md usage instructions
- Any other docs referencing build commands
