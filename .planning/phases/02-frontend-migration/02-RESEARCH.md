# Phase 2: Frontend Migration - Research

**Researched:** 2026-01-31
**Domain:** Elm 0.19.1, esbuild, Phoenix Channels ports, Canvas rendering
**Confidence:** HIGH

## Summary

This phase migrates the frontend from Elm 0.18 with Brunch to Elm 0.19.1 with esbuild, replacing the elm-phoenix-socket effect manager with a ports-based WebSocket architecture. The user has decided on a "clean slate" approach, building fresh Elm 0.19 code rather than migrating existing code.

Key findings:
- **Elm 0.19.1** is the target version, requiring elm.json (not elm-package.json), Browser.element (not Html.program), and Browser.Events for keyboard (not Keyboard module)
- **esbuild-plugin-elm** is the standard solution for compiling Elm within esbuild, integrating cleanly with Phoenix's asset pipeline
- **Ports pattern** is well-established: Phoenix JS client on JavaScript side, typed ports sending Json.Encode.Value to Elm
- **joakin/elm-canvas** is the standard Canvas library for Elm 0.19, requiring a custom element script
- **mpizenberg/elm-pointer-events** handles unified touch/mouse input for the virtual D-pad

**Primary recommendation:** Use esbuild with esbuild-plugin-elm, TypeScript for the socket.js module, and define one port per event type passing Json.Decode.Value for maximum type safety.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| elm | 0.19.1 | Elm compiler | Current stable, fixes bugs from 0.19.0 |
| elm/browser | 1.0.2 | Browser integration | Official package for Browser.element, Browser.Events |
| elm/json | 1.1.3 | JSON encoding/decoding | Required for port communication |
| elm/html | 1.0.0 | HTML rendering | Official DOM library |
| joakin/elm-canvas | 5.0.0 | Canvas rendering | Only maintained Canvas library for Elm 0.19 |
| esbuild | latest | JS bundler | Phoenix 1.7+ standard, extremely fast |
| esbuild-plugin-elm | 0.4.x | Elm compilation | Standard esbuild-Elm integration |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| mpizenberg/elm-pointer-events | 5.0.0 | Touch/pointer events | Virtual D-pad, mobile input |
| elm/time | 1.0.0 | Time handling | Animation timing, debouncing |
| elm/random | 1.0.0 | Random generation | Only if needed client-side |
| typescript | 5.x | Type-safe JS | socket.js with strict mode |
| elm-pep | latest | Pointer events polyfill | Safari/Firefox < 59 support |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| esbuild-plugin-elm | Direct elm make in watcher | More control but more config |
| elm-ts-interop | Manual port types | elm-ts-interop adds build step but guarantees type sync |
| elm-canvas | SVG rendering | Canvas better for 60fps game rendering |

**Installation:**
```bash
# In assets directory
npm install esbuild esbuild-plugin-elm typescript --save-dev
npm install elm-canvas --save

# Elm packages
elm install elm/browser
elm install elm/json
elm install elm/html
elm install elm/time
elm install joakin/elm-canvas
elm install mpizenberg/elm-pointer-events
```

## Architecture Patterns

### Recommended Project Structure
```
assets/
├── js/
│   ├── app.ts              # Entry point, initializes Elm app
│   └── socket.ts           # Phoenix socket connection, port wiring
├── elm/
│   └── src/
│       ├── Main.elm        # Browser.element entry point
│       ├── Ports.elm       # Port module with all port definitions
│       ├── Game.elm        # Game state and update logic
│       ├── Snake.elm       # Snake data types and helpers
│       ├── Input.elm       # Input handling (keyboard + touch)
│       ├── Render.elm      # Canvas rendering logic
│       └── Theme.elm       # Modern/retro theme definitions
├── elm.json                # Elm 0.19 project config
├── package.json            # Node dependencies
├── tsconfig.json           # TypeScript configuration
└── build.js                # Custom esbuild script
```

### Pattern 1: Port Module Organization
**What:** Single port module with all incoming/outgoing ports
**When to use:** Always - keeps all JS interop in one place
**Example:**
```elm
-- Source: Elm official ports guide
port module Ports exposing (..)

import Json.Decode as JD
import Json.Encode as JE

-- Outgoing (Commands)
port joinGame : JE.Value -> Cmd msg
port sendDirection : JE.Value -> Cmd msg
port leaveGame : () -> Cmd msg

-- Incoming (Subscriptions)
port receiveGameState : (JD.Value -> msg) -> Sub msg
port receiveError : (String -> msg) -> Sub msg
port playerJoined : (JD.Value -> msg) -> Sub msg
port playerLeft : (JD.Value -> msg) -> Sub msg
```

### Pattern 2: Phoenix Socket TypeScript Module
**What:** Dedicated socket.ts handling WebSocket lifecycle and port wiring
**When to use:** Phoenix Channels with Elm ports
**Example:**
```typescript
// Source: Phoenix JS docs + ports pattern
import { Socket, Channel } from "phoenix";

interface ElmApp {
  ports: {
    joinGame: { subscribe: (callback: (data: unknown) => void) => void };
    sendDirection: { subscribe: (callback: (data: unknown) => void) => void };
    receiveGameState: { send: (data: unknown) => void };
    receiveError: { send: (message: string) => void };
    playerJoined: { send: (data: unknown) => void };
    playerLeft: { send: (data: unknown) => void };
  };
}

export function connectSocket(app: ElmApp): void {
  const socket = new Socket("/socket", {});
  socket.connect();

  let channel: Channel | null = null;

  app.ports.joinGame.subscribe((payload) => {
    channel = socket.channel("game:snake", payload as object);

    channel.on("game_state", (state) => {
      app.ports.receiveGameState.send(state);
    });

    channel.on("player_joined", (data) => {
      app.ports.playerJoined.send(data);
    });

    channel.join()
      .receive("ok", (resp) => app.ports.receiveGameState.send(resp))
      .receive("error", (resp) => app.ports.receiveError.send(resp.reason));
  });

  app.ports.sendDirection.subscribe((direction) => {
    channel?.push("change_direction", direction as object);
  });
}
```

### Pattern 3: Browser.element Initialization
**What:** Elm 0.19 app initialization with ports and flags
**When to use:** All Elm 0.19 applications with JS interop
**Example:**
```elm
-- Source: Elm Browser package docs
module Main exposing (main)

import Browser
import Ports

main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.receiveGameState GotGameState
        , Ports.receiveError GotError
        , Browser.Events.onKeyDown keyDecoder
        , Browser.Events.onAnimationFrameDelta AnimationFrame
        ]
```

### Pattern 4: Keyboard Input with Browser.Events
**What:** Decode keyboard events using Browser.Events.onKeyDown
**When to use:** Game input, replacing old Keyboard module
**Example:**
```elm
-- Source: Elm browser keyboard notes
import Browser.Events
import Json.Decode as JD

type Direction = Up | Down | Left | Right

keyDecoder : JD.Decoder Msg
keyDecoder =
    JD.field "key" JD.string
        |> JD.andThen toDirection

toDirection : String -> JD.Decoder Msg
toDirection key =
    case key of
        "ArrowUp" -> JD.succeed (ChangeDirection Up)
        "ArrowDown" -> JD.succeed (ChangeDirection Down)
        "ArrowLeft" -> JD.succeed (ChangeDirection Left)
        "ArrowRight" -> JD.succeed (ChangeDirection Right)
        "w" -> JD.succeed (ChangeDirection Up)
        "s" -> JD.succeed (ChangeDirection Down)
        "a" -> JD.succeed (ChangeDirection Left)
        "d" -> JD.succeed (ChangeDirection Right)
        _ -> JD.fail "not a direction key"

subscriptions : Model -> Sub Msg
subscriptions _ =
    Browser.Events.onKeyDown keyDecoder
```

### Anti-Patterns to Avoid
- **Using Html.program:** Removed in Elm 0.19, use Browser.element
- **Effect managers (elm-phoenix-socket):** Not allowed in Elm 0.19 for user packages
- **Keyboard module:** Removed, use Browser.Events.onKeyDown with decoder
- **Tuple constructor (,):** Use Tuple.pair in Elm 0.19
- **toString on custom types:** Removed, implement custom toString functions
- **Partial custom type imports:** `exposing (Type(A,B))` not allowed, use `exposing (Type(..))`

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Phoenix WebSocket client | Custom WebSocket wrapper | Phoenix JS client | Handles reconnection, heartbeats, channel multiplexing |
| Canvas drawing | Raw canvas ports | joakin/elm-canvas | Custom element handles canvas lifecycle |
| Touch events | Manual touchstart/end | mpizenberg/elm-pointer-events | Unified pointer API, handles edge cases |
| JSON decode/encode for ports | Inline decoding | Dedicated decoder modules | Reusable, testable, maintainable |
| Animation timing | setInterval ports | Browser.Events.onAnimationFrame | Syncs with browser repaint cycle |
| Keyboard event parsing | Manual keyCode handling | Decode "key" field | keyCode deprecated, key is modern standard |

**Key insight:** Elm 0.19 removed effect managers from user packages, making ports the only interop mechanism. Use the Phoenix JS client directly in TypeScript/JavaScript rather than trying to wrap it in Elm.

## Common Pitfalls

### Pitfall 1: Forgetting elm-canvas Custom Element
**What goes wrong:** Canvas renders as empty, no errors shown
**Why it happens:** elm-canvas requires a custom element script loaded before Elm initializes
**How to avoid:** Include elm-canvas.js in HTML before Elm app script
**Warning signs:** Canvas element visible but nothing draws

```html
<!-- Must come BEFORE app.js -->
<script src="https://unpkg.com/elm-canvas@5.0.0/elm-canvas.js"></script>
<script src="/assets/app.js"></script>
```

### Pitfall 2: Tuple Syntax Changes
**What goes wrong:** Compile errors on tuple creation
**Why it happens:** `(a, b)` constructor syntax changed in 0.19
**How to avoid:** Use `Tuple.pair a b` or direct tuple literals
**Warning signs:** Error about `(,)` not being a function

```elm
-- Old (0.18)
JD.map2 (,) decoder1 decoder2

-- New (0.19)
JD.map2 Tuple.pair decoder1 decoder2
```

### Pitfall 3: Port Type Restrictions
**What goes wrong:** Compile error about unsupported port types
**Why it happens:** Ports only support certain types (not custom types directly)
**How to avoid:** Use Json.Encode.Value and decode in Elm, or encode in JS
**Warning signs:** "Port ... has an Portal type" error

```elm
-- Won't work: custom type through port
port receiveDirection : (Direction -> msg) -> Sub msg

-- Works: JSON value, decode in Elm
port receiveDirection : (JD.Value -> msg) -> Sub msg
```

### Pitfall 4: Browser.Events.onKeyDown Fires Repeatedly
**What goes wrong:** Direction changes many times per key press
**Why it happens:** Key repeat when key held down
**How to avoid:** Track key state, only emit on initial press, or debounce
**Warning signs:** Snake rapidly changing direction while key held

```elm
-- Solution: track pressed keys in model, ignore repeats
type alias Model = { pressedKeys : Set String, ... }

-- Or decode repeat field
keyDecoder =
    JD.map2 Tuple.pair
        (JD.field "key" JD.string)
        (JD.field "repeat" JD.bool)
    |> JD.andThen (\(key, repeat) ->
        if repeat then JD.fail "repeat" else toDirection key)
```

### Pitfall 5: Missing Pointer Events Polyfill
**What goes wrong:** Touch D-pad not working in Safari
**Why it happens:** Safari lacks native Pointer Events API
**How to avoid:** Include elm-pep polyfill
**Warning signs:** Works in Chrome, fails in Safari

### Pitfall 6: esbuild Not Finding Elm
**What goes wrong:** Build fails with "elm not found"
**Why it happens:** esbuild-plugin-elm expects elm in PATH or node_modules
**How to avoid:** Install elm via npm or configure pathToElm option
**Warning signs:** "ENOENT: no such file or directory, spawn elm"

```javascript
// build.js
ElmPlugin({
  pathToElm: './node_modules/.bin/elm'  // Or rely on mise/asdf
})
```

## Code Examples

Verified patterns from official sources:

### Elm 0.19 elm.json Structure
```json
{
    "type": "application",
    "source-directories": ["src"],
    "elm-version": "0.19.1",
    "dependencies": {
        "direct": {
            "elm/browser": "1.0.2",
            "elm/core": "1.0.5",
            "elm/html": "1.0.0",
            "elm/json": "1.1.3",
            "elm/time": "1.0.0",
            "joakin/elm-canvas": "5.0.0",
            "mpizenberg/elm-pointer-events": "5.0.0"
        },
        "indirect": {
            "elm/url": "1.0.0",
            "elm/virtual-dom": "1.0.3"
        }
    },
    "test-dependencies": {
        "direct": {},
        "indirect": {}
    }
}
```

### esbuild Build Script with Elm Plugin
```javascript
// assets/build.js
// Source: esbuild-plugin-elm README
const esbuild = require('esbuild');
const ElmPlugin = require('esbuild-plugin-elm');

const isProduction = process.env.NODE_ENV === 'production';
const isWatch = process.argv.includes('--watch');

async function build() {
  const ctx = await esbuild.context({
    entryPoints: ['js/app.ts'],
    bundle: true,
    outdir: '../priv/static/assets',
    target: 'es2020',
    sourcemap: !isProduction,
    minify: isProduction,
    plugins: [
      ElmPlugin({
        debug: !isProduction,
        optimize: isProduction,
        clearOnWatch: true
      })
    ]
  });

  if (isWatch) {
    await ctx.watch();
    console.log('Watching for changes...');
  } else {
    await ctx.rebuild();
    await ctx.dispose();
  }
}

build().catch(() => process.exit(1));
```

### Phoenix dev.exs Watcher Configuration
```elixir
# config/dev.exs
config :snaker, SnakerWeb.Endpoint,
  watchers: [
    node: ["build.js", "--watch", cd: Path.expand("../assets", __DIR__)]
  ]
```

### Canvas Rendering Pattern
```elm
-- Source: joakin/elm-canvas examples
import Canvas exposing (..)
import Canvas.Settings exposing (..)
import Canvas.Settings.Advanced exposing (..)
import Color

renderGame : Model -> Html Msg
renderGame model =
    Canvas.toHtml ( model.width, model.height )
        [ Html.Attributes.style "display" "block" ]
        (renderBackground model.theme
            :: renderSnakes model.snakes model.theme
            ++ renderApples model.apples model.theme
        )

renderBackground : Theme -> Renderable
renderBackground theme =
    shapes [ fill theme.backgroundColor ]
        [ rect ( 0, 0 ) (toFloat width) (toFloat height) ]

renderSnake : Snake -> Theme -> List Renderable
renderSnake snake theme =
    List.map (renderSegment theme) snake.body

renderSegment : Theme -> Position -> Renderable
renderSegment theme pos =
    shapes [ fill theme.snakeColor ]
        [ rect ( toFloat pos.x * cellSize, toFloat pos.y * cellSize )
            cellSize cellSize
        ]
```

### Virtual D-Pad with Pointer Events
```elm
-- Source: mpizenberg/elm-pointer-events
import Html.Events.Extra.Pointer as Pointer

viewDPad : Html Msg
viewDPad =
    div [ class "dpad" ]
        [ button
            [ Pointer.onDown (\_ -> ChangeDirection Up)
            , class "dpad-up"
            ]
            []
        , button
            [ Pointer.onDown (\_ -> ChangeDirection Left)
            , class "dpad-left"
            ]
            []
        , button
            [ Pointer.onDown (\_ -> ChangeDirection Right)
            , class "dpad-right"
            ]
            []
        , button
            [ Pointer.onDown (\_ -> ChangeDirection Down)
            , class "dpad-down"
            ]
            []
        ]
```

### Animation Frame for 60fps Rendering
```elm
-- Source: Browser.Events docs
import Browser.Events

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Browser.Events.onAnimationFrameDelta AnimationFrame
        , -- other subscriptions
        ]

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AnimationFrame delta ->
            -- delta is milliseconds since last frame (ideally ~16.67 for 60fps)
            ( interpolateTowardServerState delta model, Cmd.none )
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Brunch build | esbuild | Phoenix 1.6 (2021) | 10-100x faster builds |
| elm-phoenix-socket | Ports + Phoenix JS | Elm 0.19 (2018) | Effect managers removed |
| Keyboard module | Browser.Events.onKeyDown | Elm 0.19 (2018) | Use decoder pattern |
| Html.program | Browser.element | Elm 0.19 (2018) | New architecture |
| elm-package.json | elm.json | Elm 0.19 (2018) | Direct/indirect deps |
| keyCode | key field | DOM Level 3 | keyCode deprecated |
| toString | Debug.toString or custom | Elm 0.19 (2018) | No generic toString |

**Deprecated/outdated:**
- **elm-phoenix-socket:** Effect manager, incompatible with Elm 0.19
- **Brunch:** Phoenix moved to esbuild in 1.6
- **Keyboard module (elm-lang/keyboard):** Removed in 0.19, use Browser.Events
- **AnimationFrame module:** Moved to Browser.Events.onAnimationFrame

## Open Questions

Things that couldn't be fully resolved:

1. **Projection-based rendering timing**
   - What we know: Server sends 5+ tick projections, clients interpolate
   - What's unclear: Exact interpolation algorithm for smooth 60fps from 10Hz ticks
   - Recommendation: Start with linear interpolation, iterate based on feel

2. **Input cutoff implementation**
   - What we know: Direction change before 50ms applies this tick
   - What's unclear: Whether to track on client or let server enforce
   - Recommendation: Client sends timestamp, server decides application

3. **Theme toggle persistence**
   - What we know: Modern/retro themes with toggle
   - What's unclear: Whether to persist preference (localStorage? server?)
   - Recommendation: Start with localStorage via port, simple and immediate

4. **elm-ts-interop adoption**
   - What we know: Provides compile-time type safety between Elm and TS
   - What's unclear: Whether added complexity is worth it for this project
   - Recommendation: Start without it (manual types), add if port count grows

## Sources

### Primary (HIGH confidence)
- [Elm Ports Guide](https://guide.elm-lang.org/interop/ports.html) - Official port documentation
- [Elm Browser Package](https://package.elm-lang.org/packages/elm/browser/latest/Browser) - Browser.element API
- [Phoenix Asset Management](https://hexdocs.pm/phoenix/asset_management.html) - Official esbuild docs
- [Phoenix JS Client](https://hexdocs.pm/phoenix/js/) - Socket/Channel API
- [esbuild-plugin-elm README](https://github.com/phenax/esbuild-plugin-elm) - Plugin configuration
- [Browser.Events keyboard notes](https://github.com/elm/browser/blob/1.0.2/notes/keyboard.md) - Key decoding patterns
- [joakin/elm-canvas](https://package.elm-lang.org/packages/joakin/elm-canvas/latest/) - Canvas API
- [mpizenberg/elm-pointer-events](https://package.elm-lang.org/packages/mpizenberg/elm-pointer-events/latest/) - Touch handling

### Secondary (MEDIUM confidence)
- [Elm 0.18 to 0.19 Upgrade Notes](https://www.paulfioravanti.com/blog/elm-018-019-upgrade-notes/) - Migration patterns
- [elm-ts-interop](https://elm-ts-interop.com/) - TypeScript interop tool
- [paulstatezny/elm-phoenix-websocket-ports](https://github.com/paulstatezny/elm-phoenix-websocket-ports) - Ports pattern example

### Tertiary (LOW confidence)
- Various Elm Discourse threads on WebSocket approaches
- Community blog posts on migration experiences

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official packages, well-documented
- Architecture: HIGH - Established patterns from official docs
- Pitfalls: HIGH - Well-known migration issues, documented extensively
- Rendering/Animation: MEDIUM - elm-canvas well-maintained but less documented
- Input handling: MEDIUM - elm-pointer-events works but polyfill needed

**Research date:** 2026-01-31
**Valid until:** 60 days (Elm ecosystem stable, Phoenix 1.7 mature)
