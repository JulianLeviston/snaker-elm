module LocalGame exposing
    ( LocalGameState
    , init
    , tick
    , changeDirection
    , toGameState
    , addApple
    , needsMoreApples
    , getOccupiedPositions
    , respawnSnake
    )

{-| Local game state and logic for single-player mode.

Runs game engine entirely in Elm without server dependency.
Mirrors Elixir GameServer tick order: applyInput -> move -> collisions -> eating -> expiration
-}

import Engine.Apple as Apple exposing (Apple)
import Engine.Collision as Collision
import Engine.Grid as Grid
import Random
import Snake exposing (Direction(..), Position, Snake)


{-| Local game state for single-player mode.
-}
type alias LocalGameState =
    { snake : Snake
    , apples : List Apple
    , grid : { width : Int, height : Int }
    , inputBuffer : Maybe Direction
    , score : Int
    , currentTick : Int
    , invincibleUntilTick : Int
    , needsRespawn : Bool
    }


{-| Result of a tick operation.

Includes updated state plus signals for Main to handle random spawning.
-}
type alias TickResult =
    { state : LocalGameState
    , needsAppleSpawn : Int  -- Number of apples needed
    , expiredApples : List Apple  -- Apples that expired and need respawning
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


{-| Process a single game tick.

Order matches Elixir GameServer:
1. Apply buffered input
2. Move snake
3. Check collisions
4. Check apple eating
5. Check apple expiration
-}
tick : LocalGameState -> TickResult
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

        -- 4. Check apple eating
        stateAfterEating =
            checkAppleEating stateAfterCollisions

        -- 5. Check apple expiration
        expirationResult =
            Apple.tickExpiredApples stateAfterEating.currentTick stateAfterEating.apples

        stateAfterExpiration =
            { stateAfterEating | apples = expirationResult.remaining }

        -- 6. Clear input buffer and increment tick
        finalState =
            { stateAfterExpiration
                | inputBuffer = Nothing
                , currentTick = stateAfterExpiration.currentTick + 1
            }

        -- Calculate how many apples we need to spawn
        applesNeeded =
            Apple.spawnIfNeeded finalState.apples
    in
    { state = finalState
    , needsAppleSpawn = applesNeeded + List.length expirationResult.expired
    , expiredApples = expirationResult.expired
    }


{-| Check if snake head has eaten an apple.

Updates score, grows snake, and removes eaten apple.
-}
checkAppleEating : LocalGameState -> LocalGameState
checkAppleEating state =
    case Snake.head state.snake of
        Nothing ->
            state

        Just headPos ->
            let
                result =
                    Apple.checkEaten headPos state.apples
            in
            if result.eaten then
                let
                    snake =
                        state.snake

                    grownSnake =
                        { snake | pendingGrowth = snake.pendingGrowth + Apple.growthAmount }
                in
                { state
                    | apples = result.remaining
                    , snake = grownSnake
                    , score = state.score + 1
                }

            else
                state


{-| Add an apple to the game state.

Called by Main when a random position is generated.
-}
addApple : Apple -> LocalGameState -> LocalGameState
addApple apple state =
    { state | apples = apple :: state.apples }


{-| Check if more apples are needed.
-}
needsMoreApples : LocalGameState -> Bool
needsMoreApples state =
    List.length state.apples < Apple.minApples


{-| Get all occupied positions (snake + apples).

Used for safe apple spawning.
-}
getOccupiedPositions : LocalGameState -> List Position
getOccupiedPositions state =
    let
        snakePositions =
            state.snake.body

        applePositions =
            List.map .position state.apples
    in
    snakePositions ++ applePositions


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
    , apples = List.map (\apple -> { position = apple.position }) state.apples
    , gridWidth = state.grid.width
    , gridHeight = state.grid.height
    }
