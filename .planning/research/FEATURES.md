# Feature/API Changes: Elm 0.18→0.19 & Phoenix 1.3→1.7

## Executive Summary

This document identifies breaking changes and migration paths for upgrading the snaker-elm project from Elm 0.18 to 0.19 and Phoenix 1.3 to 1.7. Both upgrades involve significant breaking changes that MUST be addressed.

**Impact Level**: HIGH - Multiple critical breaking changes across both frontend and backend.

---

## Elm 0.18 → 0.19 Migration

### 1. Html.program → Browser.* [BREAKING]

**Current State** (Main.elm:299):
```elm
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
```

**Required Change**:
- `Html.program` removed in Elm 0.19
- Must migrate to `Browser.element`, `Browser.document`, or `Browser.application`

**Migration Path**:
```elm
-- New import required
import Browser

-- Replace Html.program with Browser.element
main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
```

**Notes**:
- `Browser.element` is simplest replacement for apps embedded in HTML
- `init` now receives flags parameter (use `\_ ->` if no flags needed)
- Must add explicit type annotation for `main`

---

### 2. Native Modules Removed [BREAKING]

**Current State**:
- Using `fbonetti/elm-phoenix-socket` 2.2.0 which contains Native JavaScript code
- Package depends on `elm-lang/websocket` 1.0.2 (also uses Native code)

**The Problem**:
- ALL Native modules removed from Elm 0.19
- Cannot use packages that contain Native code
- `fbonetti/elm-phoenix-socket` is NOT compatible with Elm 0.19

**Migration Path**:
1. **Option A**: Use ports to communicate with Phoenix Channels via JavaScript
   - Write JavaScript to handle Phoenix Socket connection
   - Use Elm ports for bidirectional communication
   - More boilerplate but full control

2. **Option B**: Use compatible package
   - `saschatimme/elm-phoenix` - Pure Elm 0.19 implementation
   - Actively maintained alternative
   - Different API, requires refactoring

**Recommended**: Option B (saschatimme/elm-phoenix)
- Less boilerplate than ports
- Type-safe Phoenix Channel communication
- Maintained package with Elm 0.19 support

**Example with saschatimme/elm-phoenix**:
```elm
import Phoenix.Socket as Socket
import Phoenix.Channel as Channel
import Phoenix.Push as Push

-- Socket initialization changes slightly but remains similar
socket =
    Socket.init "ws://localhost:4000/socket/websocket"
        |> Socket.withDebug
```

---

### 3. Ports API Changes [BREAKING]

**Current State**:
- No ports currently in use (Main.elm)
- May be used internally by elm-phoenix-socket package

**Changes in 0.19**:
- Port syntax unchanged but type restrictions tightened
- Cannot send/receive Functions, Json.Decode.Value directly
- Must use specific allowed types: String, Int, Float, Bool, Maybe, List, Array, tuples, records

**Migration Path**:
If implementing Phoenix connection via ports:
```elm
-- Outgoing port (Elm → JavaScript)
port sendToChannel : JE.Value -> Cmd msg

-- Incoming port (JavaScript → Elm)
port receiveFromChannel : (JD.Value -> msg) -> Sub msg
```

**Impact**: Low (if using package), High (if implementing custom ports)

---

### 4. Core Library Changes [BREAKING]

**Current Issues in Code**:

#### 4.1. `toString` removed (Main.elm:196)
```elm
-- BEFORE (0.18)
stringDirection = toString direction

-- AFTER (0.19)
-- Must use custom function or String.fromInt/String.fromFloat
stringDirection = directionToString direction
```

**Migration**: Implement type-specific string conversion functions.

#### 4.2. `Keyboard` module removed
**Current State** (Main.elm:6, 266-268):
```elm
import Keyboard

keyboardBoardControlSubscription : Sub Msg
keyboardBoardControlSubscription =
    Keyboard.ups keyCodeToChangeDirectionMsg
```

**Migration Path**:
```elm
-- Use Browser.Events instead
import Browser.Events as Events
import Json.Decode as Decode

keyboardBoardControlSubscription : Sub Msg
keyboardBoardControlSubscription =
    Events.onKeyUp (Decode.map keyCodeToChangeDirectionMsg keyDecoder)

keyDecoder : Decode.Decoder Keyboard.KeyCode
keyDecoder =
    Decode.field "keyCode" Decode.int
```

#### 4.3. `Time` API changes
**Current State** (Main.elm:5, 263):
```elm
import Time

tickBoardSubscription : Sub Msg
tickBoardSubscription =
    Time.every Board.tickDuration (BoardMsg << Board.tickBoardMsg)
```

**Migration Path**:
```elm
-- Time.every signature changed
-- BEFORE: Time.every : Time -> (Time -> msg) -> Sub msg
-- AFTER:  Time.every : Float -> (Posix -> msg) -> Sub msg

tickBoardSubscription : Sub Msg
tickBoardSubscription =
    Time.every Board.tickDuration (BoardMsg << Board.tickBoardMsg)
```

**Note**: Duration now in milliseconds (Float), time values are `Time.Posix` instead of `Float`.

---

### 5. JSON Encoding/Decoding API Changes

**Current State** (Main.elm:16-17):
```elm
import Json.Encode as JE
import Json.Decode as JD
```

**Changes**:
- `JD.andThen` argument order FLIPPED
- Field access functions simplified

**Migration Example** (Main.elm:234-244):
```elm
-- BEFORE (0.18)
(JD.string
    |> JD.andThen
        (\string ->
            case Direction.fromString string of
                Just direction -> JD.succeed direction
                Nothing -> JD.fail "Direction not supplied"
        )
)

-- AFTER (0.19)
(JD.string
    |> JD.andThen
        (\string ->
            case Direction.fromString string of
                Just direction -> JD.succeed direction
                Nothing -> JD.fail "Direction not supplied"
        )
)
```

**Actually this specific code is fine** - but watch for places using old signature:
- 0.18: `andThen : (a -> Decoder b) -> Decoder a -> Decoder b`
- 0.19: `andThen : (a -> Decoder b) -> Decoder a -> Decoder b` (same!)

**Real change**: `Decode.maybe` behavior - now succeeds with `Nothing` on null, fails on invalid JSON.

---

### 6. Package Management [BREAKING]

**Current State**:
- `elm-package.json` file
- Package names like `elm-lang/core`

**Required Changes**:
- `elm-package.json` → `elm.json`
- Different format and structure
- Package names change: `elm-lang/core` → `elm/core`
- Semantic versioning enforced

**Migration**:
```bash
# Elm 0.19 provides migration command
elm init  # Creates new elm.json
```

**New elm.json structure**:
```json
{
    "type": "application",
    "source-directories": ["."],
    "elm-version": "0.19.1",
    "dependencies": {
        "direct": {
            "elm/browser": "1.0.2",
            "elm/core": "1.0.5",
            "elm/html": "1.0.0",
            "elm/json": "1.1.3",
            "elm/time": "1.0.0"
        },
        "indirect": {}
    },
    "test-dependencies": {
        "direct": {},
        "indirect": {}
    }
}
```

---

### 7. New Features & Improvements

#### 7.1. Better Performance
- Smaller asset sizes (typically 30-50% reduction)
- Faster compilation
- Better runtime performance

#### 7.2. Improved Error Messages
- More helpful compiler errors
- Better type mismatch explanations

#### 7.3. Browser Package
- Better separation of concerns
- `Browser.element` for embedded apps
- `Browser.document` for full document control
- `Browser.application` for SPAs with routing

---

## Phoenix 1.3 → 1.7 Migration

### 8. Directory Structure Changes [BREAKING]

**Current State**:
```
lib/
  snaker/              # Business logic
  snaker_web/          # Web interface
    channels/
    controllers/
    views/
assets/                # Frontend assets
  css/
  js/
  elm/
  brunch-config.js
```

**Phoenix 1.7 Structure**:
```
lib/
  snaker/              # Business logic (same)
  snaker_web/          # Web interface
    channels/          # Same location
    controllers/       # Same location
    components/        # NEW: LiveView components
assets/                # REMOVED - assets moved
priv/
  static/              # Compiled assets
```

**NEW in 1.7**:
```
assets/                # Now at root level, not in repo
  js/
  css/
  vendor/
```

**Migration Impact**: Medium
- Most code stays in same locations
- Asset pipeline completely changed
- No structural changes to channels/controllers

---

### 9. Asset Pipeline: Brunch → esbuild [BREAKING]

**Current State** (brunch-config.js):
```javascript
plugins: {
  babel: {
    ignore: [/vendor/]
  },
  elmBrunch: {
    elmFolder: 'elm',
    mainModules: ['Main.elm'],
    outputFolder: '../js'
  }
}
```

**Required Changes**:
1. **Remove Brunch entirely**
   - Delete `brunch-config.js`
   - Remove from `package.json` dependencies

2. **Adopt esbuild**
   - Configured in `config/config.exs`
   - Much faster build times
   - Simpler configuration

**New Configuration** (config/config.exs):
```elixir
config :esbuild,
  version: "0.17.11",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
```

**Elm Integration with esbuild**:
```javascript
// assets/js/app.js
import { Elm } from "../elm/Main.elm"

const app = Elm.Main.init({
  node: document.getElementById("elm-main"),
  flags: {}
})
```

**Build Process**:
- esbuild handles JS bundling
- Separate Elm compilation step
- Both triggered by mix tasks

---

### 10. Endpoint Configuration Changes

**Current State** (endpoint.ex:28):
```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Poison
```

**Required Change**:
- Poison removed from Phoenix 1.7
- Now uses built-in Jason

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Jason  # Changed from Poison
```

**Migration**: Update `mix.exs` to replace Poison with Jason (likely already done by Phoenix).

---

### 11. Socket/Transport Configuration [BREAKING]

**Current State** (user_socket.ex:9):
```elixir
transport :websocket, Phoenix.Transports.WebSocket
```

**Changes in Phoenix 1.7**:
- Transport configuration moved to endpoint
- Socket file simplified

**New Pattern** (endpoint.ex):
```elixir
socket "/socket", SnakerWeb.UserSocket,
  websocket: true,
  longpoll: false
```

**Updated UserSocket**:
```elixir
defmodule SnakerWeb.UserSocket do
  use Phoenix.Socket

  # Channel definitions stay the same
  channel "game:*", SnakerWeb.GameChannel

  # connect/3 stays the same
  def connect(_params, socket, _connect_info) do
    new_player = Worker.new_player()
    socket = assign(socket, :player, new_player)
    {:ok, socket}
  end

  def id(_socket), do: nil
end
```

**Note**: `connect/2` becomes `connect/3` (adds `connect_info` parameter).

---

### 12. Channel API Compatibility [GOOD NEWS]

**Current Code** (game_channel.ex):
```elixir
def join("game:snake", message, socket)
def handle_in("player:change_direction", %{"direction" => direction}, socket)
def handle_out("player:join", %{player: %{id: id}} = msg, socket)
broadcast!(socket, "player:join", %{player: socket.assigns.player})
push(socket, "join", %{status: "connected"})
```

**Migration Impact**: MINIMAL
- Core Channel API remains stable
- `join/3`, `handle_in/3`, `handle_out/3` unchanged
- `broadcast!/3`, `push/3` unchanged
- Channel code requires minimal changes

**Minor Changes**:
- Better telemetry/instrumentation hooks available
- Improved error handling options
- New testing helpers

---

### 13. Dependency Updates [BREAKING]

**Current mix.exs**:
```elixir
{:phoenix, "~> 1.3.0"},
{:phoenix_pubsub, "~> 1.0"},
{:phoenix_html, "~> 2.10"},
{:cowboy, "~> 1.0"}
```

**Required Updates**:
```elixir
{:phoenix, "~> 1.7.0"},
{:phoenix_pubsub, "~> 2.1"},
{:phoenix_html, "~> 3.3"},
{:plug_cowboy, "~> 2.6"},    # Replaces standalone cowboy
{:jason, "~> 1.4"},          # JSON encoder (replaces Poison)
{:esbuild, "~> 0.7", runtime: Mix.env() == :dev}
```

**Additional for Elm**:
```elixir
# May need custom mix task or npm script for Elm compilation
```

---

### 14. GenServer/Worker Code [NO CHANGES]

**Current State** (worker.ex):
- Pure Elixir GenServer
- No Phoenix-specific dependencies

**Migration Impact**: NONE
- GenServer API stable across versions
- Worker code requires no changes
- This is good news!

---

### 15. Configuration Structure Changes

**Current** (likely in `config/config.exs`):
```elixir
config :snaker, SnakerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "...",
  render_errors: [view: SnakerWeb.ErrorView, accepts: ~w(html json)]
```

**Phoenix 1.7 Additions**:
```elixir
config :snaker, SnakerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "...",
  render_errors: [
    formats: [html: SnakerWeb.ErrorHTML, json: SnakerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Snaker.PubSub,
  # NEW: Asset watchers
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    # Add Elm watcher
    elm: {Path.expand("assets/node_modules/.bin/elm"), [
      "make",
      "assets/elm/Main.elm",
      "--output=assets/js/elm.js",
      "--debug"
    ]}
  ]
```

---

### 16. New Phoenix 1.7 Features (Optional Enhancements)

#### 16.1. Verified Routes
- Compile-time route verification
- Type-safe route helpers
- Better refactoring support

#### 16.2. Improved LiveView Integration
- Not currently using LiveView
- Could migrate some real-time features from Channels to LiveView
- Simpler for some use cases

#### 16.3. Tailwind CSS Support
- Default in Phoenix 1.7
- Optional upgrade
- Could simplify styling

#### 16.4. CoreComponents
- Reusable component library
- Not applicable to Elm frontend
- Could use for any server-rendered pages

---

## Migration Checklist

### Elm 0.18 → 0.19
- [ ] Replace `Html.program` with `Browser.element`
- [ ] Migrate from `fbonetti/elm-phoenix-socket` to `saschatimme/elm-phoenix` or ports
- [ ] Replace `toString` with type-specific converters
- [ ] Migrate `Keyboard` module to `Browser.Events`
- [ ] Update `Time` API usage
- [ ] Convert `elm-package.json` to `elm.json`
- [ ] Update package names (elm-lang/* → elm/*)
- [ ] Add type annotations to `main`
- [ ] Test all JSON decoders
- [ ] Update build configuration for Elm 0.19

### Phoenix 1.3 → 1.7
- [ ] Update dependencies in `mix.exs`
- [ ] Replace Poison with Jason
- [ ] Migrate Brunch to esbuild
- [ ] Update socket transport configuration
- [ ] Update `connect/2` to `connect/3` in UserSocket
- [ ] Configure asset watchers in config.exs
- [ ] Set up Elm compilation with esbuild
- [ ] Test all Channel functionality
- [ ] Update error view configuration
- [ ] Test WebSocket connection
- [ ] Verify GenServer worker still functions

### Testing Requirements
- [ ] Test multiplayer game connection
- [ ] Verify player join/leave events
- [ ] Test direction change broadcasts
- [ ] Verify keyboard controls
- [ ] Test game board rendering
- [ ] Verify WebSocket reconnection
- [ ] Performance test (asset size, load time)

---

## Risk Assessment

### High Risk
1. **elm-phoenix-socket migration** - Complete rewrite of socket integration required
2. **Keyboard module removal** - Game controls must be reimplemented
3. **Asset pipeline change** - Build process completely different

### Medium Risk
1. **toString removal** - Multiple locations to update
2. **Browser.* migration** - Core app structure changes
3. **Socket transport config** - Endpoint configuration changes

### Low Risk
1. **Channel API** - Minimal changes required
2. **GenServer code** - No changes needed
3. **JSON decoder updates** - Minor syntax adjustments

---

## Recommended Migration Order

1. **Phase 1: Phoenix Backend** (Lower Risk First)
   - Update mix.exs dependencies
   - Replace Poison with Jason
   - Update socket/transport configuration
   - Test channels in isolation

2. **Phase 2: Build System** (Enable Elm 0.19)
   - Remove Brunch, add esbuild
   - Configure Elm 0.19 compilation
   - Set up asset watchers
   - Verify build pipeline works

3. **Phase 3: Elm Core Migration** (Incremental Updates)
   - Update elm.json
   - Migrate to Browser.element
   - Fix toString usage
   - Update Time/Keyboard modules

4. **Phase 4: Phoenix Socket Integration** (Highest Risk Last)
   - Choose ports vs. elm-phoenix package
   - Implement new socket connection
   - Migrate all channel subscriptions
   - Update message handling

5. **Phase 5: Integration Testing**
   - End-to-end multiplayer testing
   - Performance verification
   - Browser compatibility testing

---

## Additional Resources

### Elm Migration
- Official Elm 0.19 upgrade guide: https://github.com/elm/compiler/blob/master/upgrade-docs/0.19.md
- saschatimme/elm-phoenix package: https://package.elm-lang.org/packages/saschatimme/elm-phoenix/latest/

### Phoenix Migration
- Phoenix 1.7 release notes: https://github.com/phoenixframework/phoenix/blob/v1.7/CHANGELOG.md
- Asset pipeline guide: https://hexdocs.pm/phoenix/asset_management.html
- Channel testing: https://hexdocs.pm/phoenix/testing_channels.html

---

## Summary

Both migrations involve significant breaking changes, but they are well-documented and manageable:

**Elm 0.18 → 0.19**: Primarily affects application structure (Html.program), package ecosystem (Native modules), and standard library (Keyboard, toString). The Phoenix socket integration is the highest-risk item requiring careful planning.

**Phoenix 1.3 → 1.7**: Mainly impacts build tooling (Brunch → esbuild) and configuration. The core Channel API remains stable, which is excellent news for this real-time multiplayer game.

**Total Estimated Effort**: 3-5 days
- Phoenix migration: 1-2 days
- Elm core migration: 1-2 days
- Socket integration: 1 day
- Testing/debugging: 1 day

The incremental approach outlined above minimizes risk by tackling stable components first and leaving the highest-risk socket integration for last when everything else is working.
