defmodule SnakerWeb.GameChannel do
  use Phoenix.Channel
  require Logger
  alias Snaker.GameServer

  # Intercept these events to handle via handle_out/3
  intercept ["player:join"]

  def join("game:snake", _message, socket) do
    # Subscribe to game tick broadcasts from GameServer
    Phoenix.PubSub.subscribe(Snaker.PubSub, "game:snake")

    # Join game and get initial state
    case GameServer.join_game(socket.id || :rand.uniform(1_000_000)) do
      {:ok, player_data, full_state} ->
        socket = assign(socket, :player, player_data)
        send(self(), :after_join)
        {:ok, %{player: player_data, game_state: full_state}, socket}
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  def handle_info(:after_join, socket) do
    # Broadcast player:join to all OTHER clients (not the joining player)
    # The joining player already has their info from the join response
    broadcast_from!(socket, "player:join", %{player: socket.assigns.player})
    {:noreply, socket}
  end

  # Handle outgoing broadcasts - push to client
  def handle_out("player:join", payload, socket) do
    push(socket, "player:join", payload)
    {:noreply, socket}
  end

  def handle_info({:tick, delta}, socket) do
    Logger.debug("[GameChannel] Pushing tick to client")
    push(socket, "tick", delta)
    {:noreply, socket}
  end

  def handle_info({:player_left, player_id}, socket) do
    push(socket, "player:leave", %{player_id: player_id})
    {:noreply, socket}
  end

  # Handle PubSub broadcasts received by this process
  def handle_info(%Phoenix.Socket.Broadcast{event: _event, payload: _payload}, socket) do
    # Ignore broadcasts from other channels (we handle ticks via :tick tuple)
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    if socket.assigns[:player] do
      GameServer.leave_game(socket.assigns.player.id)
      # Player leave is broadcast via PubSub from GameServer
    end
    :ok
  end

  def handle_in("player:change_direction", %{"direction" => direction}, socket) do
    player_id = socket.assigns.player.id

    case GameServer.change_direction(player_id, direction) do
      :ok -> {:reply, :ok, socket}
      {:error, reason} -> {:reply, {:error, %{reason: reason}}, socket}
    end
  end
end
