module LocalGame exposing
    ( LocalGameState
    , init
    , tick
    , changeDirection
    , toGameState
    )

{-| Local game state and logic for single-player mode.

Runs game engine entirely in Elm without server dependency.
Mirrors Elixir GameServer tick order: applyInput -> move -> collisions -> (eating in Plan 02)
-}

import Engine.Collision as Collision
import Engine.Grid as Grid
import Random
import Snake exposing (Direction(..), Position, Snake)


{-| Local game state for single-player mode.
-}
type alias LocalGameState =
    { snake : Snake
    , apples : List Position
    , grid : { width : Int, height : Int }
    , inputBuffer : Maybe Direction
    , score : Int
    , currentTick : Int
    , invincibleUntilTick : Int
    , needsRespawn : Bool
    }


{-| Initialize a new local game with random snake position.
-}
init : Random.Generator LocalGameState
init =
    let
        grid =
            Grid.defaultDimensions
    in
    randomPosition grid
        |> Random.map
            (\startPos ->
                { snake = Snake.defaultSnake startPos
                , apples = []
                , grid = grid
                , inputBuffer = Nothing
                , score = 0
                , currentTick = 0
                , invincibleUntilTick = 15  -- 1500ms invincibility at start
                , needsRespawn = False
                }
            )


{-| Generate a random position within grid bounds.
-}
randomPosition : { width : Int, height : Int } -> Random.Generator Position
randomPosition grid =
    Random.map2 Position
        (Random.int 0 (grid.width - 1))
        (Random.int 0 (grid.height - 1))


{-| Generate a random respawn position.
-}
respawnGenerator : { width : Int, height : Int } -> Random.Generator Position
respawnGenerator grid =
    randomPosition grid


{-| Process a single game tick.

Order matches Elixir GameServer:
1. Apply buffered input
2. Move snake
3. Check collisions
4. (Apple eating in Plan 02)
-}
tick : LocalGameState -> LocalGameState
tick state =
    let
        -- 1. Apply buffered input
        stateWithInput =
            applyInputBuffer state

        -- 2. Move snake
        stateAfterMove =
            moveSnake stateWithInput

        -- 3. Check collisions (only if not invincible)
        stateAfterCollisions =
            checkCollisions stateAfterMove

        -- 4. Clear input buffer and increment tick
        finalState =
            { stateAfterCollisions
                | inputBuffer = Nothing
                , currentTick = stateAfterCollisions.currentTick + 1
            }
    in
    finalState


{-| Apply buffered direction change to snake.
-}
applyInputBuffer : LocalGameState -> LocalGameState
applyInputBuffer state =
    case state.inputBuffer of
        Nothing ->
            state

        Just newDirection ->
            let
                snake =
                    state.snake

                updatedSnake =
                    { snake | direction = newDirection }
            in
            { state | snake = updatedSnake }


{-| Move the snake in its current direction.
-}
moveSnake : LocalGameState -> LocalGameState
moveSnake state =
    let
        snake =
            state.snake

        -- Calculate new head position
        currentHead =
            Snake.head snake
                |> Maybe.withDefault { x = 0, y = 0 }

        unwrappedNewHead =
            Grid.nextPosition currentHead snake.direction

        newHead =
            Grid.wrapPosition unwrappedNewHead state.grid

        -- Calculate new body
        ( newBody, newPendingGrowth ) =
            if snake.pendingGrowth > 0 then
                -- Growing: prepend head, keep all segments
                ( newHead :: snake.body, snake.pendingGrowth - 1 )

            else
                -- Not growing: prepend head, drop last segment
                ( newHead :: List.take (List.length snake.body - 1) snake.body
                , 0
                )

        updatedSnake =
            { snake
                | body = newBody
                , pendingGrowth = newPendingGrowth
            }
    in
    { state | snake = updatedSnake }


{-| Check for self-collision.
-}
checkCollisions : LocalGameState -> LocalGameState
checkCollisions state =
    let
        isInvincible =
            state.currentTick < state.invincibleUntilTick

        selfCollision =
            Collision.collidesWithSelf state.snake.body
    in
    if isInvincible then
        state

    else if selfCollision then
        { state | needsRespawn = True }

    else
        state


{-| Handle direction change from player input.

Validates the direction change (cannot reverse) and buffers it.
Only accepts first direction change per tick (rate limiting).
-}
changeDirection : Direction -> LocalGameState -> LocalGameState
changeDirection newDirection state =
    -- Only accept if no direction already buffered this tick
    case state.inputBuffer of
        Just _ ->
            -- Rate limited - already have a buffered input
            state

        Nothing ->
            -- Validate direction change
            if Snake.validDirectionChange state.snake.direction newDirection then
                { state | inputBuffer = Just newDirection }

            else
                state


{-| Respawn snake at a given position.

Resets snake to single segment, direction right, grants invincibility.
-}
respawnSnake : Position -> LocalGameState -> LocalGameState
respawnSnake pos state =
    let
        snake =
            state.snake

        respawnedSnake =
            { snake
                | body = [ pos ]
                , direction = Right
                , pendingGrowth = 0
                , isInvincible = True
            }
    in
    { state
        | snake = respawnedSnake
        , invincibleUntilTick = state.currentTick + 15  -- 1500ms at 100ms ticks
        , needsRespawn = False
    }


{-| Convert LocalGameState to GameState for rendering with existing Board.view.
-}
toGameState : LocalGameState -> { snakes : List Snake, apples : List { position : Position }, gridWidth : Int, gridHeight : Int }
toGameState state =
    let
        snake =
            state.snake

        -- Update invincibility based on tick count for display
        snakeWithInvincibility =
            { snake | isInvincible = state.currentTick < state.invincibleUntilTick }
    in
    { snakes = [ snakeWithInvincibility ]
    , apples = List.map (\pos -> { position = pos }) state.apples
    , gridWidth = state.grid.width
    , gridHeight = state.grid.height
    }


{-| Get respawn generator for external use (Main.elm).
-}
respawnPositionGenerator : LocalGameState -> Random.Generator Position
respawnPositionGenerator state =
    respawnGenerator state.grid
