# Project Research Summary

**Project:** Snaker Elm v2 - P2P WebRTC Mode
**Domain:** Browser-based P2P multiplayer game
**Researched:** 2026-02-03
**Confidence:** HIGH

## Executive Summary

Adding P2P WebRTC multiplayer to Snaker Elm is a well-scoped extension that leverages the existing architecture. The current Elm + Phoenix setup already separates rendering (Elm) from game logic (Elixir) via TypeScript ports. For P2P mode, game logic moves to Elm while TypeScript swaps Phoenix sockets for PeerJS DataChannels. This is a proven pattern with minimal new dependencies: PeerJS (31.9 KB) for WebRTC abstraction and qr (9 KB) for room sharing.

The recommended approach uses a **host-authoritative star topology**. One peer runs the game loop (porting the existing Elixir GameServer logic to pure Elm) and broadcasts state to all clients. This mirrors the current Phoenix architecture, making state synchronization trivial and avoiding the complexity of full-mesh networking or consensus protocols. Deterministic host election (lowest peer ID wins) enables seamless host migration without signaling.

Key risks center on NAT traversal (20-30% of users may have connectivity issues without TURN fallback) and Safari compatibility (requires JSON serialization, not binary). For MVP, accept PeerJS cloud signaling and defer TURN servers until user reports indicate need. The existing ports pattern and TypeScript infrastructure reduce integration risk significantly.

## Key Findings

### Recommended Stack

**Total new bundle cost:** ~41 KB gzipped. No new Elm packages required.

**Core technologies:**
- **PeerJS 1.5.5**: WebRTC DataChannel abstraction with free cloud signaling -- mature (10+ years), hides ICE/STUN complexity, TypeScript support
- **qr 0.5.4**: QR code generation for room sharing -- zero dependencies, 9 KB, SVG output
- **Elm Time.every**: Host game tick loop -- 100ms intervals match current Phoenix server tick

**Not adding:**
- TURN server (defer until user reports indicate need)
- simple-peer (PeerJS has built-in signaling)
- elm-webrtc packages (none maintained for 0.19; ports are correct pattern)

### Expected Features

**Must have (table stakes):**
- Peer connection via PeerJS DataChannels
- Room codes (use PeerJS peer IDs)
- Host game loop with state broadcasting
- Client input forwarding to host
- Player join/leave handling
- Connection status display

**Should have (competitive):**
- Host migration (deterministic election, lowest ID wins)
- Shareable links with embedded room code
- QR code for room sharing (local play UX)
- Reconnection handling (ICE restart)

**Defer (v2+):**
- TURN server fallback
- Custom signaling server (use PeerJS cloud for MVP)
- Rollback netcode (overkill for snake game)
- Voice/video chat
- Persistent rooms

**Anti-features (do not build):**
- Full mesh topology (use star; O(n) vs O(n^2) connections)
- Server-side room discovery (defeats P2P purpose)
- Input prediction (snake game doesn't need it)
- Anti-cheat (P2P is inherently trust-based)

### Architecture Approach

The architecture extends the existing dual-layer pattern: Elm handles view/input/game-logic, TypeScript handles networking via ports. For P2P mode, a new `p2p.ts` module manages PeerJS connections while `GameEngine.elm` contains the ported game logic (currently in Elixir). Host runs `Time.every 100` for tick loop; non-hosts render received state. Both modes share view components, decoders, and input handling.

**Major components:**
1. **GameEngine.elm** -- Pure game logic (tick, collision, apple spawn) ported from Elixir
2. **P2PPorts.elm** -- WebRTC port definitions (createRoom, joinRoom, sendInput, receiveState)
3. **p2p.ts** -- PeerJS connection manager, message routing
4. **hostElection.ts** -- Deterministic host election (lowest peer ID)

**Data flow (P2P host):**
1. Host receives inputs from peers via DataChannel
2. Host runs tick every 100ms using Time.every
3. Host broadcasts full game state to all peers
4. Peers render received state directly

### Critical Pitfalls

1. **NAT Traversal Failures** -- Configure STUN servers, accept 20-30% may need TURN (defer TURN for MVP). Use `chrome://webrtc-internals/` for debugging.

2. **Host Disconnect Without Migration** -- Implement deterministic election (smallest peer ID wins). All peers independently compute same result. New host broadcasts full state immediately.

3. **Safari Compatibility** -- Use `serialization: 'json'` in PeerJS config. Safari cannot use binary serialization. Test on Safari/iOS early.

4. **State Desynchronization** -- Host is sole authority. Non-hosts send inputs only. Full state broadcast each tick self-heals missed messages.

5. **Elm Port Race Conditions** -- Never assume message order. Use state machine in TypeScript. Add handshake protocol (Elm sends "ready", JS responds "initialized").

## Implications for Roadmap

Based on research, suggested phase structure follows a risk-reduction sequence: establish reliable connections before adding game logic complexity.

### Phase 1: P2P Connection Layer
**Rationale:** Foundation must be solid. NAT traversal and Safari compatibility issues will manifest here. Get connections working before adding game logic.
**Delivers:** PeerJS integration, room creation/joining, basic peer messaging
**Addresses:** Peer connection establishment, room codes, connection status display
**Avoids:** NAT traversal failures, Safari compatibility gaps, port race conditions
**Stack:** PeerJS 1.5.5 with `serialization: 'json'`

### Phase 2: Game Engine Port
**Rationale:** Isolate game logic from networking. Test locally before networked play. This is the largest new code and highest risk for logic bugs.
**Delivers:** Pure Elm game logic (tick, collision, apple spawn, snake movement)
**Addresses:** Host game loop (running locally first)
**Avoids:** State desynchronization (by testing logic in isolation)
**Notes:** Port Elixir tests to Elm. Single-player mode using Time.every for validation.

### Phase 3: Host Mode Integration
**Rationale:** Connect game engine to P2P layer. Host runs tick loop, broadcasts state. Simpler than client mode (no input relay complexity).
**Delivers:** Working host that runs game and broadcasts to connected peers
**Addresses:** Host game loop, state broadcasting
**Avoids:** Tick drift (host is sole timing authority)

### Phase 4: Client Mode Integration
**Rationale:** Depends on host working correctly. Clients receive state and send inputs.
**Delivers:** Full P2P gameplay (host + clients)
**Addresses:** Client input forwarding, state rendering

### Phase 5: Host Migration
**Rationale:** Most complex feature. Requires all prior phases working. Deterministic election simplifies but still has edge cases.
**Delivers:** Game continues when host disconnects
**Addresses:** Host migration, peer disconnect handling
**Avoids:** Session loss, split-brain scenarios

### Phase 6: Room Sharing and Polish
**Rationale:** UX improvements after core functionality works. Lower risk, independent of game logic.
**Delivers:** QR codes, shareable links, mode selection UI
**Addresses:** Shareable links, QR code sharing
**Stack:** qr 0.5.4 for QR generation

### Phase Ordering Rationale

- **Connections before logic:** NAT traversal failures are the #1 risk. Validate P2P infrastructure works before building features on it.
- **Isolated game engine:** Testing game logic without networking eliminates a variable. Match current Phoenix behavior before adding network layer.
- **Host before client:** Host is simpler (just run loop and broadcast). Client depends on host being correct.
- **Migration last:** Highest complexity, requires all other pieces working.
- **Polish last:** QR codes and UI polish don't affect core functionality.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (P2P Connection):** May need STUN server configuration research if PeerJS defaults prove unreliable
- **Phase 5 (Host Migration):** Edge cases around state transfer timing may surface during implementation

Phases with standard patterns (skip research-phase):
- **Phase 2 (Game Engine):** Straightforward port of existing Elixir logic, well-defined behavior
- **Phase 3-4 (Host/Client Integration):** Standard PeerJS patterns, documented in ARCHITECTURE.md
- **Phase 6 (Room Sharing):** Simple QR library, URL manipulation

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | PeerJS verified on npm, qr library confirmed, Elm timing patterns documented |
| Features | MEDIUM | Based on community patterns and WebRTC docs, not production P2P games |
| Architecture | HIGH | Existing codebase analyzed, clear integration points identified |
| Pitfalls | MEDIUM | WebSearch findings cross-verified with MDN and official docs |

**Overall confidence:** HIGH

### Gaps to Address

- **TURN server necessity:** Cannot determine until real-world testing with diverse networks. Plan to add if >10% of users report connection issues.
- **Game logic parity:** Elixir to Elm port needs thorough testing. Consider porting Elixir tests as first step of Phase 2.
- **Tab backgrounding:** Browser throttles timers when tab is backgrounded. For casual snake game, "game pauses" is acceptable. Document this behavior.
- **PeerJS cloud reliability:** Using free signaling for MVP. Monitor for issues and be prepared to self-host PeerServer if needed.

## Sources

### Primary (HIGH confidence)
- [PeerJS npm](https://www.npmjs.com/package/peerjs) -- Version 1.5.5, bundle size
- [PeerJS Documentation](https://peerjs.com/docs/) -- API reference, connection patterns
- [Elm Time Guide](https://guide.elm-lang.org/effects/time.html) -- Time.every for game loop
- [MDN WebRTC Data Channels](https://developer.mozilla.org/en-US/docs/Games/Techniques/WebRTC_data_channels) -- DataChannel best practices
- [qr npm](https://www.npmjs.com/package/qr) -- Version 0.5.4, zero dependencies

### Secondary (MEDIUM confidence)
- [Building P2P Multiplayer Games](https://medium.com/@aguiran/building-real-time-p2p-multiplayer-games-in-the-browser) -- Host election, state sync patterns
- [Host Migration in P2P Games](https://edgegap.com/blog/host-migration-in-peer-to-peer-or-relay-based-multiplayer-games) -- Migration strategies
- [WebRTC Browser Support 2025](https://antmedia.io/webrtc-browser-support/) -- Safari limitations
- [Elm Ports Guide](https://guide.elm-lang.org/interop/ports.html) -- Port patterns, race conditions

### Tertiary (LOW confidence)
- [WebRTC Topology Comparison (KTH)](https://www.kth.se/social/files/56143db5f2765422ae79942c/WebRTC.pdf) -- Star vs mesh bandwidth (academic, dated but principles hold)
- [PeerJS GitHub Issues](https://github.com/peers/peerjs/issues) -- Reconnection, serialization edge cases

---
*Research completed: 2026-02-03*
*Ready for roadmap: yes*
