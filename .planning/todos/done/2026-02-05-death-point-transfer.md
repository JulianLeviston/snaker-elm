---
created: 2026-02-05T18:55
title: Add death point transfer to killer
area: gameplay
files:
  - assets/src/Network/HostGame.elm
  - assets/src/Engine/Collision.elm
---

## Problem

Currently when a player dies, there's no consequence beyond respawning. The player who killed them (by causing collision) doesn't gain anything. This reduces the competitive/strategic element of the game.

## Solution

When a player dies from collision with another snake:
1. Reduce the dying player's score (by some amount - TBD: could be percentage, fixed amount, or all points)
2. Transfer those points to the killer (the snake that was collided into)

Need to track who caused the death during collision detection, then apply point transfer in the death handling logic.
