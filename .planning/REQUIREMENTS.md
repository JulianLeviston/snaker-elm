# Requirements: Snaker Elm v2

**Defined:** 2026-02-03
**Core Value:** Players can play snake together in real-time without requiring a backend server

## v2 Requirements

Requirements for P2P WebRTC mode. Each maps to roadmap phases.

### Connection

- [x] **CONN-01**: Player can create a room and receive a room code
- [x] **CONN-02**: Player can join a room by entering a room code
- [x] **CONN-03**: Player sees connection state (connecting/connected/disconnected)
- [x] **CONN-04**: Player sees error message when connection fails
- [ ] **CONN-05**: Player can share room via URL link
- [ ] **CONN-06**: Player can scan QR code to join room
- [ ] **CONN-07**: Player can copy room code with one click

### Game Engine

- [x] **ENG-01**: Game tick loop runs at 100ms intervals in Elm
- [x] **ENG-02**: Snake movement follows current direction each tick
- [x] **ENG-03**: Snake grows when eating apple
- [x] **ENG-04**: Apple spawns at random position when eaten
- [x] **ENG-05**: Apple expires after timeout and respawns
- [x] **ENG-06**: Score increments when apple eaten
- [x] **ENG-07**: Snake wraps around board edges

### Host/Client

- [x] **HOST-01**: First peer to create room becomes host
- [x] **HOST-02**: Host runs game loop and broadcasts state to all peers
- [x] **HOST-03**: Non-host peers send input to host only
- [x] **HOST-04**: Non-host peers render state received from host
- [x] **HOST-05**: New player joining mid-game receives full state
- [x] **HOST-06**: Player leaving is removed from game state
- [ ] **HOST-07**: When host disconnects, next peer (by ID) becomes host
- [ ] **HOST-08**: New host continues game with current state
- [ ] **HOST-09**: Disconnected player can reconnect to same room

### Mode Selection

- [ ] **MODE-01**: Player can choose between Phoenix mode and P2P mode

## Existing Requirements (from v1)

Already implemented and validated:

- [x] Phoenix mode multiplayer with server-authoritative state
- [x] SVG game board rendering
- [x] Keyboard controls (arrow keys)
- [x] Player join/leave in Phoenix mode
- [x] Toast notifications
- [x] Scoreboard display

## Out of Scope

Explicitly excluded from this milestone.

| Feature | Reason |
|---------|--------|
| Full mesh topology | Star topology (host-only) is simpler and sufficient |
| TURN server hosting | Use PeerJS defaults; add TURN only if NAT issues reported |
| Input prediction/rollback | Overkill for casual snake game |
| Persistent rooms | Rooms exist only while peers connected |
| Voice/video chat | Not needed for snake game |
| Spectator mode | Players only, no observers |
| Leaderboards | No persistence in P2P mode |
| Anti-cheat | Trust-based casual game |
| Server-side room discovery | Manual room sharing (codes/links/QR) |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ENG-01 | Phase 4 | Complete |
| ENG-02 | Phase 4 | Complete |
| ENG-03 | Phase 4 | Complete |
| ENG-04 | Phase 4 | Complete |
| ENG-05 | Phase 4 | Complete |
| ENG-06 | Phase 4 | Complete |
| ENG-07 | Phase 4 | Complete |
| CONN-01 | Phase 5 | Complete |
| CONN-02 | Phase 5 | Complete |
| CONN-03 | Phase 5 | Complete |
| CONN-04 | Phase 5 | Complete |
| HOST-01 | Phase 6 | Complete |
| HOST-02 | Phase 6 | Complete |
| HOST-03 | Phase 6 | Complete |
| HOST-04 | Phase 6 | Complete |
| HOST-05 | Phase 6 | Complete |
| HOST-06 | Phase 6 | Complete |
| HOST-07 | Phase 7 | Pending |
| HOST-08 | Phase 7 | Pending |
| HOST-09 | Phase 7 | Pending |
| CONN-05 | Phase 7 | Pending |
| CONN-06 | Phase 7 | Pending |
| CONN-07 | Phase 7 | Pending |
| MODE-01 | Phase 7 | Pending |

**Coverage:**
- v2 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0

---
*Requirements defined: 2026-02-03*
*Last updated: 2026-02-03 after roadmap creation*
