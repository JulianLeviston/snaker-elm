# Summary: 02-03 WebSocket Integration

**Plan:** 02-03-PLAN.md
**Status:** Complete
**Duration:** ~15 min (including debugging)

## What Was Built

Phoenix Channels integration with Elm ports for real-time game communication:

1. **socket.ts** — Phoenix socket connection with Elm port wiring
   - Connects to /socket endpoint
   - Joins game:snake channel on Elm request
   - Wires channel events (tick, player:join, player:leave) to Elm ports
   - Sends direction changes from Elm to server

2. **app.ts** — Updated Elm initialization with socket integration
   - DOMContentLoaded wrapper for reliable init
   - Connects socket after Elm init
   - Auto-joins game via Elm init command

3. **Main.elm** — Auto-join on init
   - Sends joinGame command immediately on init
   - Sets connection status to Connecting

4. **HTML template** — Elm mount point
   - Added #elm-app div for Elm to mount into
   - Script tag for app.js

## Commits

| Hash | Type | Description |
|------|------|-------------|
| fba256d | feat | Create Phoenix socket module with port wiring |
| 15336ba | feat | Update app.ts and HTML template |
| cbff879 | fix | Phoenix 1.7 layout @inner_content |
| 3e8667f | fix | JSON serialization for WebSocket messages |

## Deviations

1. **JSON serialization** — Elixir tuples ({x, y}) don't serialize to JSON. Fixed GameServer to convert tuples to maps (%{x: x, y: y}) and serialize snake.id as string, direction as atom string.

2. **Apple decoder** — Elm decoder expected nested `position` field but server sends flat {x, y}. Fixed Elm to decode position directly.

3. **PubSub broadcast handling** — Channel received PubSub broadcasts and tried to call undefined handle_out/3. Added catch-all handler to ignore broadcast structs.

4. **Phoenix 1.7 layout** — Template used `@inner` but Phoenix 1.7 uses `@inner_content`. Fixed layout template.

## Verification

Human-verified in browser:
- ✓ WebSocket connects to Phoenix server
- ✓ Player successfully joins game:snake channel
- ✓ Direction changes sent via port reach the server
- ✓ Server tick events received by Elm app (console logs)

## Files Modified

| File | Change |
|------|--------|
| assets/js/socket.ts | New — Phoenix socket with Elm port wiring |
| assets/js/app.ts | Updated — Socket integration, DOMContentLoaded |
| assets/src/Main.elm | Updated — Auto-join on init |
| assets/src/Game.elm | Updated — Apple decoder fix |
| lib/snaker/game_server.ex | Updated — JSON serialization |
| lib/snaker_web/channels/game_channel.ex | Updated — PubSub handling |
| lib/snaker_web/templates/layout/app.html.eex | Updated — @inner_content |
| lib/snaker_web/templates/page/index.html.eex | Updated — #elm-app mount |
| lib/snaker_web/endpoint.ex | Updated — Static path config |

## Next Steps

Phase 2 complete. Ready for Phase 3: Integration & Sync.
