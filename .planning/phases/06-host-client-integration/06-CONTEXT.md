# Phase 6: Host/Client Integration - Context

**Gathered:** 2026-02-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable full P2P multiplayer gameplay over WebRTC connections. Host runs the authoritative game loop, broadcasts state to clients, and processes their inputs. Clients render the shared game state and send direction inputs. Players can join mid-game and leave gracefully. Host migration is out of scope (Phase 7).

</domain>

<decisions>
## Implementation Decisions

### Message Protocol
- Delta-based state sync: send snake positions + apple state each tick
- Full state sync every 5 seconds (50 ticks) for correction
- Host broadcasts scores explicitly (clients don't derive from events)

### Input Handling
- Optimistic local response: client snake turns immediately
- Smooth interpolation toward host state when correction needed
- Last input wins: only most recent direction sent per tick
- On network hiccup: snake continues in last direction, no retry

### Player Join/Leave
- New players spawn at random safe position (not on snakes/apples)
- Spawn protection: 1500ms invincibility (matches respawn behavior)
- Disconnect grace period: 3 seconds before removal
- Within grace period: player can rejoin and keep snake/score
- Disconnected player's snake shows ghosted/faded
- No player limit per room
- Brief "Player joined" / "Player left" notifications

### Visual Feedback
- Your snake has glow/outline effect for self-identification
- Each player gets random unique color
- Scoreboard shows top 3 players only
- Collision effect: shake/bump + snake segments scatter like falling teeth

### Claude's Discretion
- Exact interpolation algorithm for corrections
- Color palette for random snake colors (just ensure distinctness)
- Notification styling and duration
- Teeth-scatter animation specifics

</decisions>

<specifics>
## Specific Ideas

- Collision animation: "shake/bump effect and the snake pieces fall out like teeth"
- Ghosted/faded treatment for disconnected players (not frozen in place)
- Top 3 scoreboard, not full ranked list

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-host-client-integration*
*Context gathered: 2026-02-03*
