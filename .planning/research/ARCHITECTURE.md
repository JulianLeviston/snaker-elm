# Architecture Research: P2P WebRTC Mode

**Domain:** P2P multiplayer integration for existing Elm + Phoenix snake game
**Researched:** 2026-02-03
**Overall Confidence:** HIGH (existing codebase analyzed, WebRTC patterns well-documented)

---

## Executive Summary

This document details how to integrate P2P WebRTC multiplayer mode alongside the existing Phoenix-based multiplayer. The architecture uses a **host-authoritative model** where one peer runs the game loop and broadcasts state, mirroring the current Phoenix GenServer pattern but running entirely client-side.

Key insight: The existing architecture already separates concerns well - Elm handles rendering and input, TypeScript handles networking, Elixir handles game logic. For P2P mode, we port the game logic to Elm and swap the TypeScript networking layer.

---

## High-Level Architecture

### Current Phoenix Mode Architecture

```
+------------------+      Phoenix Socket      +------------------+
|   Elm App        |<------------------------>|   TypeScript     |
|  (View/Input)    |         Ports            |  (socket.ts)     |
+------------------+                          +------------------+
                                                      |
                                              Phoenix Channel
                                                      |
                                                      v
                                              +------------------+
                                              | Phoenix          |
                                              | GameServer       |
                                              | (game_server.ex) |
                                              +------------------+
                                              | - Tick loop 100ms|
                                              | - Snake movement |
                                              | - Collision      |
                                              | - Apple spawn    |
                                              +------------------+
```

### Proposed P2P Mode Architecture

```
+------------------+                          +------------------+
|   Elm App        |<------------------------>|   TypeScript     |
|  (View/Input +   |         Ports            |  (p2p.ts)        |
|   GAME LOGIC*)   |                          +------------------+
+------------------+                                  |
        ^                                     PeerJS DataChannel
        |                                             |
        | *Host only runs                             v
        |  game loop                          +------------------+
        |                                     | Other Peers      |
        +------------------------------------>| (receive state)  |
                                              +------------------+
```

### Dual-Mode Architecture

```
+------------------+         +------------------+
|   Elm App        |-------->|   TypeScript     |
|                  |  Ports  |   Networking     |
+------------------+         +------------------+
                                    |
                      +-------------+-------------+
                      |                           |
                      v                           v
              +---------------+           +---------------+
              | Phoenix Mode  |           | P2P Mode      |
              | (socket.ts)   |           | (p2p.ts)      |
              +---------------+           +---------------+
```

---

## Component Breakdown

### New Components

| Component | Location | Purpose | Confidence |
|-----------|----------|---------|------------|
| `GameEngine.elm` | `assets/src/GameEngine.elm` | Pure game logic (tick, collision, apple) | HIGH |
| `P2P.elm` | `assets/src/P2P.elm` | P2P-specific state types and encoders | HIGH |
| `P2PPorts.elm` | `assets/src/P2PPorts.elm` | WebRTC port definitions | HIGH |
| `p2p.ts` | `assets/js/p2p.ts` | PeerJS connection management | HIGH |
| `hostElection.ts` | `assets/js/hostElection.ts` | Deterministic host election logic | HIGH |

### Modified Components

| Component | Changes | Reason |
|-----------|---------|--------|
| `Main.elm` | Add mode switching, P2P subscriptions | Support both modes |
| `Ports.elm` | Add P2P port declarations | WebRTC communication |
| `app.ts` | Mode selection, conditional loading | Switch between Phoenix/P2P |
| `Game.elm` | Minor: ensure decoders work for P2P format | Share types between modes |

### Components Unchanged

| Component | Reason |
|-----------|--------|
| `Snake.elm` | Already has Position, Direction, Snake types |
| `View/Board.elm` | Renders from GameState - mode agnostic |
| `View/Scoreboard.elm` | Renders from snakes list - mode agnostic |
| `socket.ts` | Phoenix mode continues to work as-is |
| `game_server.ex` | Phoenix mode continues to work as-is |

---

## Data Flow

### Phoenix Mode (Current)

```
1. Player presses arrow key
2. Elm: KeyPressed -> sendDirection port
3. TypeScript: channel.push("player:change_direction", {...})
4. Phoenix: GameServer.change_direction() buffers input
5. Phoenix: Tick fires every 100ms
6. Phoenix: GameServer broadcasts delta via PubSub
7. TypeScript: channel.on("tick") -> receiveTick port
8. Elm: GotTick updates model.gameState
9. Elm: View re-renders
```

### P2P Mode (Proposed)

**As Host:**
```
1. Player presses arrow key
2. Elm: KeyPressed -> buffer direction locally
3. Elm: Tick subscription fires (Time.every 100ms)
4. Elm: GameEngine.tick() computes new state
5. Elm: broadcastState port sends state to peers
6. TypeScript: p2p.broadcast(gameState) via DataChannel
7. Remote peers receive and render
```

**As Non-Host:**
```
1. Player presses arrow key
2. Elm: KeyPressed -> sendP2PInput port
3. TypeScript: p2p.sendToHost({direction: ...})
4. Host receives, buffers input
5. Host tick includes this player's input
6. Host broadcasts new state
7. TypeScript: receiveP2PState port
8. Elm: GotP2PState updates model.gameState
9. Elm: View re-renders
```

---

## Host Election Algorithm

### Requirements
- Deterministic: All peers compute same result independently
- No signaling needed: Works with only peer list
- Handles joins/leaves: Re-elects when topology changes
- Migration: New host receives/reconstructs state

### Algorithm: Lowest Peer ID Wins

```typescript
// hostElection.ts

export interface Peer {
  id: string;  // PeerJS assigns UUID-like IDs
  connectedAt: number;  // Timestamp for tiebreaker
}

export function electHost(peers: Peer[], selfId: string): string {
  // Include self in peer list
  const allPeers = [...peers, { id: selfId, connectedAt: Date.now() }];

  // Sort by ID (string comparison, deterministic)
  const sorted = allPeers.sort((a, b) => a.id.localeCompare(b.id));

  // Lowest ID is host
  return sorted[0].id;
}

export function amIHost(peers: Peer[], selfId: string): boolean {
  return electHost(peers, selfId) === selfId;
}
```

### Host Migration Protocol

```
1. Peer disconnects
2. All remaining peers remove disconnected peer from list
3. All peers re-run electHost() independently
4. Same result because deterministic algorithm
5. New host (if changed):
   a. Had local copy of last received state
   b. Broadcasts "i_am_host" with current state
   c. Starts tick loop
6. Non-hosts:
   a. Stop tick loop if they were running it
   b. Wait for state from new host
```

### Edge Cases

| Scenario | Handling |
|----------|----------|
| Original host disconnects | Next lowest ID becomes host, broadcasts state |
| Non-host disconnects | Host removes from player list, continues |
| Network partition | Each partition elects own host (eventually inconsistent) |
| Rejoining peer | Gets fresh state from current host |

---

## State Synchronization

### Message Types

```typescript
// p2p.ts - Message protocol

interface P2PMessage {
  type: 'game_state' | 'player_input' | 'host_announcement' | 'peer_list' | 'ping';
  payload: unknown;
  timestamp: number;
  senderId: string;
}

interface GameStateMessage {
  type: 'game_state';
  payload: {
    snakes: Snake[];
    apples: Apple[];
    gridWidth: number;
    gridHeight: number;
    tickNumber: number;  // For ordering/debugging
  };
  timestamp: number;
  senderId: string;
}

interface PlayerInputMessage {
  type: 'player_input';
  payload: {
    direction: 'up' | 'down' | 'left' | 'right';
    playerId: string;
  };
  timestamp: number;
  senderId: string;
}

interface HostAnnouncementMessage {
  type: 'host_announcement';
  payload: {
    hostId: string;
    gameState: GameStatePayload;
  };
  timestamp: number;
  senderId: string;
}
```

### Synchronization Strategy: Full State Broadcast

For a game with ~2-10 players, ~100 body segments max per snake, and 100ms tick rate:

**State size estimate:**
- 10 snakes * 100 segments * 8 bytes (x,y) = 8KB max
- Plus metadata: ~1KB
- Total: ~10KB per tick

**Bandwidth:** 10KB * 10 ticks/sec = 100KB/sec per connection
- Acceptable for WebRTC DataChannel
- PeerJS handles serialization automatically with `reliable: true`

**Why full state (not delta):**
- Simpler implementation
- Self-healing (missed message = one bad frame, next tick fixes)
- Current Phoenix mode already sends "full" snake positions each tick
- Matches existing `tickDecoder` in Elm

### Channel Configuration

```typescript
// PeerJS connection options
const conn = peer.connect(hostId, {
  reliable: true,    // Ordered, guaranteed delivery
  serialization: 'json',  // Easy debugging, compatible with Elm
  metadata: {
    playerId: myId,
    playerName: myName
  }
});
```

---

## Elm Ports Structure

### Current Ports (Phoenix Mode)

```elm
-- Outgoing (Elm -> JS)
port joinGame : JE.Value -> Cmd msg
port leaveGame : () -> Cmd msg
port sendDirection : JE.Value -> Cmd msg

-- Incoming (JS -> Elm)
port receiveGameState : (JD.Value -> msg) -> Sub msg
port receiveError : (String -> msg) -> Sub msg
port playerJoined : (JD.Value -> msg) -> Sub msg
port playerLeft : (JD.Value -> msg) -> Sub msg
port receiveTick : (JD.Value -> msg) -> Sub msg
```

### New Ports (P2P Mode)

```elm
-- assets/src/P2PPorts.elm

port module P2PPorts exposing (..)

import Json.Decode as JD
import Json.Encode as JE


-- ============================================================
-- Outgoing Ports (Elm -> JS)
-- ============================================================

-- Initialize P2P peer with optional room ID
port p2pInit : JE.Value -> Cmd msg
-- { roomId : Maybe String }

-- Create room (become host)
port p2pCreateRoom : () -> Cmd msg

-- Join existing room
port p2pJoinRoom : String -> Cmd msg
-- roomId (host's peer ID)

-- Leave P2P session
port p2pLeave : () -> Cmd msg

-- Send direction input (non-host sends to host)
port p2pSendInput : JE.Value -> Cmd msg
-- { direction : String }

-- Broadcast game state (host only)
port p2pBroadcastState : JE.Value -> Cmd msg
-- Full GameState JSON


-- ============================================================
-- Incoming Ports (JS -> Elm)
-- ============================================================

-- P2P initialized with our peer ID
port p2pReady : (JE.Value -> msg) -> Sub msg
-- { peerId : String }

-- Room created (we are host)
port p2pRoomCreated : (JE.Value -> msg) -> Sub msg
-- { roomId : String }

-- Joined room successfully
port p2pJoinedRoom : (JE.Value -> msg) -> Sub msg
-- { hostId : String, gameState : GameState, playerId : String }

-- Another peer connected (host receives)
port p2pPeerConnected : (JE.Value -> msg) -> Sub msg
-- { peerId : String, metadata : { playerName : String } }

-- Peer disconnected
port p2pPeerDisconnected : (JE.Value -> msg) -> Sub msg
-- { peerId : String }

-- Receive input from peer (host receives)
port p2pReceiveInput : (JE.Value -> msg) -> Sub msg
-- { peerId : String, direction : String }

-- Receive state update (non-host receives)
port p2pReceiveState : (JE.Value -> msg) -> Sub msg
-- Full GameState JSON

-- Host migration occurred
port p2pHostMigrated : (JE.Value -> msg) -> Sub msg
-- { newHostId : String, amIHost : Bool, gameState : GameState }

-- Error
port p2pError : (String -> msg) -> Sub msg
```

### Port Wiring in TypeScript

```typescript
// assets/js/p2p.ts

interface P2PElmPorts {
  // Outgoing (subscribe)
  p2pInit: { subscribe: (callback: (data: { roomId?: string }) => void) => void };
  p2pCreateRoom: { subscribe: (callback: () => void) => void };
  p2pJoinRoom: { subscribe: (callback: (roomId: string) => void) => void };
  p2pLeave: { subscribe: (callback: () => void) => void };
  p2pSendInput: { subscribe: (callback: (data: { direction: string }) => void) => void };
  p2pBroadcastState: { subscribe: (callback: (state: unknown) => void) => void };

  // Incoming (send)
  p2pReady: { send: (data: { peerId: string }) => void };
  p2pRoomCreated: { send: (data: { roomId: string }) => void };
  p2pJoinedRoom: { send: (data: unknown) => void };
  p2pPeerConnected: { send: (data: { peerId: string; metadata: unknown }) => void };
  p2pPeerDisconnected: { send: (data: { peerId: string }) => void };
  p2pReceiveInput: { send: (data: { peerId: string; direction: string }) => void };
  p2pReceiveState: { send: (state: unknown) => void };
  p2pHostMigrated: { send: (data: unknown) => void };
  p2pError: { send: (message: string) => void };
}
```

---

## Game Loop Ownership

### Host-Authoritative Model

Only the host runs the game tick loop. This mirrors the Phoenix GenServer pattern:

**Phoenix Mode:**
- `GameServer` GenServer runs `Process.send_after(self(), :tick, 100)`
- All clients receive state, none compute it

**P2P Mode:**
- Host's Elm app subscribes to `Time.every 100`
- Host runs `GameEngine.tick` on each interval
- Non-hosts receive state via DataChannel, ignore local tick

### Elm Implementation

```elm
-- Main.elm (simplified)

type GameMode
    = PhoenixMode PhoenixState
    | P2PMode P2PState


type alias P2PState =
    { isHost : Bool
    , peers : List PeerId
    , inputBuffer : Dict PeerId Direction  -- Host only
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.mode of
        PhoenixMode _ ->
            phoenixSubscriptions model

        P2PMode p2pState ->
            Sub.batch
                [ p2pSubscriptions
                , if p2pState.isHost then
                    Time.every 100 P2PTick
                  else
                    Sub.none
                ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.mode ) of
        ( P2PTick _, P2PMode p2pState ) ->
            if p2pState.isHost then
                let
                    newState = GameEngine.tick model.gameState p2pState.inputBuffer
                in
                ( { model | gameState = Just newState }
                , P2PPorts.p2pBroadcastState (GameEngine.encode newState)
                )
            else
                ( model, Cmd.none )

        ( GotP2PState stateJson, P2PMode _ ) ->
            case JD.decodeValue Game.decoder stateJson of
                Ok state ->
                    ( { model | gameState = Just state }, Cmd.none )
                Err _ ->
                    ( model, Cmd.none )

        -- ... other cases
```

### Tick Rate Considerations

Current Phoenix tick: 100ms (10 Hz)

For P2P mode, same rate recommended because:
- Matches existing game feel
- Reasonable bandwidth (see synchronization section)
- `Time.every 100` is reliable in Elm
- Browser tab backgrounding: Game pauses (acceptable for casual game)

**Note:** `Time.every` uses `setInterval` under the hood. For a snake game at 10 Hz, this is fine. Higher tick rates (60+ Hz) would need `requestAnimationFrame` via ports.

---

## Mode Selection

### UI Approach

```
+------------------------+
|        Snaker          |
+------------------------+
|                        |
|  [Join Server Game]    |  <- Phoenix mode (current)
|                        |
|  -- or --              |
|                        |
|  [Create P2P Room]     |  <- P2P host
|  [Join P2P Room: ____] |  <- P2P join (enter room ID)
|                        |
+------------------------+
```

### Elm Model

```elm
type Screen
    = ModeSelection
    | PlayingPhoenix PhoenixState
    | PlayingP2P P2PState
    | P2PLobby LobbyState  -- Waiting for peers


type LobbyState
    = CreatingRoom
    | WaitingInRoom { roomId : String, players : List Player }
    | JoiningRoom { roomId : String }
```

### Mode Initialization

```elm
-- User clicks "Join Server Game"
update (SelectPhoenixMode) model =
    ( { model | screen = PlayingPhoenix initialPhoenixState }
    , Ports.joinGame (JE.object [])
    )

-- User clicks "Create P2P Room"
update (SelectP2PHost) model =
    ( { model | screen = P2PLobby CreatingRoom }
    , P2PPorts.p2pCreateRoom ()
    )

-- User enters room ID and clicks "Join P2P Room"
update (SelectP2PJoin roomId) model =
    ( { model | screen = P2PLobby (JoiningRoom { roomId = roomId }) }
    , P2PPorts.p2pJoinRoom roomId
    )
```

---

## GameEngine Module (Elm)

Port of `game_server.ex` logic to pure Elm.

### Module Structure

```elm
-- assets/src/GameEngine.elm

module GameEngine exposing
    ( tick
    , applyInputs
    , moveSnakes
    , checkCollisions
    , checkAppleEating
    , spawnApplesIfNeeded
    , addPlayer
    , removePlayer
    , encode
    )

import Game exposing (GameState, Apple)
import Snake exposing (Snake, Position, Direction)
import Random


-- Core tick function (host only)
tick : GameState -> Dict PlayerId Direction -> Random.Seed -> ( GameState, Random.Seed )
tick state inputBuffer seed =
    state
        |> applyInputs inputBuffer
        |> moveSnakes
        |> checkCollisions seed
        |> checkAppleEating
        |> spawnApplesIfNeeded


-- Apply buffered direction changes
applyInputs : Dict PlayerId Direction -> GameState -> GameState
applyInputs buffer state =
    { state
        | snakes =
            List.map
                (\snake ->
                    case Dict.get snake.id buffer of
                        Just newDir ->
                            if validDirectionChange snake.direction newDir then
                                { snake | direction = newDir }
                            else
                                snake
                        Nothing ->
                            snake
                )
                state.snakes
    }


-- Move each snake one step
moveSnakes : GameState -> GameState
moveSnakes state =
    { state
        | snakes = List.map (moveSnake state.gridWidth state.gridHeight) state.snakes
    }


moveSnake : Int -> Int -> Snake -> Snake
moveSnake width height snake =
    let
        ( dx, dy ) =
            directionDelta snake.direction

        head =
            List.head snake.body |> Maybe.withDefault { x = 0, y = 0 }

        newHead =
            { x = modBy width (head.x + dx)
            , y = modBy height (head.y + dy)
            }

        newBody =
            if snake.pendingGrowth > 0 then
                newHead :: snake.body
            else
                newHead :: List.take (List.length snake.body - 1) snake.body
    in
    { snake
        | body = newBody
        , pendingGrowth = max 0 (snake.pendingGrowth - 1)
    }


-- Check self-collision and collision with other snakes
checkCollisions : Random.Seed -> GameState -> ( GameState, Random.Seed )
checkCollisions seed state =
    -- Implementation: respawn collided snakes at safe positions
    -- Use seed for random spawn position
    ...


-- Check if any snake head is on an apple
checkAppleEating : GameState -> GameState
checkAppleEating state =
    -- Implementation: grow snake, remove apple
    ...


-- Ensure minimum apple count
spawnApplesIfNeeded : ( GameState, Random.Seed ) -> ( GameState, Random.Seed )
spawnApplesIfNeeded ( state, seed ) =
    -- Implementation: spawn apples if below minimum
    ...
```

### Random Number Handling

Elm requires explicit `Random.Seed` threading. The host maintains the seed:

```elm
type alias P2PHostState =
    { gameState : GameState
    , inputBuffer : Dict PlayerId Direction
    , randomSeed : Random.Seed
    , tickCount : Int
    }
```

Initialize seed from JavaScript for true randomness:

```elm
-- Port
port initRandomSeed : (Int -> msg) -> Sub msg

-- Update
update (GotRandomSeed seedInt) model =
    ( { model | randomSeed = Random.initialSeed seedInt }, Cmd.none )
```

---

## Suggested Build Order

Based on dependencies and risk, build in this order:

### Phase 1: Game Engine in Elm (No Network)

1. **GameEngine.elm** - Port snake movement, collision from Elixir
2. **Test locally** - Single-player mode using `Time.every`
3. **Validate** - Confirm game logic matches Phoenix behavior

**Why first:** This is the largest new code. Get it right before adding network complexity.

### Phase 2: P2P Infrastructure

4. **p2p.ts** - PeerJS wrapper, connection management
5. **hostElection.ts** - Deterministic election algorithm
6. **P2PPorts.elm** - Port definitions
7. **Test connections** - Two browser tabs can connect

**Why second:** Infrastructure before integration. Test peer connections independently.

### Phase 3: Host Mode

8. **Host tick loop** - Elm `Time.every` + `broadcastState`
9. **Input handling** - Host receives inputs from peers via port
10. **Test** - Host tab runs game, other tabs see updates

**Why third:** Host is simpler (just run loop, broadcast). Get this working first.

### Phase 4: Client Mode

11. **Receive state** - Non-host receives and renders
12. **Send input** - Non-host sends direction to host
13. **Test** - Full P2P game works

**Why fourth:** Depends on host working correctly.

### Phase 5: Host Migration

14. **Detect disconnect** - PeerJS events
15. **Re-election** - All peers compute new host
16. **State handoff** - New host broadcasts state
17. **Test** - Kill host tab, game continues

**Why last:** Most complex feature, depends on everything else working.

### Phase 6: Mode Selection UI

18. **Lobby screen** - Create/join room UI
19. **Mode switching** - Phoenix vs P2P selection
20. **Polish** - Error handling, reconnection

**Why last:** UI polish after core functionality.

---

## Integration Points Summary

| Existing Component | Integration Point | Change Required |
|-------------------|-------------------|-----------------|
| `Main.elm` | Add `GameMode` type, mode-specific subscriptions | Moderate |
| `Ports.elm` | Add P2P ports (or create `P2PPorts.elm`) | Small |
| `Game.elm` | Reuse types, ensure decoders work for both modes | Minimal |
| `Snake.elm` | Reuse types, add `pendingGrowth` field if missing | Minimal |
| `app.ts` | Add mode selection, load P2P module conditionally | Moderate |
| `socket.ts` | No changes, Phoenix mode unchanged | None |
| Views | No changes, render from `GameState` regardless of mode | None |
| Phoenix backend | No changes for P2P mode | None |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| GameEngine logic bugs | Medium | High | Port tests from Elixir, extensive manual testing |
| Host migration race conditions | Medium | Medium | Clear state machine, timeout on re-election |
| WebRTC connection failures | Medium | Low | PeerJS handles retries, fallback to Phoenix mode |
| Tick timing inconsistency | Low | Medium | Use fixed tick rate, accept minor drift |
| State desync between peers | Low | High | Full state broadcast self-heals, add tick numbers |

---

## Sources

### PeerJS Documentation
- [PeerJS Official Docs](https://peerjs.com/docs/) - API reference for Peer, DataConnection

### WebRTC Architecture
- [PlayPeerJS](https://github.com/therealPaulPlay/PlayPeerJS) - Host migration patterns
- [WebRTC DataChannel Guide](https://webrtc.link/en/articles/rtcdatachannel-usage-and-message-size-limits/) - Reliability options
- [MDN WebRTC Data Channels](https://developer.mozilla.org/en-US/docs/Games/Techniques/WebRTC_data_channels) - Game development patterns

### Elm + WebRTC Integration
- [Elm WebRTC with Custom Elements](https://marc-walter.info/posts/2020-06-30_elm-conf/) - Port patterns
- [elm-community/js-integration-examples](https://github.com/elm-community/js-integration-examples) - Port best practices

### Host Migration
- [Edgegap: Host Migration in P2P Games](https://edgegap.com/blog/host-migration-in-peer-to-peer-or-relay-based-multiplayer-games) - Industry patterns

### Game Loop Timing
- [MDN: Anatomy of a Video Game](https://developer.mozilla.org/en-US/docs/Games/Anatomy) - requestAnimationFrame vs setInterval
- [JavaScript Game Loops](https://isaacsukin.com/news/2015/01/detailed-explanation-javascript-game-loops-and-timing) - Timing patterns
