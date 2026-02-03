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
    send: (data: { role: string; peerId?: string; roomCode?: string; myPeerId?: string }) => void;
  };
  peerDisconnected: { send: (peerId: string) => void };
  connectionError: { send: (message: string) => void };
  clipboardCopySuccess: { send: (data: null) => void };
  receiveGameStateP2P: { send: (data: string) => void };
  receiveInputP2P: { send: (data: string) => void };
  // Host migration events
  hostMigration: {
    send: (data: HostMigrationEvent) => void;
  };
}

// Host migration event types
type HostMigrationEvent =
  | { type: "become_host"; myPeerId: string; peers: string[] }
  | { type: "new_host"; newHostId: string }
  | { type: "connection_lost" };

interface ElmAppWithP2P {
  ports: P2PPorts;
}

// Module-level state (peer objects are not serializable for Elm)
let peer: Peer | null = null;
let connections: Map<string, DataConnection> = new Map();
let joinTimeout: ReturnType<typeof setTimeout> | null = null;

// Host migration state
let myPeerId: string | null = null;
let isHost: boolean = false;
let knownPeers: Set<string> = new Set(); // Track all peers in room (for host migration)
let currentHostId: string | null = null; // Track current host's ID (for clients)
let lastKnownGameState: string | null = null; // Last game state for migration

/**
 * Elect new host using deterministic selection (lowest peer ID)
 */
function electNewHost(excludeId: string): string | null {
  const candidates = Array.from(knownPeers)
    .filter((id) => id !== excludeId)
    .sort(); // Lexicographic sort = lowest ID first

  // Include self if not excluded
  if (myPeerId && myPeerId !== excludeId) {
    candidates.push(myPeerId);
    candidates.sort();
  }

  return candidates[0] || null;
}

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

  // Reset migration state
  myPeerId = null;
  isHost = false;
  knownPeers.clear();
  currentHostId = null;
  lastKnownGameState = null;
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
      myPeerId = id;
      isHost = true;
      currentHostId = id;
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
      knownPeers.add(conn.peer); // Track peer for migration

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
        knownPeers.delete(conn.peer); // Remove from peer tracking
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
    peer.on("open", (id) => {
      console.log(`Peer created with ID: ${id}, connecting to room: ${roomCode}`);
      myPeerId = id;
      isHost = false;
      currentHostId = roomCode;

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
          myPeerId: peer!.id, // Include client's own peerId
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

      // Handle connection close (host disconnected)
      conn.on("close", () => {
        console.log(`Disconnected from host: ${roomCode}`);
        connections.delete(roomCode);
        handleHostDisconnect(app, roomCode);
      });

      // Handle data from host
      conn.on("data", (data: any) => {
        console.log(`Received data from host:`, data);
        if (data && data.type === "state") {
          lastKnownGameState = data.data; // Store for migration
          // Extract peer list from state sync for migration tracking
          try {
            const stateData = JSON.parse(data.data);
            if (stateData.snakes) {
              // Track all snake IDs as known peers
              stateData.snakes.forEach((snake: { id: string }) => {
                if (snake.id !== myPeerId) {
                  knownPeers.add(snake.id);
                }
              });
            }
          } catch (e) {
            // Ignore parse errors
          }
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

  /**
   * Handle host disconnection with migration election
   */
  function handleHostDisconnect(app: ElmAppWithP2P, oldHostId: string): void {
    console.log(`Host ${oldHostId} disconnected, checking for migration...`);

    // Remove old host from known peers
    knownPeers.delete(oldHostId);

    // Elect new host (lowest peer ID)
    const newHostId = electNewHost(oldHostId);
    console.log(`Election result: newHostId=${newHostId}, myPeerId=${myPeerId}`);

    if (newHostId === myPeerId && myPeerId) {
      // I am the new host
      console.log("I am the new host! Transitioning...");
      isHost = true;
      currentHostId = myPeerId;

      // Set up to receive connections from other clients
      setupMigratedHostHandlers(app);

      app.ports.hostMigration.send({
        type: "become_host",
        myPeerId: myPeerId,
        peers: Array.from(knownPeers),
      });
    } else if (newHostId) {
      // Someone else is new host - reconnect to them
      console.log(`New host is ${newHostId}, reconnecting...`);
      currentHostId = newHostId;

      // In star topology, we need to reconnect to the new host
      // The new host should have set up to accept connections
      reconnectToNewHost(app, newHostId);

      app.ports.hostMigration.send({
        type: "new_host",
        newHostId: newHostId,
      });
    } else {
      // No peers left, game over
      console.log("No peers left, connection lost");
      app.ports.hostMigration.send({ type: "connection_lost" });
    }
  }

  /**
   * Set up handlers for migrated host to receive connections
   */
  function setupMigratedHostHandlers(app: ElmAppWithP2P): void {
    if (!peer) return;

    // Handle incoming connections from other clients reconnecting
    peer.on("connection", (conn) => {
      console.log(`[Migrated Host] Client connecting: ${conn.peer}`);
      connections.set(conn.peer, conn);
      knownPeers.add(conn.peer);

      conn.on("open", () => {
        console.log(`[Migrated Host] Client connected: ${conn.peer}`);
        // Don't send peerConnected again - the client is reconnecting, not joining fresh
      });

      conn.on("error", (err) => {
        console.error(`[Migrated Host] Connection error with ${conn.peer}:`, err);
      });

      conn.on("close", () => {
        console.log(`[Migrated Host] Client disconnected: ${conn.peer}`);
        connections.delete(conn.peer);
        knownPeers.delete(conn.peer);
        app.ports.peerDisconnected.send(conn.peer);
      });

      conn.on("data", (data: any) => {
        if (data && data.type === "input") {
          app.ports.receiveInputP2P.send(data.data);
        }
      });
    });
  }

  /**
   * Reconnect to new host after migration
   */
  function reconnectToNewHost(app: ElmAppWithP2P, newHostId: string): void {
    if (!peer) return;

    console.log(`Reconnecting to new host: ${newHostId}`);
    const conn = peer.connect(newHostId, { reliable: true });
    connections.set(newHostId, conn);

    conn.on("open", () => {
      console.log(`Reconnected to new host: ${newHostId}`);
    });

    conn.on("error", (err) => {
      console.error(`Failed to reconnect to new host:`, err);
      app.ports.hostMigration.send({ type: "connection_lost" });
    });

    conn.on("close", () => {
      console.log(`Disconnected from new host: ${newHostId}`);
      connections.delete(newHostId);
      // Recursive migration attempt
      handleHostDisconnect(app, newHostId);
    });

    conn.on("data", (data: any) => {
      if (data && data.type === "state") {
        lastKnownGameState = data.data;
        app.ports.receiveGameStateP2P.send(data.data);
      }
    });
  }

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
