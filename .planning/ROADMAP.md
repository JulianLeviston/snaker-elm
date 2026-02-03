# Roadmap: Snaker Elm v2

## Milestones

- [x] **v1 Multiplayer Upgrade** - Phases 1-3 (shipped 2026-02-02)
- [x] **v2 P2P WebRTC Mode** - Phases 4-7 (shipped 2026-02-03)

## Overview

This roadmap delivers serverless P2P multiplayer for Snaker Elm. The journey starts by porting the game engine from Elixir to Elm (testable in isolation), then establishes WebRTC connections via PeerJS, integrates host/client gameplay, and finishes with host migration and room sharing polish. By Phase 7, players can create rooms, share via QR/links, and play snake together without any backend server.

## Phases

**Phase Numbering:**
- v1 completed phases 1-3
- v2 starts at phase 4 (continuous numbering)

- [x] **Phase 4: Game Engine Port** - Port Elixir game logic to pure Elm
- [x] **Phase 5: P2P Connection Layer** - Establish WebRTC connections via PeerJS
- [x] **Phase 6: Host/Client Integration** - Enable P2P multiplayer gameplay
- [x] **Phase 7: Migration & Polish** - Host migration, room sharing, mode selection

## Phase Details

### Phase 4: Game Engine Port
**Goal**: Game logic runs in Elm without any server dependency
**Depends on**: Phase 3 (v1 complete)
**Requirements**: ENG-01, ENG-02, ENG-03, ENG-04, ENG-05, ENG-06, ENG-07
**Success Criteria** (what must be TRUE):
  1. Single-player game runs entirely in browser with 100ms tick loop
  2. Snake moves continuously, wraps at edges, and responds to arrow keys
  3. Eating apple grows snake, increments score, and spawns new apple
  4. Apple expires and respawns after timeout if not eaten
**Plans**: 2 plans

Plans:
- [x] 04-01-PLAN.md - Core engine: tick loop, movement, wrapping, collision
- [x] 04-02-PLAN.md - Apple system: spawning, eating, growth, expiration, score

### Phase 5: P2P Connection Layer
**Goal**: Players can establish peer connections via room codes
**Depends on**: Phase 4
**Requirements**: CONN-01, CONN-02, CONN-03, CONN-04
**Success Criteria** (what must be TRUE):
  1. Player can create a room and see a room code displayed
  2. Player can enter a room code and connect to the room creator
  3. Connection status (connecting/connected/disconnected) is visible
  4. Clear error message appears when connection fails
**Plans**: 2 plans

Plans:
- [x] 05-01-PLAN.md - P2P infrastructure: PeerJS install, ports, connection state machine
- [x] 05-02-PLAN.md - Connection UI: Create/Join buttons, room code display, status, errors

### Phase 6: Host/Client Integration
**Goal**: Full P2P multiplayer game works between connected peers
**Depends on**: Phase 5
**Requirements**: HOST-01, HOST-02, HOST-03, HOST-04, HOST-05, HOST-06
**Success Criteria** (what must be TRUE):
  1. Room creator is host and runs the game loop
  2. Host broadcasts game state and all peers see synchronized snakes
  3. Non-host players send inputs and see their actions reflected
  4. New player joining mid-game receives full state and can play immediately
  5. Player leaving is removed from all peers' game state
**Plans**: 2 plans

Plans:
- [x] 06-01-PLAN.md - Message protocol and host game loop with state broadcasting
- [x] 06-02-PLAN.md - Client state rendering, input forwarding, join/leave, visual polish

### Phase 7: Migration & Polish
**Goal**: Robust room sharing and graceful host disconnect handling
**Depends on**: Phase 6
**Requirements**: HOST-07, HOST-08, HOST-09, CONN-05, CONN-06, CONN-07, MODE-01
**Success Criteria** (what must be TRUE):
  1. When host disconnects, game continues with new host (lowest peer ID)
  2. Disconnected player can rejoin the same room
  3. Player can share room via URL link or QR code
  4. Player can copy room code with one click
  5. Player can choose between Phoenix mode and P2P mode at startup
**Plans**: 3 plans

Plans:
- [x] 07-01-PLAN.md - Mode selection: startup screen, localStorage persistence, settings override
- [x] 07-02-PLAN.md - Room sharing: QR code generation, copy code/URL buttons, visual feedback
- [x] 07-03-PLAN.md - Host migration: deterministic election, orphaned snakes, reconnection, leader indicator

## Progress

**Execution Order:** 4 -> 5 -> 6 -> 7

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 4. Game Engine Port | v2 | 2/2 | Complete | 2026-02-03 |
| 5. P2P Connection Layer | v2 | 2/2 | Complete | 2026-02-03 |
| 6. Host/Client Integration | v2 | 2/2 | Complete | 2026-02-03 |
| 7. Migration & Polish | v2 | 3/3 | Complete | 2026-02-03 |

---
*Roadmap created: 2026-02-03*
*Last updated: 2026-02-03 (Phase 7 complete, v2 milestone complete)*
