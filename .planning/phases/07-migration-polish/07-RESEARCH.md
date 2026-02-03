# Phase 7: Migration & Polish - Research

**Researched:** 2026-02-03
**Domain:** P2P host migration, room sharing (URLs/QR codes), mode selection, and reconnection handling
**Confidence:** MEDIUM

## Summary

This phase adds production-ready polish to the P2P multiplayer implementation: seamless host migration when the current host disconnects, room sharing through URL links and QR codes, mode selection between P2P and Phoenix at startup, and reconnection support for temporarily disconnected players. The research covers leader election algorithms for distributed systems, QR code generation libraries, Web Share API patterns, clipboard operations, and state preservation during connection lifecycle events.

The standard approach for host migration in P2P games is **deterministic leader election** using a simple algorithm like "lowest peer ID wins." When the host disconnects, all remaining peers independently calculate who should be the new host (the peer with the lexicographically smallest ID), and that peer transitions from client to host mode, inheriting the current game state. This avoids complex consensus protocols while ensuring all peers agree on the new host.

For room sharing, modern web apps use the **Clipboard API** (navigator.clipboard.writeText) for copy operations, the **Web Share API** (navigator.share) for native sharing on mobile, and dedicated QR code libraries like **qrcode** (npm) for generating scannable codes. QR codes should encode the full game URL (e.g., https://snaker.example.com/join/ABCD) rather than just the room code, enabling one-tap join from mobile devices.

**Primary recommendation:** Use lowest-ID election for host migration, qrcode@1.5.5 npm library for QR generation, Clipboard API with fallback for older browsers, localStorage for remembering mode preference, and preserve disconnected player snakes with visual fade (opacity: 0.5) until they die from collision.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| qrcode | 1.5.5 | Generate QR code images | 16k+ GitHub stars, supports canvas and data URL output, works in browser and Node |
| Clipboard API | (browser) | Copy text to clipboard | Modern standard, replaces deprecated execCommand, requires HTTPS |
| Web Share API | (browser) | Native share on mobile | W3C standard, progressive enhancement for mobile devices |
| localStorage | (browser) | Persist mode preference | Standard web storage, 5MB quota, synchronous API |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Elm Process/Task | core | Delayed commands | Fade orphaned snakes, timeout reconnection grace period |
| Elm Json.Encode/Decode | core | Port data serialization | All port communication with JS QR/clipboard code |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| qrcode | qrcodejs or qr-creator | qrcodejs is older (no canvas support), qr-creator is smaller but less mature |
| Lowest-ID election | Bully algorithm (highest ID) or Raft consensus | Bully requires more messages, Raft is overkill for simple games |
| Clipboard API | document.execCommand('copy') | execCommand is deprecated since 2020, doesn't work in modern browsers |
| localStorage | sessionStorage or IndexedDB | sessionStorage clears on tab close, IndexedDB is async and complex |

**Installation:**
```bash
npm install qrcode@1.5.5
```

## Architecture Patterns

### Recommended Project Structure
```
assets/
├── elm/
│   ├── Main.elm                    # Add mode selection state, host indicator
│   ├── Multiplayer/
│   │   ├── HostMigration.elm       # NEW: Election logic, state transition
│   │   ├── Reconnection.elm        # NEW: Grace period, orphan handling
│   │   └── Protocol.elm            # Extend with migration messages
│   └── View/
│       ├── ModeSelection.elm       # NEW: P2P vs Phoenix choice screen
│       └── ShareUI.elm             # NEW: Copy buttons, QR code display
├── js/
│   ├── qr-generator.js             # NEW: QR code generation via ports
│   ├── clipboard.js                # NEW: Clipboard API wrapper
│   └── peerjs-ports.js             # Extend with migration events
└── package.json                    # Add qrcode dependency
```

### Pattern 1: Deterministic Host Election (Lowest ID)

**What:** When host disconnects, all peers independently calculate the new host by sorting peer IDs and selecting the lowest. No voting or consensus needed.

**When to use:** Small player counts (2-8), trusted environment, all peers know the full peer list.

**Example:**
```elm
-- Election logic (runs on all peers when host disconnects)
type alias PeerList = List { id : String, role : Role }

electNewHost : String -> PeerList -> Maybe String
electNewHost disconnectedHostId peers =
    peers
        |> List.filter (\p -> p.id /= disconnectedHostId)
        |> List.map .id
        |> List.sort  -- Alphabetical/lexicographic order
        |> List.head  -- Lowest ID

-- In update function:
GotPeerDisconnected peerId ->
    case model.connectionState of
        Connected { role = Client, peers } ->
            case electNewHost peerId peers of
                Just newHostId ->
                    if newHostId == model.myPeerId then
                        -- I am the new host!
                        ( { model
                          | connectionState = Connected { role = Host, peers = ... }
                          , gameState = model.lastKnownGameState
                          }
                        , Cmd.none
                        )
                    else
                        -- Someone else is host
                        ( { model | expectedHostId = newHostId }
                        , Cmd.none
                        )

                Nothing ->
                    -- No peers left, show "Connection lost" screen
                    ( { model | connectionState = NotConnected }
                    , Cmd.none
                    )

        Connected { role = Host } ->
            -- I'm host, just remove disconnected peer
            ( { model | peers = List.filter (\p -> p.id /= peerId) }
            , Cmd.none
            )
```

**Source:** Adapted from [Leader Election in Distributed Systems](https://www.enjoyalgorithms.com/blog/leader-election-system-design/) and [Viewstamped Replication](https://en.wikipedia.org/wiki/Leader_election)

### Pattern 2: QR Code Generation via Elm Ports

**What:** Generate QR code image data URL in JavaScript, pass to Elm for display.

**When to use:** Room sharing, mobile scanning.

**Example:**
```elm
-- Elm ports
port generateQRCode : String -> Cmd msg  -- Outgoing: URL to encode
port qrCodeGenerated : (String -> msg) -> Sub msg  -- Incoming: data URL

-- JavaScript (qr-generator.js)
import QRCode from 'qrcode';

app.ports.generateQRCode.subscribe(async (url) => {
  try {
    const dataUrl = await QRCode.toDataURL(url, {
      width: 200,
      margin: 2,
      color: {
        dark: '#000000',
        light: '#FFFFFF'
      }
    });
    app.ports.qrCodeGenerated.send(dataUrl);
  } catch (err) {
    console.error('QR generation failed:', err);
  }
});

-- Elm view
viewQRCode : String -> Html Msg
viewQRCode dataUrl =
    img
        [ src dataUrl
        , alt "Room QR Code"
        , style "width" "200px"
        , style "height" "200px"
        ]
        []
```

**Source:** [qrcode npm documentation](https://github.com/soldair/node-qrcode) and [QRCode Browser Usage](https://qr-platform.github.io/qr-code.js/docs/usage-guide.html)

### Pattern 3: Clipboard Copy with Visual Feedback

**What:** Copy text to clipboard using modern API, show "Copied!" feedback by changing button text temporarily.

**When to use:** Copy room code, copy room URL.

**Example:**
```elm
-- Elm model
type alias Model =
    { copyButtonState : CopyButtonState
    }

type CopyButtonState
    = Ready
    | Copied

-- Elm update
CopyRoomCode code ->
    ( { model | copyButtonState = Copied }
    , Cmd.batch
        [ copyToClipboard code
        , Process.sleep 2000 |> Task.perform (\_ -> ResetCopyButton)
        ]
    )

ResetCopyButton ->
    ( { model | copyButtonState = Ready }, Cmd.none )

-- Elm view
viewCopyButton : CopyButtonState -> String -> Html Msg
viewCopyButton state code =
    button
        [ onClick (CopyRoomCode code)
        , disabled (state == Copied)
        ]
        [ text
            (case state of
                Ready -> "Copy Code"
                Copied -> "Copied!"
            )
        ]

-- JavaScript (clipboard.js)
app.ports.copyToClipboard.subscribe(async (text) => {
  try {
    await navigator.clipboard.writeText(text);
  } catch (err) {
    // Fallback for older browsers or non-HTTPS
    const textarea = document.createElement('textarea');
    textarea.value = text;
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    document.body.removeChild(textarea);
  }
});
```

**Source:** [Clipboard API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API) and [Copy to Clipboard Best Practices](https://web.dev/patterns/clipboard/copy-text)

### Pattern 4: Mode Selection with localStorage Persistence

**What:** Show mode selection screen on first visit, remember choice in localStorage, skip screen on subsequent visits.

**When to use:** Startup screen, settings screen.

**Example:**
```elm
-- Elm flags (read on init)
type alias Flags =
    { savedMode : Maybe String  -- "p2p" | "phoenix" | null
    }

init : Flags -> (Model, Cmd Msg)
init flags =
    case flags.savedMode of
        Just "p2p" ->
            -- Skip mode selection, go straight to P2P UI
            ( { model | mode = P2PMode }, Cmd.none )

        Just "phoenix" ->
            -- Skip mode selection, go straight to Phoenix UI
            ( { model | mode = PhoenixMode }, Cmd.none )

        _ ->
            -- Show mode selection screen
            ( { model | screen = ModeSelectionScreen }, Cmd.none )

-- Elm port (save mode choice)
port saveMode : String -> Cmd msg

-- JavaScript (app.js)
// Read saved mode on startup
const savedMode = localStorage.getItem('snaker-mode');
const app = Elm.Main.init({
  flags: { savedMode: savedMode }
});

// Save mode choice
app.ports.saveMode.subscribe((mode) => {
  localStorage.setItem('snaker-mode', mode);
});
```

**Source:** [localStorage Best Practices](https://rxdb.info/articles/localstorage.html) and [Elm Flags Pattern](https://guide.elm-lang.org/interop/flags.html)

### Pattern 5: Orphaned Snake with Visual Fade

**What:** When player disconnects, their snake continues moving straight with reduced opacity until it collides.

**When to use:** Reconnection grace period, visual indicator of disconnection.

**Example:**
```elm
type alias Snake =
    { id : String
    , body : List Position
    , direction : Direction
    , state : SnakeState
    }

type SnakeState
    = Active
    | Orphaned { since : Time.Posix }
    | Dead

-- On disconnect
GotPeerDisconnected peerId ->
    let
        updatedSnakes =
            List.map
                (\snake ->
                    if snake.id == peerId then
                        { snake | state = Orphaned { since = model.currentTime } }
                    else
                        snake
                )
                model.snakes
    in
    ( { model | snakes = updatedSnakes }, Cmd.none )

-- On game tick (host only)
updateSnakes : List Snake -> List Snake
updateSnakes snakes =
    List.map
        (\snake ->
            case snake.state of
                Orphaned _ ->
                    -- Continue moving in last direction
                    moveSnake snake snake.direction

                Active ->
                    -- Normal movement with input
                    moveSnake snake (getPlayerInput snake.id)

                Dead ->
                    snake
        )
        snakes

-- View with fade
viewSnake : Snake -> Svg Msg
viewSnake snake =
    let
        opacity =
            case snake.state of
                Orphaned _ -> "0.5"  -- 50% transparent
                _ -> "1.0"
    in
    g [ Svg.Attributes.opacity opacity ]
        [ -- render snake body
        ]
```

**Source:** [Coherence Authority Documentation](https://docs.coherence.io/manual/authority) and user decision from CONTEXT.md

### Pattern 6: Reconnection with State Resume

**What:** When player reconnects within grace period, restore their snake if still alive.

**When to use:** Player closes tab, loses wifi, mobile app backgrounded.

**Example:**
```elm
-- Host tracks disconnected players
type alias HostState =
    { snakes : List Snake
    , disconnectedPlayers : Dict String DisconnectionInfo
    }

type alias DisconnectionInfo =
    { peerId : String
    , snakeId : String
    , disconnectedAt : Time.Posix
    }

-- On reconnection (host side)
GotPeerReconnected peerId ->
    case Dict.get peerId model.disconnectedPlayers of
        Just info ->
            case findSnake info.snakeId model.snakes of
                Just snake ->
                    if snake.state == Dead then
                        -- Snake died while disconnected, spawn new one
                        ( model, spawnNewSnake peerId )
                    else
                        -- Restore snake, mark as active
                        let
                            updatedSnakes =
                                List.map
                                    (\s ->
                                        if s.id == info.snakeId then
                                            { s | state = Active }
                                        else
                                            s
                                    )
                                    model.snakes
                        in
                        ( { model
                          | snakes = updatedSnakes
                          , disconnectedPlayers = Dict.remove peerId model.disconnectedPlayers
                          }
                        , sendFullStateSync peerId
                        )

                Nothing ->
                    -- Snake was removed, spawn new
                    ( model, spawnNewSnake peerId )

        Nothing ->
            -- New player joining
            ( model, handleNewPlayer peerId )
```

**Source:** [WebRTC Reconnection Mechanisms](https://webrtc.ventures/2023/06/implementing-a-reconnection-mechanism-for-webrtc-mobile-applications/) and user decision from CONTEXT.md

### Anti-Patterns to Avoid

- **Complex consensus protocols:** Raft/Paxos are overkill for 2-8 player games. Deterministic election is simpler and faster.
- **Removing orphaned snakes immediately:** Preserve them for visual continuity and reconnection support.
- **QR codes with only room code:** Encode full URL for one-tap join from mobile.
- **Blocking mode selection:** Allow changing mode in settings, don't lock users into first choice.
- **Synchronous localStorage in critical path:** Read in flags at init, write asynchronously after mode selection.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| QR code generation | Custom canvas drawing with error correction | qrcode npm library | QR codes have complex error correction (Reed-Solomon), version/mask selection, and encoding modes. Library handles all edge cases. |
| Leader election algorithm | Custom voting/heartbeat protocol | Deterministic selection (lowest ID) | Voting requires multiple network round-trips and timeout tuning. Lowest-ID is instant and deterministic. |
| Clipboard copy | Manual textarea creation and selection | Clipboard API with execCommand fallback | Clipboard API is standard, handles permissions, and works across browsers. Only fall back for old browsers. |
| URL parsing for room code | String splitting and regex | URL API (new URL()) | URL API handles edge cases like query params, ports, special characters. |
| Visual "Copied!" feedback | Custom tooltip positioning and animations | Button text change with CSS transition | User decision specifies "button text changes" - simplest solution, no positioning bugs. |

**Key insight:** Host migration is the hardest part of P2P games. Using deterministic election (lowest ID) avoids the complexity of distributed consensus while guaranteeing all peers agree on the new host. This only works when all peers have the full peer list, which is true in star topology.

## Common Pitfalls

### Pitfall 1: Race Condition During Host Migration

**What goes wrong:** Old host sends final state update at same moment new host starts sending updates, clients receive conflicting game states.

**Why it happens:** WebRTC connections don't close instantly. Disconnection detection has latency (1-3 seconds).

**How to avoid:**
- Include sender peer ID in all game state messages
- Clients only accept state from expected host ID
- When host changes, clients discard messages from old host after election
- New host waits 500ms before sending first update (let old messages flush)

**Warning signs:** Game state "jumps back" after host migration, clients diverge from new host.

### Pitfall 2: Split Brain - Multiple Hosts Elected

**What goes wrong:** Network partition causes two subgroups to elect different hosts, game state diverges.

**Why it happens:** In P2P star topology, if host disconnects but some clients can still reach each other, they might elect different new hosts.

**How to avoid:**
- In star topology, clients ONLY connect to host (not to each other)
- When host disconnects, all clients lose connection simultaneously
- No split brain possible in pure star topology
- If implementing mesh (deferred to future), use host ID as tie-breaker

**Warning signs:** After migration, two clients report different host IDs.

### Pitfall 3: QR Code Generation Blocking Main Thread

**What goes wrong:** Generating large QR codes (high error correction, large data) blocks UI for 100-500ms.

**Why it happens:** Canvas operations and error correction calculations are CPU-intensive and synchronous.

**How to avoid:**
- Generate QR code once when room is created, cache data URL in model
- Use error correction level 'M' (15% correction) not 'H' (30%) for URLs
- Generate in Web Worker if generating many codes (not needed for single room code)
- For this phase: single QR per room, cache on creation, display multiple times - no performance issue

**Warning signs:** UI freezes when opening share panel, janky scrolling near QR code.

### Pitfall 4: localStorage Quota Exceeded

**What goes wrong:** Writing to localStorage throws QuotaExceededError, mode preference not saved.

**Why it happens:** 5MB quota shared across origin, other apps/tabs using same domain fill quota.

**How to avoid:**
- Catch and log errors when writing to localStorage
- Fall back gracefully (show mode selection on next visit)
- For mode preference: "p2p" or "phoenix" is <10 bytes, never hits quota
- Don't store game state or large data in localStorage

**Warning signs:** Users report mode selection appears every visit despite selecting a mode.

### Pitfall 5: Orphaned Snake Collision Detection Edge Case

**What goes wrong:** Orphaned snake collides with wall/itself, but host doesn't mark it dead, snake phases through obstacles.

**Why it happens:** Collision detection code checks for Active state only, skips Orphaned snakes.

**How to avoid:**
- Run collision detection for ALL snakes (Active, Orphaned, not Dead)
- Orphaned snakes die on collision just like Active snakes
- Only visual difference is opacity, gameplay is identical
- State transition: Orphaned → Dead (on collision)

**Warning signs:** Disconnected player's snake passes through walls, doesn't die on self-collision.

### Pitfall 6: Web Share API Not Available (Desktop Browsers)

**What goes wrong:** Calling navigator.share() throws TypeError on desktop Chrome/Firefox.

**Why it happens:** Web Share API is only available on mobile browsers and requires user activation (button click).

**How to avoid:**
- Check `navigator.share !== undefined` before calling
- Provide fallback: copy to clipboard instead
- Or hide "Share" button on desktop, show only on mobile
- User decision: all three options visible (copy code, copy URL, QR) - share is bonus

**Warning signs:** Console error "navigator.share is not a function" on desktop.

## Code Examples

Verified patterns from official sources and community best practices:

### Host Migration State Machine

```elm
-- Protocol.elm - Migration messages
type GameMsg
    = -- ... existing messages
    | HostMigrated { newHostId : String, tick : Int }
    | HostHandoff { fromId : String, toId : String, gameState : GameState }

-- HostMigration.elm
type alias MigrationState =
    { previousHostId : Maybe String
    , electionInProgress : Bool
    , newHostId : Maybe String
    }

handleHostDisconnection : String -> List Peer -> Model -> (Model, Cmd Msg)
handleHostDisconnection disconnectedHostId peers model =
    let
        newHostId =
            peers
                |> List.filter (\p -> p.id /= disconnectedHostId)
                |> List.sortBy .id
                |> List.head
                |> Maybe.map .id
    in
    case newHostId of
        Just hostId ->
            if hostId == model.myPeerId then
                -- I am the new host
                transitionToHost model
            else
                -- Wait for new host to start broadcasting
                ( { model
                  | expectedHostId = hostId
                  , migrationState = { previousHostId = Just disconnectedHostId
                                     , electionInProgress = True
                                     , newHostId = Just hostId
                                     }
                  }
                , Cmd.none
                )

        Nothing ->
            -- Game over, no peers left
            showConnectionLostScreen model

transitionToHost : Model -> (Model, Cmd Msg)
transitionToHost model =
    ( { model
      | role = Host
      , gameState = model.lastReceivedGameState  -- Inherit state
      , migrationState = { previousHostId = Nothing
                         , electionInProgress = False
                         , newHostId = Just model.myPeerId
                         }
      }
    , Cmd.batch
        [ startGameLoop  -- Begin ticking
        , broadcastToAllPeers (HostMigrated { newHostId = model.myPeerId, tick = model.lastReceivedGameState.tick })
        ]
    )
```

### Room URL Sharing with Web Share API

```javascript
// clipboard.js
app.ports.shareRoom.subscribe(async ({ code, url }) => {
  // Try native share API first (mobile)
  if (navigator.share) {
    try {
      await navigator.share({
        title: 'Join my Snaker game!',
        text: `Room code: ${code}`,
        url: url
      });
      app.ports.shareComplete.send({ method: 'native' });
    } catch (err) {
      // User cancelled or share failed
      if (err.name !== 'AbortError') {
        console.error('Share failed:', err);
      }
    }
  } else {
    // Fallback to clipboard
    try {
      await navigator.clipboard.writeText(url);
      app.ports.shareComplete.send({ method: 'clipboard' });
    } catch (err) {
      console.error('Clipboard write failed:', err);
    }
  }
});
```

**Source:** [Web Share API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Share_API) and [Navigator.share() - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/share)

### QR Code Generation with Error Handling

```javascript
// qr-generator.js
import QRCode from 'qrcode';

app.ports.generateQRCode.subscribe(async (url) => {
  try {
    const dataUrl = await QRCode.toDataURL(url, {
      width: 256,
      margin: 2,
      errorCorrectionLevel: 'M',  // Medium (15% correction)
      color: {
        dark: '#000000',
        light: '#FFFFFF'
      }
    });
    app.ports.qrCodeGenerated.send({ success: true, dataUrl: dataUrl });
  } catch (err) {
    console.error('QR generation failed:', err);
    app.ports.qrCodeGenerated.send({ success: false, error: err.message });
  }
});
```

**Source:** [qrcode npm - toDataURL API](https://github.com/soldair/node-qrcode#todataurltext-options-cberr-url)

### Mode Selection with Settings Override

```elm
-- ModeSelection.elm
type alias Model =
    { savedMode : Maybe Mode
    , currentScreen : Screen
    }

type Mode = P2PMode | PhoenixMode

type Screen
    = ModeSelectionScreen
    | GameScreen Mode
    | SettingsScreen

init : Flags -> (Model, Cmd Msg)
init flags =
    let
        screen =
            case flags.savedMode of
                Just mode ->
                    GameScreen mode  -- Skip selection, go straight to game

                Nothing ->
                    ModeSelectionScreen  -- First time, show selection
    in
    ( { savedMode = flags.savedMode
      , currentScreen = screen
      }
    , Cmd.none
    )

-- User can change mode in settings
type Msg
    = SelectMode Mode
    | ChangeMode Mode  -- From settings screen
    | OpenSettings

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        SelectMode mode ->
            ( { model | currentScreen = GameScreen mode, savedMode = Just mode }
            , saveMode (modeToString mode)  -- Port to localStorage
            )

        ChangeMode mode ->
            ( { model | currentScreen = GameScreen mode, savedMode = Just mode }
            , saveMode (modeToString mode)
            )

        OpenSettings ->
            ( { model | currentScreen = SettingsScreen }
            , Cmd.none
            )

-- View
viewModeSelection : Html Msg
viewModeSelection =
    div []
        [ h1 [] [ text "Choose your mode" ]
        , button
            [ onClick (SelectMode P2PMode)
            , class "mode-button-primary"  -- Larger, primary styling
            ]
            [ text "Direct Connect (P2P)" ]  -- User-friendly name
        , button
            [ onClick (SelectMode PhoenixMode)
            , class "mode-button-secondary"  -- Smaller, secondary styling
            ]
            [ text "Classic Online (Server)" ]
        ]
```

**Source:** User decision from CONTEXT.md

### Host Indicator SVG Icon

```elm
-- View.elm - Small crown icon next to host's snake
viewSnakeWithIndicator : Bool -> Snake -> Svg Msg
viewSnakeWithIndicator isHost snake =
    g []
        [ viewSnake snake  -- Normal snake rendering
        , if isHost then
            viewHostIndicator (getSnakeHeadPosition snake)
          else
            Svg.text ""
        ]

viewHostIndicator : Position -> Svg Msg
viewHostIndicator headPos =
    -- Small crown icon positioned near snake head
    Svg.g
        [ Svg.Attributes.transform
            ("translate(" ++ String.fromInt (headPos.x + 10) ++ "," ++ String.fromInt (headPos.y - 10) ++ ")")
        ]
        [ Svg.path
            [ Svg.Attributes.d "M 0 10 L 5 0 L 10 10 L 8 6 L 5 8 L 2 6 Z"  -- Crown shape
            , Svg.Attributes.fill "#FFD700"  -- Gold color
            , Svg.Attributes.stroke "#000000"
            , Svg.Attributes.strokeWidth "0.5"
            ]
            []
        ]
```

**Source:** User decision from CONTEXT.md (Claude's discretion on exact design)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| document.execCommand('copy') | Clipboard API (navigator.clipboard) | 2020+ (deprecated in 2020) | Better permissions model, async API, works in modern browsers |
| Custom QR libraries | qrcode npm with canvas support | 2018+ | Unified API for browser/Node, smaller bundle size, better error correction |
| Bully algorithm (highest ID) | Deterministic selection (lowest ID) | Always valid | Fewer messages, no timeout tuning, instant consensus |
| Kick player on disconnect | Grace period with orphaned state | 2015+ (mobile era) | Better UX for unstable networks, allows reconnection |
| Session-only mode preference | localStorage persistence with override | 2010+ (HTML5 storage) | Improved UX, one-time choice, can change in settings |

**Deprecated/outdated:**
- **document.execCommand('copy'):** Officially deprecated 2020, use Clipboard API
- **Synchronous QR generation blocking UI:** Modern pattern uses async/await with error handling
- **Host migration via voting:** Overkill for small P2P games, deterministic election is standard

## Open Questions

Things that couldn't be fully resolved:

1. **Host migration latency perception**
   - What we know: Deterministic election is instant (no network round-trips), but new host must load game state and start broadcasting
   - What's unclear: Will the ~500ms transition feel seamless or will players notice a hiccup?
   - Recommendation: User decision is "seamless takeover, game barely hiccups" - implement 500ms delay before new host broadcasts, test for perceptible lag. If noticeable, reduce to 200ms.

2. **QR code size vs scannability**
   - What we know: User specifies "medium size" but exact pixels unclear. QR code libraries recommend 200-300px for reliable scanning.
   - What's unclear: What is "medium" in the context of the UI layout?
   - Recommendation: Start with 256px square (2x typical minimum 128px), test on mobile devices. Ensure 2-cell margin for reliable scanning.

3. **Mode names: "Direct Connect" vs other options**
   - What we know: User wants user-friendly naming like "Direct Connect" or "Classic Online"
   - What's unclear: Which specific names resonate best with players?
   - Recommendation: User suggested "Direct Connect" for P2P and "Classic Online" for Phoenix. These are clear and approachable. Use these unless user testing suggests confusion.

4. **Reconnection grace period duration**
   - What we know: Phase 6 research recommended 3 seconds for disconnect grace period
   - What's unclear: Should reconnection have a longer grace period (30s, 60s) since user explicitly wants reconnection support?
   - Recommendation: Orphaned snakes stay until death (no timeout per user decision). Reconnection window is unlimited as long as snake is alive. Simple and aligned with user intent.

5. **Migration failure scenarios**
   - What we know: User decision is "show Connection lost game over screen when migration fails completely"
   - What's unclear: What constitutes "fails completely"? No peers left? New host can't start broadcasting?
   - Recommendation: Migration fails if (1) no peers remain after election, OR (2) new host doesn't broadcast within 5 seconds (network issue). Show "Connection lost" with "Create New Room" and "Go Home" buttons.

## Sources

### Primary (HIGH confidence)
- [Clipboard API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API) - Official W3C API documentation
- [Web Share API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Share_API) - Official W3C API documentation
- [qrcode npm - GitHub](https://github.com/soldair/node-qrcode) - Official library documentation
- [Leader Election - Wikipedia](https://en.wikipedia.org/wiki/Leader_election) - Foundational algorithms
- [localStorage - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage) - Official storage API docs

### Secondary (MEDIUM confidence)
- [Leader Election in Distributed Systems](https://www.enjoyalgorithms.com/blog/leader-election-system-design/) - Algorithm explanations
- [Host Migration in P2P Games - Edgegap Blog](https://edgegap.com/blog/host-migration-in-peer-to-peer-or-relay-based-multiplayer-games) - Industry best practices
- [WebRTC Reconnection Mechanisms](https://webrtc.ventures/2023/06/implementing-a-reconnection-mechanism-for-webrtc-mobile-applications/) - Reconnection patterns
- [Coherence Authority Documentation](https://docs.coherence.io/manual/authority) - Orphaned entity handling
- [Using localStorage - RxDB](https://rxdb.info/articles/localstorage.html) - Best practices for web storage

### Tertiary (LOW confidence - WebSearch only)
- [PlayPeerJS - GitHub](https://github.com/therealPaulPlay/PlayPeerJS) - PeerJS wrapper with host migration (not using, but confirms pattern)
- [Copy Button UI Patterns - Modern UI](https://modern-ui.org/docs/components/copy-button) - Visual feedback examples
- Various WebSearch results on P2P consensus algorithms (academic, not practical for games)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - qrcode, Clipboard API, Web Share API, localStorage all well-documented and stable
- Architecture: MEDIUM - Deterministic election is standard but Elm-specific implementation less documented
- Pitfalls: MEDIUM - Based on general distributed systems knowledge + Web API quirks
- Code examples: MEDIUM - Patterns verified from sources but not tested in this specific codebase

**Research date:** 2026-02-03
**Valid until:** ~2026-03-03 (30 days - stable domain, browser APIs unlikely to change)

**Research constraints from CONTEXT.md:**
- User locked: Seamless host migration (no notification), connection lost screen on failure, all three share options (copy/URL/QR), QR always visible inline, copy feedback via button text, mode selection on startup, P2P primary/Phoenix secondary, remember last mode, reconnection with snake resume, orphaned snakes continue straight with fade, no timeout on snake preservation
- Claude's discretion: Exact host indicator design (crown vs star), specific mode names (using "Direct Connect"/"Classic Online"), QR code exact sizing (using 256px), settings UI for changing mode preference
