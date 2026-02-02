# Features Research: P2P WebRTC Multiplayer

**Domain:** P2P browser-based multiplayer games (snake game)
**Researched:** 2026-02-03
**Confidence:** MEDIUM (based on community patterns and official WebRTC docs, verified across multiple sources)

## Executive Summary

P2P WebRTC multiplayer games require a core set of features to be playable, with host management being the critical differentiator from server-authoritative models. The existing Snaker Elm codebase already handles game state rendering, player input, and connection status - the P2P layer needs to replicate these patterns while adding peer connection management, host election, and room joining.

Star topology (host-relays-to-clients) is the correct choice for this project given the planned host-runs-game-loop architecture. This simplifies state synchronization since only the host maintains authoritative state.

---

## Table Stakes (Must Have)

Features required for a playable P2P experience. Missing any of these results in a broken or unusable game.

| Feature | Description | Complexity | Dependencies | Why Required |
|---------|-------------|------------|--------------|--------------|
| **Peer Connection Establishment** | Ability to connect peers via WebRTC DataChannels using PeerJS | Medium | PeerJS library | No connections = no multiplayer |
| **Host Selection (Initial)** | First joiner becomes host automatically | Low | Peer connection | Someone must run the game loop |
| **Room Codes** | Shareable alphanumeric codes to join specific games | Low | PeerJS peer IDs | Players need a way to find each other |
| **Host Game Loop** | Host runs tick loop, broadcasts state to clients | Medium | Existing game logic | Game needs authoritative state source |
| **Client Input Forwarding** | Clients send direction inputs to host | Low | DataChannel, existing input handling | Players need to control their snakes |
| **State Broadcasting** | Host sends game state updates to all clients | Medium | DataChannel, existing state format | Clients need to render current game |
| **Connection State Display** | Show connecting/connected/disconnected status | Low | Existing ConnectionStatus type | Players need feedback on connection |
| **Player Join Handling** | New players can join mid-game | Medium | Peer events, game state | Multi-player games need joining |
| **Player Leave Handling** | Graceful handling when players disconnect | Medium | Peer events | Players will disconnect |
| **Basic Error Display** | Show connection/join errors to user | Low | Existing error port | Users need to know when things fail |

### Feature Details

#### Peer Connection Establishment
- Use PeerJS cloud for signaling (no server needed)
- DataChannels for game data (not media streams)
- Configure for unreliable/unordered delivery for low latency (acceptable for snake game ticks)
- Handle ICE connection failures gracefully

**Existing asset to leverage:** `ConnectionStatus` type and display in Main.elm

#### Host Selection (Initial)
- Deterministic: first peer to create room is host
- Host's peer ID becomes the room code
- No election needed for initial host - just whoever creates the room

**Implementation note:** Simple boolean `isHost` flag in model

#### Room Codes
- Use PeerJS-generated peer IDs as room codes
- Keep them reasonably short (PeerJS IDs are already usable)
- Allow custom room codes if user provides one

#### Host Game Loop
- Host runs requestAnimationFrame or setInterval tick (existing Phoenix server does 100ms ticks)
- Host maintains authoritative game state
- Host processes all collision detection, apple spawning, etc.

**Existing asset to leverage:** Game.elm state structure, existing tick handling

#### State Broadcasting
- Reuse existing `GameState` JSON format from Phoenix mode
- Send on every tick (same as Phoenix `tick` event)
- Clients receive via `receiveTick` port (already exists)

**Existing asset to leverage:** `receiveTick` port, `tickDecoder` in Main.elm

---

## Differentiators (Should Have)

Features that improve the experience but are not blocking for initial P2P functionality.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **Host Migration** | Game continues if host leaves | High | Deterministic host election | Critical for robustness |
| **Shareable Links** | URL with room code embedded | Low | Room codes | Better UX than manual code entry |
| **QR Code Sharing** | Scan to join from mobile | Low | Room codes, QR library | Nice for local play |
| **Reconnection Handling** | Auto-reconnect on temporary disconnect | Medium | ICE restart, state sync | Handles network blips |
| **Latency Indicators** | Show ping to host/peers | Medium | RTT measurement | Helps debug lag issues |
| **Player Names** | Custom names instead of IDs | Low | Input field, state broadcast | More personal experience |
| **Mode Switching** | Toggle between P2P and Phoenix modes | Medium | Conditional connection logic | Flexibility for users |
| **Copy Room Code Button** | One-click copy to clipboard | Low | Browser clipboard API | Quality of life |

### Feature Details

#### Host Migration
This is the most complex differentiator but important for a polished experience.

**Implementation approach (from research):**
1. All peers maintain sorted list of peer IDs
2. When host disconnects, smallest remaining peer ID becomes new host
3. New host broadcasts "I am now host" + full game state
4. Other peers acknowledge and switch to client mode

**Why deterministic election:** Avoids split-brain where multiple peers think they're host. All peers can independently compute who the new host should be.

**Complexity factors:**
- State transfer during migration
- Handling in-flight inputs during transition
- Brief game pause during migration is acceptable

**Source:** Microsoft DirectPlay protocol uses "oldest peer becomes host" approach. p2play-js uses "smallest player ID becomes host".

#### Shareable Links
Format: `https://yoursite.com/p2p?room=ROOMCODE`

**Implementation:**
- Check URL params on load
- If room code present, auto-join instead of create
- Update URL when creating room (for easy sharing)

#### QR Code Sharing
Many P2P browser games (Playroom, MakeCode Arcade) use QR codes for easy mobile joining.

**Libraries:** qrcode.js or similar (generates QR from URL)

**UX:** Display QR code in lobby/waiting screen for host

#### Reconnection Handling
WebRTC supports ICE restart for temporary connection issues.

**When disconnected state detected:**
1. Wait briefly (connection may self-heal)
2. If still disconnected after ~3s, attempt ICE restart
3. If ICE restart fails, show reconnection UI

**Source:** MDN RTCPeerConnection.restartIce() documentation

#### Latency Indicators
Useful for debugging but not blocking.

**Implementation:**
- Periodic ping/pong messages via DataChannel
- Calculate RTT
- Display in UI (optional, maybe debug mode only)

---

## Anti-Features (Do Not Build)

Explicit exclusions with reasoning.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Full Mesh Topology** | Doesn't scale, wastes bandwidth, complex state sync | Use star topology (host-to-clients) |
| **Server-Side Room Discovery** | Defeats P2P purpose, requires infrastructure | Use direct room codes/links |
| **Rollback Netcode** | Overkill for snake game, complex implementation | Simple state broadcast is sufficient |
| **TURN Server Fallback** | Adds infrastructure cost/complexity | Accept that ~10-20% corporate users may have issues |
| **Input Prediction** | Snake game is simple enough without it | Trust host state, accept small latency |
| **Persistent Rooms** | Rooms exist only while host is connected | Clear expectation that rooms are ephemeral |
| **Voice/Video Chat** | Out of scope, different use case | Keep it simple - game data only |
| **Spectator Mode** | Additional complexity for minimal value | Players are players |
| **Match History/Leaderboards** | Requires persistence, out of P2P scope | Phoenix mode can have this if needed |
| **Anti-Cheat** | P2P inherently trust-based, host is authoritative | Accept that host could cheat (local play context) |

### Rationale Deep Dive

#### Why Star Topology, Not Full Mesh
Full mesh requires every peer to send to every other peer. For n players:
- Full mesh: n*(n-1) connections total
- Star: n-1 connections (host to each client)

For a 4-player game:
- Full mesh: 12 directional connections
- Star: 3 connections

Additionally, state synchronization is trivial in star topology - host is authoritative, sends state, done. Full mesh requires consensus protocols.

**Research finding:** "The bit rate for the mesh network got higher than the star network after a 4th user joined" - WebRTC topology research

#### Why No TURN Server
TURN servers relay traffic when direct peer connections fail (corporate firewalls, symmetric NAT). However:
- Adds infrastructure cost
- Adds latency
- Only ~10-20% of users need it
- For a casual game, acceptable to say "doesn't work on some corporate networks"

If this becomes a pain point later, can add TURN, but don't build upfront.

#### Why No Rollback Netcode
Libraries like NetplayJS implement rollback netcode for fighting games where frame-perfect timing matters. Snake game:
- 100ms tick rate (10 FPS effectively)
- Latency up to 50ms is imperceptible
- State is simple (snake positions, apple positions)
- No frame-perfect inputs needed

Simple state broadcast from host is sufficient and much simpler.

---

## Feature Dependencies

```
Room Codes
    |
    v
Peer Connection Establishment --> Host Selection (Initial)
    |                                    |
    |                                    v
    |                             Host Game Loop --> State Broadcasting
    |                                    |                |
    v                                    v                v
Player Join Handling <-----------  All clients receive state
Player Leave Handling
    |
    v
Host Migration (if built) <-- needs sorted peer list + state transfer

Shareable Links --> depends on Room Codes
QR Code Sharing --> depends on Shareable Links
Reconnection Handling --> depends on Peer Connection Establishment
```

### Critical Path for MVP

1. Peer Connection Establishment (PeerJS setup)
2. Room Codes (host creates room, others join)
3. Host Selection (creator is host)
4. Host Game Loop (port game logic from Phoenix thinking)
5. Client Input Forwarding
6. State Broadcasting
7. Player Join/Leave Handling

---

## Complexity Assessment

| Feature | Complexity | Rationale |
|---------|------------|-----------|
| Peer Connection Establishment | Medium | PeerJS handles WebRTC complexity, but still need error handling |
| Host Selection (Initial) | Low | Just a flag - whoever creates is host |
| Room Codes | Low | Use peer IDs directly |
| Host Game Loop | Medium | Need to port game logic to JS, run tick loop |
| Client Input Forwarding | Low | Simple message over DataChannel |
| State Broadcasting | Medium | Need to serialize state, broadcast to all |
| Connection State Display | Low | Already exists in Elm, just need to wire up |
| Player Join Handling | Medium | State updates, UI notifications |
| Player Leave Handling | Medium | Snake removal, state updates |
| Basic Error Display | Low | Already exists in Elm |
| Host Migration | High | State transfer, deterministic election, race conditions |
| Shareable Links | Low | URL manipulation |
| QR Code Sharing | Low | Third-party library |
| Reconnection Handling | Medium | ICE restart, timing, state resync |
| Latency Indicators | Medium | RTT measurement, UI display |
| Player Names | Low | Input field, add to state |
| Mode Switching | Medium | Conditional logic, UI for selection |

---

## Integration with Existing Codebase

The existing codebase provides strong foundations that P2P mode can leverage:

### Elm Side (Reusable)
| Existing | P2P Usage |
|----------|-----------|
| `GameState` type | Same state structure from host |
| `ConnectionStatus` type | Extend with P2P-specific states |
| `tickDecoder` | Decode state from host broadcasts |
| `playerJoinedDecoder` | Adapt for P2P join events |
| `View.Board`, `View.Scoreboard` | Unchanged - render whatever state we have |
| `Input.keyDecoder` | Unchanged - capture inputs same way |

### Elm Side (New/Modified)
| Need | Notes |
|------|-------|
| P2P-specific ports | `createRoom`, `joinRoom`, `sendInput`, `receiveState`, etc. |
| Mode selection model | Track whether in P2P or Phoenix mode |
| Host/client distinction | `isHost` flag determines behavior |
| Peer list tracking | For UI and host migration |

### JavaScript Side (New)
| Component | Purpose |
|-----------|---------|
| PeerJS connection manager | Handle peer connections, DataChannels |
| Room management | Create/join room logic |
| Host game loop | Run tick loop, maintain state |
| Message protocol | Define message types for input, state, etc. |

### JavaScript Side (Existing to Modify)
| Component | Changes |
|-----------|---------|
| `app.ts` | Add mode selection, conditional connection |
| `socket.ts` | Keep for Phoenix mode, add parallel P2P module |

---

## Sources

- [Building Real-Time P2P Multiplayer Games in the Browser](https://medium.com/@aguiran/building-real-time-p2p-multiplayer-games-in-the-browser-why-i-eliminated-the-server-d9f4ea7d4099) - p2play-js author on host election, state sync
- [Host Migration in P2P Games](https://edgegap.com/blog/host-migration-in-peer-to-peer-or-relay-based-multiplayer-games) - Host migration patterns
- [Microsoft DirectPlay Host Migration Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/mc-dpl8cs/c188116b-228c-4c39-9959-381845f3d1af) - Deterministic host election specification
- [WebRTC Data Channels - MDN](https://developer.mozilla.org/en-US/docs/Games/Techniques/WebRTC_data_channels) - DataChannel for games
- [RTCPeerConnection.restartIce() - MDN](https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/restartIce) - Reconnection mechanism
- [PeerJS Documentation](https://peerjs.com/examples) - PeerJS usage patterns
- [Toptal: Taming WebRTC with PeerJS](https://www.toptal.com/webrtc/taming-webrtc-with-peerjs) - PeerJS game development
- [GitHub flackr/lobby](https://github.com/flackr/lobby) - Lobby system for WebRTC games
- [Playroom Kit Lobby UI](https://docs.joinplayroom.com/components/lobby) - QR code and room code patterns
- [WebRTC Topology Comparison (KTH Research)](https://www.kth.se/social/files/56143db5f2765422ae79942c/WebRTC.pdf) - Star vs mesh bandwidth analysis
- [NetplayJS](https://github.com/rameshvarun/netplayjs) - Rollback netcode reference (noted as overkill for snake)
