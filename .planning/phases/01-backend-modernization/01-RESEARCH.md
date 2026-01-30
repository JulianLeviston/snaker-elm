# Phase 1: Backend Modernization - Research

**Researched:** 2026-01-31
**Domain:** Phoenix Framework Upgrade (1.3 → 1.7), Server-Authoritative Game Architecture, Environment Management
**Confidence:** HIGH

## Summary

Phase 1 involves upgrading a Phoenix 1.3 application running on Elixir 1.4 to Phoenix 1.7 with Elixir 1.15+, while implementing server-authoritative game state management. The research reveals this requires a multi-step upgrade path through Phoenix versions 1.4, 1.5, 1.6, and finally 1.7, with major breaking changes at each step.

The current codebase has a basic client-authoritative architecture where the server only tracks player metadata (color, name) and broadcasts direction changes. The new architecture requires moving all game logic (snake movement, collision detection, apple spawning) to a server-side GenServer with a 100ms tick loop broadcasting delta updates.

**Primary recommendation:** Use a staged upgrade approach (1.3→1.4→1.7 minimum), migrate to Jason early, establish mise environment management first, then implement server-authoritative game loop using GenServer with Process.send_after pattern and Phoenix.PubSub for delta broadcasts.

## Standard Stack

The established libraries/tools for this domain:

### Core Dependencies
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix | 1.7.x | Web framework | Target version; requires Elixir 1.11+ |
| Elixir | 1.15+ | Language runtime | Exceeds Phoenix 1.7 minimum (1.11), recommended for current projects |
| Erlang/OTP | 24+ | Runtime platform | Required for Elixir 1.15 compatibility |
| Jason | ~> 1.0 | JSON encoding/decoding | Default in Phoenix 1.4+, replaces Poison; 2x faster |
| Plug Cowboy | ~> 2.0 | HTTP server adapter | Replaces standalone :cowboy in Phoenix 1.4+ |
| Phoenix PubSub | ~> 2.0 | Real-time messaging | Built-in broadcast mechanism for channels |

### Supporting Tools
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| mise | latest | Environment/version manager | Replaces asdf; faster, unified tool management |
| PhoenixDiff | N/A (web tool) | Visual upgrade diff tool | Compare Phoenix versions at phoenixdiff.org |
| Phoenix Live Reload | ~> 1.0 | Development hot-reload | Keep for dev environment (already present) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Jason | Poison | Poison is legacy; Jason is 2x faster, more spec-compliant |
| mise | asdf | asdf works but mise is faster, has better UX |
| Process.send_after | :timer.send_interval | Both work; send_after is more idiomatic in GenServer init |
| GenServer tick loop | Quantum/Oban | Quantum/Oban are for scheduled jobs, not real-time game loops |

**Installation (after upgrade):**
```bash
# mise setup
curl -fsSL https://mise.run/install.sh | sh  # Linux
# or
brew install mise  # macOS

# Dependencies already in mix.exs after upgrade
mix deps.get
```

## Architecture Patterns

### Current Architecture (Phoenix 1.3, Client-Authoritative)
```
lib/snaker/
├── worker.ex                    # GenServer: only player metadata
lib/snaker_web/
├── channels/
│   ├── user_socket.ex          # Socket with transport macro (deprecated)
│   └── game_channel.ex         # Broadcasts direction changes only
```

**Current flow:** Client simulates game → sends direction changes → server broadcasts to other clients → each client maintains own game state (causes desync bug)

### Target Architecture (Phoenix 1.7, Server-Authoritative)
```
lib/snaker/
├── application.ex              # Supervision tree
├── game_server.ex              # NEW: Authoritative game state + tick loop
└── game/                       # NEW: Pure game logic modules
    ├── snake.ex                # Snake movement, collision
    ├── apple.ex                # Apple spawning
    └── grid.ex                 # Grid boundaries, safe spawn positions
lib/snaker_web/
├── endpoint.ex                 # Socket configuration (no transport macro)
├── channels/
│   ├── user_socket.ex          # Simplified: connect/id only
│   └── game_channel.ex         # Input validation, broadcast responses
```

**New flow:** Client sends input → GameServer validates → GameServer ticks (100ms) → broadcasts delta → clients render state

### Pattern 1: Server-Authoritative Game Loop with GenServer
**What:** Single GenServer maintains authoritative game state, ticks at fixed interval (100ms), broadcasts delta updates via Phoenix.PubSub

**When to use:** Real-time multiplayer games requiring synchronized state (snake, pong, etc.)

**Example:**
```elixir
# Source: https://elixircasts.io/recurring-work-with-genserver
# https://fly.io/blog/building-a-distributed-turn-based-game-system-in-elixir/

defmodule Snaker.GameServer do
  use GenServer
  @tick_interval 100  # 10 ticks/second

  def init(state) do
    schedule_tick()
    {:ok, state}
  end

  def handle_info(:tick, state) do
    new_state =
      state
      |> move_snakes()
      |> check_collisions()
      |> spawn_apples()
      |> calculate_delta(state)

    broadcast_delta(new_state.delta)
    schedule_tick()
    {:noreply, new_state}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp broadcast_delta(delta) do
    Phoenix.PubSub.broadcast(Snaker.PubSub, "game:snake", {:tick, delta})
  end
end
```

### Pattern 2: Delta-Only Broadcasts
**What:** Only send changed data each tick, not full state; send full state on join

**When to use:** Bandwidth optimization for frequent updates (tick-based games)

**Example:**
```elixir
# Full state on join
def handle_in("join", _params, socket) do
  state = GameServer.get_full_state()
  push(socket, "init", state)
  {:noreply, socket}
end

# Delta on tick
def handle_info({:tick, delta}, socket) do
  # delta = %{
  #   moved: [%{id: 1, new_head: {5, 10}}],
  #   died: [2],
  #   apples_eaten: [%{id: 3, apple_pos: {8, 8}}],
  #   apples_spawned: [%{pos: {12, 15}}]
  # }
  push(socket, "delta", delta)
  {:noreply, socket}
end
```

### Pattern 3: Phoenix 1.7 Socket Configuration (Endpoint, not Transport Macro)
**What:** Configure WebSocket/longpoll options on socket declaration in endpoint.ex, not in user_socket.ex

**When to use:** Phoenix 1.4+ (transport macro removed)

**Example:**
```elixir
# Source: https://gist.github.com/chrismccord/bb1f8b136f5a9e4abc0bfc07b832257e
# lib/snaker_web/endpoint.ex
socket "/socket", SnakerWeb.UserSocket,
  websocket: true,
  longpoll: false

# lib/snaker_web/channels/user_socket.ex (simplified)
defmodule SnakerWeb.UserSocket do
  use Phoenix.Socket

  channel "game:*", SnakerWeb.GameChannel

  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
```

### Pattern 4: Input Validation and Rate Limiting
**What:** Server validates client input (no 180° turns), processes first input per tick

**When to use:** Prevent cheating and handle network latency

**Example:**
```elixir
def handle_in("change_direction", %{"direction" => dir}, socket) do
  player_id = socket.assigns.player_id

  # Validate direction change (no reversals)
  case GameServer.change_direction(player_id, dir) do
    :ok -> {:reply, :ok, socket}
    {:error, :invalid_direction} -> {:reply, {:error, "Invalid direction"}, socket}
    {:error, :rate_limited} -> {:noreply, socket}  # Already changed this tick
  end
end
```

### Anti-Patterns to Avoid
- **Broadcasting full game state every tick:** Wastes bandwidth; use delta updates
- **Client-side game simulation with server replication:** Causes desync (current bug); server must be authoritative
- **Using :timer.send_interval in init/1:** Returns PID reference; Process.send_after is more idiomatic and returns message reference
- **Upgrading Phoenix in single jump (1.3 → 1.7):** High risk of missing breaking changes; step through at least 1.4
- **Hand-rolling WebSocket protocol:** Phoenix Channels handles reconnection, presence, etc.
- **Storing game state in channel process:** Channels are per-client; game state must be centralized in GameServer

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Periodic game ticks | Custom timer loop | Process.send_after pattern | Handles process crashes, easy to test, idiomatic Elixir |
| Broadcasting to players | Manual WebSocket sends | Phoenix.PubSub.broadcast | Handles subscriptions, disconnects, distributed nodes |
| Player disconnect detection | Heartbeat/ping system | Channel terminate/2 callback | Phoenix tracks connection state automatically |
| Safe spawn position | Random-and-retry | Grid traversal with occupied check | Random can infinite loop; systematic search guarantees result |
| Collision detection library | Custom geometry code | Built-in list/grid checks (simple game) | Snake is grid-based; complexity libraries (Collidex) overkill |
| Version management | Manual installs | mise (or asdf) | Handles Erlang/Elixir/Node, team sync via .mise.toml |
| JSON encoding | String concatenation | Jason library | Handles escaping, encoding, performance (2x Poison) |

**Key insight:** Phoenix Channels and GenServer patterns are battle-tested for real-time games. Don't build custom solutions for connection management, state synchronization, or periodic ticks—these are solved problems in the Elixir ecosystem.

## Common Pitfalls

### Pitfall 1: Skipping Intermediate Phoenix Versions
**What goes wrong:** Upgrading directly from 1.3 to 1.7 causes compounding breaking changes (transport macro, view deprecation, flash API, JSON library) that are difficult to debug simultaneously.

**Why it happens:** Developers see "just update mix.exs version" and skip reading changelogs.

**How to avoid:** Minimum path is 1.3 → 1.4 → 1.7. Each step has official upgrade guide. Run tests after each step.

**Warning signs:**
- "Module Phoenix.View is not loaded" (1.7 change)
- "transport/3 is undefined" (1.4 change)
- "json_decoder: Poison" still in config (1.4 should use Jason)

### Pitfall 2: Ignoring Elixir Version Requirements
**What goes wrong:** Phoenix 1.7 requires Elixir 1.11+. Old Elixir 1.4 won't compile Phoenix 1.7.

**Why it happens:** Focusing on Phoenix upgrade, forgetting runtime dependencies.

**How to avoid:** Upgrade Elixir first via mise. Verify `elixir --version` before changing Phoenix version.

**Warning signs:** Compilation errors about syntax or missing functions (e.g., def with guards).

### Pitfall 3: Game State Desync (Current Architecture Bug)
**What goes wrong:** Each client simulates game independently → latency causes different states → snakes appear in different positions per player.

**Why it happens:** Client-authoritative architecture is simpler initially but doesn't scale to multiplayer.

**How to avoid:** Move ALL game logic to server. Clients are "dumb terminals" that render server state.

**Warning signs:**
- Players report "I didn't hit that wall!"
- Different players see different apple positions
- Replay/spectator mode impossible (no single source of truth)

### Pitfall 4: Broadcasting Inside Tick Loop Without Rate Limiting
**What goes wrong:** Broadcasting full game state to 100 players every 100ms = 1000 messages/second → network/scheduler overload.

**Why it happens:** "Just broadcast the state" seems simple but doesn't consider message volume.

**How to avoid:**
- Delta updates (only changes)
- Topic segmentation (per-game rooms, not global)
- Full state only on join

**Warning signs:**
- Increasing latency as players join
- BEAM scheduler warnings
- Network bandwidth spikes

### Pitfall 5: Not Handling Player Disconnect in Game State
**What goes wrong:** Player disconnects but snake stays in game → blocks spaces, causes phantom collisions.

**Why it happens:** Forgot to clean up game state in channel terminate/2.

**How to avoid:** Always remove player from GameServer in terminate/2 callback.

**Warning signs:**
- "Ghost snakes" that don't move but cause collisions
- Player count doesn't decrease when players leave

### Pitfall 6: Testing Tick-Based Logic Without Controlling Time
**What goes wrong:** Tests that rely on Process.send_after are flaky (timing-dependent).

**Why it happens:** Real timers in tests cause non-deterministic behavior.

**How to avoid:**
- Expose tick trigger as separate function for tests
- Test game logic (move_snakes, check_collisions) separately from tick scheduling
- Use `send(pid, :tick)` in tests instead of waiting for timer

**Warning signs:** Tests pass locally, fail in CI; intermittent failures.

### Pitfall 7: Poison Still Configured After Migration
**What goes wrong:** Phoenix 1.4+ defaults to Jason, but Plug.Parsers might still reference Poison.

**Why it happens:** Multiple config locations (endpoint, config.exs).

**How to avoid:**
- Search codebase for "Poison" after upgrade
- Configure `:json_library, Jason` in config.exs
- Update Plug.Parsers json_decoder

**Warning signs:** JSON encoding errors; "Poison not found" in production.

## Code Examples

Verified patterns from official sources:

### GameServer with Tick Loop
```elixir
# Source: https://elixircasts.io/recurring-work-with-genserver
# Pattern: Process.send_after for recurring work

defmodule Snaker.GameServer do
  use GenServer
  require Logger

  @tick_interval 100  # 10 ticks/second

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def change_direction(player_id, direction) do
    GenServer.call(__MODULE__, {:change_direction, player_id, direction})
  end

  def join_game(player_data) do
    GenServer.call(__MODULE__, {:join, player_data})
  end

  def leave_game(player_id) do
    GenServer.cast(__MODULE__, {:leave, player_id})
  end

  # Server Callbacks
  def init(opts) do
    state = %{
      players: %{},
      snakes: %{},
      apples: [],
      grid: {30, 40},
      input_buffer: %{}  # player_id => direction (first input per tick)
    }
    schedule_tick()
    {:ok, state}
  end

  def handle_call({:change_direction, player_id, direction}, _from, state) do
    # Rate limit: only accept first direction change per tick
    if Map.has_key?(state.input_buffer, player_id) do
      {:reply, {:error, :rate_limited}, state}
    else
      # Validate no 180° reversal
      current_dir = get_in(state, [:snakes, player_id, :direction])
      if valid_direction_change?(current_dir, direction) do
        new_state = put_in(state, [:input_buffer, player_id], direction)
        {:reply, :ok, new_state}
      else
        {:reply, {:error, :invalid_direction}, state}
      end
    end
  end

  def handle_call({:join, player_data}, _from, state) do
    player_id = player_data.id
    spawn_pos = find_safe_spawn(state)

    snake = %{
      id: player_id,
      segments: [spawn_pos],  # Head only at start
      direction: :right,
      invincible_until: System.monotonic_time(:millisecond) + 2000
    }

    new_state =
      state
      |> put_in([:players, player_id], player_data)
      |> put_in([:snakes, player_id], snake)

    full_state = serialize_full_state(new_state)
    {:reply, {:ok, full_state}, new_state}
  end

  def handle_cast({:leave, player_id}, state) do
    new_state =
      state
      |> update_in([:players], &Map.delete(&1, player_id))
      |> update_in([:snakes], &Map.delete(&1, player_id))
    {:noreply, new_state}
  end

  def handle_info(:tick, state) do
    # Apply buffered input
    state_with_inputs = apply_input_buffer(state)

    # Run game tick
    {new_state, delta} =
      state_with_inputs
      |> move_all_snakes()
      |> check_collisions()
      |> update_apples()
      |> calculate_delta(state)

    # Broadcast delta
    Phoenix.PubSub.broadcast(Snaker.PubSub, "game:snake", {:tick, delta})

    # Clear input buffer and schedule next tick
    new_state = %{new_state | input_buffer: %{}}
    schedule_tick()

    {:noreply, new_state}
  end

  # Private helpers
  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp valid_direction_change?(current, new) do
    # Prevent 180° reversals
    opposites = %{up: :down, down: :up, left: :right, right: :left}
    opposites[current] != new
  end

  defp find_safe_spawn(state) do
    # Find position not occupied by snakes or apples
    {width, height} = state.grid
    occupied =
      state.snakes
      |> Map.values()
      |> Enum.flat_map(& &1.segments)
      |> MapSet.new()
      |> MapSet.union(MapSet.new(state.apples))

    # Simple grid scan (could optimize)
    Enum.find_value(0..(width * height), fn i ->
      pos = {rem(i, width), div(i, height)}
      if pos not in occupied, do: pos
    end)
  end

  defp move_all_snakes(state) do
    # Implementation details...
    state
  end

  defp check_collisions(state) do
    # Implementation details...
    state
  end

  defp update_apples(state) do
    # Implementation details...
    state
  end

  defp calculate_delta(new_state, old_state) do
    # Compare states, return {new_state, delta_map}
    delta = %{
      moved: [],      # Changed snake positions
      died: [],       # Dead snake IDs
      spawned: [],    # New snakes
      apples: []      # Apple changes
    }
    {new_state, delta}
  end

  defp apply_input_buffer(state) do
    # Apply directions from input_buffer to snakes
    state
  end

  defp serialize_full_state(state) do
    # Convert to JSON-friendly format
    %{
      snakes: Map.values(state.snakes),
      apples: state.apples,
      grid: state.grid
    }
  end
end
```

### Phoenix 1.7 Channel with GameServer Integration
```elixir
# lib/snaker_web/channels/game_channel.ex
# Source: Official Phoenix Channels docs + game server pattern

defmodule SnakerWeb.GameChannel do
  use Phoenix.Channel
  require Logger
  alias Snaker.GameServer

  def join("game:snake", _params, socket) do
    # Subscribe to tick broadcasts
    Phoenix.PubSub.subscribe(Snaker.PubSub, "game:snake")

    # Get player from socket assigns (set in UserSocket.connect/3)
    player = socket.assigns.player

    # Join game, get full state
    case GameServer.join_game(player) do
      {:ok, full_state} ->
        {:ok, full_state, socket}
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  def handle_in("change_direction", %{"direction" => direction}, socket) do
    player_id = socket.assigns.player.id

    case GameServer.change_direction(player_id, direction) do
      :ok ->
        {:reply, :ok, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_info({:tick, delta}, socket) do
    # Broadcast from GameServer
    push(socket, "tick", delta)
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    player_id = socket.assigns.player.id
    GameServer.leave_game(player_id)
    :ok
  end
end
```

### mise Configuration
```toml
# .mise.toml
# Source: https://mise.jdx.dev/configuration.html

[tools]
elixir = "1.15"      # Minor version allows 1.15.x
erlang = "26"        # Match OTP version to Elixir
node = "20"          # For asset pipeline

# Alternative: exact pinning
# elixir = "1.15.7-otp-26"
# erlang = "26.2.1"
# node = "20.11.0"
```

### mix.exs After Phoenix 1.7 Upgrade
```elixir
# Source: https://gist.github.com/chrismccord/bb1f8b136f5a9e4abc0bfc07b832257e
# Cleaned up based on 1.3→1.4→1.7 upgrade path

defmodule Snaker.Mixfile do
  use Mix.Project

  def project do
    [
      app: :snaker,
      version: "0.0.1",
      elixir: "~> 1.15",                    # Updated from 1.4
      elixirc_paths: elixirc_paths(Mix.env),
      compilers: Mix.compilers,             # Removed :phoenix (not needed in 1.11+)
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Snaker.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.0"},               # Updated from 1.3
      {:phoenix_pubsub, "~> 2.0"},          # Updated from 1.0
      {:phoenix_html, "~> 3.0"},            # Updated from 2.10
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:gettext, "~> 0.20"},                # Updated from 0.11
      {:jason, "~> 1.0"},                   # NEW: replaces Poison
      {:plug_cowboy, "~> 2.0"}              # NEW: replaces :cowboy
    ]
  end

  defp aliases do
    [
      "test": ["test"]
    ]
  end
end
```

### Endpoint Configuration (Phoenix 1.7)
```elixir
# lib/snaker_web/endpoint.ex
# Source: Phoenix 1.4 upgrade guide transport changes

defmodule SnakerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :snaker

  # Socket moved from user_socket.ex transport macro
  socket "/socket", SnakerWeb.UserSocket,
    websocket: true,
    longpoll: false

  # ... rest of endpoint config

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason  # Changed from Poison
end
```

### Config Changes for Jason
```elixir
# config/config.exs
# Source: Phoenix 1.4 upgrade guide

config :phoenix, :json_library, Jason  # NEW: global Phoenix JSON config
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Poison for JSON | Jason | Phoenix 1.4 (2018) | 2x performance, stricter spec compliance |
| :cowboy dependency | plug_cowboy | Phoenix 1.4 (2018) | Cleaner abstraction, HTTP/2 support |
| transport macro in UserSocket | socket options in Endpoint | Phoenix 1.4 (2018) | Centralized transport config |
| Phoenix.View modules | Embedded templates | Phoenix 1.7 (2023) | Simplified file structure, optional extraction |
| Phoenix.Controller.get_flash | Phoenix.Flash module | Phoenix 1.7 (2023) | Unified flash API |
| Route helpers | Verified routes (~p sigil) | Phoenix 1.7 (2023) | Compile-time verification |
| asdf | mise | 2023-2024 | Faster, better UX, unified tool management |
| Client-authoritative game state | Server-authoritative with delta | Industry standard | Prevents desync, enables anti-cheat |

**Deprecated/outdated:**
- **Poison**: Still works but unmaintained; Jason is standard
- **transport macro**: Removed in Phoenix 1.4
- **Phoenix.View**: Extracted to separate package in 1.7
- **:phoenix compiler**: Not needed for Elixir 1.11+ in mix.exs
- **Brunch asset pipeline**: Replaced by esbuild in modern Phoenix (though not required for this phase)

## Open Questions

Things that couldn't be fully resolved:

1. **Delta Calculation Algorithm Details**
   - What we know: Should compare old/new state, send only changes
   - What's unclear: Optimal data structure (map-based diff vs event log); performance at 100 players
   - Recommendation: Start simple (map-based diff), optimize if profiling shows bottleneck. Decision deferred to Claude's discretion per CONTEXT.md.

2. **Exact Invincibility Duration**
   - What we know: CONTEXT.md specifies 1-2 seconds range
   - What's unclear: Exact value for best gameplay feel
   - Recommendation: Start with 1500ms, adjust based on testing. Claude's discretion per CONTEXT.md.

3. **Metrics Collection**
   - What we know: CONTEXT.md says "add if easy, skip if complex"
   - What's unclear: What constitutes "easy" (simple Logger calls? Telemetry library?)
   - Recommendation: Use Logger for verbose mode (already decided), skip Telemetry integration for this phase. Can add telemetry hooks in Phase 3 if needed.

4. **Testing Game Tick in CI**
   - What we know: Tests should avoid real timers (flaky)
   - What's unclear: Best pattern for testing tick logic without Process.send_after
   - Recommendation: Extract game logic functions (move_snakes, etc.) and test separately; expose manual tick trigger for integration tests.

5. **Zombie Process Cleanup Strategy**
   - What we know: DynamicSupervisor can restart GameServer on crash
   - What's unclear: Should GameServer be :transient or :permanent? How to handle state loss on restart?
   - Recommendation: Start with single GameServer (:permanent), all players in one game. State loss on crash is acceptable (clients auto-reconnect and rejoin). Multi-room architecture deferred to future phase.

## Sources

### Primary (HIGH confidence)
- [Phoenix 1.7 Changelog](https://hexdocs.pm/phoenix/1.7.0/changelog.html) - Version requirements, breaking changes
- [Phoenix 1.3→1.4 Upgrade Guide](https://gist.github.com/chrismccord/bb1f8b136f5a9e4abc0bfc07b832257e) - Transport macro, Jason migration
- [Phoenix Channels Documentation](https://hexdocs.pm/phoenix/channels.html) - Channel patterns, WebSocket config
- [mise Configuration Docs](https://mise.jdx.dev/configuration.html) - .mise.toml format, version pinning
- [Elixir DynamicSupervisor Docs](https://hexdocs.pm/elixir/DynamicSupervisor.html) - Restart strategies
- [Jason vs Poison GitHub Issue](https://github.com/phoenixframework/phoenix/issues/2693) - Migration rationale

### Secondary (MEDIUM confidence)
- [ElixirCasts: Upgrading to Phoenix 1.7](https://elixircasts.io/upgrading-to-phoenix-1.7) - Practical upgrade guide
- [DEV: Upgrading to Phoenix 1.7](https://dev.to/byronsalty/upgrading-to-phoenix-17-3l21) - Community upgrade experience
- [DEV: Easy Setup Elixir/Erlang OTP using mise](https://dev.to/starch1/easy-setup-elixir-erlang-otp-using-mise-5ffm) - mise setup instructions
- [Fly.io: Building Distributed Turn-Based Game System](https://fly.io/blog/building-a-distributed-turn-based-game-system-in-elixir/) - Game architecture patterns
- [DEV: Building a Game Server in Elixir](https://dev.to/sushant12/building-a-game-server-in-elixir-27of) - GameServer implementation
- [ElixirCasts: Recurring Work with GenServer](https://elixircasts.io/recurring-work-with-genserver) - Process.send_after pattern
- [AppSignal: Multiplayer Go with Registry, PubSub, DynamicSupervisor](https://blog.appsignal.com/2019/08/13/elixir-alchemy-multiplayer-go-with-registry-pubsub-and-dynamic-supervisors.html) - Game server supervision
- [Errol Hassall: Migrating to Jason from Poison](https://errolhassall.com/blog/2018/11/16/migrating-to-jason-from-poison) - JSON migration details
- [PhoenixDiff.org](https://www.phoenixdiff.org/) - Visual diff tool
- [GitHub: PhoenixDiff](https://github.com/phoenix-diff/phoenix-diff) - Source repository

### Tertiary (LOW confidence)
- WebSearch results for "Elixir game server collision detection spawn safe position algorithm" - General concepts, no Elixir-specific authoritative source found
- Forum discussions on testing GenServers - Various approaches, no single standard
- GitHub issues on Phoenix Channels disconnect handling - Older discussions (2014-2018), may not reflect current best practices

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** - Official Phoenix docs, widely adopted versions
- Architecture patterns: **HIGH** - Multiple authoritative sources (Fly.io, official guides), well-established patterns
- Pitfalls: **MEDIUM-HIGH** - Based on upgrade guides and community reports; some are inferred from breaking changes
- Code examples: **HIGH** - Adapted from official docs and authoritative blog posts
- Delta calculation specifics: **LOW** - No single authoritative pattern found; marked as open question

**Research date:** 2026-01-31
**Valid until:** ~60 days (Phoenix stable, Elixir slow-moving; mise evolving but compatible)

**Key constraints from CONTEXT.md respected:**
- Tick rate: 100ms (researched Process.send_after pattern for this)
- Delta broadcasts: Researched delta-only pattern vs full state
- Rate limiting: First input per tick (researched input buffering)
- Collision & respawn: Safe spawn algorithm research
- Development environment: mise version pinning (researched .mise.toml)
- Error handling: Disconnect cleanup (researched terminate/2)
- Logging: Quiet default, verbose mode (researched Logger integration)
- Claude's discretion: Invincibility duration, metrics, logging format (noted in open questions)
