# Codebase Concerns

**Analysis Date:** 2026-01-30

## Tech Debt

**Board State Synchronization (Critical):**
- Issue: Multiple clients experience out-of-sync board state when new players join. The README explicitly states "Currently WIP because while multiplayer is working, it does't sync state properly."
- Files: `lib/snaker_web/channels/game_channel.ex` (line 14-18 contains TODO), `assets/elm/Main.elm`
- Impact: Multiplayer game is unplayable - players see different board states, apples appear/disappear inconsistently, snakes may collide incorrectly depending on which client's view is being used
- Fix approach: Implement board sync client pattern:
  - Designate first joining player as "board sync client"
  - Server maintains canonical board state and clock
  - Move apple generation responsibility to server instead of client-side random generation
  - New clients request full board state (snakes, apples, server time) on join
  - Broadcast apple spawn/despawn messages from server to all clients
  - Use server-sent time to keep clients synchronized

**Client-Side Apple Generation:**
- Issue: Apples are generated randomly on each client independently using `Random.generate AddApple` in `assets/elm/Data/Board.elm` (line 163)
- Files: `assets/elm/Data/Board.elm`, `assets/elm/Data/Apple.elm`
- Impact: Each client spawns different apples at different times. New clients don't know about existing apples. Apples expire independently per client.
- Fix approach: Remove client-side apple generation. Server should generate and broadcast apple events to all clients with synchronized timing.

**Client-Side Time Management:**
- Issue: Each Elm client maintains its own time via `Time.every` subscription and generates its own game ticks independently
- Files: `assets/elm/Main.elm` (lines 261-263), `assets/elm/Data/Board.elm` (line 76-78 tickDuration)
- Impact: Game loop timing drifts between clients. Server has no notion of game time, making coordination impossible
- Fix approach: Server should send a clock signal. Clients should tick based on server time with local interpolation for smooth rendering.

**Hard-Coded WebSocket URL:**
- Issue: WebSocket URL is hard-coded to `ws://localhost:4000/socket/websocket`
- Files: `assets/elm/Main.elm` (line 41)
- Impact: Application cannot be deployed to production without code change. No environment-based configuration.
- Fix approach: Pass socket URL through HTML template or environment variable during build.

## Known Bugs

**Direction Conversion Case Sensitivity:**
- Symptoms: Direction strings must be exact case match ("north", "North", "NORTH") but server may send different cases
- Files: `assets/elm/Data/Direction.elm` (lines 18-58)
- Trigger: If server sends direction in different case than what's expected
- Workaround: Ensure server always sends specific case, but code is fragile

**Player Dictionary Decode Fallback:**
- Symptoms: If a player ID in JSON cannot be converted to Int, it silently defaults to 0
- Files: `assets/elm/Data/Player.elm` (line 86): `Result.withDefault 0 (String.toInt k)`
- Trigger: Malformed player ID in JSON from server
- Workaround: None - silently creates wrong player ID instead of failing explicitly

## Security Considerations

**No Input Validation:**
- Risk: Direction changes, player IDs, and other values from server are decoded but not validated
- Files: `assets/elm/Main.elm` (decoder functions), `lib/snaker_web/channels/game_channel.ex`
- Current mitigation: Elm's type system prevents some errors, but server-side validation is minimal
- Recommendations:
  - Add validation in decoders to reject impossible values
  - Validate player IDs exist before broadcasting direction changes
  - Validate direction values are known enum values

**No Authentication/Authorization:**
- Risk: Anyone can connect to the WebSocket and pretend to be any player
- Files: `lib/snaker_web/channels/user_socket.ex`
- Current mitigation: None detected
- Recommendations: Add player authentication on socket connection, validate that clients can only control their own snake

**Console Debug Logging:**
- Risk: Socket communication is logged with `Socket.withDebug` in production
- Files: `assets/elm/Main.elm` (line 42)
- Current mitigation: None
- Recommendations: Remove or make conditional on dev environment

## Performance Bottlenecks

**HTML Rendering Grid:**
- Problem: Entire game board is re-rendered as HTML divs every tick. With 40x30 grid = 1200 DOM nodes.
- Files: `assets/elm/Board/Html.elm` (lines 67-118)
- Cause: Using `Html` library for game rendering instead of Canvas/WebGL. No virtual DOM optimization.
- Improvement path:
  - Switch to Canvas for rendering (mentioned in README as "Future")
  - Or use SVG with proper diffing
  - Or investigate Lazy rendering for static tiles

**Inefficient List Operations:**
- Problem: `List.take (List.length body - 1) body` on every snake move
- Files: `assets/elm/Data/Snake.elm` (line 112)
- Cause: Unnecessarily calculating list length
- Improvement path: Use a Deque or change snake body representation to List with last element separate

**Dictionary Lookups in Render Loop:**
- Problem: Multiple Dict.get calls per tile during every render tick
- Files: `assets/elm/Board/Html.elm` (lines 90, 93)
- Cause: Building intermediate dictionaries on every frame
- Improvement path: Pre-compute render dictionary once per board state change

## Fragile Areas

**Direction Change Logic:**
- Files: `assets/elm/Data/Snake.elm` (lines 140-160), `assets/elm/Data/Board.elm` (line 172)
- Why fragile: Complex pattern matching for preventing 180-degree turns. Easy to miss direction pairs or introduce bugs when adding new directions.
- Safe modification: Write comprehensive tests for all direction pair combinations before modifying
- Test coverage: No tests for direction logic detected

**Player Dictionary Key Conversion:**
- Files: `assets/elm/Data/Player.elm` (lines 81-89)
- Why fragile: Assumes JSON keys are stringified integers that can be parsed back. Silent fallback to 0 on failure.
- Safe modification: Add explicit error handling instead of Result.withDefault. Add validation tests.
- Test coverage: Minimal testing detected

**State Synchronization Between Processes:**
- Files: `assets/elm/Data/Board.elm`, `assets/elm/Main.elm` (messages and updates)
- Why fragile: Multiple independent update functions (Board.update, updateFromServer, updateToServer) with overlapping state concerns. Easy to miss updating one when adding new features.
- Safe modification: Consolidate state management pattern, add integration tests for message flows
- Test coverage: No integration tests detected

## Scaling Limits

**Game Tick Rate:**
- Current capacity: 100ms ticks (10 Hz) per player - manageable with ~10 players
- Limit: Broadcasting to 100+ players would cause network saturation and latency spikes
- Scaling path: Implement spatial partitioning - only broadcast state for nearby players in a large world scenario

**WebSocket Connections:**
- Current capacity: Single Phoenix channel broadcast to all players
- Limit: Hard to scale beyond 100-200 concurrent players on single server without clustering
- Scaling path: Implement game room sharding, load balance connections across multiple servers

## Dependencies at Risk

**Outdated Elm Packages:**
- Risk: elm-phoenix-socket 2.2.0 (from 2014-2015 era), elm-lang packages (core 5.1.1, html 2.0.0, keyboard 1.0.1 from pre-2016)
- Impact: No newer features, security updates, or community support. Language evolution has moved on (Elm 0.19 changed module structure).
- Migration plan:
  - Update to latest Elm (currently 0.19+)
  - Use elm-community packages where available
  - May need to rewrite socket layer with newer pattern

**Phoenix and Elixir Versions:**
- Risk: Phoenix 1.3.0 (from 2017), Elixir ~> 1.4 (from 2017), Cowboy 1.0
- Impact: Missing security patches, new features, bug fixes. Development tools have evolved.
- Migration plan:
  - Update to Phoenix 1.7+
  - Update Elixir to 1.14+
  - Review deprecations and breaking changes

## Missing Critical Features

**Collision Detection:**
- Problem: No detection when snakes collide with each other or themselves
- Blocks: Cannot implement game ending conditions or scoring penalties
- Related files: `assets/elm/Data/Board.elm`, `assets/elm/Data/Snake.elm`

**Game Over/Win Conditions:**
- Problem: Game has no end state - snakes just keep moving indefinitely
- Blocks: No complete game loop, no restart mechanism
- Related files: `assets/elm/Data/Board.elm` type doesn't have GameState field

**Player Identification:**
- Problem: Player ID assignment is simplistic (incremental integer from server). No persistency across reconnections.
- Blocks: Cannot implement player ranking, match history, or reconnection recovery
- Related files: `lib/snaker_web/channels/user_socket.ex`

## Test Coverage Gaps

**Elm Unit Tests:**
- What's not tested: All game logic in `assets/elm/Data/` modules (Board, Snake, Player, Direction, Position, Apple)
- Files: No .elm test files found
- Risk: Direction change logic, position wrapping, apple expiration, board state updates
- Priority: High - core game logic is untested

**Phoenix Channel Tests:**
- What's not tested: GameChannel message handling, player join/leave, message broadcasting
- Files: No tests in `lib/snaker_web/channels/` directory
- Risk: Server-side state management, message ordering, player connection edge cases
- Priority: High - multiplayer coordination depends on correct server behavior

**Integration Tests:**
- What's not tested: Full client-server message flows (join, move, collision detection if it existed)
- Files: No integration tests detected
- Risk: Synchronization issues discovered late in manual testing
- Priority: Critical - this is where board sync issues would be caught

**Regression Tests:**
- What's not tested: Previous multiplayer bugs (board state sync) - no automated checks prevent re-introduction
- Files: None
- Risk: Known issues reappear during refactoring
- Priority: Medium - test the specific board sync fix once implemented

---

*Concerns audit: 2026-01-30*
