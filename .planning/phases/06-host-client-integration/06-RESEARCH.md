# Phase 6: Host/Client Integration - Research

**Researched:** 2026-02-03
**Domain:** P2P multiplayer game state synchronization and host-authoritative networking
**Confidence:** MEDIUM

## Summary

This phase implements host-authoritative P2P multiplayer gameplay where the host runs the game loop and broadcasts state to clients who render it and send inputs back. The research covers state synchronization patterns, client-side prediction with server reconciliation, delta vs. full state sync tradeoffs, and best practices for handling player join/leave events.

The standard approach for real-time multiplayer games is **client-side prediction with server reconciliation**: clients immediately apply their own inputs locally (optimistic response) while the host runs the authoritative simulation. When host state arrives, clients reconcile differences through smooth interpolation rather than jarring snaps. For a fast-paced game like Snake running at 100ms ticks, delta state updates (positions + changed entities) are sent every tick, with periodic full state snapshots (every 5 seconds) for error correction.

The user has decided on delta-based updates with full state every 50 ticks, optimistic local input handling, and smooth interpolation for corrections. The host broadcasts to all clients in a star topology (already established via PeerJS in Phase 5), with no host migration in this phase.

**Primary recommendation:** Use Elm ports to send/receive JSON-encoded game messages via PeerJS DataConnection, implement separate host game loop (extends LocalGame) and client renderer (applies host state), and use linear interpolation over 2-3 ticks to smooth position corrections when client prediction diverges from host authority.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PeerJS | 1.5.5 | WebRTC data channels | Already integrated in Phase 5; handles P2P connections and chunking for large messages |
| Elm JSON | 1.1.4 | Encode/decode game state | Built into Elm; type-safe serialization of game messages |
| Elm Time | (core) | Tick subscription | Standard for game loops in Elm applications |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Random | (core) | Color generation, spawn positions | Assign distinct colors to each player, safe spawn positions |
| Process | (core) | Delayed commands | Notification timeouts, grace period timers |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| JSON | MessagePack/CBOR (via PeerJS v1.5+) | Binary formats are 2-3x faster but lose human readability and require additional Elm decoders |
| Delta updates | Full state every tick | Simpler but 5-10x more bandwidth; acceptable for small games but wasteful |
| Ports | elm-webrtc package | No mature Elm WebRTC packages exist; ports are standard pattern |

**Installation:**
No new dependencies required. All stack components already installed in Phase 5.

## Architecture Patterns

### Recommended Project Structure
```
src/
├── HostGame.elm          # Host-specific game loop (extends LocalGame)
├── ClientGame.elm        # Client-specific state renderer
├── Protocol.elm          # Message encoding/decoding (GameMsg type)
├── Multiplayer/
│   ├── Host.elm          # Host broadcast logic
│   └── Client.elm        # Client input sending + state reconciliation
└── Engine/               # Shared game logic (already exists)
    ├── Grid.elm
    ├── Collision.elm
    └── Apple.elm
```

### Pattern 1: Host-Authoritative State Broadcast (Star Topology)

**What:** Host runs the game loop and broadcasts authoritative state to all connected clients every tick. Clients are "dumb terminals" that render what the host tells them.

**When to use:** Small player counts (2-8), trusted environment, simple game logic.

**Example:**
```elm
-- Host sends every tick (100ms):
type GameMsg
    = DeltaUpdate
        { tick : Int
        , snakes : List Snake
        , apples : List Apple
        , scores : Dict String Int
        }
    | FullStateSync GameState  -- Every 50 ticks
    | PlayerJoined { id : String, name : String, color : String }
    | PlayerLeft String

-- Client sends on input:
type ClientMsg
    = InputDirection Direction
```

**Rationale:** Host has complete authority. Network partition handled by host keeping connections alive. No consensus protocol needed.

### Pattern 2: Client-Side Prediction with Server Reconciliation

**What:** Client immediately applies local input to their snake (optimistic update) while sending input to host. When host state arrives, client checks if prediction was correct. If divergent, smoothly interpolate toward authoritative position.

**When to use:** Fast-paced games where input latency is noticeable (Snake at 100ms ticks qualifies).

**Example:**
```elm
-- Client-side state
type alias ClientState =
    { authoritative : GameState  -- Last confirmed state from host
    , predicted : Snake          -- Local snake with predicted moves
    , pendingInputs : List (Int, Direction)  -- Tick number + direction
    , interpolationOffset : Position  -- For smooth corrections
    }

-- On host state received:
reconcile : GameState -> ClientState -> ClientState
reconcile hostState client =
    let
        mySnake = findMySnake hostState client.playerId
        predictedSnake = client.predicted

        -- Check if prediction matches
        diverged = mySnake.body /= predictedSnake.body
    in
    if diverged then
        -- Calculate interpolation offset
        { client
        | authoritative = hostState
        , predicted = mySnake
        , interpolationOffset = calculateOffset predictedSnake mySnake
        }
    else
        -- Prediction was correct
        { client
        | authoritative = hostState
        , predicted = mySnake
        , pendingInputs = dropProcessedInputs hostState.tick client.pendingInputs
        }
```

**Source:** [Gabriel Gambetta - Client-Side Prediction and Server Reconciliation](https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html)

### Pattern 3: Delta State Updates with Periodic Full Sync

**What:** Send only changed data (snake positions, new apples, score changes) every tick. Every N ticks, send complete game state as a safety net against accumulated errors.

**When to use:** Bandwidth optimization for games with many entities or high tick rates.

**Example:**
```elm
type GameMsg
    = Delta
        { tick : Int
        , snakes : List Snake  -- All snakes, every tick (small in Snake game)
        , apples : List Apple  -- Only when changed
        , scores : Dict String Int  -- Only when changed
        }
    | FullSync
        { tick : Int
        , gameState : GameState
        }

-- Host logic
broadcast : Int -> GameState -> GameState -> List GameMsg
broadcast tick prevState currentState =
    if modBy 50 tick == 0 then
        -- Full sync every 5 seconds (50 ticks * 100ms)
        [ FullSync { tick = tick, gameState = currentState } ]
    else
        -- Delta update
        [ Delta
            { tick = tick
            , snakes = currentState.snakes  -- Always send (6-8 positions per snake)
            , apples = if prevState.apples /= currentState.apples then currentState.apples else []
            , scores = changedScores prevState.scores currentState.scores
            }
        ]
```

**Rationale:** Snake game state is small (< 1KB per tick), so "delta" just means omitting unchanged scores/apples. Full sync prevents drift from packet loss.

**Source:** [Gaffer On Games - State Synchronization](https://gafferongames.com/post/state_synchronization/)

### Pattern 4: Disconnect Grace Period with Ghosting

**What:** When a client disconnects, don't immediately remove them. Wait 3 seconds (grace period) during which they can reconnect and resume. While disconnected, render their snake as ghosted/faded.

**When to use:** Volatile network connections, user retention during brief disconnects.

**Example:**
```elm
type PlayerState
    = Connected DataConnection
    | Disconnected { since : Time.Posix, peerId : String }

type alias HostState =
    { players : Dict String PlayerState
    , gameState : GameState
    }

-- On disconnect:
handleDisconnect : String -> HostState -> (HostState, Cmd Msg)
handleDisconnect peerId state =
    let
        updatedPlayers =
            Dict.update peerId
                (\_ -> Just (Disconnected { since = now, peerId = peerId }))
                state.players
    in
    ( { state | players = updatedPlayers }
    , Process.sleep 3000
        |> Task.perform (\_ -> RemoveIfStillDisconnected peerId)
    )

-- On tick, check for expired grace periods:
removeExpiredPlayers : Time.Posix -> HostState -> HostState
removeExpiredPlayers now state =
    { state
    | players =
        Dict.filter
            (\_ playerState ->
                case playerState of
                    Connected _ -> True
                    Disconnected d ->
                        Time.posixToMillis now - Time.posixToMillis d.since < 3000
            )
            state.players
    }
```

**Rationale:** Brief network hiccups shouldn't kick players. 3-second grace period is standard (Warcraft 3 uses 45s, but that's for turn-based; real-time games use 3-10s).

**Source:** [Getgud.io - How to Successfully Create a Reconnect Ability in Multiplayer Games](https://www.getgud.io/blog/how-to-successfully-create-a-reconnect-ability-in-multiplayer-games/)

### Anti-Patterns to Avoid

- **Broadcasting to individual clients in sequence:** Use `connections.forEach(conn => conn.send(msg))` in parallel, not awaited loops. JavaScript DataConnection.send is non-blocking.
- **Snapping positions on corrections:** Causes jarring visual glitches. Always interpolate over 1-3 ticks.
- **Client-derived scores:** Clients must render exactly what host broadcasts. Never compute score locally from events (creates divergence).
- **Unbounded message queues:** If client can't keep up with host ticks, drop old messages rather than buffering indefinitely.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Distinct random colors for players | Color distance algorithms, palette generation | Pre-selected palette with 12+ distinct colors | CIE Lab color space calculations are complex; hand-picked palettes ensure contrast and accessibility |
| Message chunking for large payloads | Custom packet splitting | PeerJS built-in chunking (v1.5+) | WebRTC has 256KB max message size; PeerJS handles chunking/reassembly automatically in binary mode |
| Timestamp synchronization | NTP-style clock sync | Tick-based sequencing | Distributed clock sync is hard; games use logical ticks (host sends tick number, clients don't need wall-clock sync) |
| Input buffering and rate limiting | Custom queue management | Single input buffer (last input wins) | Over-engineering; Snake only needs one queued direction per tick |

**Key insight:** Real-time games solve latency/synchronization with **logical time** (tick numbers) rather than wall-clock time. The host's tick counter is the source of truth. Clients never need to know "what time is it?" – only "what tick is this?"

## Common Pitfalls

### Pitfall 1: Forgetting to Clear Input Buffer on Disconnect/Reconnect
**What goes wrong:** Client disconnects with a buffered direction, reconnects, and immediately sends stale input causing unexpected snake movement.

**Why it happens:** Input buffer is part of local state, persists across connection lifecycle.

**How to avoid:** Clear `pendingInputs` and `inputBuffer` on `GotPeerDisconnected` and `GotPeerConnected` events.

**Warning signs:** Snake moves in wrong direction immediately after reconnecting.

### Pitfall 2: Host Broadcasts Before All Clients Acknowledged Join
**What goes wrong:** Host sends tick updates before client has received `PlayerJoined` and initialized their local state, causing decoder errors or missing player data.

**Why it happens:** Asynchronous connection establishment; host starts broadcasting on `connection.on('open')` but client may not have full state yet.

**How to avoid:** Host sends initial `FullStateSync` message on new player connection before starting delta updates. Client waits for first `FullStateSync` before rendering game.

**Warning signs:** "Decoder failed" errors in client console, blank game board after joining.

### Pitfall 3: JSON Encode/Decode Performance on Every Tick
**What goes wrong:** Encoding 4-8 snakes with 20+ segments each, plus apples, every 100ms causes frame drops.

**Why it happens:** Elm JSON encoding isn't zero-cost; deeply nested structures (List of Snakes with List of Positions) are expensive.

**How to avoid:**
- Keep JSON structure flat (avoid nested objects where possible)
- Consider binary serialization (MessagePack via PeerJS) if profiling shows >10ms encode/decode time
- For Snake game scale (< 10 players, < 100 positions total), JSON is fine; measure before optimizing

**Warning signs:** Profiler shows >5ms in JSON.Encode.encode or JD.decodeValue during tick processing.

### Pitfall 4: Broadcasting to Disconnected Peers Causes Errors
**What goes wrong:** Host tries to send to a DataConnection that's closed, throwing exceptions and potentially crashing the port subscription.

**Why it happens:** PeerJS connection state is asynchronous; connection may close between checking state and sending data.

**How to avoid:** Wrap `conn.send()` in try-catch in JavaScript. Filter `connections` by `conn.open === true` before broadcasting.

**Warning signs:** Console errors "Cannot send data to closed connection", host game loop stops running.

### Pitfall 5: Client Prediction Without Tick Acknowledgment Creates Drift
**What goes wrong:** Client keeps applying inputs indefinitely without knowing which ones the host has processed, eventually diverging wildly.

**Why it happens:** No feedback loop; client doesn't drop processed inputs from queue.

**How to avoid:** Host includes `lastProcessedTick` in delta updates. Client removes inputs with `tick <= lastProcessedTick` from pending queue.

**Warning signs:** Client snake drifts further from authoritative position over time, interpolation can't catch up.

## Code Examples

Verified patterns from official sources and community best practices:

### Elm Port Definitions for Game Messages

```elm
-- Ports.elm additions
port sendGameState : JE.Value -> Cmd msg
port sendInput : JE.Value -> Cmd msg
port receiveGameState : (JD.Value -> msg) -> Sub msg
port receivePlayerInput : (JD.Value -> msg) -> Sub msg
```

### JavaScript Broadcasting to All Peers

```typescript
// peerjs-ports.ts - Host broadcasting
function broadcastToAll(data: any): void {
  connections.forEach((conn, peerId) => {
    if (conn.open) {
      try {
        conn.send(data);
      } catch (err) {
        console.error(`Failed to send to ${peerId}:`, err);
        // Connection may have closed; cleanup will happen on 'close' event
      }
    }
  });
}

// Subscribe to Elm's outgoing game state
app.ports.sendGameState.subscribe((data: any) => {
  broadcastToAll(data);
});

// Forward incoming input from clients to Elm
connections.forEach((conn) => {
  conn.on('data', (data) => {
    if (data.type === 'input') {
      app.ports.receivePlayerInput.send({
        peerId: conn.peer,
        direction: data.direction,
        tick: data.tick,
      });
    }
  });
});
```

### Elm Game State Encoding (Delta Update)

```elm
-- Protocol.elm
type GameMsg
    = DeltaUpdate DeltaData
    | FullStateSync GameState
    | PlayerSpawned { playerId : String, position : Position, color : String }
    | PlayerDied String

type alias DeltaData =
    { tick : Int
    , snakes : List Snake
    , apples : List Apple
    , scores : Dict String Int
    }

encodeDelta : DeltaData -> JE.Value
encodeDelta delta =
    JE.object
        [ ( "type", JE.string "delta" )
        , ( "tick", JE.int delta.tick )
        , ( "snakes", JE.list encodeSnake delta.snakes )
        , ( "apples", JE.list encodeApple delta.apples )
        , ( "scores", encodeScores delta.scores )
        ]

encodeSnake : Snake -> JE.Value
encodeSnake snake =
    JE.object
        [ ( "id", JE.string snake.id )
        , ( "body", JE.list encodePosition snake.body )
        , ( "direction", JE.string (directionToString snake.direction) )
        , ( "color", JE.string snake.color )
        , ( "isInvincible", JE.bool snake.isInvincible )
        , ( "state", JE.string snake.state )
        ]

-- Full state sync (every 50 ticks)
encodeFullState : GameState -> JE.Value
encodeFullState state =
    JE.object
        [ ( "type", JE.string "full_sync" )
        , ( "tick", JE.int state.tick )
        , ( "snakes", JE.list encodeSnake state.snakes )
        , ( "apples", JE.list encodeApple state.apples )
        , ( "scores", encodeScores state.scores )
        , ( "gridWidth", JE.int state.gridWidth )
        , ( "gridHeight", JE.int state.gridHeight )
        ]
```

**Source:** Adapted from [elm-gameroom](https://github.com/peterszerzo/elm-gameroom) encoder/decoder patterns

### Client Input Sending (Last Input Wins)

```elm
-- ClientGame.elm
type alias ClientState =
    { gameState : Maybe GameState
    , myPlayerId : String
    , inputBuffer : Maybe Direction  -- Only store most recent
    , lastSentTick : Int
    }

-- On KeyPressed:
handleInput : Direction -> ClientState -> (ClientState, Cmd Msg)
handleInput dir state =
    ( { state | inputBuffer = Just dir }
    , sendInputToHost state.myPlayerId dir
    )

-- Send to host immediately (optimistic)
sendInputToHost : String -> Direction -> Cmd Msg
sendInputToHost playerId dir =
    Ports.sendInput
        (JE.object
            [ ( "type", JE.string "input" )
            , ( "direction", JE.string (directionToString dir) )
            ]
        )
```

### Linear Interpolation for Smooth Corrections

```elm
-- ClientGame.elm - Visual smoothing
type alias RenderState =
    { snake : Snake
    , displayOffset : Position  -- Visual offset for interpolation
    , interpolationProgress : Float  -- 0.0 to 1.0
    }

-- When host state diverges from prediction:
applyCorrection : Snake -> Snake -> RenderState -> RenderState
applyCorrection predicted authoritative render =
    case (Snake.head predicted, Snake.head authoritative) of
        (Just predHead, Just authHead) ->
            if predHead /= authHead then
                -- Start interpolation from predicted to authoritative
                let
                    offset =
                        { x = predHead.x - authHead.x
                        , y = predHead.y - authHead.y
                        }
                in
                { render
                | snake = authoritative
                , displayOffset = offset
                , interpolationProgress = 0.0
                }
            else
                { render | snake = authoritative }

        _ ->
            { render | snake = authoritative }

-- On render tick (separate from game tick):
updateInterpolation : Float -> RenderState -> RenderState
updateInterpolation deltaTime render =
    if render.interpolationProgress < 1.0 then
        let
            -- Interpolate over 200ms (2 game ticks)
            speed = deltaTime / 200.0
            newProgress = min 1.0 (render.interpolationProgress + speed)

            -- Lerp offset toward zero
            newOffset =
                { x = round (toFloat render.displayOffset.x * (1.0 - newProgress))
                , y = round (toFloat render.displayOffset.y * (1.0 - newProgress))
                }
        in
        { render
        | displayOffset = newOffset
        , interpolationProgress = newProgress
        }
    else
        render

-- In view:
viewSnake : RenderState -> Html msg
viewSnake render =
    let
        visualHead =
            case Snake.head render.snake of
                Just h ->
                    { x = h.x + render.displayOffset.x
                    , y = h.y + render.displayOffset.y
                    }
                Nothing -> { x = 0, y = 0 }
    in
    -- Render with visualHead instead of actual head
    ...
```

**Source:** Interpolation technique from [Gabriel Gambetta - Entity Interpolation](https://www.gabrielgambetta.com/entity-interpolation.html)

### Distinct Color Palette for Players

```elm
-- PlayerColors.elm
distinctColors : List String
distinctColors =
    [ "e74c3c"  -- Red
    , "3498db"  -- Blue
    , "2ecc71"  -- Green
    , "f39c12"  -- Orange
    , "9b59b6"  -- Purple
    , "1abc9c"  -- Turquoise
    , "e91e63"  -- Pink
    , "ff5722"  -- Deep Orange
    , "00bcd4"  -- Cyan
    , "cddc39"  -- Lime
    , "795548"  -- Brown
    , "607d8b"  -- Blue Grey
    ]

assignColor : List String -> String -> String
assignColor usedColors playerId =
    distinctColors
        |> List.filter (\c -> not (List.member c usedColors))
        |> List.head
        |> Maybe.withDefault "67a387"  -- Fallback color
```

**Rationale:** Pre-selected palette from Material Design, ensures sufficient contrast and accessibility. 12 colors support 12 simultaneous players.

**Source:** Color palette based on [Material Design Color System](https://material.io/design/color/the-color-system.html), verified for distinctness in [Mokole Visually Distinct Colors Generator](https://mokole.com/palette.html)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Full state broadcast every tick | Delta updates with periodic full sync | ~2010s (broadband era) | 5-10x bandwidth reduction for large game states |
| TCP sockets (WebSockets) | WebRTC DataChannels (unreliable mode) | 2015+ | Lower latency (no head-of-line blocking), P2P capable |
| Server-authoritative only | Client-side prediction + reconciliation | ~2000s (Quake 3) | Perceived responsiveness despite network latency |
| Kick on disconnect | Grace period with reconnection | 2010s+ | Better UX for mobile/unstable networks |

**Deprecated/outdated:**
- **Phoenix Channels for game loop:** Being replaced with P2P in this phase. Phoenix Channels remain for matchmaking/lobby (Phase 7).
- **Lockstep synchronization:** Requires all clients to advance in lock-step (deterministic simulation). Not suitable for real-time games with variable latency.

## Open Questions

Things that couldn't be fully resolved:

1. **Interpolation duration for corrections**
   - What we know: Typical range is 100-300ms (1-3 game ticks); faster games use shorter durations
   - What's unclear: Optimal value for Snake at 100ms tick rate with typical P2P latency (20-100ms)
   - Recommendation: Start with 200ms (2 ticks) linear interpolation. If corrections are too jarring, increase to 300ms. If too slow, decrease to 100ms. This is a "feel" parameter requiring playtesting.

2. **Handling host crash/disconnect mid-game**
   - What we know: Host migration is deferred to Phase 7; clients will disconnect when host disappears
   - What's unclear: Should clients show "Host disconnected" error or auto-return to lobby?
   - Recommendation: Show error notification for 3 seconds, then reset to P2PNotConnected state (same as manual leave). Phase 7 will implement proper migration.

3. **Maximum simultaneous players before performance degrades**
   - What we know: Star topology scales linearly with player count (N connections for N players from host perspective); typical P2P limit is 8-12 players
   - What's unclear: At what player count does Elm JSON encoding or PeerJS broadcasting become a bottleneck?
   - Recommendation: No enforced limit in this phase. Monitor performance; if >8 players causes lag, Phase 7 can add limit.

4. **Collision animation timing with state synchronization**
   - What we know: User wants "shake/bump + teeth scatter" effect on collision
   - What's unclear: Should animation trigger on client-side collision detection (immediate but might be wrong) or wait for host confirmation (correct but delayed)?
   - Recommendation: Trigger animation optimistically on client-side collision, cancel if host state shows no collision. Animation duration should match grace period for correction (200ms).

## Sources

### Primary (HIGH confidence)
- [Gaffer On Games - State Synchronization](https://gafferongames.com/post/state_synchronization/) - Authoritative guide to delta vs full state sync
- [Gabriel Gambetta - Client-Side Prediction and Server Reconciliation](https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html) - Definitive explanation of prediction patterns
- [MDN - WebRTC data channels](https://developer.mozilla.org/en-US/docs/Games/Techniques/WebRTC_data_channels) - Official WebRTC documentation for games
- [PeerJS Documentation](https://peerjs.com/docs/) - Official API reference for data channels

### Secondary (MEDIUM confidence)
- [Medium - How I Made a Multiplayer Snake Game](https://medium.com/weekly-webtips/how-i-made-a-multiplayer-snake-game-6d59956c5acf) - Real-world Snake multiplayer implementation
- [GitHub - ouroboros](https://github.com/ouroboros-team/ouroboros) - P2P snake game exploring WebRTC challenges
- [GitHub - elm-gameroom](https://github.com/peterszerzo/elm-gameroom) - Elm multiplayer framework with encoder/decoder patterns
- [Getgud.io - Reconnect Ability in Multiplayer Games](https://www.getgud.io/blog/how-to-successfully-create-a-reconnect-ability-in-multiplayer-games/) - Grace period best practices
- [WebRTC Hacks - Peer-to-peer gaming with DataChannel](https://webrtchacks.com/datachannel-multiplayer-game/) - Technical deep-dive on WebRTC for games

### Tertiary (LOW confidence - WebSearch only)
- [GitHub - netplayjs](https://github.com/rameshvarun/netplayjs) - Framework using rollback netcode (different architecture than chosen approach)
- [Photon Engine - Interpolation vs Extrapolation](https://doc.photonengine.com/bolt/current/in-depth/interpolation-vs-extrapolation) - Unity-specific but concepts apply
- [CRDT-Based Game State Synchronization in P2P VR](https://arxiv.org/html/2503.17826) - Academic research, too complex for this scope

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - PeerJS and Elm JSON are proven, already integrated
- Architecture: MEDIUM - Patterns well-established but Elm implementation less documented
- Pitfalls: MEDIUM - Based on general game dev experience + some Elm-specific knowledge
- Code examples: MEDIUM - Patterns verified from sources but not tested in this specific codebase

**Research date:** 2026-02-03
**Valid until:** ~2026-03-03 (30 days - stable domain, patterns unlikely to change)

**Research constraints from CONTEXT.md:**
- User locked: Delta-based state sync, full sync every 50 ticks, optimistic local input, smooth interpolation, 3s disconnect grace period
- Claude's discretion: Exact interpolation algorithm (recommended linear over 2 ticks), color palette (provided 12-color Material Design palette), notification styling, teeth-scatter animation specifics
