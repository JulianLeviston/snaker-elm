---
created: 2026-02-05T23:34
title: QR code should auto-join room
area: ui
files:
  - assets/js/app.js
  - assets/src/Main.elm
---

## Problem

When scanning the QR code or following the room URL with `?room=XXXX` parameter, users currently land on the connection UI but don't automatically join the room. They have to manually enter the code or click join.

The expected UX is: scan QR → immediately join the game as a client.

## Solution

- Detect `?room=XXXX` parameter on page load in JavaScript
- Auto-trigger room join flow if parameter is present
- Pass the room code through Elm flags or trigger port message on init
