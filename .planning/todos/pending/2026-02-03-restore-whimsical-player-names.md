---
created: 2026-02-03T17:45
title: Restore whimsical player names
area: ui
files:
  - assets/src/Main.elm
  - lib/snaker_web/channels/game_channel.ex
---

## Problem

The original game had whimsical randomly-generated player names (like "Fuzzy Banana" or "Electric Penguin") that added personality to the multiplayer experience. During the v2 P2P migration, this feature was either lost or not ported.

New players joining a game currently get generic identifiers instead of fun, memorable names. This affects both P2P mode (where names should be generated client-side) and Phoenix mode (where names may have been server-generated).

## Solution

TBD - Need to investigate:
1. Where were names generated in the original codebase?
2. For P2P mode: Generate names client-side in Elm
3. For Phoenix mode: Restore server-side generation or use same client-side approach
4. Consider a word list approach (adjective + noun) for easy generation
