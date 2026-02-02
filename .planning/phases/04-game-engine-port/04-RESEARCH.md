# Phase 4: Game Engine Port - Research

**Researched:** 2026-02-03
**Domain:** Elm game loop implementation and state management
**Confidence:** HIGH

## Summary

This phase ports the Elixir game engine to pure Elm, creating a single-player snake game with 100ms tick loop. The research focused on Elm-specific patterns for game loops, time-based subscriptions, state management, and random number generation.

The standard approach for Elm game loops is using `Time.every` subscriptions for fixed-interval ticks. The existing codebase already has Input handling (Browser.Events.onKeyDown), Snake types, and view rendering in place from v1. The port needs to add: game tick loop, collision detection, apple management, and score tracking entirely in Elm.

The Elixir reference implementation (GameServer, Snake, Apple, Grid modules) provides authoritative game rules: 100ms ticks, edge wrapping, collision detection (self and other snakes), invincibility periods (1500ms), apple spawning (minimum 3), and growth amount (3 segments per apple).

**Primary recommendation:** Use Time.every for 100ms tick subscription, store game state in Model with Random.Seed for deterministic apple spawning, implement game logic as pure functions matching Elixir behavior.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| elm/time | 1.0.0 | Game tick subscriptions | Official Elm package for time-based effects |
| elm/browser | 1.0.2 | Browser.Events for keyboard input | Already used in project, official package |
| elm/random | 1.0.0 | Random number generation for apple spawning | Official Elm package for randomness |
| elm/core | 1.0.5 | Basic types and functions | Elm standard library |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| elm/json | 1.1.3 | JSON encoding/decoding | Already in project for serialization |
| elm/svg | 1.0.1 | SVG rendering for game board | Already in project for visualization |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Time.every | AnimationFrame (elm-lang/animation-frame) | AnimationFrame gives 60fps smoothness but is overkill for 100ms tick loop; Time.every is simpler and sufficient |
| Random.generate | Manual seed management with Random.step | Random.generate handles side effects cleanly; manual seeds are error-prone |

**Installation:**
No new dependencies required - all packages already in elm.json.

## Architecture Patterns

### Recommended Project Structure
```
src/
├── Main.elm              # Entry point, update/view/subscriptions
├── Game.elm              # Game state types and logic
├── Snake.elm             # Snake types and movement
├── Input.elm             # Keyboard input (already exists)
├── Engine/
│   ├── Tick.elm          # Game loop tick logic
│   ├── Collision.elm     # Collision detection
│   ├── Apple.elm         # Apple spawning and management
│   └── Grid.elm          # Grid utilities and wrapping
└── View/
    ├── Board.elm         # Already exists
    ├── Scoreboard.elm    # Already exists
    └── Notifications.elm # Already exists
```

### Pattern 1: Time-Based Game Loop with Fixed Tick
**What:** Use Time.every subscription to trigger game ticks at fixed 100ms intervals
**When to use:** For turn-based or grid-based games requiring consistent timing regardless of frame rate
**Example:**
```elm
-- Source: Official Elm guide (https://guide.elm-lang.org/effects/time.html)
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every 100 Tick  -- 10 ticks per second
        , Browser.Events.onKeyDown (JD.map KeyPressed Input.keyDecoder)
        ]

type Msg
    = Tick Time.Posix
    | KeyPressed (Maybe Direction)
```

### Pattern 2: Game State with Input Buffer
**What:** Store pending direction changes in model, apply on next tick to prevent input loss
**When to use:** When inputs arrive faster than game updates (player mashing keys)
**Example:**
```elm
-- Based on Elixir GameServer pattern
type alias Model =
    { snake : Snake
    , apples : List Position
    , grid : Grid
    , inputBuffer : Maybe Direction  -- Apply on next tick
    , score : Int
    , seed : Random.Seed
    , gameStatus : GameStatus
    }

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        KeyPressed (Just direction) ->
            if validDirectionChange model.snake.direction direction then
                ( { model | inputBuffer = Just direction }, Cmd.none )
            else
                ( model, Cmd.none )

        Tick _ ->
            model
                |> applyInputBuffer
                |> moveSnake
                |> checkCollisions
                |> checkAppleEating
                |> spawnApplesIfNeeded
                |> clearInputBuffer
```

### Pattern 3: Pure Game Logic Functions
**What:** Implement game logic as pure functions that take old state and return new state
**When to use:** Always - enables testing and matches Elm architecture
**Example:**
```elm
-- Pure function matching Elixir Snake.move/2
moveSnake : Model -> Model
moveSnake model =
    let
        newHead = nextHeadPosition model.snake model.grid
        newSegments =
            if model.snake.pendingGrowth > 0 then
                newHead :: model.snake.segments
            else
                newHead :: List.take (List.length model.snake.segments - 1) model.snake.segments
    in
    { model | snake = { snake | segments = newSegments } }

-- Pure collision check matching Elixir
collidesWithSelf : Snake -> Bool
collidesWithSelf snake =
    case snake.segments of
        head :: tail ->
            List.member head tail
        [] ->
            False
```

### Pattern 4: Random.generate for Controlled Side Effects
**What:** Use Random.generate command to get random values without manual seed management
**When to use:** For apple spawning - cleaner than threading seeds through update
**Example:**
```elm
-- Source: Elm Random documentation patterns
type Msg
    = SpawnApple
    | NewApplePosition Position
    | Tick Time.Posix

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        SpawnApple ->
            let
                occupiedPositions = getAllOccupied model
                generator = randomSafePosition occupiedPositions model.grid
            in
            ( model, Random.generate NewApplePosition generator )

        NewApplePosition pos ->
            ( { model | apples = pos :: model.apples }, Cmd.none )

-- Generator that avoids occupied positions
randomSafePosition : List Position -> Grid -> Random.Generator Position
randomSafePosition occupied grid =
    Random.map2 Position
        (Random.int 0 (grid.width - 1))
        (Random.int 0 (grid.height - 1))
    |> Random.andThen (\pos ->
        if List.member pos occupied then
            randomSafePosition occupied grid  -- Retry
        else
            Random.constant pos
    )
```

### Anti-Patterns to Avoid
- **Storing Time.Posix in model for invincibility:** Store tick count or milliseconds as Int instead - simpler and testable
- **Updating view-specific state on every tick:** Only update game state; derive view data in view function
- **Direction change without validation:** Always check opposite direction prevention (can't go from Up to Down directly)
- **Mixing Commands in tick pipeline:** Keep tick update pure, generate Commands only when needed (apple spawn)

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Random numbers | Custom RNG or manual seed threading | Random.generate with generators | Handles side effects correctly, composable generators, avoids seed bugs |
| Keyboard input | Raw event.key parsing | Browser.Events.onKeyDown with decoder | Already implemented in Input.elm, handles repeat events and preventDefault |
| Time intervals | requestAnimationFrame wrapper | Time.every subscription | Simpler for fixed-tick games, built-in, no sync issues |
| Position wrapping | Modulo with negative number bugs | rem (x + width) width pattern | Handles negative wraps correctly (Elixir uses this) |

**Key insight:** Elm's subscription and command system handles side effects (time, random, events) - don't fight the architecture by trying to make everything synchronous.

## Common Pitfalls

### Pitfall 1: Negative Modulo Wrapping
**What goes wrong:** Using `rem` or `modBy` directly on negative positions gives negative results
**Why it happens:** In Elm, `rem -1 30` returns `-1`, not `29`
**How to avoid:** Use pattern `rem (value + dimension) dimension` from Elixir reference
**Warning signs:** Snake disappearing when crossing left/top edges
**Example:**
```elm
-- WRONG: rem can return negative
wrapX : Int -> Int -> Int
wrapX x width = rem x width

-- CORRECT: Add dimension before rem
wrapX : Int -> Int -> Int
wrapX x width = rem (x + width) width
```

### Pitfall 2: Direction Change Race Conditions
**What goes wrong:** Player presses Left then Up quickly, snake reverses into itself
**Why it happens:** Without input buffer, both changes apply before next tick validation
**How to avoid:** Use input buffer pattern - only store first direction per tick
**Warning signs:** Snake dying unexpectedly on rapid key presses
**Example:**
```elm
-- WRONG: Direct application
KeyPressed dir ->
    ( { model | snake = updateDirection model.snake dir }, Cmd.none )

-- CORRECT: Buffer and validate
KeyPressed dir ->
    if model.inputBuffer == Nothing && validChange model.snake.direction dir then
        ( { model | inputBuffer = Just dir }, Cmd.none )
    else
        ( model, Cmd.none )
```

### Pitfall 3: Growing Snake During Death
**What goes wrong:** Snake eats apple and dies on same tick, keeps growth
**Why it happens:** Order of operations - eating before collision check
**How to avoid:** Match Elixir order - move, collisions, eating, spawning
**Warning signs:** Respawned snake longer than expected
**Example:**
```elm
-- CORRECT order from Elixir GameServer
updateOnTick : Model -> Model
updateOnTick model =
    model
        |> applyInputBuffer
        |> moveSnake           -- 1. Move first
        |> checkCollisions     -- 2. Check death (respawns if dead)
        |> checkAppleEating    -- 3. Eating only if alive
        |> spawnApples         -- 4. Spawn new apples
```

### Pitfall 4: Random.generate Timing
**What goes wrong:** Apple spawn command issued but position arrives 1-2 ticks later
**Why it happens:** Random.generate is async - returns Cmd, not immediate value
**How to avoid:** Track apple count separately, spawn command immediately when needed
**Warning signs:** Momentary "2 apples" then back to 3, or delayed spawns
**Example:**
```elm
-- Track that spawn is in-flight
type alias Model =
    { apples : List Position
    , pendingAppleSpawn : Bool  -- True when waiting for Random.generate
    }

spawnIfNeeded : Model -> (Model, Cmd Msg)
spawnIfNeeded model =
    if List.length model.apples < 3 && not model.pendingAppleSpawn then
        ( { model | pendingAppleSpawn = True }
        , Random.generate NewApple (appleGenerator model)
        )
    else
        ( model, Cmd.none )
```

### Pitfall 5: Invincibility Timing
**What goes wrong:** Using Time.Posix for invincibility expiry causes time zone confusion
**Why it happens:** Time.Posix is absolute clock time, not game time
**How to avoid:** Store invincibility as tick count (invincibleUntilTick : Int)
**Warning signs:** Invincibility lasting wrong duration or testing issues
**Example:**
```elm
-- WRONG: Absolute time
type alias Snake =
    { invincibleUntil : Time.Posix }

-- CORRECT: Relative ticks
type alias Snake =
    { invincibleUntilTick : Int }

type alias Model =
    { currentTick : Int
    , snake : Snake
    }

isInvincible : Model -> Bool
isInvincible model =
    model.currentTick < model.snake.invincibleUntilTick
```

## Code Examples

Verified patterns from Elixir reference and Elm ecosystem:

### Edge Wrapping (Grid.elm)
```elm
-- Source: Elixir Grid module and Snake.move/2
wrapPosition : Position -> Grid -> Position
wrapPosition pos grid =
    { x = rem (pos.x + grid.width) grid.width
    , y = rem (pos.y + grid.height) grid.height
    }

nextPosition : Position -> Direction -> Position
nextPosition pos direction =
    case direction of
        Up -> { pos | y = pos.y - 1 }
        Down -> { pos | y = pos.y + 1 }
        Left -> { pos | x = pos.x - 1 }
        Right -> { pos | x = pos.x + 1 }
```

### Collision Detection
```elm
-- Source: Elixir Snake module collides_with_self? and collides_with?
collidesWithSelf : Snake -> Bool
collidesWithSelf snake =
    case snake.segments of
        head :: tail ->
            List.member head tail
        [] ->
            False

-- For single-player, just check self collision
-- Multi-player collision kept for future phases per CONTEXT decisions
```

### Apple Eating
```elm
-- Source: Elixir Apple.check_eaten/2 and Snake.grow/2
checkAppleEating : Model -> (Model, Cmd Msg)
checkAppleEating model =
    case List.head model.snake.segments of
        Just head ->
            if List.member head model.apples then
                ( { model
                    | apples = List.filter ((/=) head) model.apples
                    , snake = growSnake model.snake 3
                    , score = model.score + 1
                  }
                , Cmd.none
                )
            else
                ( model, Cmd.none )
        Nothing ->
            ( model, Cmd.none )

growSnake : Snake -> Int -> Snake
growSnake snake amount =
    { snake | pendingGrowth = snake.pendingGrowth + amount }
```

### Safe Spawn Position
```elm
-- Source: Elixir Grid.find_safe_spawn/2
findSafeSpawn : List Position -> Grid -> Random.Generator Position
findSafeSpawn occupied grid =
    let
        allPositions =
            List.range 0 (grid.width - 1)
                |> List.concatMap (\x ->
                    List.range 0 (grid.height - 1)
                        |> List.map (\y -> { x = x, y = y })
                )
        available = List.filter (\p -> not (List.member p occupied)) allPositions
    in
    case available of
        [] ->
            -- Grid full - shouldn't happen, return center
            Random.constant { x = grid.width // 2, y = grid.height // 2 }
        positions ->
            Random.uniform (List.head positions |> Maybe.withDefault {x=0,y=0})
                (List.tail positions |> Maybe.withDefault [])
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Keyboard module | Browser.Events | Elm 0.19 (2018) | Must use onKeyDown with JSON decoders |
| elm-lang/animation-frame | Time.every | Elm 0.19 (2018) | Simpler API, sufficient for fixed-tick games |
| Native modules | Ports only | Elm 0.19 (2018) | No native code in userland - not needed for this phase |

**Deprecated/outdated:**
- Keyboard.arrows and Keyboard.wasd: Removed in 0.19, use Browser.Events.onKeyDown
- AnimationFrame.times: Removed in 0.19, use Time.every or Browser.Events.onAnimationFrame
- Manual Task-based ticks: Time.every subscriptions are cleaner and standard

## Open Questions

Things that couldn't be fully resolved:

1. **Apple expiration timing**
   - What we know: Elixir code mentions "apple expires after timeout" in success criteria
   - What's unclear: No timeout code found in Elixir Apple module
   - Recommendation: Implement apple expiration if found in Elixir, otherwise skip for MVP (can add later)

2. **Score persistence**
   - What we know: Score increments on apple eaten
   - What's unclear: Should score persist across death/respawn?
   - Recommendation: Check Elixir behavior - likely resets on death for single-player

3. **Multiple snakes in single-player**
   - What we know: Elixir has multi-snake collision detection
   - What's unclear: Does single-player mode use this?
   - Recommendation: Keep snake-to-snake collision code (marked in CONTEXT as needed for later) but only spawn one snake

## Sources

### Primary (HIGH confidence)
- Elixir reference implementation (lib/snaker/game_server.ex, lib/snaker/game/*.ex)
- Existing Elm codebase (assets/src/*.elm, elm.json)
- Elm official packages: elm/time 1.0.0, elm/random 1.0.0, elm/browser 1.0.2

### Secondary (MEDIUM confidence)
- [Elm Time Guide](https://guide.elm-lang.org/effects/time.html) - Time.every patterns
- [Snake in Elm blog post](https://ethanfrei.com/posts/snake-in-elm.html) - Snake game architecture
- [Elm game state guide](https://github.com/xarvh/elm-game-state) - Complex game state patterns
- [Beginning Elm - Commands chapter](https://elmprogramming.com/commands.html) - Random.generate usage
- [Randomness in Elm by Charlie Koster](https://ckoster22.medium.com/randomness-in-elm-8e977457bf1b) - Random patterns

### Tertiary (LOW confidence - WebSearch only)
- [Game Loop patterns discussion](https://groups.google.com/d/topic/elm-discuss/nEtLpSlELSA) - Community patterns
- [Elm keyboard input discussion](https://discourse.elm-lang.org/t/getting-keyboard-input/1988) - 0.19 migration patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages verified in elm.json, official Elm packages
- Architecture: HIGH - Verified against Elixir reference code and existing Elm code
- Pitfalls: HIGH - Derived from Elixir implementation details and Elm 0.19 specifics
- Code examples: HIGH - Based on actual Elixir code and Elm package documentation

**Research date:** 2026-02-03
**Valid until:** 2026-03-03 (30 days - stable technology stack)
