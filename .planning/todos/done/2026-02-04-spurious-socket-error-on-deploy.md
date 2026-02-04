---
created: 2026-02-04T$(date "+%H:%M")
title: Fix spurious socket connection error on deployed P2P
area: ui
files: []
---

## Problem

When deploying the static P2P build and connecting, a socket connection error appears on screen even though the connection actually succeeded. This is confusing UX - the error message shouldn't show if the connection worked.

Likely causes to investigate:
- Phoenix socket code attempting to connect when in P2P-only mode
- Error message not being cleared after successful P2P connection
- Race condition between P2P connect and error display

## Solution

TBD - Needs investigation:
- Check if Phoenix socket code runs in static build
- Verify error state management in Elm
- May need to suppress Phoenix socket in P2P-only mode
