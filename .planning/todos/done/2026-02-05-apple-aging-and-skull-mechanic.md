---
created: 2026-02-05T10:35
title: Add apple aging lifecycle with skull penalty
area: general
files: []
---

## Problem

Apples currently have no lifecycle - they just sit there. Need a more dynamic food system with risk/reward mechanics.

## Solution

Implement apple aging lifecycle:

**Visual progression:**
1. **Green** (fresh) - +1 value, +1 snake length
2. **Yellow** (aging) - +2 value, +2 snake length  
3. **Red** (old) - +3 value, +3 snake length
4. **Flashing/pulsing** (expiring) - pulse 3 times slowly as warning
5. **White skull** (expired) - PENALTY: halves snake size AND score

**Skull penalty effects:**
- Flash the portion of snake that will be removed 3 times
- Make snake jitter/shake during the effect
- Then remove the back half of the snake

**Timing:**
- Each color stage lasts some duration (TBD)
- Flashing happens at the end of red stage before skull
- Creates tension: grab it early for less points, or wait and risk skull?
