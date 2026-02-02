# Phase 3: Integration & Sync - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

All players see identical, synchronized game state in real-time. Server broadcasts full state on player join; all connected players see each other's snakes in correct positions immediately. Rendering, player identity, join/leave feedback, and collision handling are in scope. New gameplay features (power-ups, game modes, chat) are not.

</domain>

<decisions>
## Implementation Decisions

### Visual rendering
- Rounded segments for snake body (softer look with circles for each segment)
- Distinct head with eyes or different shape/brighter color
- Death effect: fade out over ~0.5 seconds
- Apples rendered as emoji/icon (e.g., apple emoji)

### Player identity
- Random colors assigned to each player on join
- Auto-generated names (like original implementation)
- Names displayed both above snake head AND in scoreboard
- Scoreboard shows all players with name + length, sorted by score (highest first)
- "You" indicator: subtle glow around your snake segments

### Join/leave behavior
- Toast notification when player joins ("Blue Snake joined")
- Fade out + message when player disconnects ("Blue Snake left")
- Spawn invincibility (1.5s) shown with flashing/blinking snake
- Auto-respawn after 2-3 second delay (no manual respawn)

### Edge cases
- Head-on collision: longer snake wins, shorter dies
- Equal length head-on: both snakes die (mutual destruction)
- Spawn position: random safe spot away from other snakes
- Apple spawn: rate-based (new apple every X ticks, not fixed count)

### Claude's Discretion
- Exact glow effect implementation
- Toast notification styling and duration
- Respawn delay duration (within 2-3 second range)
- Apple spawn rate tuning
- Exact color palette for random player colors

</decisions>

<specifics>
## Specific Ideas

- Auto-generated names should match the original implementation style
- Scoreboard leaderboard-style with longest snakes at top
- Invincibility flashing should be noticeable but not distracting

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-integration-sync*
*Context gathered: 2026-02-01*
