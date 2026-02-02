# Phase 5: P2P Connection Layer - Research

**Researched:** 2026-02-03
**Domain:** WebRTC P2P connections with PeerJS and Elm ports
**Confidence:** MEDIUM

## Summary

This phase implements peer-to-peer connection infrastructure using PeerJS (a WebRTC wrapper) integrated with Elm via ports. The pattern follows the existing port architecture in the codebase (Phoenix WebSocket ports) but adapts it for P2P data channels. The user has specified a room code-based connection flow (4-character alphanumeric codes, letters only A-Z) with specific UI requirements: inline Create/Join buttons, auto-uppercase input, auto-connect after 4 characters, and toast notifications for errors.

PeerJS 1.5.5 is the current stable version, providing a simplified WebRTC API. The library handles WebRTC complexity (ICE negotiation, data channels, signaling server) while exposing a clean event-based API perfect for Elm ports. The connection pattern is "host-authoritative star topology" (already decided in STATE.md) where the host peer creates a room with their peer ID as the room code, and clients connect directly to the host's peer ID.

**Key architectural insight:** Room codes ARE the host's PeerJS peer ID. No separate signaling or room management server is needed - PeerJS's cloud signaling server (peerjs.com) handles peer discovery. A 4-letter code translates to a PeerJS peer ID format, making "joining room ABCD" equivalent to "connect to peer ABCD."

**Primary recommendation:** Use PeerJS 1.5.5 via npm, implement bidirectional ports (Elm -> JS commands, JS -> Elm events), handle all connection state in Elm model, and use Process.sleep + Task.perform for 5-second toast auto-dismiss (pattern already exists in Main.elm for player join notifications).

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PeerJS | 1.5.5 | WebRTC wrapper with signaling | Industry standard for simple P2P, free cloud signaling, 12k+ GitHub stars |
| Elm ports | 0.19 | JS interop | Only way to integrate JS libraries in Elm, existing pattern in codebase |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Elm Process/Task | core 5.1.1 | Delayed commands | Toast auto-dismiss timing (existing pattern in Main.elm line 248) |
| Elm Json.Encode/Decode | core 5.1.1 | Port data serialization | All port communication requires JSON encoding/decoding |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| PeerJS | simple-peer | Lower-level, no built-in signaling server, more complex |
| PeerJS | Native WebRTC | 10x more code, manual ICE/STUN/signaling, not worth complexity |
| Cloud signaling | Self-hosted PeerServer | Deferred per STATE.md decision, adds ops burden |

**Installation:**
```bash
npm install peerjs@1.5.5
```

## Architecture Patterns

### Recommended Project Structure
```
assets/
├── src/
│   ├── Ports.elm                    # Add P2P ports to existing port module
│   ├── Main.elm                     # Add connection UI state to Model
│   └── View/
│       └── ConnectionUI.elm         # NEW: Create/Join UI component
├── js/
│   ├── app.js                       # Existing entry point
│   └── peerjs-ports.js              # NEW: PeerJS port handlers
└── package.json                     # Add peerjs dependency
```

### Pattern 1: Room Code as Peer ID
**What:** The 4-letter room code IS the host's PeerJS peer ID. No separate room management.
**When to use:** Always for this phase (host-authoritative topology).
**How it works:**
- Host creates peer with ID "ABCD" (generated or chosen)
- Host displays "ABCD" as room code
- Client enters "ABCD" and calls `peer.connect("ABCD")`
- PeerJS cloud server brokers the connection

**Example:**
```javascript
// Host side
const hostPeer = new Peer("ABCD", {
  host: 'peerjs.com',
  secure: true
});

// Client side
const clientPeer = new Peer(); // Random ID
const conn = clientPeer.connect("ABCD"); // Connect to host
```

### Pattern 2: Bidirectional Elm Ports
**What:** Commands flow Elm -> JS (create room, join room, send data), Events flow JS -> Elm (connected, disconnected, data received, errors).
**When to use:** All P2P interactions.
**Follows existing pattern:** See assets/src/Ports.elm lines 1-44 for Phoenix WebSocket ports.

**Example:**
```elm
-- Outgoing (Elm -> JS)
port createRoom : JE.Value -> Cmd msg
port joinRoom : String -> Cmd msg
port leaveRoom : () -> Cmd msg

-- Incoming (JS -> Elm)
port roomCreated : (String -> msg) -> Sub msg
port peerConnected : (JD.Value -> msg) -> Sub msg
port peerDisconnected : (String -> msg) -> Sub msg
port connectionError : (String -> msg) -> Sub msg
```

### Pattern 3: Connection State Machine
**What:** Track connection lifecycle in Elm model with explicit states.
**States:** `NotConnected` | `Creating` | `Joining String` | `Connected { role: Host | Client, roomCode: String }`
**Why:** User requirements specify different UI for each state (Create/Join buttons -> spinner -> connected status).

**Example:**
```elm
type ConnectionState
    = NotConnected
    | CreatingRoom
    | JoiningRoom String  -- Stores the code being joined
    | Connected { role : Role, roomCode : String }

type Role = Host | Client
```

### Pattern 4: Toast Auto-Dismiss
**What:** Show error notification, auto-clear after 5 seconds using Process.sleep.
**When to use:** Connection errors ("Room not found", "Connection failed").
**Existing pattern:** Main.elm lines 246-252 for player join notifications.

**Example:**
```elm
-- In update function
ConnectionError errMsg ->
    ( { model | notification = Just errMsg }
    , Process.sleep 5000
        |> Task.perform (\_ -> ClearNotification)
    )
```

### Anti-Patterns to Avoid
- **Storing peer instances in Elm model:** Peer objects are not serializable. Keep them in JS, reference by ID only.
- **Creating multiple peer instances:** One peer instance per player session. Creating many causes resource leaks.
- **Ignoring disconnection events:** WebRTC connections can drop. Always listen for `disconnected` and `close` events.
- **Blocking UI during connection:** Use spinners and allow cancellation (user requirement).

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WebRTC signaling | Custom WebSocket + STUN coordination | PeerJS cloud signaling | WebRTC signaling is complex (SDP exchange, ICE candidates, STUN/TURN). PeerJS abstracts this completely. |
| Room code generation | Random 4-char strings | Sequential + prime number multiplication OR check DB for uniqueness | Naive random has birthday paradox collisions. See "Common Pitfalls #2". |
| Clipboard copy | document.execCommand('copy') | navigator.clipboard.writeText() | execCommand is deprecated, clipboard API is the modern standard (works in all browsers 2024+). |
| Connection retry logic | Manual setTimeout loops | PeerJS automatic reconnection + explicit user retry | PeerJS handles network transients. For true failures, let user retry via UI (clearer UX). |
| Visual "Copied!" feedback | Custom tooltip positioning | Simple state flag + conditional CSS class | User requirement is just "visual feedback" - className toggle is sufficient. |

**Key insight:** WebRTC has 100+ edge cases (NAT traversal, codec negotiation, ICE gathering). PeerJS has 7+ years of production hardening. Don't reimplement.

## Common Pitfalls

### Pitfall 1: Ambiguous Room Code Characters
**What goes wrong:** User sees "O" (letter) but types "0" (zero), room not found.
**Why it happens:** 26 letters (A-Z) includes O, I which look like 0, 1.
**How to avoid:**
- Use ONLY letters A-Z (user decision) and consider excluding I, O to prevent confusion
- OR use a visually unambiguous subset like "23456789CFGHJMPQRVWX" (22 chars, used by Open Location Code)
- User decision is "letters only (A-Z)" so implement that, but document the ambiguity risk
**Warning signs:** User reports "room doesn't exist" but code looks correct in screenshot.

**Source:** [Understanding and avoiding visually ambiguous characters in IDs](https://gajus.com/blog/avoiding-visually-ambiguous-characters-in-ids), [Avoiding Confusion With Alphanumeric Characters - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC3541865/)

### Pitfall 2: Room Code Collision Probability
**What goes wrong:** Two hosts generate same code, client joins wrong room.
**Why it happens:** 26^4 = 456,976 combinations. Birthday paradox means 50% collision at ~800 active rooms.
**How to avoid:**
- **For small scale (<100 concurrent rooms):** Naive random is fine, collision is 1-2%
- **For larger scale:** Use database sequence + prime multiplication to guarantee uniqueness (see [Oregon State Blog: Generating Unique Room Codes Using Number Theory](https://blogs.oregonstate.edu/melsbyg/2023/01/09/primetime/))
- **Phase 5 scope:** Simple random is acceptable, Phase 6+ may add collision handling
**Warning signs:** User reports joining wrong game, host ID in logs doesn't match.

**Source:** [Ready For Prime Time: Generating Unique Room Codes Using Number Theory](https://blogs.oregonstate.edu/melsbyg/2023/01/09/primetime/), [Random Strings: The Terrible Cost of Friendliness](https://medium.com/engineering-livestream/random-strings-the-terrible-cost-of-friendliness-242820e4358e)

### Pitfall 3: Error Event Routing Confusion
**What goes wrong:** `peer.connect()` fails but error fires on peer object, not connection object.
**Why it happens:** PeerJS Issue #1281 - when connection can't be made, error emits to peer not conn.
**How to avoid:** Listen for errors on BOTH `peer.on('error')` and `conn.on('error')`. Map both to same Elm port.
**Warning signs:** "Room not found" errors aren't caught, app shows spinner forever.

**Source:** [PeerJS Issue #1281](https://github.com/peers/peerjs/issues/1281), [PeerJS Documentation](https://peerjs.com/docs/)

### Pitfall 4: Connection State vs Data Channel State
**What goes wrong:** PeerJS fires `conn.on('open')` but data channel isn't ready, sends fail silently.
**Why it happens:** `open` event fires when ICE negotiation completes, but data channel has its own ready state.
**How to avoid:** In PeerJS, `open` event reliably indicates data channel is ready. BUT always check `conn.open === true` before calling `conn.send()`.
**Warning signs:** First message after connection always fails, subsequent messages work.

**Source:** [PeerJS Documentation - DataConnection Events](https://peerjs.com/docs/)

### Pitfall 5: Disconnected vs Closed State Handling
**What goes wrong:** Connection drops (network hiccup), app shows "disconnected" but doesn't allow reconnect.
**Why it happens:** WebRTC `iceConnectionState` fires `disconnected` on transients, `failed` on permanent failures. PeerJS closes connection on `disconnected` (Issue #898).
**How to avoid:**
- On `close` event, update Elm model to `NotConnected` and show "Connection lost" toast
- Provide "Create Room" / "Join Room" buttons again (let user manually reconnect)
- Phase 5 doesn't auto-reconnect (defer to Phase 6+)
**Warning signs:** Network blip kicks user out, they can't rejoin without refresh.

**Source:** [PeerJS Issue #898 - Connections getting closed after a while](https://github.com/peers/peerjs/issues/898), [Handling WebRTC session disconnections - BlogGeek.me](https://bloggeek.me/handling-session-disconnections-in-webrtc/)

## Code Examples

Verified patterns from official sources and research:

### Creating a Peer (Host)
```javascript
// Source: https://peerjs.com/docs/ + room code pattern research
import Peer from 'peerjs';

// Host creates peer with 4-letter ID
const roomCode = generateRoomCode(); // e.g., "XBQR"
const peer = new Peer(roomCode, {
  host: 'peerjs.com',
  secure: true,
  config: {
    iceServers: [
      { urls: 'stun:stun.l.google.com:19302' }
    ]
  }
});

peer.on('open', (id) => {
  // Send room code back to Elm
  app.ports.roomCreated.send(id);
});

peer.on('connection', (conn) => {
  // Client connected to host
  setupConnection(conn);
});

peer.on('error', (err) => {
  app.ports.connectionError.send(errorToMessage(err));
});
```

### Connecting to Peer (Client)
```javascript
// Source: https://peerjs.com/docs/
const peer = new Peer(); // Random client ID
peer.on('open', () => {
  const conn = peer.connect(roomCode); // roomCode from Elm (e.g., "XBQR")

  conn.on('open', () => {
    app.ports.peerConnected.send({ role: 'client', roomCode: roomCode });
  });

  conn.on('data', (data) => {
    app.ports.dataReceived.send(data);
  });

  conn.on('close', () => {
    app.ports.peerDisconnected.send(roomCode);
  });

  conn.on('error', (err) => {
    app.ports.connectionError.send(errorToMessage(err));
  });
});
```

### Error Message Mapping
```javascript
// Source: https://peerjs.com/docs/ error types
function errorToMessage(err) {
  const messages = {
    'peer-unavailable': 'Room not found',
    'network': 'Connection failed - check your internet',
    'server-error': 'Connection failed - server unavailable',
    'socket-error': 'Connection failed - socket closed',
    'unavailable-id': 'Room code already in use',
  };
  return messages[err.type] || 'Connection failed';
}
```

### Elm Port Definitions
```elm
-- Source: Existing Ports.elm pattern (lines 1-44) adapted for P2P
port module Ports exposing
    ( createRoom
    , joinRoom
    , leaveRoom
    , sendData
    , roomCreated
    , peerConnected
    , peerDisconnected
    , dataReceived
    , connectionError
    )

import Json.Decode as JD
import Json.Encode as JE

-- Outgoing ports (Commands to JS)

port createRoom : () -> Cmd msg

port joinRoom : String -> Cmd msg

port leaveRoom : () -> Cmd msg

port sendData : JE.Value -> Cmd msg

-- Incoming ports (Subscriptions from JS)

port roomCreated : (String -> msg) -> Sub msg

port peerConnected : (JD.Value -> msg) -> Sub msg

port peerDisconnected : (String -> msg) -> Sub msg

port dataReceived : (JD.Value -> msg) -> Sub msg

port connectionError : (String -> msg) -> Sub msg
```

### Auto-Uppercase Input (Elm)
```elm
-- Source: https://guide.elm-lang.org/architecture/forms.html pattern
-- User types "abcd", model stores "ABCD", input displays "ABCD"
type Msg
    = RoomCodeInput String
    | ...

update msg model =
    case msg of
        RoomCodeInput str ->
            let
                uppercased = String.toUpper str

                -- Auto-connect when 4 characters entered
                cmd =
                    if String.length uppercased == 4 then
                        Ports.joinRoom uppercased
                    else
                        Cmd.none
            in
            ( { model | roomCodeInput = uppercased }, cmd )
```

### Clipboard Copy with Feedback
```javascript
// Source: https://developer.mozilla.org/en-US/docs/Web/API/Clipboard/writeText
// Source: https://web.dev/patterns/clipboard/copy-text (updated 2026-01-23)
app.ports.copyToClipboard.subscribe(async (text) => {
  try {
    await navigator.clipboard.writeText(text);
    app.ports.clipboardCopySuccess.send(null);
  } catch (err) {
    console.error('Clipboard copy failed:', err);
    // Fallback: text is already displayed, user can copy manually
  }
});
```

```elm
-- In Elm update function
CopyRoomCode ->
    ( model, Ports.copyToClipboard model.roomCode )

ClipboardCopySuccess ->
    ( { model | showCopiedFeedback = True }
    , Process.sleep 2000 |> Task.perform (\_ -> HideCopiedFeedback)
    )
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| document.execCommand('copy') | navigator.clipboard.writeText() | 2020-2021 | execCommand deprecated, clipboard API is async and more reliable |
| Simple-peer library | PeerJS with cloud signaling | 2018-2020 | PeerJS added free cloud server, removing need for custom signaling |
| Manual ICE candidate exchange | PeerJS auto-handling | Always PeerJS | PeerJS abstracts SDP/ICE completely |
| WebRTC with separate STUN/TURN config | PeerJS built-in defaults | PeerJS 1.x | Free Google STUN included, TURN optional |

**Deprecated/outdated:**
- **document.execCommand('copy')**: Use navigator.clipboard.writeText() (MDN recommendation 2020+)
- **PeerJS < 1.5.0**: Versions before 1.5.3 had CSP issues with unsafe-eval (fixed in 1.5.3, May 2024)
- **HTTP for clipboard API**: Modern clipboard requires HTTPS or localhost (security requirement 2019+)

## Open Questions

Things that couldn't be fully resolved:

1. **Room code character set (I/O ambiguity)**
   - What we know: User decision is "letters only (A-Z)", 4 characters
   - What's unclear: Whether to exclude I/O to prevent "looks like 1/0" confusion
   - Recommendation: Implement full A-Z as specified, add clarifying copy: "Enter code (letters only, case-insensitive)". If user reports confusion, revisit in Phase 6.

2. **PeerJS cloud server rate limits**
   - What we know: PeerJS offers free cloud signaling at peerjs.com
   - What's unclear: Concurrent connection limits, rate limits, uptime SLA
   - Recommendation: Use free tier for Phase 5-7. Per STATE.md, self-hosting is deferred. Monitor for reliability issues.

3. **Connection timeout duration**
   - What we know: PeerJS has no documented timeout for connection attempts
   - What's unclear: How long to show spinner before considering connection failed
   - Recommendation: Implement client-side 10-second timeout. If `peerConnected` doesn't fire within 10s of `joinRoom`, show "Connection failed" toast and return to NotConnected state.

4. **Reconnection UX after network drop**
   - What we know: PeerJS closes connection on ICE `disconnected` state (Issue #898)
   - What's unclear: Should app remember last room code and show "Reconnect" button?
   - Recommendation: Phase 5 scope is "connection infrastructure only". On disconnect, clear room code and return to initial state (Create/Join buttons). Phase 6 can add "last known room" memory.

## Sources

### Primary (HIGH confidence)
- [PeerJS Official Documentation](https://peerjs.com/docs/) - Core API reference
- [PeerJS GitHub Releases](https://github.com/peers/peerjs/releases) - Version 1.5.5 confirmed June 2025
- [MDN: Clipboard API](https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API) - writeText method specification
- [MDN: WebRTC Data Channels](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Build_a_phone_with_peerjs) - Connection patterns
- [Elm Official Guide: Ports](https://guide.elm-lang.org/interop/ports.html) - Port interop patterns
- [Elm Official Guide: Forms](https://guide.elm-lang.org/architecture/forms.html) - Input handling patterns

### Secondary (MEDIUM confidence)
- [PeerJS GitHub Issues #1281](https://github.com/peers/peerjs/issues/1281) - Error routing behavior (community confirmed)
- [PeerJS GitHub Issues #898](https://github.com/peers/peerjs/issues/898) - Connection lifecycle behavior (open issue)
- [Oregon State Blog: Room Code Generation](https://blogs.oregonstate.edu/melsbyg/2023/01/09/primetime/) - Prime number uniqueness pattern (academic source)
- [Gajus: Avoiding Visually Ambiguous Characters](https://gajus.com/blog/avoiding-visually-ambiguous-characters-in-ids) - Character set recommendations
- [PMC: Avoiding Confusion With Alphanumeric Characters](https://pmc.ncbi.nlm.nih.gov/articles/PMC3541865/) - Medical field research on character confusion
- [Medium: Random Strings Cost of Friendliness](https://medium.com/engineering-livestream/random-strings-the-terrible-cost-of-friendliness-242820e4358e) - Collision probability analysis
- [ELM-CONF: WebRTC with Elm](https://marc-walter.info/posts/2020-06-30_elm-conf/) - Ports + WebRTC integration pattern
- [BlogGeek.me: Handling WebRTC Session Disconnections](https://bloggeek.me/handling-session-disconnections-in-webrtc/) - Connection state management

### Tertiary (LOW confidence - marked for validation)
- WebSearch results on Elm toast notification packages (pablen/toasty, iosphere/elm-toast) - Found via search but not verified in production use
- Generic clipboard API tutorials (various sources) - Patterns confirmed by MDN, but tutorial quality varies

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - PeerJS is well-documented, version 1.5.5 is stable (June 2025), Elm ports are standard practice
- Architecture: HIGH - Room-code-as-peer-ID pattern is validated by PeerJS docs, port pattern matches existing codebase, connection state machine is standard Elm pattern
- Pitfalls: MEDIUM - Issues #1281 and #898 are real but workarounds exist, collision math is sound but not production-tested in this codebase, character ambiguity is documented but severity depends on user behavior
- UI patterns: HIGH - Auto-uppercase is trivial String.toUpper, toast auto-dismiss exists in Main.elm, clipboard API is standard and verified by MDN

**Research date:** 2026-02-03
**Valid until:** 2026-03-03 (30 days - PeerJS is stable, WebRTC specs are mature)
