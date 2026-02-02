---
created: 2026-01-31T02:34
title: Multi-language multi-backend showcase system
area: planning
files: []
---

## Problem

The current Snaker game is a single-stack application (Elm + Phoenix/Elixir). There's a vision to expand this into a multi-language showcase platform that demonstrates real-time multiplayer snake with various frontend and backend combinations.

Target stacks to showcase:
- **Backends:** Elixir/Phoenix, Rails, Haskell, Rust
- **Frontends:** Elm, PureScript with React, Bun with TypeScript, vanilla React

The system would sync game state across different backend implementations, allowing comparison of approaches to real-time multiplayer in different languages/frameworks.

## Solution

TBD — This is a significant architectural expansion beyond v1 scope.

Possible approaches:
1. Shared protocol spec (WebSocket message format) that all backends implement
2. Adapter layer that normalizes backend differences
3. Frontend implementations that work with any backend via standard protocol
4. Benchmark/comparison dashboard showing latency, throughput across stacks

Consider for v2/v3 milestone after current upgrade completes.
