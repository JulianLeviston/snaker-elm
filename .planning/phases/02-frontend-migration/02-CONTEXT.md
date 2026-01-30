# Phase 2: Frontend Migration - Context

**Gathered:** 2026-01-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Elm 0.19.1 application communicates with Phoenix 1.7 via ports-based WebSocket. Includes asset pipeline migration (Brunch → esbuild), keyboard/touch input handling, and game rendering. This phase delivers a working frontend that can join channels and send direction changes — full state sync is Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Ports Architecture
- One port per event type (joinGame, sendDirection, receiveGameState, etc.)
- Dedicated socket.js module for WebSocket connection logic
- Dedicated error port for connection errors (separate from game state)
- Typed records through ports — JS transforms server JSON into exact shape Elm expects
- TypeScript with strict mode on the JavaScript side

### Game Rendering — Distributed System
- **Clients are autonomous participants**, not dumb renderers
- Server broadcasts **projected trajectory (5+ ticks ahead)** — "here's where things are going if nothing changes"
- Clients simulate forward using projections, server syncs periodically to correct drift
- **Resilience:** If server is silent for 1-2 ticks, clients continue smoothly from projections
- **Input cutoff at half-tick:** Direction change before 50ms applies this tick; after 50ms applies next tick
- **requestAnimationFrame for 60fps rendering** — interpolate toward next projected state
- **Canvas rendering** with beautiful graphics
- **Theme toggle:** Modern (gradients, shadows, particles) AND retro (pixel art, limited palette)

### Input Handling
- Keyboard input captured in Elm via Browser.Events
- Debounce key repeats (rate-limit direction changes)
- Support both Arrow keys and WASD
- On-screen virtual D-pad for mobile/touch

### Migration Strategy
- **Clean slate** — Fresh Elm 0.19 project, port concepts (not code) from old
- **Feature modules:** Game.elm, Snake.elm, Input.elm, Ports.elm, etc.
- **Start completely fresh** — no preserving old game logic or visuals
- Delete old Elm code after migration (git history preserves it)

### Claude's Discretion
- Exact debounce timing
- Virtual D-pad positioning and styling
- Interpolation easing function
- Particle effect details for modern theme
- Specific color palettes for each theme

</decisions>

<specifics>
## Specific Ideas

- "Distributed system where server is synchronization point, not sole authority"
- "Clients should be smart — they can predict and continue if server is briefly unavailable"
- "Canvas with amazing beautiful graphics"
- "Modern AND retro theme with toggle"
- Input rounded down to nearest half-tick for fairness

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-frontend-migration*
*Context gathered: 2026-01-31*
