---
created: 2026-02-05T18:31
title: Host leave causes room to show UUID
area: p2p
files:
  - src/P2P.elm
  - src/Main.elm
---

## Problem

When player 1 creates a room, player 2 joins, and then player 1 (the host) leaves, player 2 ends up with a room number displaying as some UUID instead of the original room code.

This appears to be a host migration issue where the room identifier is being replaced with a peer ID or internal identifier during the handoff process.

## Solution

TBD - Need to investigate:
- How room codes are stored vs peer IDs
- What happens during host election when original host leaves
- Whether room code should persist through host migration
