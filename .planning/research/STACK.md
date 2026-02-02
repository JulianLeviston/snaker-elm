# Stack Research: P2P WebRTC for Snaker Elm

**Project:** Snaker Elm v2 - P2P Multiplayer Mode
**Researched:** 2026-02-03
**Overall Confidence:** HIGH

## Executive Summary

Adding P2P WebRTC multiplayer to the existing Elm + Phoenix snake game requires minimal new dependencies. The existing ports-based architecture (TypeScript <-> Elm via JSON) maps cleanly to WebRTC operations. PeerJS provides battle-tested WebRTC abstraction with free cloud signaling. The `qr` library offers zero-dependency QR generation at minimal bundle cost.

---

## Recommended Stack Additions

| Library | Version | Purpose | Bundle Size | Confidence |
|---------|---------|---------|-------------|------------|
| peerjs | 1.5.5 | WebRTC DataChannel abstraction | 31.9 KB gzip | HIGH |
| qr | 0.5.4 | QR code generation for room links | 9 KB gzip (encode only) | HIGH |

**Total new bundle:** ~41 KB gzipped

**No new Elm packages required.** The existing `elm/time` and `elm/browser` packages already support game tick loops.

---

## PeerJS Details

### Current Version
**1.5.5** (stable, latest as of npm registry check 2026-02-03)

A beta v2.0.0 exists but is not recommended for production - stick with 1.x stable line.

### Bundle Size
- Minified + Gzipped: **31.9 KB**
- Dependencies: 4 (webrtc-adapter, eventemitter3, etc.)

### Core API for Data Connections

```typescript
import Peer, { DataConnection } from 'peerjs';

// Create peer (host generates room)
const peer = new Peer();  // Auto-generated ID, or pass custom ID
peer.on('open', (id) => console.log('My peer ID:', id));

// Host: Listen for connections
peer.on('connection', (conn: DataConnection) => {
  conn.on('open', () => console.log('Client connected'));
  conn.on('data', (data) => handleClientInput(data));
  conn.send({ type: 'gameState', state: {...} });
});

// Client: Connect to host
const conn = peer.connect('host-peer-id');
conn.on('open', () => conn.send({ type: 'input', direction: 'up' }));
conn.on('data', (data) => handleGameState(data));

// Cleanup
conn.close();
peer.destroy();
```

### Signaling Server
- Default: `0.peerjs.com` (free cloud, port 443)
- Limitation: Shared server, ID collisions possible with manual IDs
- For production: Can self-host peerjs-server, but free cloud is fine for MVP
- Note: After WebRTC connection established, all game traffic is pure P2P (no server)

### Browser Support
- Chrome, Edge, Firefox, Safari (tested via BrowserStack)
- Firefox 102+ required for CBOR/MessagePack support

### Why PeerJS
1. **Mature**: 10+ years of development, widely used
2. **Simple API**: Hides ICE/STUN/TURN complexity
3. **DataChannel focus**: Perfect for game state sync (not media streaming)
4. **Free signaling**: 0.peerjs.com eliminates server costs for MVP
5. **TypeScript**: Good type definitions available

### Sources
- [PeerJS npm](https://www.npmjs.com/package/peerjs) - Version verification
- [PeerJS Documentation](https://peerjs.com/docs/) - API reference
- [PeerJS GitHub](https://github.com/peers/peerjs) - Source and releases
- [Best of JS - PeerJS](https://bestofjs.org/projects/peerjs) - Bundle size

---

## QR Code Generation

### Recommendation: `qr` by Paul Miller

| Criteria | qr | qrcode (node-qrcode) |
|----------|----|--------------------|
| Version | 0.5.4 | 1.5.4 |
| Bundle | 9 KB (encode) | ~15 KB |
| Dependencies | 0 | Multiple |
| SVG Support | Yes | Yes |
| Maintained | Active (Jan 2026) | Active |

### Why `qr` over `qrcode`
1. **Zero dependencies**: No supply chain risk, fully auditable
2. **Smaller**: 9 KB vs ~15 KB for encode-only use case
3. **Modern**: ESM native, recent TypeScript rewrite
4. **Performance**: Faster benchmarks than alternatives

### API Usage

```typescript
import encodeQR from 'qr';

// Generate SVG string for room URL
const roomUrl = `https://snaker.app/join/${roomCode}`;
const svgElement = encodeQR(roomUrl, 'svg');

// Insert into DOM
document.getElementById('qr-container').appendChild(svgElement);
```

### Integration Note
QR generation happens entirely in JavaScript. No Elm ports needed for QR - just render the SVG in a container that Elm creates, then populate via JS when room code changes.

### Sources
- [qr GitHub](https://github.com/paulmillr/qr) - API and bundle size
- [qr npm](https://www.npmjs.com/package/qr) - Version verification

---

## Elm Game Loop Timing

### For P2P Host: Use `Time.every` (NOT `onAnimationFrameDelta`)

The existing game uses server-side tick at fixed intervals. For P2P mode where Elm runs the game loop, use the same pattern:

```elm
import Time

subscriptions : Model -> Sub Msg
subscriptions model =
    if model.isHost && model.gameRunning then
        Time.every tickIntervalMs Tick
    else
        Sub.none

-- Example: 100ms tick = 10 FPS (same as current server)
tickIntervalMs : Float
tickIntervalMs = 100
```

### Why `Time.every` Not `onAnimationFrameDelta`

| Aspect | Time.every | onAnimationFrameDelta |
|--------|------------|----------------------|
| Purpose | Fixed interval logic | Smooth visual animation |
| Rate | Configurable (e.g., 100ms) | ~60 FPS (16.67ms) |
| Use case | Game tick, state updates | Rendering, interpolation |
| Network sync | Predictable intervals | Variable, harder to sync |

For snake game physics (grid-based movement at fixed rate), `Time.every` is correct. The current server ticks at ~100ms intervals - replicate this in Elm for P2P host.

**Exception:** If adding smooth visual interpolation between ticks in the future, use `onAnimationFrameDelta` for rendering while keeping `Time.every` for game logic.

### Existing Elm Packages (No additions needed)

The project already has:
- `elm/time 1.0.0` - Provides `Time.every`
- `elm/browser 1.0.2` - Provides `onAnimationFrameDelta` if needed

### Sources
- [Elm Time Guide](https://guide.elm-lang.org/effects/time.html) - Time.every usage
- [Browser.Events](https://package.elm-lang.org/packages/elm/browser/latest/Browser.Events) - Animation frame APIs
- [Elm Game Loop Tutorial](https://sbaechler.gitbooks.io/elm-hexagon/doc/gameloop.html) - Patterns

---

## Elm Ports for WebRTC

### Existing Pattern (Leverage It)

The current codebase has a clean TypeScript <-> Elm ports pattern:

**Elm side (`Ports.elm`):**
```elm
port module Ports exposing (...)

-- Commands (Elm -> JS)
port joinGame : JE.Value -> Cmd msg
port sendDirection : JE.Value -> Cmd msg

-- Subscriptions (JS -> Elm)
port receiveGameState : (JD.Value -> msg) -> Sub msg
port receiveError : (String -> msg) -> Sub msg
```

**JS side (`socket.ts`):**
```typescript
app.ports.joinGame.subscribe((payload) => { ... });
app.ports.receiveGameState.send(gameState);
```

### New Ports for P2P Mode

Add to `Ports.elm`:

```elm
-- P2P Commands (Elm -> JS)
port createRoom : () -> Cmd msg
port joinRoom : String -> Cmd msg  -- Room code
port sendP2PState : JE.Value -> Cmd msg  -- Host broadcasts state
port sendP2PInput : JE.Value -> Cmd msg  -- Client sends input

-- P2P Subscriptions (JS -> Elm)
port roomCreated : (String -> msg) -> Sub msg  -- Receive room code
port peerConnected : (JE.Value -> msg) -> Sub msg
port peerDisconnected : (String -> msg) -> Sub msg
port receiveP2PState : (JD.Value -> msg) -> Sub msg  -- Clients receive state
port receiveP2PInput : (JD.Value -> msg) -> Sub msg  -- Host receives input
port p2pError : (String -> msg) -> Sub msg
```

### New TypeScript Module (`p2p.ts`)

```typescript
import Peer, { DataConnection } from 'peerjs';

interface ElmP2PPorts {
  createRoom: { subscribe: (cb: () => void) => void };
  joinRoom: { subscribe: (cb: (code: string) => void) => void };
  sendP2PState: { subscribe: (cb: (data: unknown) => void) => void };
  sendP2PInput: { subscribe: (cb: (data: unknown) => void) => void };
  roomCreated: { send: (code: string) => void };
  peerConnected: { send: (data: unknown) => void };
  peerDisconnected: { send: (peerId: string) => void };
  receiveP2PState: { send: (data: unknown) => void };
  receiveP2PInput: { send: (data: unknown) => void };
  p2pError: { send: (msg: string) => void };
}

export function initP2P(app: { ports: ElmP2PPorts }) {
  let peer: Peer | null = null;
  const connections: Map<string, DataConnection> = new Map();

  // Implementation follows existing socket.ts pattern
  // ...
}
```

### Port Design Principles

1. **Separate P2P ports from Phoenix ports**: Don't mix concerns; game mode determines which ports are active
2. **Use `JE.Value`/`JD.Value` for complex data**: Matches existing pattern, allows flexible JSON
3. **Keep ports thin**: Business logic in Elm, transport logic in TypeScript
4. **Error ports for each subsystem**: `receiveError` (Phoenix) vs `p2pError` (WebRTC)

### Sources
- [Elm Ports Guide](https://guide.elm-lang.org/interop/ports.html) - Official documentation
- [Bridging Elm and JavaScript with Ports](https://thoughtbot.com/blog/bridging-elm-and-javascript-with-ports) - Best practices
- Existing `socket.ts` in project - Proven pattern to follow

---

## What NOT to Add

### Do NOT Add: simple-peer
- **Why suggested**: Another WebRTC abstraction
- **Why skip**: PeerJS is more mature, has built-in signaling server, better docs
- **Bundle**: Similar size but less ecosystem support

### Do NOT Add: elm-webrtc or WebRTC Elm packages
- **Why suggested**: Native Elm WebRTC
- **Why skip**: No maintained Elm 0.19 WebRTC packages exist; ports are the correct pattern
- **Evidence**: [webrtc-elm-play](https://github.com/TheOddler/webrtc-elm-play) project archived 2018, used JS+ports approach

### Do NOT Add: qrcode-generator or qrcodejs
- **Why suggested**: Older QR libraries
- **Why skip**: `qr` is smaller, zero-dep, actively maintained

### Do NOT Add: Additional signaling servers
- **Why suggested**: Custom signaling for reliability
- **Why skip for MVP**: PeerJS cloud (0.peerjs.com) is free and sufficient; add self-hosted later if needed

### Do NOT Add: TURN server
- **Why suggested**: NAT traversal fallback
- **Why skip for MVP**: WebRTC DataChannels usually work peer-to-peer; add TURN only if users report connection issues in symmetric NAT scenarios

### Do NOT Add: Elm animation packages
- **Why suggested**: Game rendering
- **Why skip**: Existing SVG rendering works; `elm/time` and `elm/browser` provide all needed timing

---

## Integration Points with Existing Code

### Existing Files to Modify

| File | Changes |
|------|---------|
| `assets/package.json` | Add `peerjs`, `qr` dependencies |
| `assets/src/Ports.elm` | Add P2P port definitions |
| `assets/src/Main.elm` | Add P2P mode state, subscriptions |
| `assets/js/app.ts` | Conditional init of socket vs P2P |

### New Files to Create

| File | Purpose |
|------|---------|
| `assets/js/p2p.ts` | PeerJS integration, P2P port handlers |
| `assets/js/qr.ts` | QR code rendering helper |
| `assets/src/P2P.elm` | P2P-specific types, encoders/decoders |
| `assets/src/GameLogic.elm` | Pure game logic (tick, collision, scoring) ported from Elixir |

### Mode Architecture

```
                    [UI Layer - Elm]
                          |
            +-------------+-------------+
            |                           |
      [Phoenix Mode]              [P2P Mode]
            |                           |
      socket.ts                    p2p.ts
            |                           |
      Phoenix Channels            PeerJS
            |                           |
      [Server GameServer]         [Host Elm]
```

Both modes share:
- Elm UI components (Board, Scoreboard, etc.)
- JSON decoders for game state
- Direction input handling

P2P mode adds:
- Game logic in Elm (currently in Elixir GameServer)
- Host tick loop via `Time.every`
- QR code display for room sharing

---

## Installation Commands

```bash
cd assets

# Add new dependencies
npm install peerjs@1.5.5 qr@0.5.4

# TypeScript types (peerjs includes its own)
# qr has TypeScript support built-in
```

### Updated package.json

```json
{
  "dependencies": {
    "phoenix": "file:../deps/phoenix",
    "phoenix_html": "file:../deps/phoenix_html",
    "peerjs": "^1.5.5",
    "qr": "^0.5.4"
  }
}
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| PeerJS cloud downtime | Low | High | Monitor status.peerjs.com; fallback to self-hosted if needed |
| NAT traversal failures | Medium | Medium | Most modern networks work; defer TURN until user reports |
| Game logic port accuracy | Low | High | Port Elixir tests to Elm; fuzz test collision detection |
| Browser compatibility | Low | Low | PeerJS handles; stick to DataChannel (not media) |

---

## Confidence Assessment

| Area | Confidence | Reasoning |
|------|------------|-----------|
| PeerJS selection | HIGH | Verified npm, docs, active maintenance |
| QR library selection | HIGH | Verified npm, zero-dep, recent release |
| Elm timing approach | HIGH | Official docs confirm Time.every for fixed intervals |
| Ports pattern | HIGH | Existing codebase proves pattern works |
| Bundle impact | HIGH | Verified sizes via npm/bundlephobia sources |
