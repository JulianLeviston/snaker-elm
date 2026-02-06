---
created: 2026-02-05T23:49
title: Add venom spitting mechanic with snake splitting
area: gameplay
files: []
---

## Problem

The game currently lacks offensive combat mechanics. Players can only avoid each other or cause collisions. Adding a ranged attack option would create more strategic gameplay and a new game mode variant.

## Solution

Add a "Venom Spitting" game mode option in game setup:

**Offensive mechanic:**
- Players can shoot venom projectiles
- Hitting another snake splits it into multiple pieces
- Split pieces become separate entities

**Self-split mechanic for leaders:**
- If a player is in the lead (longest snake), they can voluntarily split themselves
- Creates two separate snakes controlled by the same player
- Both snakes respond to the same directional controls
- Each snake dies independently (can lose one but keep playing with the other)

**Game mode toggle:**
- Optional setting during room/game setup
- Off by default to preserve classic gameplay
