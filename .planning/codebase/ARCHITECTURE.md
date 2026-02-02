# Architecture

**Analysis Date:** 2026-01-30

## Pattern Overview

**Overall:** Client-server multiplayer game with event-driven WebSocket communication

**Key Characteristics:**
- Elm frontend handles client-side game state, UI rendering, and keyboard input
- Phoenix Channels backend manages player state and coordinates multiplayer events
- Real-time bidirectional communication via WebSocket for low-latency synchronization
- Separation of concerns: frontend manages local board/snake logic, backend coordinates players

## Layers

**Frontend (Elm 0.18):**
- Purpose: Render game UI, handle user input, manage client-side game state
- Location: `assets/elm/`
- Contains: Main module, data models, view components, Phoenix Socket integration
- Depends on: Phoenix Socket library for WebSocket communication
- Used by: Browser, communicates with backend via WebSocket

**Backend (Phoenix/Elixir):**
- Purpose: Manage player sessions, broadcast game events, coordinate multiplayer state
- Location: `lib/snaker_web/` (web layer) and `lib/snaker/` (core logic)
- Contains: Channels (GameChannel), sockets, controllers, views
- Depends on: Elixir runtime, Phoenix framework, OTP supervision
- Used by: Elm frontend via WebSocket, serves initial HTML page

**Runtime Infrastructure:**
- Purpose: Supervision tree, stateful player management
- Location: `lib/snaker/application.ex`, `lib/snaker/worker.ex`
- Contains: Application supervisor, GenServer for player state
- Depends on: Elixir OTP
- Used by: Phoenix channels for player coordination

## Data Flow

**Game Initialization:**

1. Browser loads HTML from `GET /` route
2. Phoenix renders layout template (`app.html.eex`) with Elm mount point (`elm_target` div)
3. JavaScript entry point (`assets/js/app.js`) initializes Elm app at DOM element
4. Elm main program starts: `Html.program` with `init`, `view`, `update`, `subscriptions`
5. Elm `init` creates WebSocket connection to `ws://localhost:4000/socket/websocket`
6. Elm joins `game:snake` channel
7. Backend `UserSocket.connect/2` creates new player via `Worker.new_player()`
8. Backend `GameChannel.join/3` broadcasts `"join"` event with current players
9. Elm receives `JoinGame` message, decodes player data, sets up snake

**Player Direction Change (Client→Server):**

1. User presses arrow key (38, 37, 39, 40)
2. Keyboard subscription (`keyboardBoardControlSubscription`) triggers
3. `keyCodeToChangeDirectionMsg` converts keycode to Direction
4. Elm generates `BoardMsg (ChangeDirection direction)`
5. `Board.update` processes `ChangeDirection`, updates local snake direction
6. Main update checks for direction change, calls `updateToServer SendChangeDirection`
7. Elm encodes current player ID and direction to JSON
8. Creates Phoenix Push: `Push.init "player:change_direction" "game:snake"`
9. Elm sends via `Socket.push` to backend
10. Backend `GameChannel.handle_in/3` receives direction change
11. Backend broadcasts `"player:change_direction"` to all players on channel
12. All connected Elm clients receive broadcast via `"player:change_direction"` handler
13. Each client's `updateFromServer PlayerChangedDirection` processes update
14. Updates remote player's snake direction via `Board.toChangePlayerDirectionMsg`

**Game Tick (Local):**

1. `Time.every Board.tickDuration` subscription fires every 100ms
2. Generates `BoardMsg (Board.tickBoardMsg currentTime)`
3. `Board.update` processes `Tick newTime`
4. For each player's snake:
   - Snake moves via `moveSnake` (advances body positions)
   - Apple growth checked via `growSnake` (length increases if apple eaten)
   - Apple expiration via `expireApples` (removes expired apples)
5. If no apples remain, generates new apple via `Random.generate AddApple`
6. Board renders updated snake positions and apples

**State Management:**

- **Frontend state:** `Board` record contains all game state (snakes dict, apples, current player ID)
- **Backend state:** `Snaker.Worker` GenServer maintains global player registry
- **Synchronization:** Backend broadcasts discrete events (join, direction change, leave); clients apply changes locally
- **Conflict handling:** Direction changes prevent 180-degree reversals via `changeSnakeDirection` logic

## Key Abstractions

**Board (Data.Board):**
- Purpose: Encapsulates game state for single client's view
- Examples: `assets/elm/Data/Board.elm`
- Pattern: Record-based state with pure update function
- Contains: current player ID, time, snake dict (by player ID), apple list
- Responsibility: Game logic orchestration (snake movement, apple handling, player management)

**Snake (Data.Snake):**
- Purpose: Single snake entity with position and direction
- Examples: `assets/elm/Data/Snake.elm`
- Pattern: Pure functions transform snake state
- Contains: player (owner), direction, body (list of positions)
- Operations: move, grow, change direction, validate moves

**Player (Data.Player):**
- Purpose: Player identity and visual representation
- Examples: `assets/elm/Data/Player.elm`
- Pattern: Simple data record with ID, name, color
- Shared: Serialized by backend, decoded by frontend via JSON

**Position (Data.Position):**
- Purpose: Board coordinates with wrapping at edges
- Examples: `assets/elm/Data/Position.elm`
- Pattern: 2D coordinate with dimension constants
- Grid size: 40x30 (x, y), wraps when movement exceeds bounds

**Apple (Data.Apple):**
- Purpose: Collectible item with expiration
- Examples: `assets/elm/Data/Apple.elm`
- Pattern: Immutable with expiration timestamp
- Lifecycle: Spawned randomly, expires after 3-8 seconds, removed when eaten

**Direction (Data.Direction):**
- Purpose: Movement direction with conversion utilities
- Examples: `assets/elm/Data/Direction.elm`
- Pattern: Union type (North, South, East, West) with converters
- Conversions: keyboard keycode → Direction, string → Direction (from server)

**Phoenix Socket Integration (fbonetti/elm-phoenix-socket):**
- Purpose: WebSocket connection management and message routing
- Pattern: Elm port abstraction over Phoenix client library
- Channels: Declarative event subscriptions via `Socket.on`
- Model: `Socket Msg` held in main Model, updated via `PhoenixMsg`

**GameChannel (Backend):**
- Purpose: Coordinates multiplayer game state on server
- Examples: `lib/snaker_web/channels/game_channel.ex`
- Pattern: Phoenix Channel with push/broadcast coordination
- Handlers: `join/3`, `handle_in/3`, `handle_out/3`, `terminate/3`
- Filtering: `handle_out/3` prevents echoing to sender

**Worker GenServer (Backend):**
- Purpose: Stateful global player registry
- Examples: `lib/snaker/worker.ex`
- Pattern: Named GenServer with player state in map
- Operations: create player (random name/color), delete player, list all players

## Entry Points

**Frontend:**
- Location: `assets/elm/Main.elm` module
- Triggers: Browser loads page, DOM ready, Elm runtime initializes
- Responsibilities: Initialize WebSocket, set up subscriptions, coordinate all game logic updates

**Backend HTTP:**
- Location: `lib/snaker_web/router.ex` (route) → `lib/snaker_web/controllers/page_controller.ex`
- Triggers: `GET /` HTTP request
- Responsibilities: Render HTML layout with Elm mount point

**Backend WebSocket:**
- Location: `lib/snaker_web/channels/user_socket.ex` (connect) → `lib/snaker_web/channels/game_channel.ex` (join)
- Triggers: Elm connects to WebSocket endpoint, joins channel
- Responsibilities: Authenticate connection, create player, broadcast to all channel subscribers

## Error Handling

**Strategy:** Silent failures with graceful degradation

**Patterns:**
- JSON decode failures in `updateFromServer` use `case` with `Err _` branch that returns unchanged model
- No error events broadcast from server (no explicit error handling contract)
- Invalid direction strings handled via `Direction.fromString` returning `Maybe Direction`
- Server doesn't validate snake collision or board bounds (client-side only)

## Cross-Cutting Concerns

**Logging:**
- Frontend: None (no logging library)
- Backend: `require Logger` in GameChannel, debug logs for disconnects

**Validation:**
- Direction changes: Frontend validates via pattern matching (prevents 180-degree reversals)
- Position wrapping: `wrapPosition` handles edge-of-board wraparound
- No server-side collision detection (MVE scope)

**Authentication:**
- None: Socket connection auto-creates anonymous player via Worker
- Each client gets random name and color, identified by auto-incrementing ID

**State Synchronization:**
- Event-driven: Only direction changes and player joins/leaves broadcasted
- Board state (apples, snake positions) computed independently by each client
- Grid dimensions hardcoded (40x30 in Position module, matching server expectations)

---

*Architecture analysis: 2026-01-30*
