# Migration Pitfalls: Elm 0.18→0.19 + Phoenix 1.3→1.7

**Analysis Date:** 2026-01-30

**Project Context:** Snaker-elm multiplayer snake game with WebSocket state sync, using elm-phoenix-socket (Native modules), Brunch asset pipeline, and Phoenix Channels.

---

## Table of Contents

1. [Elm 0.18→0.19 Breaking Changes](#elm-018019-breaking-changes)
2. [Phoenix 1.3→1.7 Breaking Changes](#phoenix-131-7-breaking-changes)
3. [elm-phoenix-socket Replacement](#elm-phoenix-socket-replacement)
4. [Asset Pipeline Migration (Brunch→esbuild)](#asset-pipeline-migration-brunchesbuild)
5. [Multiplayer State Sync Issues](#multiplayer-state-sync-issues)
6. [Phoenix Channel Pattern Changes](#phoenix-channel-pattern-changes)
7. [Cross-Cutting Migration Risks](#cross-cutting-migration-risks)

---

## Elm 0.18→0.19 Breaking Changes

### PITFALL 1: Package Format Changed (elm-package.json → elm.json)

**Root Cause:**
Elm 0.19 completely replaced `elm-package.json` with `elm.json` and changed package repository from package.elm-lang.org to package.elm-lang.org/packages. Format and schema are incompatible.

**Warning Signs:**
- `elm-package.json` exists in `/Users/julian/code/elm/snaker-elm/assets/elm/`
- Dependencies specify version ranges like `"5.1.1 <= v < 6.0.0"` (old format)
- `elm-version` field specifies `"0.18.0 <= v < 0.19.0"`

**Prevention Strategy:**
1. Run `elm init` in clean directory to see new format
2. Use `elm-json` tool (npm package) to assist conversion
3. Map old package names to new ones:
   - `elm-lang/core` → `elm/core` (now split into multiple packages)
   - `elm-lang/html` → `elm/html`
   - `elm-lang/keyboard` → REMOVED (see Pitfall 2)
   - `fbonetti/elm-phoenix-socket` → NO OFFICIAL 0.19 VERSION

**Phase Mapping:** Phase 1 - Elm upgrade preparation

---

### PITFALL 2: Keyboard Module Removed

**Root Cause:**
`elm-lang/keyboard` was removed in 0.19. Keyboard input now handled via `Browser.Events.onKeyDown`/`onKeyUp` with custom decoders.

**Warning Signs:**
- `import Keyboard` in `/Users/julian/code/elm/snaker-elm/assets/elm/Main.elm` (line 6)
- `Keyboard.ups keyCodeToChangeDirectionMsg` subscription (line 268)
- `Keyboard.KeyCode` type used (line 271)

**Impact:**
Snake direction control (arrow keys) will break completely. Players cannot move.

**Prevention Strategy:**
1. Replace `Keyboard.ups` with `Browser.Events.onKeyUp`
2. Create custom decoder for keycode: `JD.field "keyCode" JD.int`
3. Ensure decoder returns same Msg type as before
4. Test all four arrow keys (38↑, 37←, 39→, 40↓) work identically

**Code Pattern:**
```elm
-- OLD (0.18):
import Keyboard
Keyboard.ups keyCodeToChangeDirectionMsg

-- NEW (0.19):
import Browser.Events
Browser.Events.onKeyUp (JD.map keyCodeToChangeDirectionMsg keyDecoder)

keyDecoder : JD.Decoder Keyboard.KeyCode
keyDecoder = JD.field "keyCode" JD.int
```

**Phase Mapping:** Phase 1 - Elm upgrade, after package conversion

---

### PITFALL 3: Html.program → Browser.* APIs

**Root Cause:**
`Html.program` removed. Must use `Browser.element`, `Browser.document`, or `Browser.application` with different type signatures.

**Warning Signs:**
- `main = Html.program` in `/Users/julian/code/elm/snaker-elm/assets/elm/Main.elm` (line 298-304)
- No `Browser` import exists

**Impact:**
App won't compile. Entry point signature changes.

**Prevention Strategy:**
1. Choose `Browser.element` (simplest, matches current behavior)
2. Change `init : ( Model, Cmd Msg )` to `init : () -> ( Model, Cmd Msg )`
3. Wrap program record with `{ init = \_ -> init, ... }` pattern
4. Add `import Browser`

**Code Pattern:**
```elm
-- OLD (0.18):
main = Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

-- NEW (0.19):
main = Browser.element
    { init = \_ -> init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }
```

**Phase Mapping:** Phase 1 - Elm upgrade, core API changes

---

### PITFALL 4: Time.every API Changed

**Root Cause:**
`Time.every` now takes `Float` (milliseconds) instead of `Time.Time`. Subscription signature changed.

**Warning Signs:**
- `Time.every Board.tickDuration` in subscription (line 263)
- `Board.tickDuration` likely returns `Time.Time` type
- No explicit millisecond conversion

**Impact:**
Game tick timing may break, causing snakes to move at wrong speed or not at all.

**Prevention Strategy:**
1. Check `Board.tickDuration` return type in `/Users/julian/code/elm/snaker-elm/assets/elm/Data/Board.elm`
2. Change to return `Float` in milliseconds
3. Update `Time.every` to match: `Time.every 100.0 (\posix -> ...)`
4. Convert `Tick` message to accept `Posix` instead of `Time.Time`

**Phase Mapping:** Phase 1 - Elm upgrade, time API changes

---

### PITFALL 5: toString Removed for Custom Types

**Root Cause:**
`toString` removed for custom types in 0.19. Must implement custom stringification.

**Warning Signs:**
- `toString direction` in `/Users/julian/code/elm/snaker-elm/assets/elm/Main.elm` (line 196)
- `Direction` is custom union type (North, South, East, West)

**Impact:**
Direction changes won't serialize to JSON. Server receives broken/missing data.

**Prevention Strategy:**
1. Create explicit `Direction.toString : Direction -> String` function
2. Replace all `toString direction` calls with `Direction.toString direction`
3. Ensure serialized values match what server expects (check `Direction.fromString` for reverse mapping)

**Code Pattern:**
```elm
-- In Data/Direction.elm:
toString : Direction -> String
toString dir =
    case dir of
        North -> "North"
        South -> "South"
        East -> "East"
        West -> "West"
```

**Phase Mapping:** Phase 1 - Elm upgrade, after basic compilation succeeds

---

### PITFALL 6: Native Modules Forbidden

**Root Cause:**
Elm 0.19 forbids Native modules (JavaScript FFI) in application code. Only core packages can use them.

**Warning Signs:**
- `fbonetti/elm-phoenix-socket` uses Native modules internally
- No official 0.19 port exists from original author
- Dependency on Phoenix Socket JavaScript client

**Impact:**
WebSocket communication completely broken. Game becomes single-player only.

**Prevention Strategy:**
1. Find alternative: `elm-phoenix` or implement custom ports-based solution
2. Budget significant time - this is most complex migration piece
3. See PITFALL 13 for detailed replacement strategy

**Phase Mapping:** Phase 2 - WebSocket replacement (critical path)

---

### PITFALL 7: Json.Decode API Refinements

**Root Cause:**
Some decoder combinators changed slightly. `andThen` more commonly used instead of chaining.

**Warning Signs:**
- `JD.andThen` used in playerChangedDirectionDecoder (line 235-244)
- Pattern should still work but may have subtle breaking changes
- Error messages changed significantly

**Impact:**
Low - code likely works but error messages during JSON decode failures are less helpful.

**Prevention Strategy:**
1. Test all JSON decoders with actual server payloads
2. Add explicit type annotations to decoder functions
3. Use `JD.decodeString` in tests to verify behavior

**Phase Mapping:** Phase 1 - Elm upgrade, validation phase

---

## Phoenix 1.3→1.7 Breaking Changes

### PITFALL 8: Directory Structure Changed

**Root Cause:**
Phoenix 1.7 consolidated web directory structure. `lib/snaker_web/` patterns changed.

**Warning Signs:**
- Current structure: `lib/snaker_web/channels/`, `lib/snaker_web/controllers/`
- Phoenix 1.7 uses different controller/view organization
- Templates moved from `lib/snaker_web/templates/` to `lib/snaker_web/controllers/*_html/`

**Impact:**
Medium - mostly affects new generators, not runtime behavior. Mixing old/new structure causes confusion.

**Prevention Strategy:**
1. Don't run generators until after migration complete
2. Keep existing structure working first
3. Optionally refactor to new structure in separate phase
4. Check `mix phx.routes` still works after upgrade

**Phase Mapping:** Phase 3 - Phoenix upgrade, structural changes (optional)

---

### PITFALL 9: Phoenix.Transports Removed

**Root Cause:**
`Phoenix.Transports.WebSocket` removed. Replaced by `Phoenix.Socket.Transport` behavior.

**Warning Signs:**
- `transport :websocket, Phoenix.Transports.WebSocket` in `/Users/julian/code/elm/snaker-elm/lib/snaker_web/channels/user_socket.ex` (line 9)

**Impact:**
WebSocket connections fail immediately. No clients can connect.

**Prevention Strategy:**
1. Replace with `socket "/socket", SnakerWeb.UserSocket, websocket: true`
2. Remove explicit `transport` declarations
3. Move socket configuration to endpoint config if needed
4. Test connection with browser DevTools before testing game

**Code Pattern:**
```elixir
# OLD (1.3):
transport :websocket, Phoenix.Transports.WebSocket

# NEW (1.7):
# In endpoint.ex:
socket "/socket", SnakerWeb.UserSocket,
  websocket: true,
  longpoll: false
```

**Phase Mapping:** Phase 3 - Phoenix upgrade, WebSocket config

---

### PITFALL 10: Cowboy 1.0 → 2.x Breaking Changes

**Root Cause:**
Phoenix 1.7 requires Cowboy 2.x. Transport layer completely rewritten.

**Warning Signs:**
- `{:cowboy, "~> 1.0"}` in `/Users/julian/code/elm/snaker-elm/mix.exs` (line 43)
- Cowboy 1.x dependencies (cowlib ~> 1.0.2, ranch ~> 1.3.2)

**Impact:**
WebSocket upgrade handshake may fail. Connection drops immediately after connecting.

**Prevention Strategy:**
1. Update to `{:cowboy, "~> 2.10"}` in mix.exs
2. Update `plug_cowboy` dependency if present
3. Run `mix deps.clean --all && mix deps.get`
4. Check for custom Cowboy handler code (unlikely in this project)
5. Test WebSocket connection in browser DevTools Network tab

**Phase Mapping:** Phase 3 - Phoenix upgrade, dependency updates

---

### PITFALL 11: Brunch Removed from Phoenix

**Root Cause:**
Phoenix 1.6+ removed Brunch in favor of esbuild. No migration path in Phoenix generators.

**Warning Signs:**
- `brunch-config.js` in `/Users/julian/code/elm/snaker-elm/assets/`
- `node_modules/brunch/bin/brunch` watcher in `/Users/julian/code/elm/snaker-elm/config/dev.exs` (line 14)
- `elmBrunch` plugin configuration

**Impact:**
Assets don't compile. Elm code not bundled. Game doesn't load in browser.

**Prevention Strategy:**
See PITFALL 14-16 for detailed esbuild migration strategy.

**Phase Mapping:** Phase 4 - Asset pipeline replacement (parallel with Phase 3)

---

### PITFALL 12: Phoenix.Channel handle_out Behavior

**Root Cause:**
`handle_out/3` filtering behavior may have subtle changes in message interception.

**Warning Signs:**
- `handle_out` used for preventing echo in `/Users/julian/code/elm/snaker-elm/lib/snaker_web/channels/game_channel.ex` (lines 33-45)
- Pattern: `if socket.assigns.player.id != id do push(...)`

**Impact:**
Low - pattern should still work but test that players don't see their own join/direction broadcasts echoed.

**Prevention Strategy:**
1. Manual testing with two browser windows
2. Check browser console for duplicate messages
3. Add logging to `handle_out` during migration
4. Verify `broadcast!` vs `broadcast_from!` behavior

**Phase Mapping:** Phase 3 - Phoenix upgrade, validation phase

---

## elm-phoenix-socket Replacement

### PITFALL 13: No Official 0.19 Port Exists

**Root Cause:**
`fbonetti/elm-phoenix-socket` (2.2.0) is Elm 0.18 only. Author abandoned project. Uses Native modules.

**Warning Signs:**
- Dependency in `elm-package.json`: `"fbonetti/elm-phoenix-socket": "2.2.0 <= v < 3.0.0"`
- Imports: `Phoenix.Socket`, `Phoenix.Channel`, `Phoenix.Push` in Main.elm

**Impact:**
CRITICAL - No WebSocket communication. Multiplayer completely broken.

**Prevention Strategy:**
Two approaches:

**Option A: Use ports (recommended for control)**
1. Import Phoenix JavaScript client directly in app.js
2. Create Elm ports for send/receive messages
3. Implement Socket state management in JavaScript
4. Rewrite Main.elm to use port commands/subscriptions
5. Test thoroughly - this is complete rewrite of communication layer

**Option B: Use elm-phoenix (community fork)**
1. Check if `elm-phoenix` package has 0.19 support
2. Compare API to see how similar it is
3. May still require significant refactoring
4. Less control over WebSocket lifecycle

**Recommended:** Option A (ports) because:
- Full control over Phoenix JS client version
- Can add retry logic, error handling in JS
- Easier to debug connection issues
- More flexible for future changes

**Phase Mapping:** Phase 2 - WebSocket replacement (highest risk, critical path)

---

### PITFALL 14: Socket Initialization Patterns Changed

**Root Cause:**
Moving from elm-phoenix-socket library calls to ports changes initialization flow.

**Warning Signs:**
- `Socket.init "ws://localhost:4000/socket/websocket"` in init (line 41)
- Socket state held in Model as `phxSocket : Socket Msg`
- Update function has `PhoenixMsg (Socket.Msg Msg)` case

**Impact:**
Init, update, and subscriptions need major rewrite.

**Prevention Strategy:**
1. Create port module: `port module Ports exposing (..)`
2. Define ports:
   - `port phoenixSend : JE.Value -> Cmd msg`
   - `port phoenixReceive : (JE.Value -> msg) -> Sub msg`
3. Replace Socket model field with connection state enum
4. Handle reconnection logic in JavaScript
5. Map all Socket.push calls to phoenixSend
6. Map all Socket.on subscriptions to phoenixReceive with message tagging

**Port Patterns:**
```elm
-- Send direction change:
-- OLD: Socket.push push_ model.phxSocket
-- NEW: phoenixSend <| JE.object
        [ ("event", JE.string "player:change_direction")
        , ("payload", payload)
        ]

-- Receive messages:
-- OLD: Socket.on "join" "game:snake" (DispatchServerMsg JoinGame)
-- NEW: phoenixReceive (\value ->
        case JD.decodeValue eventDecoder value of
            Ok ("join", data) -> DispatchServerMsg JoinGame data
            ...
        )
```

**Phase Mapping:** Phase 2 - WebSocket replacement, after ports defined

---

### PITFALL 15: Channel Join Timing Issues

**Root Cause:**
Port-based implementation may connect before channel ready. Race condition in init.

**Warning Signs:**
- Current code joins channel immediately in init (line 52)
- No explicit ready state handling
- Messages may be sent before connection established

**Impact:**
First few messages lost. Player doesn't join game properly. State desync from start.

**Prevention Strategy:**
1. Add connection state to Model: `type ConnectionState = Connecting | Connected | Disconnected`
2. Don't send messages until Connected
3. JavaScript sends "connected" message when channel joined
4. Queue outgoing messages in Elm until connection ready
5. Add retry logic in JavaScript for join failures

**JavaScript Pattern:**
```javascript
socket.connect()
socket.onOpen(() => {
  channel = socket.channel("game:snake", {})
  channel.join()
    .receive("ok", () => app.ports.phoenixReceive.send({
      event: "connected",
      payload: {}
    }))
    .receive("error", () => console.error("Join failed"))
})
```

**Phase Mapping:** Phase 2 - WebSocket replacement, testing phase

---

## Asset Pipeline Migration (Brunch→esbuild)

### PITFALL 16: Elm Not Built-in to esbuild

**Root Cause:**
esbuild doesn't have native Elm support. Brunch had `elm-brunch` plugin.

**Warning Signs:**
- `elmBrunch` config in `/Users/julian/code/elm/snaker-elm/assets/brunch-config.js` (lines 51-55)
- Elm source in `assets/elm/` directory
- Main module output to `assets/js/`

**Impact:**
Elm code not compiled. JavaScript bundle missing Elm app. Blank page in browser.

**Prevention Strategy:**
1. Use `node-elm-compiler` npm package or direct `elm make` call
2. Two-stage build: Elm compile → esbuild bundle
3. Update package.json scripts:
   - `"build:elm": "elm make elm/Main.elm --output=../js/elm.js"`
   - `"build:js": "esbuild js/app.js --bundle --outdir=../priv/static/assets"`
   - `"build": "npm run build:elm && npm run build:js"`
4. Update dev watcher in config/dev.exs to run both
5. Add `assets/js/elm.js` to gitignore

**Phase Mapping:** Phase 4 - Asset pipeline, parallel with Phoenix upgrade

---

### PITFALL 17: esbuild Doesn't Auto-Require Modules

**Root Cause:**
Brunch had `autoRequire` config. esbuild needs explicit imports.

**Warning Signs:**
- `autoRequire: { "js/app.js": ["js/app"] }` in brunch-config.js (line 60)
- JavaScript may use implicit module loading

**Impact:**
Elm app not initialized. DOM element exists but nothing renders.

**Prevention Strategy:**
1. Check `assets/js/app.js` for explicit require/import statements
2. Ensure `Elm.Main.init({ node: document.getElementById('elm_target') })` is called
3. With esbuild, all imports must be explicit at top of file
4. Test that app.js executes by adding console.log

**Phase Mapping:** Phase 4 - Asset pipeline, JavaScript migration

---

### PITFALL 18: Different Output Path Conventions

**Root Cause:**
Brunch outputs to `paths.public` (priv/static). esbuild defaults need configuration.

**Warning Signs:**
- `public: "../priv/static"` in brunch-config.js (line 42)
- Phoenix expects assets in `priv/static/assets/`
- Cache manifest in `priv/static/cache_manifest.json`

**Impact:**
Assets 404 in production. Phoenix can't find compiled files.

**Prevention Strategy:**
1. Configure esbuild outdir: `--outdir=../priv/static/assets`
2. Update Phoenix endpoint config to match
3. Generate digest/manifest if deploying to production
4. Test with `MIX_ENV=prod mix phx.server`

**Phase Mapping:** Phase 4 - Asset pipeline, configuration phase

---

## Multiplayer State Sync Issues

### PITFALL 19: Client Tick Timing Divergence Amplified

**Root Cause:**
Existing bug: clients tick independently at 100ms intervals. Migration may make worse.

**Warning Signs:**
- `Time.every Board.tickDuration` in each client (Main.elm line 263)
- No server clock synchronization
- TODO comment in game_channel.ex acknowledges missing board sync (line 14)

**Impact:**
CRITICAL - If migration doesn't address this, bug persists. Snake positions diverge between clients.

**Prevention Strategy:**
1. DON'T defer this fix - address during migration
2. Move tick authority to server
3. Server broadcasts `tick` event with server timestamp every 100ms
4. Clients receive tick, update all snakes deterministically
5. Client-side prediction optional (render between ticks)
6. See Pitfall 20 for apple generation

**Phase Mapping:** Phase 5 - State sync fix (can't ship without this)

---

### PITFALL 20: Apple Generation Must Move to Server

**Root Cause:**
Apples generated client-side with `Random.generate` in Board.elm. Each client has different apples.

**Warning Signs:**
- `Random.generate AddApple` generates apples locally
- No apple events broadcast from server
- Apple expiration timestamps based on client time

**Impact:**
Players collect different apples. Visual inconsistency. Game unplayable when positions matter.

**Prevention Strategy:**
1. Remove client-side apple generation completely
2. Server GenServer holds apple list with spawn times
3. Server broadcasts `apple:spawn` with position and expiration
4. Server broadcasts `apple:despawn` when expired or collected
5. Clients passively render apples from server messages
6. Server RNG ensures all clients see same apples

**Phase Mapping:** Phase 5 - State sync fix (required for playability)

---

### PITFALL 21: Player Join Without Full State

**Root Cause:**
New player joins but only receives other player IDs, not snake positions or directions.

**Warning Signs:**
- `push(socket, "join", %{player: ..., players: Worker.players()})` (game_channel.ex line 13)
- `Worker.players()` only has player metadata (id, name, color)
- No snake body positions sent
- No apple list sent

**Impact:**
New player sees snakes at wrong positions. Collision detection wrong. Unfair gameplay.

**Prevention Strategy:**
1. Server maintains canonical board state in GenServer
2. On join, send complete state:
   ```elixir
   %{
     player: current_player,
     players: all_players,
     snakes: %{player_id => %{direction: dir, body: [positions]}},
     apples: [%{position: {x, y}, expires_at: timestamp}],
     server_time: :os.system_time(:millisecond)
   }
   ```
3. Client reconstructs entire board from this payload
4. Use server_time for client clock offset calculation

**Phase Mapping:** Phase 5 - State sync fix (blocking multiplayer)

---

## Phoenix Channel Pattern Changes

### PITFALL 22: GenServer Not Thread-Safe for Concurrent Updates

**Root Cause:**
`Snaker.Worker` GenServer may have race conditions when multiple players update simultaneously.

**Warning Signs:**
- `Worker.new_player()` assigns IDs (likely sequential)
- Map-based player storage
- No explicit locking or transaction semantics

**Impact:**
Player ID collisions. Lost updates. Corrupt state under load.

**Prevention Strategy:**
1. Review Worker.ex for race conditions (need to read file)
2. Use GenServer call instead of cast for state mutations
3. Ensure player ID generation is atomic
4. Consider using Registry for player lookups
5. Add tests for concurrent player joins

**Phase Mapping:** Phase 5 - State sync, when adding board state to Worker

---

### PITFALL 23: broadcast! vs broadcast_from! Confusion

**Root Cause:**
Code uses `broadcast!` with `handle_out` filtering instead of `broadcast_from!`.

**Warning Signs:**
- `broadcast!(socket, "player:join", ...)` in game_channel.ex (line 12)
- `handle_out` checks `if socket.assigns.player.id != id` (line 34)
- Pattern works but is indirect

**Impact:**
Low - works but confusing. `handle_out` runs for every client including sender.

**Prevention Strategy:**
1. Prefer `broadcast_from!(socket, event, payload)` to exclude sender automatically
2. Remove `handle_out` clauses that only filter sender
3. Simpler code, less CPU overhead
4. Keep `handle_out` only for transformations, not filtering

**Refactor:**
```elixir
# OLD:
broadcast!(socket, "player:join", %{player: socket.assigns.player})
def handle_out("player:join", %{player: %{id: id}}, socket) do
  if socket.assigns.player.id != id do
    push(socket, "player:join", ...)
  end
end

# NEW:
broadcast_from!(socket, "player:join", %{player: socket.assigns.player})
# No handle_out needed
```

**Phase Mapping:** Phase 3 - Phoenix upgrade, refactoring phase (optional)

---

### PITFALL 24: Missing Error Handling for Malformed Messages

**Root Cause:**
`handle_in` pattern matches expected shape but no catch-all clause.

**Warning Signs:**
- `handle_in("player:change_direction", %{"direction" => direction, "player_id" => player_id}, socket)` (line 28)
- No validation of direction value
- No validation player_id exists
- No catch-all `handle_in` clause

**Impact:**
Malformed client messages crash channel process. All players disconnected.

**Prevention Strategy:**
1. Add catch-all: `def handle_in(_event, _payload, socket), do: {:noreply, socket}`
2. Validate direction is valid enum value
3. Validate player_id matches socket.assigns.player.id (security)
4. Return error tuples instead of crashing: `{:reply, {:error, %{reason: "invalid direction"}}, socket}`

**Phase Mapping:** Phase 3 - Phoenix upgrade, hardening phase

---

## Cross-Cutting Migration Risks

### PITFALL 25: Version Lock-Step Requirement

**Root Cause:**
Can't upgrade Elm and Phoenix independently. Socket communication couples them.

**Warning Signs:**
- Changing Elm breaks socket message format
- Changing Phoenix breaks WebSocket endpoint
- Need both working simultaneously to test

**Impact:**
CRITICAL - Can't incrementally migrate. Big-bang cutover required.

**Prevention Strategy:**
1. Branch strategy: create `upgrade` branch
2. Don't attempt partial migrations on master
3. Keep old version running until new fully working
4. Consider blue-green deployment for production
5. Can't A/B test mixed versions

**Phase Mapping:** All phases - architecture constraint

---

### PITFALL 26: Hard-coded localhost URL

**Root Cause:**
WebSocket URL hard-coded to `ws://localhost:4000/socket/websocket` in Main.elm.

**Warning Signs:**
- String literal in init (Main.elm line 41)
- No environment variable
- No template injection

**Impact:**
Production deployment broken. Can't test on staging. Must rebuild for each environment.

**Prevention Strategy:**
1. During Elm migration, parameterize URL
2. Pass from HTML template via flags:
   ```html
   <script>
   var app = Elm.Main.init({
     node: document.getElementById('elm_target'),
     flags: { socketUrl: window.location.protocol === 'https:' ? 'wss://' : 'ws://' + window.location.host + '/socket/websocket' }
   })
   </script>
   ```
3. Update Elm init signature: `init : { socketUrl : String } -> ( Model, Cmd Msg )`

**Phase Mapping:** Phase 2 - WebSocket replacement, configuration

---

### PITFALL 27: No Rollback Strategy for Data Format Changes

**Root Cause:**
If socket message format changes, old clients can't talk to new server.

**Warning Signs:**
- JSON payload format changes (e.g., adding snake body positions)
- No versioning in messages
- No compatibility layer

**Impact:**
During deployment, connected clients break. Need full refresh.

**Prevention Strategy:**
1. Add version field to all messages: `%{version: 1, ...}`
2. Server handles multiple versions during transition
3. Client checks version, shows "refresh required" if mismatch
4. Graceful degradation: old clients get legacy format
5. Plan deployment: deploy server first, wait for client rollout

**Phase Mapping:** Phase 5 - State sync, message format design

---

### PITFALL 28: Testing Multiplayer in Development

**Root Cause:**
Single developer testing with one browser misses race conditions and sync issues.

**Warning Signs:**
- No automated multiplayer tests
- Manual testing with one client
- Timing bugs only appear with multiple clients

**Impact:**
Bugs found in production. Poor player experience.

**Prevention Strategy:**
1. Test with 2+ browser windows simultaneously during every change
2. Add artificial latency to dev environment (Chrome DevTools throttling)
3. Consider Wallaby/Hound for multi-client integration tests
4. Test rapid join/leave scenarios
5. Test message ordering (direction change before join completes)

**Phase Mapping:** All phases - testing practice

---

### PITFALL 29: Mix Deps Cache Confusion

**Root Cause:**
Cached dependencies from Phoenix 1.3 may conflict with 1.7 after upgrade.

**Warning Signs:**
- Compilation errors about missing modules
- Version conflicts in mix.lock
- Transitive dependencies outdated

**Impact:**
Build failures. Confusing error messages. Time wasted debugging.

**Prevention Strategy:**
1. Before Phoenix upgrade: `mix deps.clean --all`
2. Delete `_build/` directory
3. Delete `mix.lock`
4. Run `mix deps.get` fresh
5. Run `mix compile --force`
6. Check for deprecation warnings: `mix compile --warnings-as-errors`

**Phase Mapping:** Phase 3 - Phoenix upgrade, preparation step

---

### PITFALL 30: npm vs Mix Asset Workflows

**Root Cause:**
Phoenix 1.7 uses mix tasks for assets (`mix assets.deploy`). Brunch used npm scripts.

**Warning Signs:**
- `npm run deploy` in package.json (line 5)
- Deployment docs reference npm commands
- CI/CD scripts use npm

**Impact:**
Production builds fail. Deployment broken.

**Prevention Strategy:**
1. Update to mix-based workflow:
   - Development: `mix phx.server` (auto-runs watchers)
   - Production: `mix assets.deploy`
2. Keep npm scripts for local asset building
3. Update CI/CD to use mix commands
4. Test production build locally: `MIX_ENV=prod mix do compile, assets.deploy, phx.server`

**Phase Mapping:** Phase 4 - Asset pipeline, deployment changes

---

## Summary: Critical Path Pitfalls

These pitfalls MUST be addressed to have a working game:

1. **PITFALL 6** - Native modules forbidden (Elm 0.19)
2. **PITFALL 13** - elm-phoenix-socket replacement
3. **PITFALL 9** - Phoenix.Transports removed
4. **PITFALL 16** - Elm not built-in to esbuild
5. **PITFALL 19** - Client tick timing divergence
6. **PITFALL 20** - Apple generation client-side
7. **PITFALL 21** - Player join without full state

**Risk Level:**
- **HIGH RISK:** Pitfalls 6, 13 (WebSocket rewrite required)
- **MEDIUM RISK:** Pitfalls 9, 16, 19-21 (known solutions exist)
- **LOW RISK:** All others (tactical fixes)

---

*Pitfall analysis: 2026-01-30*
*Project: snaker-elm Elm 0.18→0.19 + Phoenix 1.3→1.7 migration*
