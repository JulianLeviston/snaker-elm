# Technology Stack

**Analysis Date:** 2026-01-30

## Languages

**Primary:**
- Elixir 1.4+ - Backend server and game state management
- Elm 0.18.0 - Frontend client application for game UI

**Secondary:**
- JavaScript - Asset pipeline and build tooling
- HTML/CSS - Static markup and styling

## Runtime

**Environment:**
- Erlang OTP - Elixir runtime (via Mix)
- Node.js - Asset compilation and development tooling

**Package Manager:**
- Mix (Elixir) - Version defined in `mix.exs`
- npm - Node.js dependencies in `assets/package.json`
- Elm package manager - Elm dependencies in `assets/elm` directory

## Frameworks

**Core:**
- Phoenix 1.3.0 - Web framework for HTTP and WebSocket server
- Phoenix PubSub 1.0 - Pub/Sub adapter using PG2
- Phoenix HTML 2.10 - Server-side HTML generation

**Frontend:**
- Elm 0.18.0 - Client-side functional reactive programming framework
- elm-phoenix-socket 2.2.0 - WebSocket communication with Phoenix
- elm-lang/websocket 1.0.2 - Low-level WebSocket support

**Build/Dev:**
- Brunch 2.10.9 - Asset bundler and build tool
- Babel Brunch 6.1.1 - ES6 transpilation
- Elm Brunch 0.9.0 - Elm compiler integration with Brunch
- Clean CSS Brunch 2.10.0 - CSS minification
- UglifyJS Brunch 2.10.0 - JavaScript minification
- Phoenix Live Reload 1.1 - Development hot reload (dev only)

## Key Dependencies

**Critical:**
- phoenix_pubsub ~> 1.0 - Game state broadcasting between clients
- cowboy ~> 1.0 - HTTP server and WebSocket handler
- poison ~> 2.2 or ~> 3.0 - JSON serialization

**Infrastructure:**
- phoenix_html ~> 2.10 - HTML templating utilities
- cowlib ~> 1.0.2 - Cowboy support library
- ranch ~> 1.3.2 - Network socket handling
- gettext ~> 0.11 - Internationalization (configured but minimal use)
- plug ~> 1.3.3 or ~> 1.4 - HTTP middleware

**Development Only:**
- phoenix_live_reload ~> 1.0 - Code reloading during development
- file_system ~> 0.1 - File system monitoring for live reload

## Configuration

**Environment:**
- `config/config.exs` - Base configuration
- `config/dev.exs` - Development overrides (port 4000, code reloader enabled)
- `config/prod.exs` - Production overrides
- `config/test.exs` - Test environment configuration

**Key Configs:**
- Endpoint: `SnakerWeb.Endpoint` listening on port 4000
- WebSocket: `/socket` route for `SnakerWeb.UserSocket`
- PubSub: Phoenix.PubSub.PG2 adapter
- Logger: Console output with metadata

**Brunch Configuration:**
- Config file: `assets/brunch-config.js`
- Elm source folder: `assets/elm`
- Main module: `assets/elm/Main.elm`
- Output: `assets/js/app.js` (compiled Elm and JavaScript bundle)
- Watches: Static assets, CSS, JS, vendor code, and Elm files

## Platform Requirements

**Development:**
- Elixir 1.4+
- Node.js with npm
- Elm 0.18.0
- Mix (Elixir's build tool)

**Production:**
- Elixir/Erlang runtime
- HTTP server compatible with cowboy transport
- Port configuration via environment variable `PORT`

---

*Stack analysis: 2026-01-30*
