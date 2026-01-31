# Phase 3: Integration & Sync - Research

**Researched:** 2026-02-01
**Domain:** Elm 0.19 game rendering with real-time WebSocket synchronization
**Confidence:** MEDIUM

## Summary

This phase integrates Elm frontend rendering with the Phoenix backend game server to create a synchronized multiplayer snake game. The research focused on Elm SVG rendering patterns, CSS-based visual effects (glow, flashing, fade-out), multiplayer game UI conventions (scoreboard, toast notifications), and state synchronization pitfalls.

The standard approach is to use **Elm's native SVG library** for rendering the game board (circles for snake segments, apples as text/emoji), **CSS animations** for visual effects (invincibility flashing, death fade-out, glow indicators), and **pure HTML/CSS** for UI elements (scoreboard, toast notifications). For a small game with ~5-10 concurrent players and ~100 grid cells, SVG performance is sufficient without requiring Canvas optimization.

The critical synchronization concern is ensuring the Elm model updates atomically on tick events - the entire game state must be replaced in a single update, not piecemeal, to prevent visual tearing or inconsistent intermediate states.

**Primary recommendation:** Use elm/svg 1.0.1 for all rendering, CSS keyframe animations for visual effects, and structure the view with Html.Keyed for the snake list to minimize DOM churn.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| elm/svg | 1.0.1 | SVG rendering | Official Elm package, simple API matching Html module structure |
| elm/html | 1.0.0 | DOM structure, events, CSS | Official Elm package for web applications |
| elm/json | 1.1.3 | JSON decoding | Official decoder library, already in use for WebSocket messages |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| CSS animations | Native | Visual effects (fade, flash, glow) | Better performance than JavaScript-driven animations |
| Html.Keyed | Built-in | Optimize list rendering | Essential for dynamic player lists to prevent full re-render |
| Html.Lazy | Built-in | Skip unchanged subtree rendering | Use for scoreboard if player list grows beyond 10 players |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| elm/svg | Canvas (elm-canvas) | Canvas has better performance at 5k+ elements, but SVG is simpler to develop and debug. For <100 elements (typical game state), SVG is sufficient. |
| CSS animations | Elm-based animation libraries | CSS runs on GPU compositor, better performance. Elm animation libraries add complexity without benefit for simple effects. |
| Custom toast component | JavaScript toast library (toastify.js) | Elm-native approach maintains type safety and single source of truth. JS library breaks Elm architecture. |

**Installation:**
```bash
# Already installed in project
# elm/svg, elm/html, elm/json are part of standard Elm 0.19 core
```

## Architecture Patterns

### Recommended Project Structure
```
assets/src/
├── Main.elm              # Top-level app, WebSocket integration
├── Game.elm              # Game state types and decoders
├── Snake.elm             # Snake types and decoders
├── View/
│   ├── Board.elm         # SVG game board rendering
│   ├── Scoreboard.elm    # Player list and scores
│   └── Notifications.elm # Toast notifications
├── Ports.elm             # JavaScript interop (already exists)
└── Input.elm             # Keyboard handling (already exists)
```

### Pattern 1: SVG Grid-Based Rendering
**What:** Render game state as SVG elements positioned on a fixed grid
**When to use:** Games with discrete grid positions (snake, Pac-Man, Tetris)
**Example:**
```elm
-- Source: Elm SVG community patterns + elm-discuss board game thread
viewBoard : GameState -> Html Msg
viewBoard state =
    Svg.svg
        [ width (String.fromInt (state.gridWidth * cellSize))
        , height (String.fromInt (state.gridHeight * cellSize))
        , viewBox ("0 0 " ++ String.fromInt (state.gridWidth * cellSize)
                         ++ " " ++ String.fromInt (state.gridHeight * cellSize))
        ]
        [ Svg.g [] (List.map viewApple state.apples)
        , Html.Keyed.node "g" [] (List.map viewKeyedSnake state.snakes)
        ]

viewSnakeSegment : Position -> String -> Html msg
viewSnakeSegment pos color =
    Svg.circle
        [ cx (String.fromInt (pos.x * cellSize + cellSize // 2))
        , cy (String.fromInt (pos.y * cellSize + cellSize // 2))
        , r (String.fromInt (cellSize // 2 - 2))
        , fill ("#" ++ color)
        ]
        []
```

### Pattern 2: Keyed Nodes for Dynamic Lists
**What:** Use Html.Keyed.node for lists where items are added/removed/reordered
**When to use:** Player lists, snake segments that change frequently
**Example:**
```elm
-- Source: Elm Guide - Optimization
viewKeyedSnake : Snake -> ( String, Html msg )
viewKeyedSnake snake =
    ( snake.id  -- Key prevents full re-render when snakes move
    , Svg.g [] (List.map (viewSnakeSegment snake.color) snake.body)
    )
```

### Pattern 3: CSS Class Toggling for Visual Effects
**What:** Toggle CSS classes to trigger animations instead of managing animation state in Elm
**When to use:** Simple effects like fade-out, flashing, glow
**Example:**
```elm
-- Source: Elm Discourse CSS transition patterns
viewSnake : Snake -> Bool -> Html msg
viewSnake snake isInvincible =
    Svg.g
        [ classList
            [ ("snake", True)
            , ("invincible", isInvincible)  -- CSS handles animation
            ]
        ]
        (List.map viewSegment snake.body)
```

CSS:
```css
.snake.invincible {
    animation: flash 0.2s infinite;
}

@keyframes flash {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.3; }
}
```

### Pattern 4: Server Tick as Single Source of Truth
**What:** Replace entire game state on each tick, don't merge or patch
**When to use:** Server-authoritative multiplayer games
**Example:**
```elm
-- Source: Game networking patterns + Elm architecture
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotTick value ->
            case JD.decodeValue Game.decoder value of
                Ok newState ->
                    -- Replace entire state atomically
                    ( { model | gameState = Just newState }, Cmd.none )
                Err _ ->
                    ( model, Cmd.none )
```

### Anti-Patterns to Avoid
- **Piecemeal state updates:** Don't update individual snake positions separately. Replace the full state to prevent race conditions.
- **String concatenation for styles:** Use proper Html attributes, not inline style strings. Elm's type system catches errors.
- **Animating with Elm subscriptions:** Don't use Time.every for visual effects. CSS animations run on GPU compositor and are more performant.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Toast notifications | Custom Elm notification queue manager | Simple HTML div with CSS animations and timeout | Notification state is transient UI, not core model. CSS handles timing better than Elm subscriptions. |
| Player color generation | Custom palette cycling logic | Pre-defined hex array from backend | Backend already has color list. Reuse it to ensure consistency across clients. |
| Invincibility timer display | Elm subscription polling invincibility_until | CSS animation triggered by class | Server tells us invincible/not via boolean. CSS handles visual timing. |
| Smooth movement interpolation | Frame-by-frame position tweening | None - server sends discrete positions 10/sec | At 10 ticks/sec, interpolation adds complexity without smoothness gain. Trust server positions. |

**Key insight:** For server-authoritative games, the client is a "dumb renderer." Visual effects should use CSS/GPU, not Elm state. Don't try to predict or smooth server state - it creates sync bugs.

## Common Pitfalls

### Pitfall 1: Decode Failure on Partial Updates
**What goes wrong:** Elm decoder fails when server sends partial state (delta updates), causing silent failures and stale UI.
**Why it happens:** Server optimization sends only changed fields, but Elm decoder expects all fields every time.
**How to avoid:** Ensure server always sends full state structure (can send same values, just include all fields). Backend GameServer already does this in `serialize_full_state/1`.
**Warning signs:** "Expecting a field" errors in console, UI freezing while network tab shows tick messages arriving.

### Pitfall 2: Visual Tearing from Race Conditions
**What goes wrong:** Snake appears disconnected or in two places at once for one frame.
**Why it happens:** Updating model.snakes in one message handler, model.apples in another, with render in between.
**How to avoid:** Always update entire game state in a single case branch. Don't have separate handlers for snakes, apples, players.
**Warning signs:** Flickering positions, snakes "jumping" across grid, apples appearing/disappearing mid-tick.

### Pitfall 3: Forgetting Elm 0.19 Html.Keyed Import
**What goes wrong:** Html.Keyed.node not found error, or rendering full list on every tick.
**Why it happens:** Html.Keyed is separate import, not exposed from Html module.
**How to avoid:** Import explicitly: `import Html.Keyed`
**Warning signs:** Compile error, or performance degradation as player count increases (check with 5+ snakes).

### Pitfall 4: Z-Index Issues with SVG Rendering Order
**What goes wrong:** Snake heads render under apples, or dead snakes appear on top of living snakes.
**Why it happens:** SVG doesn't have z-index - elements render in document order.
**How to avoid:** Render in correct order: background → apples → snakes (sorted by state) → UI overlay.
**Warning signs:** Visual elements appearing in wrong layer, heads hidden by bodies of other snakes.

### Pitfall 5: Player ID Mismatch Between Server and Client
**What goes wrong:** "You" indicator highlights wrong snake, or direction changes affect other player.
**Why it happens:** Server sends integer player IDs, Elm stores as String, comparison fails.
**How to avoid:** Decode player ID as String consistently. Server serializes with `to_string(snake.id)`.
**Warning signs:** Multiple snakes show "you" glow, or no snake shows glow. Direction changes don't work.

## Code Examples

Verified patterns from official sources and community best practices:

### SVG Circle for Snake Segment
```elm
-- Source: elm/svg package examples
viewSegment : Position -> String -> Html msg
viewSegment pos color =
    Svg.circle
        [ Svg.Attributes.cx (String.fromInt (pos.x * 20 + 10))
        , Svg.Attributes.cy (String.fromInt (pos.y * 20 + 10))
        , Svg.Attributes.r "8"
        , Svg.Attributes.fill ("#" ++ color)
        , Svg.Attributes.stroke "#000"
        , Svg.Attributes.strokeWidth "1"
        ]
        []
```

### Keyed Node for Snake List
```elm
-- Source: Elm Guide - Html.Keyed optimization
viewSnakes : List Snake -> String -> Html msg
viewSnakes snakes playerId =
    Html.Keyed.node "g"
        []
        (List.map
            (\snake -> ( snake.id, viewSnake snake (snake.id == playerId) ))
            snakes
        )
```

### CSS Invincibility Flash
```css
/* Source: CSS animation best practices - W3C MDN */
.snake.invincible {
    animation: flash 200ms ease-in-out infinite;
}

@keyframes flash {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.3; }
}
```

### CSS Death Fade-Out
```css
/* Source: CSS transitions - MDN */
.snake.dying {
    animation: fadeOut 500ms ease-out forwards;
}

@keyframes fadeOut {
    from { opacity: 1; }
    to { opacity: 0; }
}
```

### CSS Glow Effect for "You" Indicator
```css
/* Source: CSS glow effects collection */
.snake.you circle {
    filter: drop-shadow(0 0 8px currentColor)
            drop-shadow(0 0 12px currentColor);
}
```

### Toast Notification HTML/CSS
```elm
-- Source: Elm patterns + toast notification practices
viewNotification : Maybe String -> Html msg
viewNotification maybeMsg =
    case maybeMsg of
        Just msg ->
            div [ class "toast" ] [ text msg ]
        Nothing ->
            text ""
```

```css
/* Source: Modern toast notification patterns 2026 */
.toast {
    position: fixed;
    top: 20px;
    right: 20px;
    padding: 12px 20px;
    background: rgba(0, 0, 0, 0.8);
    color: white;
    border-radius: 4px;
    animation: slideInFadeOut 3s ease-out forwards;
}

@keyframes slideInFadeOut {
    0% { transform: translateX(400px); opacity: 0; }
    10% { transform: translateX(0); opacity: 1; }
    90% { transform: translateX(0); opacity: 1; }
    100% { transform: translateX(400px); opacity: 0; }
}
```

### Scoreboard with Sorted Players
```elm
-- Source: Elm List.sortBy pattern
viewScoreboard : List Snake -> Html msg
viewScoreboard snakes =
    div [ class "scoreboard" ]
        [ h3 [] [ text "Players" ]
        , div [ class "player-list" ]
            (snakes
                |> List.sortBy (\s -> negate (List.length s.body))  -- Longest first
                |> List.map viewPlayerEntry
            )
        ]

viewPlayerEntry : Snake -> Html msg
viewPlayerEntry snake =
    div [ class "player-entry" ]
        [ span [ class "player-color", style "background-color" ("#" ++ snake.color) ] []
        , span [ class "player-name" ] [ text snake.name ]
        , span [ class "player-score" ] [ text (String.fromInt (List.length snake.body)) ]
        ]
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| elm-phoenix-socket library | Ports-based WebSocket | Elm 0.19 (2019) | elm-phoenix-socket incompatible with 0.19, ports are standard way |
| Client-side game simulation | Server-authoritative with tick broadcast | Phoenix 1.7 + 2026 patterns | Eliminates sync bugs, server is source of truth |
| Canvas for simple grid games | SVG unless 5k+ elements | Modern browser SVG performance | SVG easier to develop, debug, style with CSS |
| JavaScript animation libraries | CSS animations with class toggling | Modern CSS3 support (2020+) | Better performance (GPU compositor), simpler Elm code |

**Deprecated/outdated:**
- **elm-animation library:** Not maintained for Elm 0.19. Use CSS animations instead.
- **WebSocket subscriptions in Elm:** Elm 0.19 removed native WebSocket support. Use ports.
- **Manual interpolation between ticks:** Adds complexity without benefit at 10 ticks/sec. Server positions are ground truth.

## Open Questions

Things that couldn't be fully resolved:

1. **Server-side invincibility timer representation**
   - What we know: Server tracks `invincible_until` timestamp, checks with `is_invincible?/1`
   - What's unclear: Does server send boolean `is_invincible` in serialized snake, or does client calculate from timestamp?
   - Recommendation: Add `is_invincible: boolean` to serialized snake. Simpler than client timestamp comparison, avoids clock sync issues.

2. **Death animation timing and state**
   - What we know: Need 0.5s fade-out before snake disappears
   - What's unclear: Does server mark snake as "dying" before removal, or does client detect removal and animate?
   - Recommendation: Server should send `state: "alive" | "dying" | "respawning"` field. Client animates based on state, not by detecting changes.

3. **Apple spawn rate tuning**
   - What we know: Server has `spawn_apples_if_needed/1`, currently spawns to maintain minimum count
   - What's unclear: Should be time-based (1 apple per N ticks) or count-based (maintain X apples)?
   - Recommendation: Start with count-based (3 apples), tune based on gameplay testing. Time-based can flood board if no one eats.

4. **Maximum player count and performance**
   - What we know: SVG handles <100 elements well, game has ~30-50 elements per 3 players
   - What's unclear: At what player count does SVG performance degrade?
   - Recommendation: Test with 10 simulated players. If 60fps maintained, SVG is fine. If not, optimize with Html.Lazy on scoreboard first, Canvas as last resort.

## Sources

### Primary (HIGH confidence)
- [elm/svg 1.0.1](https://package.elm-lang.org/packages/elm/svg/latest/) - Official Elm SVG package (version confirmed)
- [Elm Guide - Optimization](https://guide.elm-lang.org/optimization/) - Html.Keyed and Html.Lazy patterns
- [Elm Guide - JSON](https://guide.elm-lang.org/effects/json.html) - Decoder patterns and error handling

### Secondary (MEDIUM confidence)
- [Elm Discourse: Board game rendering in 0.17](https://elm-discuss.narkive.com/BbhAf0BB/recommended-way-to-render-a-board-game-in-0-17) - SVG grid patterns (verified with official docs)
- [MDN: Using CSS Animations](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_animations/Using_CSS_animations) - Keyframes, timing, best practices
- [CSS-Tricks: Animation](https://css-tricks.com/almanac/properties/a/animation/) - CSS animation property reference
- [SVG vs Canvas 2025 comparison](https://www.svggenie.com/blog/svg-vs-canvas-vs-webgl-performance-2025) - Performance thresholds (verified with community consensus)
- [Game Networking: Time Synchronization](https://daposto.medium.com/game-networking-2-time-tick-clock-synchronisation-9a0e76101fe5) - Tick-based sync patterns
- [How Multiplayer Games Sync State](https://medium.com/@qingweilim/how-do-multiplayer-games-sync-their-state-part-1-ab72d6a54043) - State vs delta updates

### Tertiary (LOW confidence - marked for validation)
- [jQuery Script: Toast Notifications 2026](https://www.jqueryscript.net/blog/Best-Toast-Notification-jQuery-Plugins.html) - Survey of patterns, but not Elm-specific
- [CSS Glow Effects 2026](https://www.testmuai.com/blog/glowing-effects-in-css/) - Multiple examples, but not game-specific
- [Elm 0.19 game examples](https://github.com/rofrol/elm-games) - Community collection, quality varies

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - elm/svg and elm/html are official, well-documented, proven
- Architecture: MEDIUM - Patterns verified across multiple sources, but not Elm 0.19-specific for all
- Rendering: HIGH - SVG vs Canvas thresholds confirmed, CSS animation support verified
- Synchronization: MEDIUM - General game networking patterns, not Phoenix-specific
- Visual effects: MEDIUM - CSS patterns verified, but Elm integration is standard practice not documented

**Research date:** 2026-02-01
**Valid until:** 2026-03-01 (30 days - stable technologies, minimal API churn)

**Notes:**
- No Context7 queries performed (elm/svg, elm/html not in Context7 library database)
- All Elm package versions verified against package.elm-lang.org
- CSS animation browser support: 98%+ modern browsers (caniuse.com)
- WebSocket binary protocol not needed - JSON sufficient for <10 players at 10 ticks/sec
