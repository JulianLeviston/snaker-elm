---
created: 2026-02-05T19:09
title: Fix app title and add version number
area: ui
files:
  - assets/src/Main.elm:1332
---

## Problem

The app title currently says "Snaker - Elm 0.19.1" which shows the Elm language version rather than the app version. This is odd for users who don't care about the tech stack.

## Solution

- Change title to "Snaker v1.2" (or similar)
- Start tracking our own version numbers
- Consider storing version in a constant that can be updated
