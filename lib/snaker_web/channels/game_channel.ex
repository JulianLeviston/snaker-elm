defmodule SnakerWeb.GameChannel do
  use Phoenix.Channel
  require Logger
  alias Snaker.Worker

  def join("game:snake", message, socket) do
    send(self(), {:after_join, message})
    {:ok, socket}
  end

  def handle_info({:after_join, message}, socket) do
    broadcast!(socket, "player:join", %{player: socket.assigns.player})
    push(socket, "join", %{status: "connected", player: socket.assigns.player, players: Worker.players()})
    # TODO: push the entire board to the new client, along with a period, and a list of apples
    # and players. Whenever a new apple is added, we must send a broadcast message
    # to the client, and whenever a movement happens from the client, likewise.
    # the clients must maintain their own time, but also be aware of the global time
    # Obviously to do that we have to have the board... :)
    {:noreply, socket}
  end

  def terminate(reason, socket) do
    Worker.delete_player(socket.assigns.player.id)
    broadcast!(socket, "player:leave", %{player: socket.assigns.player})
    Logger.debug("> #{inspect(socket.assigns.player)} leaving because of #{inspect(reason)}")
  end

  def handle_in("player:change_direction", %{direction: direction, player_id: player_id} = msg, socket) do
    broadcast!(socket, "player:change_direction", %{player_id: player_id, direction: direction})
    {:reply, {:ok, %{player_id: player_id}}, socket}
  end

  def handle_out("player:join", %{player: %{id: id}} = msg, socket) do
    if socket.assigns.player.id != id do
      push(socket, "player:join", Map.take(msg, [:player]))
    end
    {:noreply, socket}
  end

  def handle_out("player:change_direction", %{direction: _, player_id: player_id} = msg, socket) do
    if socket.assigns.player.id != player_id do
      push(socket, "player:change_direction", Map.take(msg, [:direction, :player_id]))
    end
    {:noreply, socket}
  end
end
