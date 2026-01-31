defmodule Snaker.GameServer do
  @moduledoc """
  Authoritative game state server.

  Maintains single source of truth for all game state:
  - Snake positions, directions, segments
  - Apple positions
  - Player metadata

  Ticks every 100ms, broadcasting delta updates to all connected clients.
  """

  use GenServer
  require Logger

  alias Snaker.Game.{Snake, Apple, Grid}

  @tick_interval 100  # 10 ticks/second
  @first_names ["Jesse", "Vanessa", "George", "Henry", "Theresa", "Sean", "Sandra", "Penelope",
    "Samantha", "Ziggy", "Kirk", "Veronica", "Zoobadooba", "Tigger", "Zoomy-zoom"]
  @animals ["Kitten", "Fox", "Panda", "Tiger", "Giraffe", "Horse", "Pig", "Bird", "Squirrel", "Snake",
    "Pheasant", "Raccoon", "Leopard", "Goat", "Crocodile", "Armadillo", "Crow", "Donkey", "Ferret",
    "Lizard", "Coyote", "Duck", "Gorilla", "Goose", "Camel", "Weasel", "Heron", "Shark"]
  @adjectives ["Platonic", "Smoochy", "Squishy", "Thoughtless", "Amazing", "Unfathomable", "Inscrutible",
    "Immense", "Stoic", "Frivolous", "Smirking", "Dangerous", "Zazzy", "Laughing", "Incontrovertible"]
  @colours ["67a387", "e6194b", "3cb44b", "ffe119", "0082c8", "f58231", "911eb4",
    "46f0f0", "f032e6", "d2f53c", "fabebe", "008080", "e6beff", "aa6e28", "fffac8",
    "800000", "aaffc3", "808000", "ffd8b1"]

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def join_game(player_id) do
    GenServer.call(__MODULE__, {:join, player_id})
  end

  def leave_game(player_id) do
    GenServer.cast(__MODULE__, {:leave, player_id})
  end

  def change_direction(player_id, direction) do
    GenServer.call(__MODULE__, {:change_direction, player_id, direction})
  end

  def get_full_state do
    GenServer.call(__MODULE__, :get_full_state)
  end

  # For testing
  def trigger_tick do
    send(__MODULE__, :tick)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      snakes: %{},
      apples: [],
      grid: Grid.default_dimensions(),
      input_buffer: %{},
      next_player_id: 1,
      tick_count: 0
    }

    # Spawn initial apples
    state = spawn_initial_apples(state)

    schedule_tick()
    {:ok, state}
  end

  @impl true
  def handle_call({:join, _player_id}, _from, state) do
    # Generate player data
    player_id = state.next_player_id
    color = Enum.random(@colours)
    name = random_name()

    # Find safe spawn position
    occupied = get_all_occupied_positions(state)
    spawn_pos = Grid.find_safe_spawn(occupied, state.grid)

    snake = Snake.new(player_id, spawn_pos, color, name)

    new_state =
      state
      |> put_in([:snakes, player_id], snake)
      |> Map.update!(:next_player_id, &(&1 + 1))

    player_data = %{
      id: player_id,
      colour: color,
      name: name
    }

    full_state = serialize_full_state(new_state)

    Logger.debug("[GameServer] Player #{player_id} (#{name}) joined at #{inspect(spawn_pos)}")

    {:reply, {:ok, player_data, full_state}, new_state}
  end

  @impl true
  def handle_call({:change_direction, player_id, direction}, _from, state) do
    direction_atom = String.to_existing_atom(direction)

    # Rate limit: only accept first direction change per tick
    if Map.has_key?(state.input_buffer, player_id) do
      {:reply, {:error, :rate_limited}, state}
    else
      case Map.get(state.snakes, player_id) do
        nil ->
          {:reply, {:error, :player_not_found}, state}
        snake ->
          if Snake.valid_direction_change?(snake.direction, direction_atom) do
            new_state = put_in(state, [:input_buffer, player_id], direction_atom)
            {:reply, :ok, new_state}
          else
            {:reply, {:error, :invalid_direction}, state}
          end
      end
    end
  rescue
    ArgumentError ->
      {:reply, {:error, :invalid_direction}, state}
  end

  @impl true
  def handle_call(:get_full_state, _from, state) do
    {:reply, serialize_full_state(state), state}
  end

  @impl true
  def handle_cast({:leave, player_id}, state) do
    Logger.debug("[GameServer] Player #{player_id} left")

    new_state =
      state
      |> update_in([:snakes], &Map.delete(&1, player_id))
      |> update_in([:input_buffer], &Map.delete(&1, player_id))

    # Broadcast player removal
    Phoenix.PubSub.broadcast(Snaker.PubSub, "game:snake", {:player_left, player_id})

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:tick, state) do
    old_state = state

    # 1. Apply buffered direction changes
    state = apply_input_buffer(state)

    # 2. Move all snakes
    state = move_all_snakes(state)

    # 3. Check collisions (death/respawn)
    state = check_collisions(state)

    # 4. Check apple eating
    state = check_apple_eating(state)

    # 5. Spawn apples if needed
    state = spawn_apples_if_needed(state)

    # 6. Clear input buffer
    state = %{state | input_buffer: %{}, tick_count: state.tick_count + 1}

    # 7. Calculate and broadcast delta
    delta = calculate_delta(old_state, state)
    broadcast_tick(delta)

    # Log tick in verbose mode (every 10 ticks = 1 second)
    if rem(state.tick_count, 10) == 0 do
      snake_count = map_size(state.snakes)
      apple_count = length(state.apples)
      Logger.debug("[GameServer] Tick #{state.tick_count}: #{snake_count} snakes, #{apple_count} apples")
    end

    schedule_tick()
    {:noreply, state}
  end

  # Private Helpers

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp apply_input_buffer(state) do
    Enum.reduce(state.input_buffer, state, fn {player_id, direction}, acc ->
      case Map.get(acc.snakes, player_id) do
        nil -> acc
        snake ->
          {:ok, updated_snake} = Snake.change_direction(snake, direction)
          put_in(acc, [:snakes, player_id], updated_snake)
      end
    end)
  end

  defp move_all_snakes(state) do
    new_snakes =
      state.snakes
      |> Enum.map(fn {id, snake} -> {id, Snake.move(snake, state.grid)} end)
      |> Map.new()

    %{state | snakes: new_snakes}
  end

  defp check_collisions(state) do
    snakes = state.snakes

    # Check each snake for collisions
    Enum.reduce(snakes, state, fn {player_id, snake}, acc ->
      if Snake.is_invincible?(snake) do
        acc
      else
        # Self collision
        self_collision = Snake.collides_with_self?(snake)

        # Collision with other snakes
        other_collision =
          acc.snakes
          |> Map.values()
          |> Enum.any?(fn other -> Snake.collides_with?(snake, other) end)

        if self_collision or other_collision do
          respawn_snake(acc, player_id)
        else
          acc
        end
      end
    end)
  end

  defp respawn_snake(state, player_id) do
    case Map.get(state.snakes, player_id) do
      nil -> state
      snake ->
        occupied = get_all_occupied_positions(state)
        spawn_pos = Grid.find_safe_spawn(occupied, state.grid)

        new_snake = %{snake |
          segments: [spawn_pos],
          direction: :right,
          pending_growth: 0,
          invincible_until: System.monotonic_time(:millisecond) + 1500
        }

        Logger.debug("[GameServer] Player #{player_id} died and respawned at #{inspect(spawn_pos)}")

        put_in(state, [:snakes, player_id], new_snake)
    end
  end

  defp check_apple_eating(state) do
    Enum.reduce(state.snakes, state, fn {player_id, snake}, acc ->
      head = Snake.head(snake)
      {eaten, remaining_apples} = Apple.check_eaten(acc.apples, head)

      if eaten do
        grown_snake = Snake.grow(snake, Apple.growth_amount())
        Logger.debug("[GameServer] Player #{player_id} ate apple at #{inspect(head)}")

        acc
        |> Map.put(:apples, remaining_apples)
        |> put_in([:snakes, player_id], grown_snake)
      else
        acc
      end
    end)
  end

  defp spawn_apples_if_needed(state) do
    occupied = get_all_occupied_positions(state)
    new_apples = Apple.spawn_if_needed(state.apples, occupied, state.grid)
    %{state | apples: new_apples}
  end

  defp spawn_initial_apples(state) do
    # Spawn apples until we have minimum count
    Enum.reduce(1..3, state, fn _, acc ->
      spawn_apples_if_needed(acc)
    end)
  end

  defp get_all_occupied_positions(state) do
    snake_positions =
      state.snakes
      |> Map.values()
      |> Enum.flat_map(&Snake.all_positions/1)
      |> MapSet.new()

    MapSet.union(snake_positions, MapSet.new(state.apples))
  end

  defp calculate_delta(_old_state, new_state) do
    # For now, send full positions each tick
    # Can optimize to true delta later if needed
    %{
      snakes: new_state.snakes |> Map.values() |> Enum.map(&serialize_snake/1),
      apples: Enum.map(new_state.apples, &serialize_position/1)
    }
  end

  defp broadcast_tick(delta) do
    Phoenix.PubSub.broadcast(Snaker.PubSub, "game:snake", {:tick, delta})
  end

  defp serialize_full_state(state) do
    %{
      snakes: state.snakes |> Map.values() |> Enum.map(&serialize_snake/1),
      apples: Enum.map(state.apples, &serialize_position/1),
      grid_width: elem(state.grid, 0),
      grid_height: elem(state.grid, 1)
    }
  end

  defp serialize_snake(snake) do
    %{
      id: to_string(snake.id),
      body: Enum.map(snake.segments, &serialize_position/1),
      direction: Atom.to_string(snake.direction),
      color: snake.color,
      name: snake.name
    }
  end

  defp serialize_position({x, y}), do: %{x: x, y: y}

  defp random_name do
    [name, adjective, animal] =
      [@first_names, @adjectives, @animals]
      |> Enum.map(&Enum.random(&1))
    "#{name} the #{adjective} #{animal}"
  end
end
