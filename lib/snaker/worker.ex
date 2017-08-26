defmodule Snaker.Worker do
  use GenServer
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

  def new_player() do
    GenServer.call(__MODULE__, {:new_player})
  end

  def delete_player(player_id) do
    GenServer.cast(__MODULE__, {:delete_player, player_id})
  end

  def players() do
    GenServer.call(__MODULE__, {:players})
  end

  def start_link(initial_value) do
    GenServer.start_link(__MODULE__, initial_value, name: __MODULE__)
  end

  def init(_initial_value) do
    initial_map = %{players: %{}, apples: [], grid_dimensions: %{x: 30, y: 40}}
    {:ok, initial_map}
  end

  def handle_call({:new_player}, _from, %{players: players} = state) do
    player_id = next_player_id(players)
    player_data = %{
      id: player_id,
      colour: random_colour(),
      name: random_name()
    }
    new_state = put_in(state, [:players, player_id], player_data)
    {:reply, player_data, new_state}
  end

  def handle_call({:players}, _from, state) do
    {:reply, state.players, state}
  end

  def handle_cast({:delete_player, player_id}, state) do
    new_state = update_in(state, [:players], &Map.delete(&1, player_id))
    {:noreply, new_state}
  end

  defp next_player_id(players) do
    max_id =
      players
      |> Map.keys
      |> Enum.max(fn() -> 0 end)
    max_id + 1
  end

  defp random_name do
    [name, adjective, animal] =
      [@first_names, @adjectives, @animals]
      |> Enum.map(&Enum.random(&1))
    description = "#{adjective} #{animal}"
    "#{name} the #{description}"
  end

  defp random_colour do
    Enum.random(@colours)
  end
end
