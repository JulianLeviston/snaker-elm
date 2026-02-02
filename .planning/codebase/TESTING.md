# Testing Patterns

**Analysis Date:** 2026-01-30

## Test Framework

### Elixir Backend

**Runner:**
- ExUnit (Elixir standard library test framework)
- Version determined by Elixir version (~> 1.4 in `mix.exs`)
- Config: `test/test_helper.exs`

**Assertion Library:**
- ExUnit assertions built-in (e.g., `assert`, `assert_response`)
- Phoenix-specific assertions via `Phoenix.ConnTest` and `Phoenix.ChannelTest`

**Run Commands:**
```bash
mix test              # Run all tests
mix test --watch     # Watch mode (requires file_system watcher)
mix test --cover     # Coverage report
```

### Elm Frontend

- **No testing framework detected**
- No test files found in `assets/elm/` directory
- Elm code not covered by automated tests
- Phoenix Socket integration tested indirectly through Elixir channel tests only

## Test File Organization

### Location and Naming

**Elixir:**
- **Pattern:** Co-located with source code under `test/` directory mirror
- **Structure:**
  ```
  lib/snaker_web/controllers/page_controller.ex
  → test/snaker_web/controllers/page_controller_test.exs

  lib/snaker_web/views/error_view.ex
  → test/snaker_web/views/error_view_test.exs

  lib/snaker_web/channels/game_channel.ex
  → No test file found (untested)
  ```

- **Naming Convention:** `{module_name}_test.exs` (suffix `_test.exs`)

**Test Organization in File:**
```
test/snaker_web/views/error_view_test.exs
├── test/2 - test macro with description and setup
├── use SnakerWeb.ConnCase, async: true - marks async/sync
└── Assertions
```

### Example Test Structure

From `test/snaker_web/controllers/page_controller_test.exs`:
```elixir
defmodule SnakerWeb.PageControllerTest do
  use SnakerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end
end
```

From `test/snaker_web/views/error_view_test.exs`:
```elixir
defmodule SnakerWeb.ErrorViewTest do
  use SnakerWeb.ConnCase, async: true

  import Phoenix.View

  test "renders 404.html" do
    assert render_to_string(SnakerWeb.ErrorView, "404.html", []) ==
           "Page not found"
  end

  test "render 500.html" do
    assert render_to_string(SnakerWeb.ErrorView, "500.html", []) ==
           "Internal server error"
  end
end
```

## Test Structure

### Case Templates

**ConnCase (for controller/view tests):**
Location: `test/support/conn_case.ex`

```elixir
defmodule SnakerWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Phoenix.ConnTest
      import SnakerWeb.Router.Helpers
      @endpoint SnakerWeb.Endpoint
    end
  end

  setup tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
```

**Setup Pattern:**
- `use SnakerWeb.ConnCase` injects test context
- `%{conn: conn}` parameter provides Phoenix test connection
- Ecto database sandbox setup commented out (database not in use)

**ChannelCase (for channel tests):**
Location: `test/support/channel_case.ex`

```elixir
defmodule SnakerWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Phoenix.ChannelTest
      @endpoint SnakerWeb.Endpoint
    end
  end

  setup tags do
    {:ok, _} = Supervisor.start_link([...], strategy: :one_for_one)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
```

**Note:** `SnakerWeb.GameChannel` (the main game channel) has no test file and is untested.

### Patterns Observed

#### Assertion Pattern
```elixir
# For HTTP controllers
assert html_response(conn, 200) =~ "Expected text"

# For rendered views
assert render_to_string(ViewModule, "template.html", context) == "expected_output"
```

#### Setup/Teardown
- **Setup:** Implicit via case template injection
- No explicit setup blocks with `setup do` observed
- Ecto database sandbox commented out, not in use
- No teardown logic needed (no stateful resources)

## Mocking

**Framework:** Not detected - no mocking library in dependencies

**Patterns Observed:**
- No mocks used in existing tests
- No stubbing of external services
- No test doubles observed

**Current Approach:**
- Tests use actual Phoenix framework components
- Database operations disabled (no Ecto in use)
- Real GenServer (`Snaker.Worker`) would be used in channel tests (but no channel tests exist)

## Fixtures and Factories

**Test Data:**
- No fixture files detected
- No factory libraries (like ExMachina) in dependencies
- Hard-coded test data in tests themselves
- No reusable test data builders

**Location:**
- Data generation code not observed in test support files
- Each test provides its own data

## Coverage

**Requirements:** Not enforced by project configuration

**View Coverage:**
- Test files present for views: `error_view_test.exs`, `page_view_test.exs`, `layout_view_test.exs`
- Controllers partially tested: `page_controller_test.exs` (only)
- Channels untested: No `game_channel_test.exs`
- Business logic untested: No tests for `Snaker.Worker`

**Critical Coverage Gaps:**
1. `SnakerWeb.GameChannel` - Main game logic handler, completely untested
2. `Snaker.Worker` - GenServer managing player state, untested
3. `Data.Board` - Core game board logic (Elm), untested
4. `Data.Snake` - Snake movement and collision logic (Elm), untested

**Test Existence:**
```
lib/snaker_web/views/
  ├── error_view.ex ✓ tested (error_view_test.exs)
  ├── layout_view.ex ✓ tested (layout_view_test.exs)
  ├── page_view.ex ✓ tested (page_view_test.exs)
  └── error_helpers.ex ✗ untested

lib/snaker_web/controllers/
  └── page_controller.ex ✓ tested (page_controller_test.exs)

lib/snaker_web/channels/
  ├── user_socket.ex ✗ untested
  └── game_channel.ex ✗ untested (critical gap)

lib/snaker/
  └── worker.ex ✗ untested

assets/elm/
  ├── Main.elm ✗ untested
  └── Data/
      ├── Board.elm ✗ untested
      ├── Snake.elm ✗ untested
      ├── Direction.elm ✗ untested
      ├── Player.elm ✗ untested
      ├── Position.elm ✗ untested
      └── Apple.elm ✗ untested
```

## Test Types

### Unit Tests

**Scope:**
- Individual controller actions
- View rendering functions
- Public module API

**Approach:**
- Isolated from other modules
- Use real Phoenix framework components
- Example: `page_controller_test.exs` tests single HTTP GET route

**Current State:**
- Limited unit test coverage
- Views tested in isolation (good)
- Controllers minimally tested (only one action)

### Integration Tests

**Scope:**
- Channel message handling
- Player lifecycle (join/leave)
- Multi-player interactions

**Current State:**
- Not implemented
- `SnakerWeb.GameChannel` should have integration tests for:
  - Player joining a game
  - Direction changes being broadcast
  - Player leaving game
  - Multiple players interacting

### End-to-End Tests

**Framework:** Not used

**Missing:**
- No Elm-to-Elixir integration tests
- No WebSocket connection tests
- No full game flow tests

## Common Patterns

### Async Testing

```elixir
use SnakerWeb.ConnCase, async: true
```

- `async: true` allows parallel test execution
- Used in `ErrorViewTest` (view rendering doesn't depend on state)
- **Not used in:** controller tests (may have shared connection state)
- **Note:** Ecto sandbox configuration commented out, so async is safe

### HTTP Testing Pattern

```elixir
test "GET /", %{conn: conn} do
  conn = get conn, "/"
  assert html_response(conn, 200) =~ "Welcome to Phoenix!"
end
```

**Steps:**
1. Inject test connection via case template
2. Make HTTP request using `get/2` helper
3. Assert response status with `html_response/2`
4. Pattern match response body with `=~` operator

### View Rendering Pattern

```elixir
test "renders 404.html" do
  assert render_to_string(SnakerWeb.ErrorView, "404.html", []) ==
         "Page not found"
end
```

**Steps:**
1. Call `render_to_string/3` with view module, template name, context
2. Assert exact string match with `==`
3. No fixtures needed - templates are tested as-is

### Error Testing (Missing)

No error case tests observed. Pattern that should be used:

```elixir
test "handles invalid input" do
  conn = get conn, "/?invalid=true"
  assert response_status(conn) == 400
end
```

### Async/Await Testing (Not Applicable)

Elixir uses message passing instead of async/await. No special patterns observed for testing concurrent behavior.

---

*Testing analysis: 2026-01-30*
