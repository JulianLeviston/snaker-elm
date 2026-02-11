---
created: 2026-02-11T10:26:38.419Z
title: Enhance ball venom duration and wall bounce randomization
area: engine
files:
  - assets/src/Engine/Projectile.elm:199-289
  - assets/src/Engine/VenomType.elm:51-58
---

## Problem

Ball venom projectiles currently have a 30-tick lifetime (3 seconds at 100ms/tick) which feels too short for their bouncing behavior. They also bounce deterministically on wall hits — once diagonal, they always reflect at the same angle. Adding a random chance to change angle/direction on each wall hit would make ball venom more unpredictable and fun.

## Solution

1. **Increase ball venom lifetime** in `VenomType.maxLifetime`: bump BallVenom from 30 to ~50-60 ticks (5-6 seconds)
2. **Add random direction change on bounce**: In `moveBallOneStep`, after flipping the wall-perpendicular velocity component, add a small chance (e.g., 20-30%) to also randomize the parallel component to ±1. This would cause occasional angle changes on bounces instead of always reflecting predictably.
3. Update existing tests to match new lifetime and verify randomized bounce behavior.
