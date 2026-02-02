# Requirements: Snaker Elm v2

**Defined:** 2026-02-03
**Core Value:** Players can play snake together in real-time without requiring a backend server

## v2 Requirements

Requirements for P2P WebRTC mode. Each maps to roadmap phases.

### Connection

- [ ] **CONN-01**: Player can create a room and receive a room code
- [ ] **CONN-02**: Player can join a room by entering a room code
- [ ] **CONN-03**: Player sees connection state (connecting/connected/disconnected)
- [ ] **CONN-04**: Player sees error message when connection fails
- [ ] **CONN-05**: Player can share room via URL link
- [ ] **CONN-06**: Player can scan QR code to join room
- [ ] **CONN-07**: Player can copy room code with one click

### Game Engine

- [ ] **ENG-01**: Game tick loop runs at 100ms intervals in Elm
- [ ] **ENG-02**: Snake movement follows current direction each tick
- [ ] **ENG-03**: Snake grows when eating apple
- [ ] **ENG-04**: Apple spawns at random position when eaten
- [ ] **ENG-05**: Apple expires after timeout and respawns
- [ ] **ENG-06**: Score increments when apple eaten
- [ ] **ENG-07**: Snake wraps around board edges

### Host/Client

- [ ] **HOST-01**: First peer to create room becomes host
- [ ] **HOST-02**: Host runs game loop and broadcasts state to all peers
- [ ] **HOST-03**: Non-host peers send input to host only
- [ ] **HOST-04**: Non-host peers render state received from host
- [ ] **HOST-05**: New player joining mid-game receives full state
- [ ] **HOST-06**: Player leaving is removed from game state
- [ ] **HOST-07**: When host disconnects, next peer (by ID) becomes host
- [ ] **HOST-08**: New host continues game with current state
- [ ] **HOST-09**: Disconnected player can reconnect to same room

### Mode Selection

- [ ] **MODE-01**: Player can choose between Phoenix mode and P2P mode

## Existing Requirements (from v1)

Already implemented and validated:

- ✓ Phoenix mode multiplayer with server-authoritative state
- ✓ SVG game board rendering
- ✓ Keyboard controls (arrow keys)
- ✓ Player join/leave in Phoenix mode
- ✓ Toast notifications
- ✓ Scoreboard display

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
| CONN-01 | TBD | Pending |
| CONN-02 | TBD | Pending |
| CONN-03 | TBD | Pending |
| CONN-04 | TBD | Pending |
| CONN-05 | TBD | Pending |
| CONN-06 | TBD | Pending |
| CONN-07 | TBD | Pending |
| ENG-01 | TBD | Pending |
| ENG-02 | TBD | Pending |
| ENG-03 | TBD | Pending |
| ENG-04 | TBD | Pending |
| ENG-05 | TBD | Pending |
| ENG-06 | TBD | Pending |
| ENG-07 | TBD | Pending |
| HOST-01 | TBD | Pending |
| HOST-02 | TBD | Pending |
| HOST-03 | TBD | Pending |
| HOST-04 | TBD | Pending |
| HOST-05 | TBD | Pending |
| HOST-06 | TBD | Pending |
| HOST-07 | TBD | Pending |
| HOST-08 | TBD | Pending |
| HOST-09 | TBD | Pending |
| MODE-01 | TBD | Pending |

**Coverage:**
- v2 requirements: 24 total
- Mapped to phases: 0
- Unmapped: 24

---
*Requirements defined: 2026-02-03*
*Last updated: 2026-02-03 after initial definition*
