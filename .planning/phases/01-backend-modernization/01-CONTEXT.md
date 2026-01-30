# Phase 1: Backend Modernization - Context

**Gathered:** 2026-01-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Upgrade Phoenix to 1.7, establish server-authoritative game state with full game logic (movement, collisions, respawning), and set up modern development environment with mise. This phase delivers the backend infrastructure that Phase 2 (Frontend Migration) will connect to via ports-based WebSocket.

</domain>

<decisions>
## Implementation Decisions

### Game Tick Rate & State Broadcast
- Tick rate: 100ms (10 ticks/second) — classic snake feel
- Broadcast content: Delta only (changes since last tick)
- Initial sync: Full state on player join, then delta updates after
- Input validation: Server validates direction changes (no 180° reversals)
- Rate limiting: Process only first direction change per tick per player

### Collision & Respawn
- Full collision detection: walls, self, and other snakes
- On death: Respawn at safe position (not on other snakes or walls)
- Brief invincibility period after respawn (1-2 seconds)
- Safe spawn: Server finds non-colliding position for respawn

### Development Environment
- Version pinning: Minor version range in .mise.toml (e.g., `elixir = "~1.15"`)
- Testing: Add tests for GameServer authoritative state logic
- CI: No CI this phase — local development only
- Data storage: In-memory only (GenServer process state, no database)

### Error Handling & Resilience
- Player disconnect: Immediate removal from game state
- Process crash: Supervisor restarts GameServer, clients auto-reconnect and rejoin
- Invalid messages: Log warning and drop (helps debugging)

### Logging & Observability
- Default: Quiet output (moderate in dev, errors-only in prod)
- Verbose mode: Available via flag/config — logs every tick, join, disconnect, direction change
- Game events: Logged in verbose mode (apple eaten, collision, respawn)
- Prod vs dev: Dev moderate by default, prod errors only

### Claude's Discretion
- Exact invincibility duration (1-2 seconds range)
- Metrics collection (add if easy, skip if complex)
- Specific logging format and levels
- Delta calculation algorithm details

</decisions>

<specifics>
## Specific Ideas

- Process first direction change per tick (not latest) to give time for data to arrive
- Respawn should find a "non-weird" position — not on top of other snakes or too close to walls

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-backend-modernization*
*Context gathered: 2026-01-31*
