# Phase 7: Migration & Polish - Context

**Gathered:** 2026-02-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Robust room sharing and graceful host disconnect handling. This phase delivers: (1) seamless host migration when the current host drops, (2) room sharing via URL links, QR codes, and copy buttons, (3) mode selection between P2P and Phoenix at startup, and (4) reconnection support for disconnected players.

</domain>

<decisions>
## Implementation Decisions

### Host Migration UX
- Seamless takeover — new host takes over silently, game barely hiccups, no notification
- When migration fails completely, show "Connection lost" game over screen with options to create new room or go home
- Subtle host indicator — small crown/star icon by host's snake (informational only)
- No notification when you become the new host — just get the indicator, no interruption

### Room Sharing Interface
- Share buttons appear directly below the room code display
- All three sharing options available: copy code, copy URL link, and QR code
- QR code always visible inline at medium size
- Copy feedback via button text change: button changes from "Copy" to "Copied!" briefly

### Mode Selection Flow
- Mode selection on startup screen — first thing players see
- P2P is the primary/larger option, Phoenix is secondary/smaller
- Remember player's last mode choice — skip selection screen if previously chosen (can change in settings)
- User-friendly naming (e.g., "Direct Connect" vs "Classic Online" — Claude picks clear, approachable names)

### Reconnection Behavior
- Resume snake on reconnect — player gets their original snake back if it's still alive
- Snake preserved until death — no timeout, snake stays until it dies naturally from collision
- Orphaned snake continues straight in last direction until it hits something
- Subtle fade on orphaned snakes — slightly transparent to show player is disconnected

### Claude's Discretion
- Exact host indicator design (crown vs star vs other)
- Specific user-friendly mode names
- QR code sizing and styling
- Settings UI for changing remembered mode preference

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches within the decisions above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-migration-polish*
*Context gathered: 2026-02-03*
