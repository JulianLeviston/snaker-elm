# External Integrations

**Analysis Date:** 2026-01-30

## APIs & External Services

**Real-Time Communication:**
- Phoenix Channels WebSocket - Game state synchronization and player coordination
  - SDK/Client: `elm-phoenix-socket` (Elm) / `Phoenix.Channel` (Elixir)
  - URL: `ws://localhost:4000/socket/websocket` (configured in `assets/elm/Main.elm` line 41)
  - Channel: `game:snake` - Primary game channel for all multiplayer communication

## Data Storage

**Databases:**
- Not configured - Database dependencies commented out in `mix.exs` (lines 38-39)
- PostgreSQL client available but disabled: `postgrex ~> 0.13.0` (unused)
- Ecto ORM available but disabled in configuration

**In-Memory State:**
- GenServer `Snaker.Worker` - Maintains game state (players, apples, grid dimensions)
  - Location: `lib/snaker/worker.ex`
  - State model: `%{players: %{}, apples: [], grid_dimensions: %{x: 30, y: 40}}`
  - Not persisted between restarts

**File Storage:**
- Static assets via Plug.Static - Serves from `priv/static` directory
  - Configured in `lib/snaker_web/endpoint.ex` (line 10)
  - Supported formats: CSS, fonts, images, JavaScript, favicon, robots.txt

**Caching:**
- None - All game state is live in-memory via GenServer

## Authentication & Identity

**Auth Provider:**
- Custom / None - No authentication system implemented
- Players identified by numeric ID assigned by `Snaker.Worker.new_player()`
- Socket connection creates anonymous player: `lib/snaker_web/channels/user_socket.ex` lines 23-27
- Player names are randomly generated: `lib/snaker/worker.ex` lines 63-69

**Player Identification:**
- Player ID: Sequential integer assigned on connection
- Player attributes: `id`, `name`, `colour` (hex code)

## Monitoring & Observability

**Error Tracking:**
- None detected - No external error tracking service configured

**Logs:**
- Elixir Logger via Console appender
- Configuration: `config/config.exs` lines 21-24
- Dev format: `[$level] $message\n`
- Production format: `$time $metadata[$level] $message\n`
- Metadata includes `request_id`
- Channel lifecycle events logged in `lib/snaker_web/channels/game_channel.ex` line 25

## CI/CD & Deployment

**Hosting:**
- Not configured - Expected to be deployed as standalone Elixir application
- Port is configurable via `PORT` environment variable: `config/dev.exs` line 10, `lib/snaker_web/endpoint.ex` lines 50-52
- HTTP server: Cowboy 1.0+

**CI Pipeline:**
- None detected - No CI configuration files present

## Environment Configuration

**Required env vars:**
- `PORT` - HTTP server port (required in production per `lib/snaker_web/endpoint.ex` line 51)
- Optional: `MIX_ENV` - Environment selection (dev/prod/test)

**Secrets location:**
- `config/config.exs` - Contains hardcoded `secret_key_base` for session signing (line 16)
- Session signing salt: `"FF8zt4ZZ"` (hardcoded in `lib/snaker_web/endpoint.ex` line 39)

## Webhooks & Callbacks

**Incoming:**
- None - Application does not receive external webhooks

**Outgoing:**
- Phoenix Channel messages - Broadcasts to connected game clients
- Broadcast events:
  - `"player:join"` - New player connected (line 12)
  - `"player:leave"` - Player disconnected (line 24)
  - `"player:change_direction"` - Player direction change (line 29)
- Channel listeners in Elm: `assets/elm/Main.elm` lines 43-46

## WebSocket Message Protocol

**Channel:** `game:snake`

**Server → Client Events:**
- `join` - Player joined successfully with current player data and all connected players
  - Payload: `{status: "connected", player: Player, players: Dict<PlayerId, Player>}`
- `player:join` - New player joined the game
  - Payload: `{player: Player}`
- `player:leave` - Player left the game
  - Payload: `{player: Player}`
- `player:change_direction` - Player changed snake direction
  - Payload: `{player_id: Int, direction: String}`

**Client → Server Events:**
- `player:change_direction` - Send current player's direction change
  - Payload: `{direction: String, player_id: Int}`
  - Implementation: `assets/elm/Main.elm` lines 194-211

---

*Integration audit: 2026-01-30*
