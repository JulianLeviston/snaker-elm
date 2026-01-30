defmodule SnakerWeb.GameChannel do
  use Phoenix.Channel
  require Logger
  alias Snaker.GameServer

  def join("game:snake", _message, socket) do
    # Subscribe to game broadcasts
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
    broadcast!(socket, "player:join", %{player: socket.assigns.player})
    {:noreply, socket}
  end

  def handle_info({:tick, delta}, socket) do
    push(socket, "tick", delta)
    {:noreply, socket}
  end

  def handle_info({:player_left, player_id}, socket) do
    push(socket, "player:leave", %{player_id: player_id})
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    if socket.assigns[:player] do
      GameServer.leave_game(socket.assigns.player.id)
      broadcast!(socket, "player:leave", %{player: socket.assigns.player})
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
