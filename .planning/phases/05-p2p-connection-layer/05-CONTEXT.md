# Phase 5: P2P Connection Layer - Context

**Gathered:** 2026-02-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Players can establish peer connections via room codes. Host creates a room and displays a code; client enters the code and connects. Connection status is visible and errors are clearly communicated. This phase is connection infrastructure only — actual gameplay synchronization is Phase 6.

</domain>

<decisions>
## Implementation Decisions

### Room Code Format
- 4 characters, letters only (A-Z)
- Large, centered, prominent display for host
- Copy button with visual "Copied!" feedback

### Connection UI Flow
- Create/Join buttons inline on main game screen
- Join input expands inline (not modal or separate view)
- Cancel option during connection returns to main
- Once connected, Create/Join buttons disappear (show Leave option instead)

### Status & Error Display
- Text status line (e.g., "Connecting...", "Connected to ABCD", "Disconnected")
- Status shown at top of game area
- Errors as toast/notification, auto-dismiss after ~5s
- Clear distinct messages for "Room not found" and "Connection failed"

### Join Experience
- Input auto-uppercases as user types
- Auto-connect after 4 characters entered (no submit button)
- Spinner replaces input while connecting
- On success, client goes directly to gameplay (sees current game state)

### Claude's Discretion
- Exact spinner/loading animation style
- Toast positioning and animation
- Copy button icon choice
- Specific error message wording

</decisions>

<specifics>
## Specific Ideas

No specific references — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-p2p-connection-layer*
*Context gathered: 2026-02-03*
