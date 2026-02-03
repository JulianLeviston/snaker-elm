// PeerJS integration with Elm ports for P2P connections
import Peer, { DataConnection } from "peerjs";

// Interface for P2P-specific Elm ports
interface P2PPorts {
  // Outgoing (Elm -> JS commands)
  createRoom: { subscribe: (callback: (data: null) => void) => void };
  joinRoom: { subscribe: (callback: (roomCode: string) => void) => void };
  leaveRoom: { subscribe: (callback: () => void) => void };
  copyToClipboard: { subscribe: (callback: (text: string) => void) => void };
  broadcastGameState: { subscribe: (callback: (data: string) => void) => void };
  sendInputP2P: { subscribe: (callback: (data: string) => void) => void };

  // Incoming (JS -> Elm events)
  roomCreated: { send: (roomCode: string) => void };
  peerConnected: {
    send: (data: { role: string; peerId?: string; roomCode?: string }) => void;
  };
  peerDisconnected: { send: (peerId: string) => void };
  connectionError: { send: (message: string) => void };
  clipboardCopySuccess: { send: (data: null) => void };
  receiveGameStateP2P: { send: (data: string) => void };
  receiveInputP2P: { send: (data: string) => void };
}

interface ElmAppWithP2P {
  ports: P2PPorts;
}

// Module-level state (peer objects are not serializable for Elm)
let peer: Peer | null = null;
let connections: Map<string, DataConnection> = new Map();
let joinTimeout: ReturnType<typeof setTimeout> | null = null;

/**
 * Generate a 4-letter room code (A-Z only)
 */
function generateRoomCode(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  let code = "";
  for (let i = 0; i < 4; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

/**
 * Map PeerJS error types to user-friendly messages
 */
function errorToMessage(err: Error & { type?: string }): string {
  const errorType = err.type || "";

  switch (errorType) {
    case "peer-unavailable":
      return "Room not found";
    case "unavailable-id":
      return "Room code already in use";
    case "network":
      return "Connection failed - check your internet";
    case "browser-incompatible":
      return "Your browser does not support WebRTC";
    case "disconnected":
      return "Lost connection to server";
    case "invalid-id":
      return "Invalid room code format";
    case "invalid-key":
      return "Invalid API key";
    case "ssl-unavailable":
      return "SSL required for WebRTC";
    case "server-error":
      return "Server error - try again later";
    case "socket-error":
      return "Connection error - try again";
    case "socket-closed":
      return "Connection closed unexpectedly";
    case "webrtc":
      return "WebRTC connection failed";
    default:
      console.error("PeerJS error:", err);
      return "Connection failed";
  }
}

/**
 * Clean up peer state
 */
function cleanup(): void {
  if (joinTimeout) {
    clearTimeout(joinTimeout);
    joinTimeout = null;
  }

  connections.forEach((conn) => {
    try {
      conn.close();
    } catch (e) {
      // Ignore errors during cleanup
    }
  });
  connections.clear();

  if (peer) {
    try {
      peer.destroy();
    } catch (e) {
      // Ignore errors during cleanup
    }
    peer = null;
  }
}

/**
 * Setup PeerJS port subscriptions
 */
export function setupPeerPorts(app: ElmAppWithP2P): void {
  // Subscribe to createRoom command
  app.ports.createRoom.subscribe(() => {
    // Cleanup any existing peer
    cleanup();

    const roomCode = generateRoomCode();
    console.log(`Creating room with code: ${roomCode}`);

    // Use default PeerJS cloud server (0.peerjs.com)
    peer = new Peer(roomCode);

    // Handle peer open (successfully connected to signaling server)
    peer.on("open", (id) => {
      console.log(`Room created with ID: ${id}`);
      app.ports.roomCreated.send(id);
    });

    // Handle errors on peer object
    peer.on("error", (err) => {
      console.error("Peer error:", err);
      const message = errorToMessage(err);
      app.ports.connectionError.send(message);
    });

    // Handle incoming connections (clients connecting to host)
    peer.on("connection", (conn) => {
      console.log(`Client connecting: ${conn.peer}`);
      connections.set(conn.peer, conn);

      // Setup connection event handlers
      conn.on("open", () => {
        console.log(`Client connected: ${conn.peer}`);
        app.ports.peerConnected.send({
          role: "host",
          peerId: conn.peer,
        });
      });

      conn.on("error", (err) => {
        console.error(`Connection error with ${conn.peer}:`, err);
        app.ports.connectionError.send(errorToMessage(err));
      });

      conn.on("close", () => {
        console.log(`Client disconnected: ${conn.peer}`);
        connections.delete(conn.peer);
        app.ports.peerDisconnected.send(conn.peer);
      });

      // Handle data from clients
      conn.on("data", (data: any) => {
        console.log(`Received data from ${conn.peer}:`, data);
        if (data && data.type === "input") {
          app.ports.receiveInputP2P.send(data.data);
        }
      });
    });
  });

  // Subscribe to joinRoom command
  app.ports.joinRoom.subscribe((roomCode: string) => {
    // Cleanup any existing peer
    cleanup();

    console.log(`Joining room: ${roomCode}`);

    // Create peer with random ID for client (uses default PeerJS cloud)
    peer = new Peer();

    // Handle peer open (successfully connected to signaling server)
    peer.on("open", () => {
      console.log(`Peer created, connecting to room: ${roomCode}`);

      // Connect to the room (host)
      const conn = peer!.connect(roomCode, {
        reliable: true,
      });

      // Store connection
      connections.set(roomCode, conn);

      // Set 10-second timeout for connection
      joinTimeout = setTimeout(() => {
        console.error("Connection timeout");
        app.ports.connectionError.send(
          "Connection timed out - room may not exist"
        );
        cleanup();
      }, 10000);

      // Handle connection open
      conn.on("open", () => {
        console.log(`Connected to room: ${roomCode}`);

        // Clear timeout on successful connection
        if (joinTimeout) {
          clearTimeout(joinTimeout);
          joinTimeout = null;
        }

        app.ports.peerConnected.send({
          role: "client",
          roomCode: roomCode,
        });
      });

      // Handle connection error
      conn.on("error", (err) => {
        console.error(`Connection error:`, err);

        // Clear timeout on error
        if (joinTimeout) {
          clearTimeout(joinTimeout);
          joinTimeout = null;
        }

        app.ports.connectionError.send(errorToMessage(err));
      });

      // Handle connection close
      conn.on("close", () => {
        console.log(`Disconnected from room: ${roomCode}`);
        connections.delete(roomCode);
        app.ports.peerDisconnected.send(roomCode);
      });

      // Handle data from host
      conn.on("data", (data: any) => {
        console.log(`Received data from host:`, data);
        if (data && data.type === "state") {
          app.ports.receiveGameStateP2P.send(data.data);
        }
      });
    });

    // Handle errors on peer object
    peer.on("error", (err) => {
      console.error("Peer error:", err);

      // Clear timeout on error
      if (joinTimeout) {
        clearTimeout(joinTimeout);
        joinTimeout = null;
      }

      app.ports.connectionError.send(errorToMessage(err));
    });
  });

  // Subscribe to leaveRoom command
  app.ports.leaveRoom.subscribe(() => {
    console.log("Leaving room");
    cleanup();
  });

  // Subscribe to broadcastGameState command (host sends to all clients)
  app.ports.broadcastGameState.subscribe((jsonData: string) => {
    connections.forEach((conn) => {
      if (conn.open) {
        conn.send({ type: "state", data: jsonData });
      }
    });
  });

  // Subscribe to sendInputP2P command (client sends to host)
  app.ports.sendInputP2P.subscribe((jsonData: string) => {
    // Client should only have one connection (to host)
    connections.forEach((conn) => {
      if (conn.open) {
        conn.send({ type: "input", data: jsonData });
      }
    });
  });

  // Subscribe to copyToClipboard command
  app.ports.copyToClipboard.subscribe((text: string) => {
    navigator.clipboard
      .writeText(text)
      .then(() => {
        console.log("Text copied to clipboard");
        app.ports.clipboardCopySuccess.send(null);
      })
      .catch((err) => {
        console.error("Failed to copy to clipboard:", err);
        // Don't send error for clipboard - just log it
      });
  });
}
