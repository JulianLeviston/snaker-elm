# Phase 4: Game Engine Port - Context

**Gathered:** 2026-02-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Port the Elixir game engine to pure Elm so the game logic runs entirely in the browser. This phase delivers a single-player snake game with 100ms tick loop, arrow key movement, edge wrapping, apple eating/growth/scoring, and apple expiration — testable without any network code.

</domain>

<decisions>
## Implementation Decisions

### Fidelity to Elixir
- Match the feel of the Elixir engine, but OK to simplify edge cases or improve UX where sensible
- Not a line-by-line port — use Elixir as authoritative reference for game rules
- Snake-to-snake collision: **keep** — snakes die when hitting each other (core multiplayer mechanic needed for later phases)
- Self-collision: **yes** — hitting your own tail causes death (classic snake behavior)
- Spawn position: **random** — snakes spawn at random grid positions (like Elixir)

### Claude's Discretion
- Exact tick implementation approach (Time.every, requestAnimationFrame wrapper, etc.)
- Internal state structure (as long as it supports the game rules)
- How to handle edge cases not explicitly covered in Elixir (simplify where reasonable)
- Apple spawn algorithm details (avoid snake positions)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — the Elixir engine is the reference. Match gameplay feel, not implementation details.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-game-engine-port*
*Context gathered: 2026-02-03*
