# Phoenix Channels + Elm Architecture for Real-Time Multiplayer

**Research Date:** 2026-01-30
**Context:** Fixing multiplayer state sync bug in Elm/Phoenix snake game upgrade (0.18→0.19, Phoenix 1.3→1.7)

## Executive Summary

The current multiplayer bug stems from an **event-only synchronization pattern** where clients independently compute game state based on local timing. The fix requires adopting an **authoritative server pattern** where the server maintains canonical game state and broadcasts full state updates. This research defines the architecture, component boundaries, data flow, and build order for implementing proper real-time state synchronization.

## Problem Analysis

### Current Architecture (Broken)

**Pattern:** Event-driven synchronization with client-side simulation

```
┌─────────────────────────────────────────────────────────────┐
│ CLIENT A                      CLIENT B                       │
├───────────────────────────────┼─────────────────────────────┤
│ Local tick: 100ms             │ Local tick: 100ms            │
│ Snake positions: computed     │ Snake positions: computed    │
│ Apple spawn: random           │ Apple spawn: random          │
│                               │                              │
│ Sends: direction changes only │ Sends: direction changes only│
│ Receives: direction changes   │ Receives: direction changes  │
└───────────────┬───────────────┴────────────────┬─────────────┘
                │                                │
                └────────────┐   ┐───────────────┘
                             │   │
                     ┌───────▼───▼────────┐
                     │ PHOENIX CHANNEL     │
                     │ (No game state)     │
                     │                     │
                     │ - Broadcasts events │
                     │ - Manages players   │
                     └─────────────────────┘
```

**Why this fails:**
1. **Timing drift**: Each client ticks independently (100ms intervals never align)
2. **Position divergence**: Snakes move based on local time, not synchronized time
3. **No initial state**: New players only receive directions, not positions
4. **Apple inconsistency**: Each client spawns different apples at different times

### Required Architecture (Authoritative Server)

**Pattern:** Server-authoritative with client prediction and reconciliation

```
┌─────────────────────────────────────────────────────────────┐
│ CLIENT A                      CLIENT B                       │
├───────────────────────────────┼─────────────────────────────┤
│ Predicted state (smooth)      │ Predicted state (smooth)     │
│ Local tick: 100ms             │ Local tick: 100ms            │
│                               │                              │
│ Sends: input (direction)      │ Sends: input (direction)     │
│ Receives: state snapshots     │ Receives: state snapshots    │
│ Reconciles: server truth      │ Reconciles: server truth     │
└───────────────┬───────────────┴────────────────┬─────────────┘
                │                                │
                │    State updates (broadcast)   │
                │  ◄─────────────────────────────┤
                │                                │
                └────────────┐   ┐───────────────┘
                             │   │
                     ┌───────▼───▼────────┐
                     │ SERVER (GenServer)  │
                     │ Authoritative state │
                     │                     │
                     │ - Tick: 100ms       │
                     │ - Snakes: positions │
                     │ - Apples: spawning  │
                     │ - Collision: detect │
                     │ - Broadcast: state  │
                     └─────────────────────┘
```

## Component Boundaries

### 1. Server Components (Phoenix/Elixir)

#### GameServer (GenServer) - NEW
**Responsibility:** Authoritative game loop and state

**Location:** `lib/snaker/game_server.ex`

**State:**
```elixir
%{
  game_id: String.t(),
  tick_count: non_neg_integer(),
  last_tick: DateTime.t(),
  snakes: %{player_id => Snake.t()},
  apples: [Apple.t()],
  grid_dimensions: %{x: integer(), y: integer()}
}
```

**Operations:**
- `start_link(game_id)` - Start game loop
- `handle_info(:tick)` - Execute game tick (100ms interval)
- `handle_call(:get_state)` - Return full game state
- `handle_cast({:player_input, player_id, direction})` - Process input
- `handle_cast({:add_player, player_id, player_data})` - Add snake
- `handle_cast({:remove_player, player_id})` - Remove snake

**Tick Logic:**
1. Process queued inputs (direction changes)
2. Move all snakes one step
3. Check apple collisions → grow snakes
4. Spawn new apples if needed
5. Expire old apples
6. Broadcast state snapshot via PubSub

#### GameChannel (Phoenix.Channel) - MODIFIED
**Responsibility:** WebSocket communication and player connection lifecycle

**Location:** `lib/snaker_web/channels/game_channel.ex`

**Changes from current:**
- `join/3`: Request full game state from GameServer, send to joining client
- `handle_in("player:input")`: Forward input to GameServer, do NOT broadcast
- `handle_info({:game_tick, state})`: Receive from PubSub, broadcast to all clients
- Remove `handle_out` filtering (server is authoritative, no echo prevention needed)

**Events:**
- Incoming: `"player:input"` (direction changes)
- Outgoing: `"game:state"` (full state snapshot), `"player:joined"`, `"player:left"`

#### Worker (GenServer) - UNCHANGED
**Responsibility:** Player registry (name, color generation)

**Location:** `lib/snaker/worker.ex`

**No changes required** - continues to generate player metadata

#### GameSupervisor (Supervisor) - NEW
**Responsibility:** Supervise GameServer instances (one per game room)

**Location:** `lib/snaker/game_supervisor.ex`

**Pattern:** DynamicSupervisor for multiple game rooms (future-proofing)

### 2. Client Components (Elm 0.19)

#### Main Module - MODIFIED
**Responsibility:** WebSocket integration and message routing

**Location:** `assets/elm/src/Main.elm`

**Changes:**
- Upgrade to `Browser.element` (Elm 0.19 API)
- Use ports for WebSocket (elm-phoenix-socket not compatible with 0.19)
- Handle `"game:state"` messages → full board reconciliation
- Send `"player:input"` instead of `"player:change_direction"`
- Remove local tick-based position updates for remote players

**Subscriptions:**
- `gameStateReceived` port (from JavaScript)
- `Time.every 100` (for smooth client-side prediction)
- `Browser.Events.onKeyDown` (keyboard input)

#### Board Module - MODIFIED
**Responsibility:** Game state and rendering logic

**Location:** `assets/elm/src/Data/Board.elm`

**Changes:**
- Add `serverTick` field to track server's tick count
- `reconcileState : ServerState -> Board -> Board` function
- Remove apple generation logic (server handles this)
- Keep local tick for smooth interpolation between server updates
- Add prediction logic: apply local input immediately, wait for server confirmation

**State:**
```elm
type alias Board =
    { currentPlayerId : PlayerId
    , serverTick : Int  -- NEW: server's tick count
    , localTick : Int   -- NEW: client's interpolation tick
    , snakes : Dict PlayerId Snake
    , apples : List Apple
    , pendingInputs : List (Int, Direction)  -- NEW: for reconciliation
    }
```

#### WebSocket Integration (Ports) - NEW
**Responsibility:** Phoenix Channels connection via JavaScript

**Location:**
- `assets/elm/src/Ports.elm` (Elm side)
- `assets/js/socket.js` (JavaScript side)

**Elm Ports:**
```elm
port sendInput : InputMsg -> Cmd msg
port gameStateReceived : (ServerState -> msg) -> Sub msg
```

**JavaScript:**
- Use official Phoenix JavaScript client
- Handle channel join, leave, message sending
- Decode JSON to Elm-compatible format
- Send to Elm via port subscriptions

### 3. Data Models (Shared Understanding)

#### Snake Position State
**Server format (JSON):**
```json
{
  "player_id": 1,
  "direction": "North",
  "body": [
    {"x": 15, "y": 20},
    {"x": 15, "y": 21},
    {"x": 15, "y": 22}
  ],
  "colour": "67a387"
}
```

**Elm type:**
```elm
type alias Snake =
    { playerId : PlayerId
    , direction : Direction
    , body : List Position
    , colour : String
    }
```

#### Game State Snapshot
**Server broadcasts every tick (100ms):**
```json
{
  "tick": 1234,
  "snakes": { "1": {...}, "2": {...} },
  "apples": [
    {"position": {"x": 10, "y": 10}, "spawn_time": 1234, "expire_time": 1264}
  ]
}
```

## Data Flow Diagrams

### Player Join Flow

```
┌──────────┐                  ┌─────────────┐                ┌────────────┐
│ Client   │                  │ GameChannel │                │ GameServer │
└────┬─────┘                  └──────┬──────┘                └─────┬──────┘
     │                               │                              │
     │ WebSocket connect             │                              │
     ├──────────────────────────────►│                              │
     │                               │                              │
     │                               │ create player (Worker)       │
     │                               ├──────────────────────┐       │
     │                               │                      │       │
     │                               │◄─────────────────────┘       │
     │                               │                              │
     │ join "game:snake"             │                              │
     ├──────────────────────────────►│                              │
     │                               │                              │
     │                               │ add_player(id, data)         │
     │                               ├─────────────────────────────►│
     │                               │                              │
     │                               │                              │◄─┐ Add snake
     │                               │                              │  │ at random pos
     │                               │                              ├──┘
     │                               │                              │
     │                               │ :ok, game_state              │
     │                               │◄─────────────────────────────┤
     │                               │                              │
     │ "player:joined" (to others)   │                              │
     │◄──────────────────────────────┤                              │
     │                               │                              │
     │ "game:state" (full state)     │                              │
     │◄──────────────────────────────┤                              │
     │                               │                              │
     │◄─┐ Render all snakes          │                              │
     │  │ with correct positions     │                              │
     ├──┘                            │                              │
     │                               │                              │
```

### Input → State Update Flow

```
┌──────────┐                  ┌─────────────┐                ┌────────────┐
│ Client   │                  │ GameChannel │                │ GameServer │
└────┬─────┘                  └──────┬──────┘                └─────┬──────┘
     │                               │                              │
     │◄─┐ User presses ↑             │                              │
     │  │ (arrow key)                │                              │
     ├──┘                            │                              │
     │                               │                              │
     │◄─┐ Apply locally              │                              │
     │  │ (prediction)               │                              │
     │  │ Store pending input        │                              │
     ├──┘                            │                              │
     │                               │                              │
     │ "player:input" {dir: "North"} │                              │
     ├──────────────────────────────►│                              │
     │                               │                              │
     │                               │ player_input(id, North)      │
     │                               ├─────────────────────────────►│
     │                               │                              │
     │                               │                              │◄─┐ Queue input
     │                               │                              │  │ for next tick
     │                               │                              ├──┘
     │                               │                              │
     │                      ... 100ms tick interval ...             │
     │                               │                              │
     │                               │                              │◄─┐ Process tick:
     │                               │                              │  │ - Apply inputs
     │                               │                              │  │ - Move snakes
     │                               │                              │  │ - Check apples
     │                               │                              ├──┘
     │                               │                              │
     │                               │ broadcast via PubSub         │
     │                               │ :game_tick, state            │
     │                               │◄─────────────────────────────┤
     │                               │                              │
     │ "game:state" {tick: 1235, ...}│                              │
     │◄──────────────────────────────┤                              │
     │                               │                              │
     │◄─┐ Reconcile:                 │                              │
     │  │ - Clear pending inputs     │                              │
     │  │ - Update positions         │                              │
     │  │ - Re-render                │                              │
     ├──┘                            │                              │
     │                               │                              │
```

### Game Tick Flow (Server-Driven)

```
                  ┌────────────────────────────────┐
                  │ GameServer (every 100ms)       │
                  │                                │
                  │ 1. Process input queue         │
                  │    └─ Apply direction changes  │
                  │                                │
                  │ 2. Move all snakes             │
                  │    └─ nextPosition(dir, head)  │
                  │                                │
                  │ 3. Check apple collisions      │
                  │    └─ If eaten: grow snake     │
                  │                                │
                  │ 4. Expire apples (timeout)     │
                  │                                │
                  │ 5. Spawn new apples (random)   │
                  │    └─ If count < 3             │
                  │                                │
                  │ 6. Broadcast state snapshot    │
                  │    └─ Phoenix.PubSub.broadcast │
                  └────────────┬───────────────────┘
                               │
                               ▼
                  ┌────────────────────────────────┐
                  │ PubSub: "game:snake:tick"      │
                  └────────────┬───────────────────┘
                               │
               ┌───────────────┼───────────────┐
               │               │               │
               ▼               ▼               ▼
        ┌───────────┐   ┌───────────┐   ┌───────────┐
        │ Channel 1 │   │ Channel 2 │   │ Channel N │
        │ (Player A)│   │ (Player B)│   │ (Player N)│
        └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
              │               │               │
              │ push          │ push          │ push
              │ "game:state"  │ "game:state"  │ "game:state"
              │               │               │
              ▼               ▼               ▼
        ┌───────────┐   ┌───────────┐   ┌───────────┐
        │ Client A  │   │ Client B  │   │ Client N  │
        └───────────┘   └───────────┘   └───────────┘
```

## Specific Answers to Research Questions

### 1. Should the server be authoritative for snake positions, or just events?

**Answer:** Server must be authoritative for positions.

**Reasoning:**
- **Event-only synchronization fails** because clients with different tick timing compute different positions even with identical direction histories
- **Authoritative positions** ensure all clients see the same game state
- **Trade-off:** Higher bandwidth (full state vs events) but guaranteed consistency

**Implementation:**
- Server: Compute positions every tick, broadcast full snake bodies
- Client: Accept server positions as truth, use for rendering
- Client prediction: Optional optimization (see question 4)

### 2. How to broadcast full game state on player join?

**Answer:** Two-tier approach: initial state + ongoing updates

**Join Protocol:**
1. **Player joins channel** → `GameChannel.join/3` triggered
2. **Server queries GameServer** → `GameServer.get_state()` returns full state
3. **Send to joining client only** → `push(socket, "game:state", state)`
4. **Broadcast to others** → `broadcast!(socket, "player:joined", %{player: ...})`
5. **Subscribe to tick broadcasts** → Already subscribed via channel membership

**State format:**
```json
{
  "tick": 1234,
  "snakes": {
    "1": {
      "player_id": 1,
      "direction": "East",
      "body": [{"x": 15, "y": 20}, {"x": 14, "y": 20}, {"x": 13, "y": 20}],
      "colour": "67a387",
      "name": "Jesse the Platonic Kitten"
    },
    "2": { ... }
  },
  "apples": [
    {"position": {"x": 10, "y": 10}, "spawn_time": 1230, "expire_time": 1260}
  ],
  "grid_dimensions": {"x": 40, "y": 30}
}
```

**Elm handling:**
```elm
updateFromServer : ServerMsg -> JE.Value -> Model -> ( Model, Cmd Msg )
updateFromServer msg raw model =
    case msg of
        GameState ->
            case JD.decodeValue gameStateDecoder raw of
                Ok fullState ->
                    ( { model | board = Board.fromServerState fullState }
                    , Cmd.none
                    )
                -- ...
```

### 3. How do Phoenix Presence and Channels differ for state tracking?

**Answer:** Use Channels for game state, Presence for player metadata only.

**Phoenix.Presence:**
- **Purpose:** Track which users are online, with metadata (name, color, status)
- **Use case:** Lobby system, player list, "who's connected"
- **Not suitable for:** Fast-changing game state (positions, apples)
- **Limitation:** Designed for slowly-changing metadata, not 10Hz updates

**Phoenix.Channel:**
- **Purpose:** Real-time message passing
- **Use case:** Game state broadcasts, input handling
- **Suitable for:** High-frequency updates (100ms tick = 10 Hz)

**Recommended architecture:**
```
Phoenix.Presence
  └─ Track: player online/offline, metadata (name, color)
  └─ Update rate: On join/leave only

Phoenix.Channel + PubSub
  └─ Track: snake positions, apples, game state
  └─ Update rate: Every 100ms (game tick)
```

**Phoenix 1.7 changes from 1.3:**
- Presence API unchanged (stable since Phoenix 1.2)
- Channel API largely unchanged (few deprecations)
- **New:** `Phoenix.PubSub` now separate from channels (cleaner separation)
- **Migration:** Replace `Phoenix.PubSub.PG2` with `Phoenix.PubSub` (automatic in Phoenix 1.7)

### 4. What's the recommended Elm architecture for real-time games in 0.19?

**Answer:** Ports-based architecture with prediction/reconciliation pattern

**Elm 0.19 changes affecting architecture:**
- **Removed:** Native modules (no more direct JavaScript interop)
- **Changed:** `elm-lang/*` → `elm/*` package namespace
- **New:** Must use ports for all JavaScript integration (including WebSocket)
- **Removed:** `elm-lang/websocket` package (must use JavaScript client)

**Recommended architecture:**

```
┌─────────────────────────────────────────────────┐
│ ELM APPLICATION                                 │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │ Main.elm                                 │  │
│  │  - Browser.element                       │  │
│  │  - Model: Board + pending inputs         │  │
│  │  - Update: handle ports + local tick     │  │
│  │  - Subscriptions: ports + Time.every     │  │
│  └────────┬───────────────────────┬─────────┘  │
│           │                       │             │
│           │ Cmd                   │ Sub         │
│           │                       │             │
│  ┌────────▼───────────┐  ┌────────▼─────────┐  │
│  │ Ports.elm          │  │ Ports.elm        │  │
│  │ - sendInput        │  │ - gameStateRecv  │  │
│  │ - joinGame         │  │ - playerJoined   │  │
│  │ - leaveGame        │  │ - playerLeft     │  │
│  └────────┬───────────┘  └────────▲─────────┘  │
└───────────┼──────────────────────┼─────────────┘
            │                      │
    ════════╪══════════════════════╪══════════════
            │   JavaScript         │
            │                      │
┌───────────▼──────────────────────┴─────────────┐
│ assets/js/socket.js                            │
│                                                 │
│ - Phoenix.Socket connection                    │
│ - Channel join/push/on                         │
│ - JSON encode/decode                           │
│ - Port subscriptions                           │
└───────────┬─────────────────────────────────────┘
            │
            │ WebSocket (wss://)
            │
┌───────────▼─────────────────────────────────────┐
│ Phoenix Channel                                 │
└─────────────────────────────────────────────────┘
```

**Files structure:**
```
assets/
├── elm/
│   ├── src/
│   │   ├── Main.elm           # Browser.element, main app
│   │   ├── Ports.elm          # Port definitions
│   │   ├── Data/
│   │   │   ├── Board.elm      # Game state + reconciliation
│   │   │   ├── Snake.elm
│   │   │   ├── Player.elm
│   │   │   └── ...
│   │   └── View/
│   │       └── Board.elm      # Rendering (SVG or Canvas)
│   └── elm.json               # Elm 0.19 package format
└── js/
    ├── app.js                 # Entry point
    └── socket.js              # Phoenix Socket + Elm ports
```

**Prediction/Reconciliation pattern:**

```elm
-- Client applies input immediately (feels responsive)
update msg model =
    case msg of
        KeyPressed direction ->
            let
                predictedBoard =
                    Board.applyDirection model.currentPlayerId direction model.board

                pendingInputs =
                    (model.serverTick, direction) :: model.pendingInputs
            in
            ( { model
                | board = predictedBoard
                , pendingInputs = pendingInputs
              }
            , sendInput { direction = direction }
            )

        -- Server state arrives (authoritative)
        GameStateReceived serverState ->
            let
                reconciledBoard =
                    Board.fromServerState serverState

                -- Reapply pending inputs not yet confirmed by server
                finalBoard =
                    List.foldl
                        (\(tick, dir) board ->
                            if tick > serverState.tick then
                                Board.applyDirection model.currentPlayerId dir board
                            else
                                board
                        )
                        reconciledBoard
                        model.pendingInputs

                cleanedInputs =
                    List.filter (\(tick, _) -> tick > serverState.tick) model.pendingInputs
            in
            ( { model
                | board = finalBoard
                , serverTick = serverState.tick
                , pendingInputs = cleanedInputs
              }
            , Cmd.none
            )
```

**Key packages for Elm 0.19:**
- `elm/core` - Core language
- `elm/json` - JSON encoding/decoding
- `elm/time` - Time and subscriptions
- `elm/browser` - Browser.element
- `elm/html` or `elm/svg` - Rendering

**No Phoenix-specific package needed** - use ports instead

### 5. How to handle the timing of ticks across clients?

**Answer:** Server-authoritative tick with client interpolation

**Problem:**
- Network latency varies (20-200ms typical)
- State updates arrive at different times per client
- Clients need smooth 60fps rendering, server sends 10Hz updates

**Solution: Server tick + client interpolation**

**Server side:**
```elixir
defmodule Snaker.GameServer do
  use GenServer

  @tick_interval 100  # 100ms = 10 Hz

  def init(game_id) do
    schedule_tick()
    {:ok, %{
      game_id: game_id,
      tick_count: 0,
      snakes: %{},
      apples: [],
      input_queue: []
    }}
  end

  def handle_info(:tick, state) do
    # 1. Process queued inputs
    new_state = process_inputs(state)

    # 2. Simulate game (move snakes, check apples, etc.)
    new_state = simulate_tick(new_state)

    # 3. Increment tick counter
    new_state = %{new_state | tick_count: state.tick_count + 1}

    # 4. Broadcast state with tick number
    Phoenix.PubSub.broadcast(
      Snaker.PubSub,
      "game:#{state.game_id}",
      {:game_tick, serialize_state(new_state)}
    )

    # 5. Schedule next tick
    schedule_tick()

    {:noreply, new_state}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end
end
```

**Client side (Elm):**
```elm
-- Client maintains two timelines:
-- 1. Server tick (discrete, 100ms) - authoritative
-- 2. Render tick (continuous, 16ms for 60fps) - interpolated

type alias Model =
    { serverState : Board      -- Last confirmed state from server
    , renderState : Board      -- Interpolated state for rendering
    , serverTick : Int         -- Server's tick number
    , timeSinceUpdate : Float  -- For interpolation
    }

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ gameStateReceived GameStateReceived  -- From server (100ms)
        , Time.every 16 RenderTick             -- 60fps rendering
        ]

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        -- Server state arrives (authoritative, 10Hz)
        GameStateReceived serverState ->
            ( { model
                | serverState = serverState.board
                , serverTick = serverState.tick
                , timeSinceUpdate = 0
              }
            , Cmd.none
            )

        -- Render tick (smooth animation, 60fps)
        RenderTick delta ->
            let
                -- Interpolate between last server state and predicted next state
                interpolationFactor =
                    min 1.0 (model.timeSinceUpdate / 100)  -- 100ms server tick

                renderState =
                    Board.interpolate
                        model.serverState
                        interpolationFactor
            in
            ( { model
                | renderState = renderState
                , timeSinceUpdate = model.timeSinceUpdate + delta
              }
            , Cmd.none
            )
```

**Interpolation strategy:**
For snake game, simple approach:
```elm
-- Don't interpolate positions (discrete grid movement)
-- Just use latest server state directly
-- Smooth movement comes from CSS transitions on rendered tiles

view : Model -> Html Msg
view model =
    -- Render serverState, not interpolated state
    -- CSS transition: transform 100ms ease-out
    Board.view model.serverState
```

**Why this works:**
- Snake movement is discrete (grid-based), not continuous
- 100ms server tick matches snake move speed
- CSS transitions provide smooth visual movement
- No complex interpolation needed

**Alternative (if implementing smooth movement):**
```elm
-- For sub-tile smooth movement:
interpolate : Board -> Float -> Board
interpolate board factor =
    { board
        | snakes =
            Dict.map
                (\_ snake ->
                    { snake
                        | renderPosition =
                            lerp
                                snake.previousPosition
                                snake.currentPosition
                                factor
                    }
                )
                board.snakes
    }
```

**Handling latency:**
- **High latency (>200ms):** Server state arrives late, client sees stutter
  - **Mitigation:** Prediction (apply local inputs immediately)
  - **Recovery:** Reconciliation (when server state arrives, correct if needed)
- **Low latency (<50ms):** Minimal prediction needed
  - **Simple:** Just render server state directly

## Build Order and Dependencies

### Phase 1: Server Authoritative State (Backend)

**Objective:** Server maintains and broadcasts game state

**Components (build in order):**

1. **GameServer GenServer** (`lib/snaker/game_server.ex`)
   - Start with basic state structure (snakes, apples, tick)
   - Implement tick loop (100ms interval)
   - Add snake movement logic (ported from Elm)
   - Add apple spawning/expiry logic
   - **Test:** Unit test state transitions
   - **Dependencies:** None (can build standalone)

2. **Game state serialization** (`lib/snaker/game_state.ex`)
   - JSON encoding for state snapshot
   - Match Elm decoder expectations
   - **Test:** Encoding matches Elm decoders
   - **Dependencies:** GameServer state structure

3. **GameSupervisor** (`lib/snaker/game_supervisor.ex`)
   - DynamicSupervisor for game instances
   - Start one game on application start (hardcode ID for now)
   - **Test:** Supervisor restarts crashed games
   - **Dependencies:** GameServer

4. **Update Application supervisor** (`lib/snaker/application.ex`)
   - Add GameSupervisor to supervision tree
   - **Dependencies:** GameSupervisor

**Deliverable:** Server runs game loop, can be inspected via `iex`

### Phase 2: Server Broadcast (Backend)

**Objective:** Broadcast state to connected clients

**Components:**

5. **PubSub integration** (in `GameServer`)
   - `Phoenix.PubSub.broadcast` on each tick
   - Topic: `"game:#{game_id}:tick"`
   - **Test:** Multiple subscribers receive messages
   - **Dependencies:** Phase 1 complete

6. **GameChannel modifications** (`lib/snaker_web/channels/game_channel.ex`)
   - `join/3`: Add player to GameServer, send initial state
   - `handle_info({:game_tick, state})`: Broadcast to socket
   - `handle_in("player:input")`: Forward to GameServer
   - `terminate/2`: Remove player from GameServer
   - **Test:** Channel test (join, receive state, send input)
   - **Dependencies:** GameServer, PubSub

**Deliverable:** Backend can accept WebSocket connections and broadcasts state

### Phase 3: Client WebSocket (Frontend - JavaScript)

**Objective:** Elm can communicate with Phoenix Channels

**Components:**

7. **Phoenix JavaScript client** (`assets/js/socket.js`)
   - Install `phoenix` npm package
   - Connect to socket
   - Join channel
   - Set up port integration
   - **Test:** Manual connection test (browser console)
   - **Dependencies:** None (standalone JavaScript)

8. **Elm ports** (`assets/elm/src/Ports.elm`)
   - Define outgoing ports (sendInput, joinGame, leaveGame)
   - Define incoming ports (gameStateReceived, playerJoined, playerLeft)
   - **Test:** Type-check only (no runtime test needed)
   - **Dependencies:** None

**Deliverable:** JavaScript can connect and communicate with backend

### Phase 4: Client State Handling (Frontend - Elm)

**Objective:** Elm receives and renders server state

**Components:**

9. **Elm 0.19 upgrade** (all `assets/elm/src/*.elm`)
   - Migrate to `elm/core`, `elm/json`, `elm/browser`, `elm/html`, `elm/time`
   - Update syntax (`<|` spacing, `andThen` signature changes)
   - Remove `elm-lang/keyboard` (use `Browser.Events.onKeyDown`)
   - **Test:** `elm make` compiles successfully
   - **Dependencies:** Elm 0.19 installed

10. **Main.elm refactor** (`assets/elm/src/Main.elm`)
    - Change `Html.program` → `Browser.element`
    - Add port subscriptions
    - Remove old Phoenix Socket code
    - Add `gameStateReceived` handler
    - **Test:** Compiles and initializes
    - **Dependencies:** Elm 0.19 upgrade, Ports

11. **Board.elm state reconciliation** (`assets/elm/src/Data/Board.elm`)
    - Add `fromServerState : ServerState -> Board` function
    - Remove local apple generation (now server-driven)
    - Add `serverTick` field to model
    - **Test:** Decoder test (mock JSON → Board)
    - **Dependencies:** Server state format defined

**Deliverable:** Elm app renders server-sent state

### Phase 5: Client Input Handling (Frontend)

**Objective:** User input sent to server, prediction applied locally

**Components:**

12. **Input handling** (`assets/elm/src/Main.elm` + `Ports.elm`)
    - Keyboard event → sendInput port
    - Apply direction change locally (prediction)
    - Track pending inputs
    - **Test:** Keypress sends message (check browser console)
    - **Dependencies:** Ports, Board.elm

13. **Reconciliation logic** (`assets/elm/src/Data/Board.elm`)
    - When server state arrives, reconcile with pending inputs
    - Clear confirmed inputs
    - Reapply unconfirmed inputs
    - **Test:** Unit test reconciliation function
    - **Dependencies:** Board state structure

**Deliverable:** User can control snake with immediate feedback

### Phase 6: Integration and Polish

**Objective:** End-to-end multiplayer working correctly

**Components:**

14. **Integration testing**
    - Two browser windows connect
    - Both see same snake positions
    - Direction changes propagate correctly
    - Player join/leave handled
    - **Test:** Manual testing + automated channel test
    - **Dependencies:** All previous phases

15. **Bug fixes and polish**
    - Fix any desync issues
    - Tune tick rate if needed
    - Add error handling (disconnect, reconnect)
    - **Test:** Stress test (multiple players, poor network)
    - **Dependencies:** Integration testing complete

**Deliverable:** Multiplayer state sync bug fixed

### Dependency Graph

```
Phase 1 (Server State)
  ├─ 1. GameServer
  ├─ 2. State serialization (depends on 1)
  ├─ 3. GameSupervisor (depends on 1)
  └─ 4. Application supervisor (depends on 3)

Phase 2 (Server Broadcast)
  ├─ 5. PubSub integration (depends on Phase 1)
  └─ 6. GameChannel (depends on 5)

Phase 3 (Client WebSocket)
  ├─ 7. Phoenix JS client (independent)
  └─ 8. Elm ports (independent)

Phase 4 (Client State)
  ├─ 9. Elm 0.19 upgrade (independent)
  ├─ 10. Main.elm refactor (depends on 8, 9)
  └─ 11. Board.elm reconciliation (depends on 2, 9)

Phase 5 (Client Input)
  ├─ 12. Input handling (depends on Phase 4)
  └─ 13. Reconciliation (depends on 11, 12)

Phase 6 (Integration)
  ├─ 14. Integration testing (depends on Phase 2, 5)
  └─ 15. Bug fixes (depends on 14)
```

**Critical path:** 1 → 2 → 3 → 4 → 5 → 6 → 9 → 10 → 11 → 12 → 14 → 15
**Parallel work:** Phase 1-2 (backend) can progress while Phase 3 (JS) is being built

## Specific Recommendations for State Sync Bug

### Root Cause
- Clients compute positions independently
- No synchronization of initial state
- Apple spawning is client-side random (inconsistent)

### Fix Approach

**High-level strategy:**
Move game simulation to server, broadcast authoritative state.

**Detailed steps:**

1. **Server becomes authoritative** (Phase 1-2)
   - GameServer runs game loop
   - Snakes move on server
   - Apples spawn on server
   - State broadcasted every 100ms

2. **Clients receive state snapshots** (Phase 4)
   - On join: receive full current state
   - Every tick: receive state update
   - Render based on server state

3. **Client prediction (optional optimization)** (Phase 5)
   - Apply own input immediately
   - Reconcile when server confirms
   - Prevents input lag feeling

**Minimal fix (if time-constrained):**
- Skip client prediction (Phase 5)
- Just render server state directly
- Acceptable for 100ms tick rate
- Can add prediction later if input feels laggy

**Testing criteria:**
- [ ] Two players join at different times
- [ ] Both players see identical snake positions
- [ ] Both players see identical apples
- [ ] Direction changes apply to correct snake
- [ ] Snake positions don't drift over time
- [ ] New player sees existing players in correct positions

### Migration Gotchas

**Phoenix 1.3 → 1.7:**
- `Phoenix.PubSub.PG2` → `Phoenix.PubSub` (config change)
- Directory structure changes (optional, can keep old structure)
- `use Phoenix.Channel` unchanged (stable API)
- WebSocket transport: unchanged

**Elm 0.18 → 0.19:**
- `Html.program` → `Browser.element`
- `elm-lang/*` → `elm/*` packages
- Keyboard: `Keyboard.ups` → `Browser.Events.onKeyDown`
- Time: `Time.every` signature changed (same concept)
- No `elm-phoenix-socket` equivalent (use ports)

**Assets pipeline (Brunch → esbuild):**
- Phoenix 1.7 uses `esbuild` instead of Brunch
- Elm compilation: separate step via `elm make`
- Add to `mix.exs` assets setup

## Quality Gate Checklist

- [x] State sync fix approach clearly documented
  - Authoritative server pattern with full state broadcast
  - Client reconciliation with optional prediction

- [x] Server vs client responsibilities defined
  - **Server:** Game loop, snake movement, apple spawning, collision detection, state broadcast
  - **Client:** Input capture, state rendering, optional prediction, reconciliation

- [x] Data flow diagram or description included
  - Player join flow (3 diagrams)
  - Input → state update flow
  - Game tick flow (server-driven)
  - Component architecture diagrams

- [x] Specific questions answered
  1. Server authoritative for positions: YES
  2. Broadcast full state on join: Two-tier (initial + ongoing)
  3. Presence vs Channels: Channels for game state, Presence for metadata
  4. Elm 0.19 architecture: Ports-based with prediction/reconciliation
  5. Tick timing: Server tick + client interpolation (or CSS transitions)

- [x] Build order with dependencies
  - 6 phases, 15 components
  - Dependency graph included
  - Critical path identified
  - Parallel work opportunities noted

## References

**Phoenix Channels (1.7):**
- Official docs: https://hexdocs.pm/phoenix/channels.html
- PubSub: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html
- Presence: https://hexdocs.pm/phoenix/presence.html

**Elm 0.19:**
- Guide: https://guide.elm-lang.org/
- Browser package: https://package.elm-lang.org/packages/elm/browser/latest/
- Ports: https://guide.elm-lang.org/interop/ports.html

**Game Architecture Patterns:**
- Client-Server Game Architecture (Gaffer on Games): Fast-paced multiplayer patterns
- Source Multiplayer Networking (Valve): Prediction and lag compensation
- Phoenix Presence Guide: Distributed user tracking

**Existing codebase analysis:**
- `.planning/codebase/ARCHITECTURE.md` - Current architecture documented 2026-01-30
- `.planning/codebase/CONCERNS.md` - Known bugs and tech debt documented 2026-01-30

---

*Architecture research completed: 2026-01-30*
