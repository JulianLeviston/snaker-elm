# Coding Conventions

**Analysis Date:** 2026-01-30

## Overview

This codebase is a Phoenix/Elixir backend with Elm 0.18 frontend. Conventions are observed separately for each language with distinct patterns.

## Naming Patterns

### Elm Files
- **Modules:** PascalCase for all modules (e.g., `Data.Direction`, `Board.Html`, `Main`)
- **Type Aliases:** PascalCase (e.g., `Player`, `Board`, `Snake`, `Position`, `Apple`)
- **Functions:** camelCase (e.g., `fromString`, `keyCodeToMaybeDirection`, `randomApple`, `nextPositionInDirection`)
- **Type Tags:** PascalCase (e.g., `North`, `East`, `SnakeSegment`, `AppleTile`, `EmptyTile`)
- **Message Types:** PascalCase, often paired as `type Msg` (e.g., `type Msg = Tick Time | ChangeDirection Direction | AddApple Apple`)
- **Private helpers:** Prefix with underscore or use lowercase names in `where` clauses (e.g., `snakeTilePositionsOf`, `row`)

### Elixir Files
- **Modules:** PascalCase with namespace hierarchy using dots (e.g., `SnakerWeb.GameChannel`, `SnakerWeb.PageController`, `Snaker.Worker`)
- **Functions:** snake_case (e.g., `new_player`, `delete_player`, `random_name`, `random_colour`)
- **Variables:** snake_case (e.g., `player_id`, `socket`, `new_state`)
- **Constants:** SCREAMING_SNAKE_CASE (e.g., `@first_names`, `@animals`, `@colours`)
- **Callbacks:** typically follow naming pattern `handle_*` for GenServer callbacks (e.g., `handle_call`, `handle_cast`, `handle_info`)

## Code Style

### Formatting

**Elm:**
- Standard formatting conventions, imports grouped logically
- Type annotations on all top-level functions
- Exposing lists explicitly defined in module declaration
- Example from `Main.elm`:
  ```elm
  module Main exposing (main)

  import Html exposing (Html, text)
  import Html.Attributes exposing (style)
  import Time
  import Keyboard
  ```

**Elixir:**
- No explicit formatter configuration file detected (`.formatter.exs` missing)
- Code generally follows Phoenix conventions
- Guard clauses used in pattern matching
- Example from `snaker_web/channels/game_channel.ex`:
  ```elixir
  def join("game:snake", message, socket) do
    send(self(), {:after_join, message})
    {:ok, socket}
  end
  ```

### Linting

**Elm:**
- No `.eslintrc` or linting configuration detected
- No explicit linting tool configured in project

**Elixir:**
- No `.credo.exs` configuration detected
- No explicit linting tool configured in project
- Code patterns suggest manual style adherence to Phoenix conventions

## Import Organization

### Elm Import Order
1. Core language modules (e.g., `Html`, `Time`, `Random`)
2. Standard library modules (e.g., `Dict`, `Keyboard`)
3. Local Data modules (e.g., `Data.Direction`, `Data.Board`)
4. Local View modules (e.g., `Board.Html`)
5. Third-party integrations (e.g., `Phoenix.Socket`, `Json.Encode`)

Example from `Main.elm` (lines 1-17):
```elm
module Main exposing (main)

import Html exposing (Html, text)
import Html.Attributes exposing (style)
import Time
import Keyboard
import Random
import Dict exposing (Dict)
import Data.Direction as Direction exposing (Direction(..))
import Data.Board as Board exposing (Board)
import Data.Player as Player exposing (Player, PlayerId)
import Board.Html
import Phoenix.Socket as Socket exposing (Socket)
import Phoenix.Channel as Channel
import Phoenix.Push as Push
import Json.Encode as JE
import Json.Decode as JD
```

### Elixir Import/Alias Order
1. Module declarations and `use` statements
2. `require` statements
3. `alias` statements
4. `import` statements (rarely used)

Example from `snaker_web/channels/game_channel.ex`:
```elixir
defmodule SnakerWeb.GameChannel do
  use Phoenix.Channel
  require Logger
  alias Snaker.Worker
```

### Path Aliases

**Elm:**
- Aliases created with `as` keyword for brevity (e.g., `import Data.Direction as Direction`)
- Full expose lists used when multiple items needed from module
- Used to shorten long module names for cleaner code

**Elixir:**
- `alias` used to shorten module references (e.g., `alias Snaker.Worker`)
- Accessed directly after aliasing (e.g., `Worker.new_player()`)

## Error Handling

### Elm

**Decoder Error Handling:**
- `Result` type used with `case` pattern matching for JSON decoding
- `Err _` pattern discards error details, treating as silent failure
- Example from `Main.elm` (lines 115-136):
  ```elm
  case JD.decodeValue joinGameDecoder raw of
      Ok ( player, playersDict ) ->
          let
              ( newBoard1, boardCmd1 ) =
                  Board.update (Board.toSetCurrentPlayerMsg player) model.board
          in
              ( newModel, Cmd.batch [ newCmd1, newCmd2 ] )
      Err _ ->
          ( model, Cmd.none )
  ```

**Maybe Handling:**
- `case` expressions with `Nothing` and `Just` patterns
- `Maybe.withDefault` used when default value is appropriate
- Example from `Data.Board.elm` (lines 102-105):
  ```elm
  directionOfPlayer playerId { snakes } =
      Dict.get playerId snakes
          |> Maybe.map Snake.direction
  ```

**Message Dispatch:**
- Returned as part of Model update tuple `(Model, Cmd Msg)`
- Errors silently ignored in many cases, no error propagation pattern observed

### Elixir

**Success/Error Tuples:**
- Standard Phoenix pattern: `{:ok, value}` or `{:error, reason}`
- Example from `snaker_web/channels/user_socket.ex` (lines 24-27):
  ```elixir
  def connect(_params, old_socket) do
    new_player = Worker.new_player()
    socket = assign(old_socket, :player, new_player)
    {:ok, socket}
  end
  ```

**GenServer Returns:**
- `{:reply, value, state}` for call responses
- `{:noreply, state}` for cast responses
- Example from `snaker/worker.ex` (lines 35-43):
  ```elixir
  def handle_call({:new_player}, _from, %{players: players} = state) do
    player_id = next_player_id(players)
    player_data = %{...}
    new_state = put_in(state, [:players, player_id], player_data)
    {:reply, player_data, new_state}
  end
  ```

**Broadcasting Errors:**
- Errors not explicitly handled in channels; broadcast assumed to succeed
- Logging used for debug information via `Logger.debug()`

## Logging

### Elm
- No logging framework detected in Elm code
- No debug output observed except through Phoenix Socket debugging: `Socket.withDebug`

### Elixir
**Framework:** `Logger` module (Elixir standard library)

**Usage Pattern:**
- `require Logger` imported in channel module
- `Logger.debug()` used for informational messages
- Example from `snaker_web/channels/game_channel.ex` (line 25):
  ```elixir
  Logger.debug("> #{inspect(socket.assigns.player)} leaving because of #{inspect(reason)}")
  ```

**When to Log:**
- Lifecycle events (player disconnect, connection termination)
- Socket state transitions
- Debug information for development

## Comments

### When to Comment
- Complex business logic is uncommented (e.g., snake direction validation in `Data.Snake.changeSnakeDirection`)
- TODO comments used to mark incomplete features
- Example TODO from `snaker_web/channels/game_channel.ex` (lines 14-18):
  ```elixir
  # TODO: push the entire board to the new client, along with a period, and a list of apples
  # and players. Whenever a new apple is added, we must send a broadcast message
  # to the client, and whenever a movement happens from the client, likewise.
  ```

### Documentation
- No module-level documentation observed
- No JSDoc/TSDoc annotations in Elm
- No `@doc` or `@moduledoc` in Elixir except in generated test support files

## Function Design

### Elm

**Size Guidelines:**
- Functions range from single-liners to ~20 lines
- Helper functions nested in `let...in` blocks when used by single parent function
- Top-level functions tend to be composition of smaller operations

**Parameters:**
- Type annotations required on all top-level functions
- Pattern matching in function parameters preferred over guards
- Example from `Data.Direction.elm`:
  ```elm
  fromString : String -> Maybe Direction
  fromString string =
      case string of
          "north" -> Just North
          "North" -> Just North
          ...
  ```

**Return Values:**
- `(Model, Cmd Msg)` tuple pattern for all update functions
- `Html Msg` return type for view functions
- Generators used for random values: `Generator Position`, `Generator Apple`

**Purity:**
- All functions are pure (no side effects)
- Commands used for side effects via Elm's effects model

### Elixir

**Size Guidelines:**
- Functions generally 5-15 lines, some up to ~30 lines
- Helper functions defined as `defp` (private) at module level
- Guard clauses used to narrow function clause matching

**Parameters:**
- Pattern matching in function head preferred
- `_` used to ignore unused parameters
- Example from `snaker/worker.ex` (lines 35-43):
  ```elixir
  def handle_call({:new_player}, _from, %{players: players} = state) do
    ...
  end
  ```

**Return Values:**
- GenServer callbacks return tuples with specific formats
- `handle_call` returns `{:reply, response, new_state}`
- `handle_cast` returns `{:noreply, new_state}`
- Channel handlers return `{:noreply, socket}` or `{:reply, {:ok, data}, socket}`

**Side Effects:**
- Allowed at module level (GenServer state changes, process messaging)
- `send(self(), {:after_join, message})` used for inter-process communication

## Module Design

### Elm

**Exposing Lists:**
- Explicit exposing of public API only
- Type constructors exposed (e.g., `Direction(..)` exposes all variants)
- Functions grouped by type in exposing list
- Example from `Data.Direction.elm`:
  ```elm
  module Data.Direction
      exposing
          ( Direction(..)
          , fromString
          , keyCodeToMaybeDirection
          )
  ```

**Type Definitions:**
- Type aliases used extensively for domain objects (`Player`, `Board`, `Snake`)
- Type tags (Union Types) used for variants (`Direction`, `TileType`, `ServerMsg`)
- Decoder functions co-located with type definitions

**Barrel Files:**
- Not observed; each module has single responsibility

### Elixir

**Module Organization:**
- One public module per file (e.g., `SnakerWeb.GameChannel` in `game_channel.ex`)
- Handler functions grouped by pattern (e.g., all `handle_*` together)
- Private helper functions at end of module marked with `defp`

**Pattern:**
Example from `snaker/worker.ex`:
```elixir
defmodule Snaker.Worker do
  use GenServer

  # Module attributes (constants)
  @first_names [...]

  # Public API
  def new_player() do ...
  def delete_player(player_id) do ...

  # GenServer callbacks
  def init(_initial_value) do ...
  def handle_call({:new_player}, _from, state) do ...

  # Private helpers
  defp next_player_id(players) do ...
end
```

**Attributes:**
- Module attributes (constants) defined at top with `@` prefix
- Used for configuration data (player name lists, colors, etc.)

---

*Convention analysis: 2026-01-30*
