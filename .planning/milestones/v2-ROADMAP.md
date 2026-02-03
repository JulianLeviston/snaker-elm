# Milestone v2: P2P WebRTC Mode

**Status:** SHIPPED 2026-02-03
**Phases:** 4-7
**Total Plans:** 9

## Overview

This milestone delivers serverless P2P multiplayer for Snaker Elm. The journey started by porting the game engine from Elixir to Elm (testable in isolation), then established WebRTC connections via PeerJS, integrated host/client gameplay, and finished with host migration and room sharing polish. Players can now create rooms, share via QR/links, and play snake together without any backend server.

## Phases

### Phase 4: Game Engine Port

**Goal**: Game logic runs in Elm without any server dependency
**Depends on**: Phase 3 (v1 complete)
**Requirements**: ENG-01, ENG-02, ENG-03, ENG-04, ENG-05, ENG-06, ENG-07
**Plans**: 2 plans

Plans:
- [x] 04-01-PLAN.md - Core engine: tick loop, movement, wrapping, collision
- [x] 04-02-PLAN.md - Apple system: spawning, eating, growth, expiration, score

**Details:**
- Created Engine/Grid.elm with edge wrapping and position utilities
- Created Engine/Collision.elm with self and other-snake collision detection
- Created Engine/Apple.elm with spawning, eating, expiration logic
- Created LocalGame.elm with complete single-player game state
- 100ms tick loop via Time.every subscription
- Invincibility tracked as tick count (15 ticks = 1500ms)
- Apple expiry at 100 ticks (10 seconds)

### Phase 5: P2P Connection Layer

**Goal**: Players can establish peer connections via room codes
**Depends on**: Phase 4
**Requirements**: CONN-01, CONN-02, CONN-03, CONN-04
**Plans**: 2 plans

Plans:
- [x] 05-01-PLAN.md - P2P infrastructure: PeerJS install, ports, connection state machine
- [x] 05-02-PLAN.md - Connection UI: Create/Join buttons, room code display, status, errors

**Details:**
- Installed PeerJS and created peerjs-ports.ts
- 4-letter A-Z room codes for human-friendly sharing
- 10-second timeout for P2P join attempts
- Auto-join when room code input reaches 4 characters
- Connection state machine in Elm (Disconnected → Connecting → Connected)
- ConnectionUI view module with status display

### Phase 6: Host/Client Integration

**Goal**: Full P2P multiplayer game works between connected peers
**Depends on**: Phase 5
**Requirements**: HOST-01, HOST-02, HOST-03, HOST-04, HOST-05, HOST-06
**Plans**: 2 plans

Plans:
- [x] 06-01-PLAN.md - Message protocol and host game loop with state broadcasting
- [x] 06-02-PLAN.md - Client state rendering, input forwarding, join/leave, visual polish

**Details:**
- Network/Protocol.elm with message types and JSON codecs
- Network/HostGame.elm with multi-player host game loop
- Network/ClientGame.elm for client-side state rendering
- Full sync every 50 ticks (5 seconds) to recover from packet loss
- 30-tick grace period for disconnected players before removal
- Hash-based snake color assignment from 12-color palette
- Host's peerId equals room code for simplified identification
- CSS-based collision animations (shake + teeth-scatter)

### Phase 7: Migration & Polish

**Goal**: Robust room sharing and graceful host disconnect handling
**Depends on**: Phase 6
**Requirements**: HOST-07, HOST-08, HOST-09, CONN-05, CONN-06, CONN-07, MODE-01
**Plans**: 3 plans

Plans:
- [x] 07-01-PLAN.md - Mode selection: startup screen, localStorage persistence, settings override
- [x] 07-02-PLAN.md - Room sharing: QR code generation, copy code/URL buttons, visual feedback
- [x] 07-03-PLAN.md - Host migration: deterministic election, orphaned snakes, reconnection, leader indicator

**Details:**
- Mode selection on first visit, P2P primary, Phoenix secondary
- localStorage key 'snaker-mode' stores mode preference
- Screen-based routing (ModeSelectionScreen, GameScreen, SettingsScreen)
- qrcode@1.5.4 for QR generation via Elm ports
- baseUrl passed via Flags for URL construction
- Deterministic host election (lowest peer ID wins)
- Leader pulsing animation for host indicator
- SVG opacity attribute for orphaned snakes
- QR code positioned below game board

---

## Milestone Summary

**Key Decisions:**

| Decision | Rationale |
|----------|-----------|
| Host-authoritative star topology | Mirrors Phoenix architecture, simpler than mesh |
| PeerJS for signaling | Free cloud service, defer self-hosting |
| Game engine isolated first | Testable without network complexity |
| 4-letter room codes | Human-friendly, sufficient entropy |
| Full sync every 50 ticks | Recover from packet loss |
| Hash-based snake colors | Consistent colors without coordination |
| Deterministic host election | Lowest peer ID wins, reproducible |
| localStorage mode persistence | Remember user preference |

**Issues Resolved:**

- Game state sync working without server dependency
- P2P connections established via PeerJS cloud
- Host migration seamless with state preservation
- Room sharing via QR codes and URL links

**Issues Deferred:**

- None - all v2 requirements satisfied

**Technical Debt Incurred:**

- Minor UI polish noted (functional but could be improved)
- Hardcoded 30x40 grid dimensions (intentional simplification)

---

*For current project status, see .planning/PROJECT.md*
*Archived: 2026-02-03 as part of v2 milestone completion*
