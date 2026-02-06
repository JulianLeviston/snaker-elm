---
created: 2026-02-06T11:50
title: Fix apple sync bug and add max apple count
area: gameplay
files:
  - assets/src/Main.elm
  - assets/src/Network/HostGame.elm
---

## Problem

Two related issues observed:

1. **Apple sync issue**: When going away from the browser window and coming back, apples appear to be "all in sync" when they should have spawned randomly over time. This suggests apples may be spawning in batches when the tab is backgrounded, or there's a timing issue.

2. **Too many apples**: The number of apples can grow excessively. There should be a max cap (suggested ~30% of grid coordinates).

## Solution

1. Investigate apple spawning logic when tab is backgrounded (browser throttles `requestAnimationFrame` and timers when tab is inactive)
2. Add a maximum apple count check before spawning new apples
3. Consider clearing excess apples or preventing spawn when at capacity
