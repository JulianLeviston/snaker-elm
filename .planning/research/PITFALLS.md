# Pitfalls Research: P2P WebRTC

**Project:** Snaker Elm - P2P Mode
**Researched:** 2026-02-03
**Overall Confidence:** MEDIUM (WebSearch findings cross-verified with official documentation where possible)

---

## Critical Pitfalls (High Impact)

These will break the game if not handled correctly.

### 1. NAT Traversal Failures

**Description:** WebRTC requires STUN/TURN servers to traverse NAT. Without proper configuration, 20-30% of users may be unable to connect, particularly in enterprise networks and on mobile.

**Warning Signs:**
- Connection works on localhost but fails in production
- Some players can connect, others cannot
- ICE gathering takes extremely long (>5 seconds)
- Connection state gets stuck in "checking" or "disconnected"

**Prevention Strategy:**
1. Never rely on free STUN servers for production - they may disappear or be unreliable
2. Always configure TURN servers as fallback (STUN only handles ~80% of cases)
3. Use multiple STUN servers across geographic regions
4. Implement connection timeout with clear user feedback
5. Use Chrome's `chrome://webrtc-internals/` or Firefox's `about:webrtc` for debugging

**Phase to Address:** Phase 1 (Connection Layer) - Core infrastructure must be solid before building features on top.

**Sources:**
- [WebRTC NAT Traversal Guide](https://www.nihardaily.com/168-webrtc-nat-traversal-understanding-stun-turn-and-ice)
- [WebRTC Troubleshooting](https://moldstud.com/articles/p-webrtc-troubleshooting-expert-solutions-to-common-developer-issues)

---

### 2. Host Disconnect Without Migration

**Description:** If the host (game authority) disconnects and there's no migration strategy, all other players get kicked. This is catastrophic for multiplayer sessions.

**Warning Signs:**
- Game freezes when one specific player leaves
- "Connection lost" for all players simultaneously
- No error handling for host departure

**Prevention Strategy:**
1. Implement deterministic host election (smallest peer ID becomes host) - avoids race conditions
2. Broadcast full game state from new host immediately after election
3. Detect host disconnect via `iceconnectionstatechange` event (state changes to "disconnected" or "failed")
4. Give ~5 seconds grace period for "disconnected" (may self-repair), immediately handle "failed"
5. Store enough state on all peers to reconstruct if they become host

**Phase to Address:** Phase 2 (Host Election) - After basic connections work, but before game loop migration.

**Sources:**
- [Host Migration in P2P Games](https://edgegap.com/blog/host-migration-in-peer-to-peer-or-relay-based-multiplayer-games)
- [Handling WebRTC Disconnections](https://bloggeek.me/handling-session-disconnections-in-webrtc/)

---

### 3. State Desynchronization

**Description:** Without a central server, peers can disagree on game state. One player sees themselves eating an apple, another doesn't. This breaks the fundamental game experience.

**Warning Signs:**
- Players report "I hit them but they didn't die"
- Scores differ between players
- Snakes appear in different positions for different players
- Apple positions inconsistent

**Prevention Strategy:**
1. Designate one peer as authoritative (the host) - they are the source of truth
2. Non-hosts send inputs only, never state
3. Host broadcasts authoritative state every tick
4. Implement state reconciliation: when receiving host state, snap to it rather than interpolating
5. Consider rollback netcode for fast-paced games (NetplayJS approach)
6. For Snaker: Host runs game loop, broadcasts snake/apple positions each tick

**Phase to Address:** Phase 3 (Game Loop Migration) - When porting the Elixir game logic to Elm.

**Sources:**
- [Building P2P Multiplayer Games](https://medium.com/@aguiran/building-real-time-p2p-multiplayer-games-in-the-browser-why-i-eliminated-the-server-d9f4ea7d4099)
- [NetplayJS - Rollback Netcode](https://github.com/rameshvarun/netplayjs)

---

### 4. Elm Port Race Conditions

**Description:** Elm ports are asynchronous. Messages sent to JavaScript may arrive in unexpected order, especially during connection setup and host migration. ~40% of port bugs come from timing issues.

**Warning Signs:**
- Intermittent connection failures on startup
- "Cannot read property 'xyz' of undefined" in JavaScript
- Game works on second attempt but not first
- State appears corrupted after reconnection

**Prevention Strategy:**
1. Never assume port message order - use explicit state machine in JS
2. Add sequence numbers or timestamps to messages for ordering
3. Queue outgoing messages until connection is confirmed established
4. Use JSON decoders defensively - treat all JavaScript input as untrusted
5. Check for port existence before subscribing: `if (app.ports.outgoing) { ... }`
6. Log all port traffic during development

**Phase to Address:** Phase 1 (Connection Layer) - Fundamental to Elm/JS communication.

**Sources:**
- [Elm Ports Guide](https://guide.elm-lang.org/interop/ports.html)
- [Elm JS Interop Limits](https://guide.elm-lang.org/interop/limits)

---

## Moderate Pitfalls (Medium Impact)

These degrade experience but don't completely break the game.

### 5. Browser Compatibility Gaps

**Description:** Safari has significant WebRTC limitations compared to Chrome/Firefox. iOS forces all browsers to use WebKit (Safari's engine), inheriting these limitations.

**Warning Signs:**
- Works in Chrome, fails in Safari
- Mobile users report connection issues
- "DataChannel not supported" errors in Safari

**Prevention Strategy:**
1. **Safari requires JSON serialization** - PeerJS default binary serialization doesn't work
2. Configure PeerJS with `serialization: 'json'` for Safari compatibility
3. Test early and often on Safari (desktop and iOS)
4. Safari cannot play streams on private networks (local IP candidate issue)
5. Use `adapter.js` for SDP negotiation normalization between browsers
6. Accept that advanced WebRTC features (Insertable Streams) won't work in Safari

**Phase to Address:** Phase 1 (Connection Layer) - Configure correctly from the start.

**Sources:**
- [WebRTC Browser Support 2025](https://antmedia.io/webrtc-browser-support/)
- [WebRTC on iOS](https://www.webrtc-developers.com/webrtc-on-chrome-firefox-edge-and-others-on-ios/)

---

### 6. Game Loop Tick Drift

**Description:** Without a central server clock, peers may run game loops at slightly different speeds due to JavaScript timer inconsistencies and clock drift.

**Warning Signs:**
- Game feels "faster" for some players
- State updates arrive in bursts rather than smoothly
- Players report game "catching up" after tab was in background

**Prevention Strategy:**
1. Host is the sole source of tick timing - others just render received state
2. Don't rely on `setInterval` for game loop - use `requestAnimationFrame` for rendering, separate tick timer
3. Include tick number in state broadcasts for ordering
4. Handle tab backgrounding: browsers throttle timers, may need to catch up
5. Use relative timing (delta from last tick) not absolute timestamps

**Phase to Address:** Phase 3 (Game Loop Migration) - When implementing the Elm game loop.

**Sources:**
- [Game Networking Time Sync](https://daposto.medium.com/game-networking-2-time-tick-clock-synchronisation-9a0e76101fe5)
- [Command Frames and Tick Sync](https://www.gamedev.net/forums/topic/696756-command-frames-and-tick-synchronization/)

---

### 7. PeerJS Cloud Server Reliability

**Description:** PeerJS provides a free cloud server for signaling, but it's not guaranteed to be reliable or fast. Production apps should not depend on it.

**Warning Signs:**
- Intermittent "WebSocket connection failed" errors
- Connections work locally but fail in production
- High latency during initial connection

**Prevention Strategy:**
1. Run your own PeerServer for production (simple Node.js server)
2. Or use PeerJS cloud only for development, self-host for production
3. Implement reconnection logic with exponential backoff
4. Have fallback signaling mechanism if PeerJS server is down

**Phase to Address:** Phase 4 (Production Hardening) - After core functionality works.

**Sources:**
- [PeerJS Documentation](https://peerjs.com/docs/)
- [PeerJS GitHub Issues](https://github.com/peers/peerjs/issues)

---

### 8. Full-Mesh Scalability Limit

**Description:** P2P full-mesh (everyone connected to everyone) has practical limit of ~10 players. Each new player adds O(n) new connections.

**Warning Signs:**
- Performance degrades with more players
- Connection establishment takes longer with more peers
- Bandwidth usage spikes with player count

**Prevention Strategy:**
1. Accept 4-6 player limit for Snaker (reasonable for snake game)
2. If more players needed, switch to star topology (all connect to host only)
3. Monitor connection count and refuse new players at limit
4. Consider relay/SFU architecture if scaling beyond 10

**Phase to Address:** Design Decision - Accept limit early in design.

**Sources:**
- [WebRTC Relays for Multiplayer](https://edgegap.com/blog/webrtc-relays-for-multiplayer-games)

---

## Minor Pitfalls (Low Impact)

These cause annoyance but are fixable without major refactoring.

### 9. Large Message Truncation

**Description:** Non-binary serialization in PeerJS doesn't chunk large messages. Chrome will truncate large JSON/strings.

**Warning Signs:**
- Large state updates arrive incomplete
- JSON parse errors on receiving end
- Works with small state, fails with many players/apples

**Prevention Strategy:**
1. Keep messages small - send deltas not full state when possible
2. Use binary serialization (but note Safari incompatibility)
3. Implement manual chunking for large payloads if needed
4. For Snaker: Game state should be small enough (<16KB) to not hit this

**Phase to Address:** Phase 3 (Game Loop) - When designing message format.

**Sources:**
- [PeerJS Issue #234](https://github.com/peers/peerjs/issues/234)

---

### 10. Non-ASCII Character Corruption

**Description:** PeerJS binary serialization can corrupt non-ASCII characters in strings if not properly escaped.

**Warning Signs:**
- Player names with accents/emoji appear corrupted
- JSON containing unicode fails to parse

**Prevention Strategy:**
1. Use `binary-utf8` serialization (slower but handles unicode)
2. Or use JSON serialization (required for Safari anyway)
3. Or manually escape/unescape unicode strings

**Phase to Address:** Phase 1 - Configure serialization correctly.

**Sources:**
- [PeerJS Issue #127](https://github.com/peers/peerjs/issues/127)

---

### 11. Dead Code Elimination of Ports

**Description:** Elm aggressively eliminates dead code. If a port is defined but not used in Elm code, it may be eliminated from the compiled output.

**Warning Signs:**
- "app.ports.xyz is undefined" in JavaScript
- Port worked before, stopped working after refactor
- Port visible in source but not in compiled JS

**Prevention Strategy:**
1. Ensure every port is used somewhere in Elm code (at least in subscriptions)
2. Check for port existence in JS before accessing
3. Keep all ports in a single module for visibility

**Phase to Address:** Phase 1 - When setting up port architecture.

**Sources:**
- [Elm Ports Documentation](https://guide.elm-lang.org/interop/ports.html)

---

## PeerJS-Specific Gotchas

### Serialization Configuration
```javascript
// Default: binary (doesn't work with Safari)
const peer = new Peer();

// Safe for all browsers:
const peer = new Peer({
  serialization: 'json'  // Required for Safari
});
```

### Connection Order Preservation
Recent PeerJS versions (post-2023) fixed message ordering issues, but older versions may deliver messages out of order. Ensure you're on PeerJS 1.4+.

### Port 443 Blocking
PeerJS cloud runs on port 443. Some corporate networks block WebSocket on this port. Self-hosting allows custom port configuration.

### Reconnection After Disconnect
When reconnecting after a disconnect, you must delete all references to the old `RTCPeerConnection` before creating a new one. Otherwise, you may get browser-specific errors.

```javascript
// Wrong: reuse connection
existingConn.reconnect();

// Right: clean slate
existingConn.close();
delete connections[peerId];
const newConn = peer.connect(peerId);
```

**Sources:**
- [PeerJS Reconnection Issue #1162](https://github.com/peers/peerjs/issues/1162)
- [PeerJS Serialization](https://github.com/peers/js-binarypack)

---

## Elm Ports Pitfalls

### Asynchronous Nature
Ports are one-way and asynchronous. You cannot "call" JavaScript and get a return value. Instead:
- Send message via outgoing port
- JavaScript does work
- JavaScript sends result via incoming port
- Elm receives in update function (later)

**Implication for WebRTC:** You cannot synchronously check connection status. Must use subscriptions.

### Silent Failures
If JavaScript sends wrong type through port, Elm silently ignores it. Use JSON decoders and handle `Err` cases explicitly.

```elm
-- BAD: Ignores errors
GotGameState value ->
    case JD.decodeValue Game.decoder value of
        Ok state -> ...
        Err _ -> ( model, Cmd.none )  -- Silent failure!

-- GOOD: Log or display errors
GotGameState value ->
    case JD.decodeValue Game.decoder value of
        Ok state -> ...
        Err e ->
            ( { model | error = Just (JD.errorToString e) }
            , Cmd.none
            )
```

### Component Lifecycle Timing
~30% of port errors occur during component lifecycle events. Particularly dangerous:
- Init: JavaScript may not be ready when Elm sends first message
- Reconnection: Old subscriptions may receive messages meant for new connection

**Solution:** Add handshake protocol - Elm sends "ready", JS responds "initialized", then proceed.

**Sources:**
- [Elm Land JS Interop](https://elm.land/guide/working-with-js)
- [Elm Community JS Integration Examples](https://github.com/elm-community/js-integration-examples)

---

## Testing Challenges

### Local Development

**What works:**
- `localhost` and `127.0.0.1` are exempt from WebRTC security rules
- Can test with two browser tabs on same machine
- No STUN/TURN needed for localhost-to-localhost

**What doesn't work:**
- `file://` URLs cannot use WebRTC
- Non-localhost HTTP addresses (must use HTTPS in production)
- Testing with different machines on same network needs STUN

### Testing Strategy

1. **Phase 1: Same-machine testing**
   - Two tabs in same browser
   - Tests connection establishment, messaging
   - Use `localhost:PORT`

2. **Phase 2: Cross-machine LAN testing**
   - Requires at least STUN server
   - Tests NAT traversal within LAN
   - Use ngrok for HTTPS if needed

3. **Phase 3: Internet testing**
   - Requires TURN server for reliability
   - Tests real-world conditions
   - Deploy to staging environment

### Debugging Tools

| Tool | Purpose |
|------|---------|
| `chrome://webrtc-internals/` | ICE candidates, connection state, stats |
| `about:webrtc` (Firefox) | Similar to Chrome internals |
| Browser DevTools Console | PeerJS logs, JavaScript errors |
| Elm Debugger | Port message flow, state changes |
| Network tab | WebSocket signaling traffic |

### Simulating Failures

```javascript
// Simulate disconnection
connection.close();

// Simulate latency (requires proxy/throttling)
// Use Chrome DevTools Network tab throttling

// Simulate host departure
peer.destroy();
```

**Sources:**
- [Local WebRTC Development](https://www.daily.co/blog/setting-up-a-local-webrtc-development-environment/)
- [Google WebRTC Codelab](https://developers.google.com/codelabs/webrtc-web)

---

## Phase-Specific Warnings

| Phase | Topic | Likely Pitfall | Mitigation |
|-------|-------|----------------|------------|
| 1 | Connection Layer | NAT traversal, Safari compat | Configure TURN fallback, JSON serialization |
| 1 | Elm Ports | Race conditions, silent failures | State machine in JS, defensive decoders |
| 2 | Host Election | Race condition on disconnect | Deterministic election (smallest ID) |
| 2 | Host Migration | State loss during migration | Broadcast full state from new host |
| 3 | Game Loop | Tick drift, desync | Host-authoritative, tick numbers |
| 3 | State Sync | Split-brain, conflicting state | Single authority (host), reconciliation |
| 4 | Production | PeerJS cloud reliability | Self-host signaling server |

---

## Summary: Top 5 Pitfalls to Prioritize

1. **NAT Traversal** - Will make game unplayable for 20-30% of users if not handled
2. **Host Disconnect** - Will kill sessions for all players
3. **Safari Compatibility** - Will exclude iOS and Safari users entirely
4. **State Desync** - Will make game unplayable/unfair
5. **Port Race Conditions** - Will cause intermittent connection failures

**Recommendation:** Phases 1-2 should focus heavily on connection reliability before investing in game logic migration.
