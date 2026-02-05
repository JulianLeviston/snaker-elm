# Snaker

A multiplayer Snake game written in Elm and Phoenix, with support for both server-based and peer-to-peer gameplay.

**Play Now: [genericoverlords.com/snaker](https://www.genericoverlords.com/snaker)**

![](https://raw.githubusercontent.com/JulianLeviston/snaker-elm/main/images/snaker-elm.png)

## Background

The idea should be familiar: you are a snake, and you want to eat randomly appearing apples. This makes you grow. Apples appear for a brief time, then reappear somewhere else.

## Multiplayer Modes

Snaker supports two multiplayer modes:

- **P2P Mode** - Serverless peer-to-peer connections using WebRTC (PeerJS). One player hosts and shares a room code or QR code with others. No server required after the initial page load.
- **Phoenix Mode** - Traditional server-based multiplayer using Phoenix channels. Game state is managed on the server.

Your mode preference is saved locally and remembered between sessions.

## Running Locally

To start the system:

1. Install Elixir dependencies: `mix deps.get`
2. Install Node.js dependencies: `npm install`
3. Start Phoenix endpoint: `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Static Build (P2P Only)

For P2P-only deployment without a Phoenix server:

```bash
npm run build:static
```

This generates a standalone `dist/index.html` that can be hosted on any static file server.

## Development

- **Elm frontend**: `/assets/src/` (Elm 0.19.1)
- **Phoenix backend**: `/lib/`
- **JavaScript interop**: `/assets/js/` (TypeScript)

The build uses esbuild with the Elm plugin. Run `npm run watch` for development with hot reloading.

## Project Structure

```
assets/
  src/           # Elm source files
    Main.elm     # Application entry point
    Engine/      # Game logic (collision, grid, apple spawning)
    Network/     # P2P host/client game management
    View/        # UI components (board, scoreboard, connection UI)
  js/            # TypeScript for JS interop
    app.ts       # Entry point, wires Elm ports
    socket.ts    # Phoenix channel connection
    peerjs-ports.ts  # WebRTC P2P connections
lib/
  snaker/        # Elixir game logic
  snaker_web/    # Phoenix web layer
```

## Future

- Experiment with WebGL and/or WebGPU
- "Levels" and other interesting features
