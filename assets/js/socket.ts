// Phoenix socket connection with Elm port wiring
import { Socket, Channel } from "phoenix";

interface ElmApp {
  ports: {
    joinGame: { subscribe: (callback: (data: unknown) => void) => void };
    leaveGame: { subscribe: (callback: () => void) => void };
    sendDirection: { subscribe: (callback: (data: unknown) => void) => void };
    receiveGameState: { send: (data: unknown) => void };
    receiveError: { send: (message: string) => void };
    playerJoined: { send: (data: unknown) => void };
    playerLeft: { send: (data: unknown) => void };
    receiveTick: { send: (data: unknown) => void };
  };
}

export function connectSocket(app: ElmApp): void {
  const socket = new Socket("/socket", {});
  socket.connect();

  let channel: Channel | null = null;

  // Handle join game request from Elm
  app.ports.joinGame.subscribe((payload) => {
    console.log("Joining game channel...", payload);

    channel = socket.channel("game:snake", payload as object);

    // Wire server events to Elm ports
    channel.on("tick", (delta) => {
      console.log("Tick received:", delta);
      app.ports.receiveTick.send(delta);
    });

    channel.on("player:join", (data) => {
      console.log("Player joined:", data);
      app.ports.playerJoined.send(data);
    });

    channel.on("player:leave", (data) => {
      console.log("Player left:", data);
      app.ports.playerLeft.send(data);
    });

    // Join the channel
    channel
      .join()
      .receive("ok", (response) => {
        console.log("Joined game channel successfully:", response);
        // Send initial game state to Elm
        if (response.game_state) {
          app.ports.receiveGameState.send(response.game_state);
        }
      })
      .receive("error", (response) => {
        console.error("Failed to join game channel:", response);
        app.ports.receiveError.send(response.reason || "Failed to join game");
      })
      .receive("timeout", () => {
        console.error("Channel join timeout");
        app.ports.receiveError.send("Connection timeout");
      });
  });

  // Handle direction changes from Elm
  app.ports.sendDirection.subscribe((data) => {
    if (channel) {
      console.log("Sending direction:", data);
      channel.push("player:change_direction", data as object);
    } else {
      console.warn("Cannot send direction: not connected to channel");
    }
  });

  // Handle leave game request from Elm
  app.ports.leaveGame.subscribe(() => {
    if (channel) {
      console.log("Leaving game channel...");
      channel.leave();
      channel = null;
    }
  });

  // Handle socket errors
  socket.onError(() => {
    console.error("Socket error");
    app.ports.receiveError.send("Socket connection error");
  });

  socket.onClose(() => {
    console.log("Socket closed");
  });
}
