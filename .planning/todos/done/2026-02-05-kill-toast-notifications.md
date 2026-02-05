---
created: 2026-02-05T19:00
title: Add colorful kill toast notifications
area: ui
files:
  - assets/src/Main.elm
  - assets/src/Network/HostGame.elm
---

## Problem

When a player kills another player, there's no dramatic announcement. Missed opportunity for fun multiplayer moments.

## Solution

Show a small toast notification when someone kills another player, using colorfully dramatic language (not rude). Examples:

- "Fuzzy Banana **obliterated** Electric Penguin!"
- "Cosmic Noodle **dominated** Sneaky Pickle!"
- "Bouncy Waffle **destroyed** Mighty Taco!"
- "Sparkly Muffin **annihilated** Dizzy Wizard!"
- "Zippy Narwhal **eliminated** Wobbly Hamster!"
- "Cheeky Llama **crushed** Sassy Badger!"

Randomly pick from a list of dramatic verbs to keep it fresh and entertaining.
