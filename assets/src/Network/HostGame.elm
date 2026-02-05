module Network.HostGame exposing
    ( HostGameState
    , SnakeData
    , SnakeStatus(..)
    , TickResult
    , Kill
    , init
    , generatePlayerName
    , tick
    , addPlayer
    , removePlayer
    , confirmRemovePlayer
    , markOrphaned
    , bufferInput
    , changeHostDirection
    , toStateSyncPayload
    , toGameState
    , getOccupiedPositions
    , addApple
    , respawnSnake
    , fromClientState
    )

{-| Multi-player host game loop.

Extends LocalGame pattern for host-authoritative multiplayer.
Key differences:
- Multiple snakes in a Dict (keyed by playerId)
- Host's own snake is one of the snakes (id matches host's peerId)
- Each snake has individual invincibility tracking
- Collision detection between all snakes
-}

import Dict exposing (Dict)
import Engine.Apple as Apple exposing (Apple)
import Engine.Collision as Collision
import Engine.Grid as Grid
import NameGenerator
import Network.ClientGame as ClientGame
import Network.Protocol as Protocol exposing (StateSyncPayload)
import Random
import Snake exposing (Direction(..), Position, Snake)


{-| Game state for host running multiplayer game.
-}
type alias HostGameState =
    { snakes : Dict String SnakeData
    , apples : List Apple
    , grid : { width : Int, height : Int }
    , scores : Dict String Int
    , currentTick : Int
    , hostId : String -- Host's own player ID
    , pendingInputs : Dict String Direction -- Buffered inputs per player
    , disconnectedPlayers : Dict String Int -- playerId -> disconnectTick (for grace period)
    }


{-| Snake status for tracking active vs orphaned snakes.
-}
type SnakeStatus
    = Active
    | Orphaned
    | Dead


{-| Individual snake data with per-snake invincibility tracking.
-}
type alias SnakeData =
    { snake : Snake
    , invincibleUntilTick : Int
    , needsRespawn : Bool
    , status : SnakeStatus -- Active, Orphaned, or Dead
    }


{-| Result of a tick operation.
-}
type alias TickResult =
    { state : HostGameState
    , needsAppleSpawn : Int -- Number of apples needed
    , expiredApples : List Apple -- Apples that expired and need respawning
    , stateSync : StateSyncPayload -- For broadcasting
    , kills : List Kill -- Kills that happened this tick
    }


{-| A kill event for notifications and point transfer.
-}
type alias Kill =
    { victimId : String
    , victimName : String
    , killerId : Maybe String -- Nothing if self-kill or wall
    , killerName : Maybe String
    , pointsTransferred : Int
    }


{-| Color palette for snake colors - maximally distinct and colorblind-friendly.
    Uses varied hues, saturations, and brightnesses for clear differentiation.
-}
snakeColors : List String
snakeColors =
    [ "e6194b" -- red
    , "3cb44b" -- green
    , "ffe119" -- yellow
    , "4363d8" -- blue
    , "f58231" -- orange
    , "911eb4" -- purple
    , "42d4f4" -- cyan
    , "f032e6" -- magenta
    , "bfef45" -- lime
    , "fabed4" -- pink
    , "469990" -- teal
    , "dcbeff" -- lavender
    ]


{-| Simple string hash for deterministic color assignment.
-}
hashString : String -> Int
hashString str =
    String.foldl (\char acc -> acc * 31 + Char.toCode char) 0 str
        |> abs


{-| Get color for a player ID.
-}
colorForPlayer : String -> String
colorForPlayer playerId =
    let
        index =
            modBy (List.length snakeColors) (hashString playerId)
    in
    List.drop index snakeColors
        |> List.head
        |> Maybe.withDefault "67a387"


{-| Initialize a new host game with random snake position and whimsical name.
-}
init : String -> Random.Generator HostGameState
init hostId =
    let
        grid =
            Grid.defaultDimensions
    in
    Random.map2
        (\startPos hostName ->
            let
                hostSnake =
                    { id = hostId
                    , body = [ startPos, { x = startPos.x - 1, y = startPos.y }, { x = startPos.x - 2, y = startPos.y } ]
                    , direction = Right
                    , color = colorForPlayer hostId
                    , name = hostName
                    , isInvincible = True
                    , state = "alive"
                    , pendingGrowth = 0
                    }

                hostData =
                    { snake = hostSnake
                    , invincibleUntilTick = 15 -- 1500ms at 100ms ticks
                    , needsRespawn = False
                    , status = Active
                    }
            in
            { snakes = Dict.singleton hostId hostData
            , apples = []
            , grid = grid
            , scores = Dict.singleton hostId 0
            , currentTick = 0
            , hostId = hostId
            , pendingInputs = Dict.empty
            , disconnectedPlayers = Dict.empty
            }
        )
        (randomPosition grid)
        NameGenerator.generate


{-| Generate a random whimsical player name.
-}
generatePlayerName : Random.Generator String
generatePlayerName =
    NameGenerator.generate


{-| Generate a random position within grid bounds.
-}
randomPosition : { width : Int, height : Int } -> Random.Generator Position
randomPosition grid =
    Random.map2 Position
        (Random.int 2 (grid.width - 1))
        (Random.int 0 (grid.height - 1))


{-| Add a new player with spawn position.
-}
addPlayer : String -> String -> Position -> HostGameState -> HostGameState
addPlayer playerId name pos state =
    let
        newSnake =
            { id = playerId
            , body = [ pos, { x = pos.x - 1, y = pos.y }, { x = pos.x - 2, y = pos.y } ]
            , direction = Right
            , color = colorForPlayer playerId
            , name = name
            , isInvincible = True
            , state = "alive"
            , pendingGrowth = 0
            }

        newData =
            { snake = newSnake
            , invincibleUntilTick = state.currentTick + 15
            , needsRespawn = False
            , status = Active
            }
    in
    { state
        | snakes = Dict.insert playerId newData state.snakes
        , scores = Dict.insert playerId 0 state.scores
    }


{-| Mark player as disconnected (start grace period).

During grace period, snake continues moving in last direction but is orphaned (faded).
The snake will continue until it collides and dies naturally.
-}
removePlayer : String -> HostGameState -> HostGameState
removePlayer playerId state =
    { state
        | disconnectedPlayers =
            Dict.insert playerId (state.currentTick + 30) state.disconnectedPlayers
        , snakes =
            Dict.update playerId
                (Maybe.map (\data -> { data | status = Orphaned }))
                state.snakes
    }


{-| Mark a player's snake as orphaned (for host migration).
-}
markOrphaned : String -> HostGameState -> HostGameState
markOrphaned playerId state =
    { state
        | snakes =
            Dict.update playerId
                (Maybe.map (\data -> { data | status = Orphaned }))
                state.snakes
    }


{-| Actually remove a player after grace period.
-}
confirmRemovePlayer : String -> HostGameState -> HostGameState
confirmRemovePlayer playerId state =
    { state
        | snakes = Dict.remove playerId state.snakes
        , scores = Dict.remove playerId state.scores
        , disconnectedPlayers = Dict.remove playerId state.disconnectedPlayers
        , pendingInputs = Dict.remove playerId state.pendingInputs
    }


{-| Buffer input for a player.
-}
bufferInput : String -> Direction -> HostGameState -> HostGameState
bufferInput playerId direction state =
    -- Only accept if no direction already buffered this tick
    case Dict.get playerId state.pendingInputs of
        Just _ ->
            -- Rate limited - already have a buffered input
            state

        Nothing ->
            -- Validate direction change
            case Dict.get playerId state.snakes of
                Just snakeData ->
                    if Snake.validDirectionChange snakeData.snake.direction direction then
                        { state | pendingInputs = Dict.insert playerId direction state.pendingInputs }

                    else
                        state

                Nothing ->
                    state


{-| Change direction for host's snake (called directly, not through network).
-}
changeHostDirection : Direction -> HostGameState -> HostGameState
changeHostDirection direction state =
    bufferInput state.hostId direction state


{-| Process one game tick.

Order matches Elixir GameServer:
1. Apply all buffered inputs
2. Move all snakes
3. Check collisions (self and with others)
4. Handle respawns for collided snakes
5. Check apple eating (any snake can eat)
6. Check apple expiration
7. Generate StateSyncPayload
-}
tick : HostGameState -> TickResult
tick state =
    let
        -- Check grace period for disconnected players
        stateWithRemovals =
            cleanupDisconnectedPlayers state

        -- 1. Apply all buffered inputs
        stateWithInputs =
            applyAllInputs stateWithRemovals

        -- 2. Move all snakes
        stateAfterMove =
            moveAllSnakes stateWithInputs

        -- 3. Check collisions (self and with others) - also handles point transfers
        collisionResult =
            checkAllCollisions stateAfterMove

        -- 4. Respawns are handled separately via needsRespawn flag

        -- 5. Check apple eating (any snake can eat)
        stateAfterEating =
            checkAllAppleEating collisionResult.state

        -- 6. Check apple expiration
        expirationResult =
            Apple.tickExpiredApples stateAfterEating.currentTick stateAfterEating.apples

        stateAfterExpiration =
            { stateAfterEating | apples = expirationResult.remaining }

        -- 7. Clear input buffers and increment tick
        finalState =
            { stateAfterExpiration
                | pendingInputs = Dict.empty
                , currentTick = stateAfterExpiration.currentTick + 1
            }

        -- Calculate apples needed
        applesNeeded =
            Apple.spawnIfNeeded finalState.apples + List.length expirationResult.expired

        -- Full sync every 50 ticks
        isFull =
            modBy 50 finalState.currentTick == 0
    in
    { state = finalState
    , needsAppleSpawn = applesNeeded
    , expiredApples = expirationResult.expired
    , stateSync = toStateSyncPayloadWithKills isFull collisionResult.kills finalState
    , kills = collisionResult.kills
    }


{-| Remove players whose grace period has expired.
-}
cleanupDisconnectedPlayers : HostGameState -> HostGameState
cleanupDisconnectedPlayers state =
    Dict.foldl
        (\playerId disconnectTick acc ->
            if state.currentTick >= disconnectTick then
                confirmRemovePlayer playerId acc

            else
                acc
        )
        state
        state.disconnectedPlayers


{-| Apply all buffered inputs to their respective snakes.
    Orphaned snakes continue in their last direction (no input processing).
-}
applyAllInputs : HostGameState -> HostGameState
applyAllInputs state =
    { state
        | snakes =
            Dict.map
                (\playerId snakeData ->
                    -- Skip orphaned snakes - they continue straight
                    case snakeData.status of
                        Orphaned ->
                            snakeData

                        Dead ->
                            snakeData

                        Active ->
                            case Dict.get playerId state.pendingInputs of
                                Just newDirection ->
                                    let
                                        snake =
                                            snakeData.snake
                                    in
                                    { snakeData | snake = { snake | direction = newDirection } }

                                Nothing ->
                                    snakeData
                )
                state.snakes
    }


{-| Move all snakes in their current direction.
-}
moveAllSnakes : HostGameState -> HostGameState
moveAllSnakes state =
    { state
        | snakes =
            Dict.map
                (\_ snakeData ->
                    moveSnake state.grid snakeData
                )
                state.snakes
    }


{-| Move a single snake.
-}
moveSnake : { width : Int, height : Int } -> SnakeData -> SnakeData
moveSnake grid snakeData =
    let
        snake =
            snakeData.snake

        currentHead =
            Snake.head snake
                |> Maybe.withDefault { x = 0, y = 0 }

        unwrappedNewHead =
            Grid.nextPosition currentHead snake.direction

        newHead =
            Grid.wrapPosition unwrappedNewHead grid

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
    { snakeData | snake = updatedSnake }


{-| Result of collision checking - updated state plus any kills.
-}
type alias CollisionResult =
    { state : HostGameState
    , kills : List Kill
    }


{-| Check collisions for all snakes, tracking kills for notifications and point transfer.
-}
checkAllCollisions : HostGameState -> CollisionResult
checkAllCollisions state =
    let
        -- Get all snake bodies for other-snake collision checks
        allBodies =
            Dict.toList state.snakes
                |> List.map (\( id, data ) -> ( id, data.snake.body ))

        -- Check each snake and collect results
        ( newSnakes, kills ) =
            Dict.foldl
                (\playerId snakeData ( accSnakes, accKills ) ->
                    let
                        ( newData, maybeKill ) =
                            checkCollisions state.currentTick playerId snakeData allBodies state
                    in
                    ( Dict.insert playerId newData accSnakes
                    , case maybeKill of
                        Just kill ->
                            kill :: accKills

                        Nothing ->
                            accKills
                    )
                )
                ( Dict.empty, [] )
                state.snakes

        -- Apply point transfers for kills
        scoresAfterKills =
            List.foldl applyKillPointTransfer state.scores kills
    in
    { state = { state | snakes = newSnakes, scores = scoresAfterKills }
    , kills = kills
    }


{-| Apply point transfer for a kill: victim loses half, killer gains that amount.
-}
applyKillPointTransfer : Kill -> Dict String Int -> Dict String Int
applyKillPointTransfer kill scores =
    case kill.killerId of
        Just killerId ->
            let
                victimScore =
                    Dict.get kill.victimId scores |> Maybe.withDefault 0

                pointsToTransfer =
                    victimScore // 2
            in
            scores
                |> Dict.update kill.victimId (Maybe.map (\s -> s - pointsToTransfer))
                |> Dict.update killerId (Maybe.map (\s -> s + pointsToTransfer))

        Nothing ->
            -- Self-kill: just lose half points, no one gains
            let
                victimScore =
                    Dict.get kill.victimId scores |> Maybe.withDefault 0

                pointsLost =
                    victimScore // 2
            in
            Dict.update kill.victimId (Maybe.map (\s -> s - pointsLost)) scores


{-| Check collision for a single snake.
    Orphaned snakes become Dead on collision (no respawn).
    Active snakes get needsRespawn = True on collision.
    Returns updated snake data and optionally a Kill event.
-}
checkCollisions : Int -> String -> SnakeData -> List ( String, List Position ) -> HostGameState -> ( SnakeData, Maybe Kill )
checkCollisions currentTick playerId snakeData allBodies state =
    let
        isInvincible =
            currentTick < snakeData.invincibleUntilTick

        selfCollision =
            Collision.collidesWithSelf snakeData.snake.body

        -- Check collision with other snakes' bodies - returns killer ID if collision
        maybeKillerId =
            findKiller playerId snakeData.snake.body allBodies

        hasCollision =
            selfCollision || maybeKillerId /= Nothing

        victimScore =
            Dict.get playerId state.scores |> Maybe.withDefault 0

        makeKill killerId =
            { victimId = playerId
            , victimName = snakeData.snake.name
            , killerId = killerId
            , killerName = killerId |> Maybe.andThen (\kid -> Dict.get kid state.snakes) |> Maybe.map (.snake >> .name)
            , pointsTransferred = victimScore // 2
            }
    in
    if isInvincible then
        ( snakeData, Nothing )

    else if hasCollision then
        case snakeData.status of
            Orphaned ->
                -- Orphaned snake dies permanently (no respawn)
                ( { snakeData | status = Dead }
                , Just (makeKill maybeKillerId)
                )

            Active ->
                -- Active snake needs respawn
                ( { snakeData | needsRespawn = True }
                , Just (makeKill (if selfCollision then Nothing else maybeKillerId))
                )

            Dead ->
                -- Already dead
                ( snakeData, Nothing )

    else
        ( snakeData, Nothing )


{-| Find which snake killed this one (if any). Returns the killer's ID.
-}
findKiller : String -> List Position -> List ( String, List Position ) -> Maybe String
findKiller playerId body allBodies =
    case body of
        [] ->
            Nothing

        head :: _ ->
            allBodies
                |> List.filter (\( otherId, _ ) -> otherId /= playerId)
                |> List.filter (\( _, otherBody ) -> Collision.collidesWithOther head otherBody)
                |> List.head
                |> Maybe.map Tuple.first


{-| Check apple eating for all snakes.
-}
checkAllAppleEating : HostGameState -> HostGameState
checkAllAppleEating state =
    Dict.foldl
        (\playerId snakeData acc ->
            checkAppleEatingForSnake playerId snakeData acc
        )
        state
        state.snakes


{-| Check if a specific snake eats any apple.
-}
checkAppleEatingForSnake : String -> SnakeData -> HostGameState -> HostGameState
checkAppleEatingForSnake playerId snakeData state =
    case Snake.head snakeData.snake of
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
                        snakeData.snake

                    grownSnake =
                        { snake | pendingGrowth = snake.pendingGrowth + Apple.growthAmount }

                    updatedData =
                        { snakeData | snake = grownSnake }

                    currentScore =
                        Dict.get playerId state.scores |> Maybe.withDefault 0
                in
                { state
                    | apples = result.remaining
                    , snakes = Dict.insert playerId updatedData state.snakes
                    , scores = Dict.insert playerId (currentScore + 1) state.scores
                }

            else
                state


{-| Convert game state to StateSyncPayload for broadcasting.

Note: Grid dimensions are not included in state sync - both host and client
use Engine.Grid.defaultDimensions (30x40) which never changes during gameplay.
-}
toStateSyncPayload : Bool -> HostGameState -> StateSyncPayload
toStateSyncPayload isFull state =
    toStateSyncPayloadWithKills isFull [] state


{-| Convert game state to StateSyncPayload with kills for broadcasting.
-}
toStateSyncPayloadWithKills : Bool -> List Kill -> HostGameState -> StateSyncPayload
toStateSyncPayloadWithKills isFull kills state =
    { snakes =
        Dict.values state.snakes
            |> List.filter (\snakeData -> snakeData.status /= Dead) -- Don't include dead snakes
            |> List.map
                (\snakeData ->
                    let
                        s =
                            snakeData.snake
                    in
                    { id = s.id
                    , body = s.body
                    , direction = s.direction
                    , color = s.color
                    , name = s.name
                    , isInvincible = state.currentTick < snakeData.invincibleUntilTick
                    , status = statusToProtocol snakeData.status
                    }
                )
    , apples =
        List.map
            (\apple ->
                { position = apple.position
                , expiresAtTick = apple.expiresAtTick
                }
            )
            state.apples
    , scores = state.scores
    , tick = state.currentTick
    , isFull = isFull
    , kills =
        List.map
            (\kill ->
                { victimName = kill.victimName, killerName = kill.killerName }
            )
            kills
    }


{-| Convert internal SnakeStatus to Protocol.SnakeStatus.
-}
statusToProtocol : SnakeStatus -> Protocol.SnakeStatus
statusToProtocol status =
    case status of
        Active ->
            Protocol.Active

        Orphaned ->
            Protocol.Orphaned

        Dead ->
            Protocol.Dead


{-| Convert HostGameState to GameState for rendering with existing Board.view.
-}
toGameState : HostGameState -> { snakes : List Snake, apples : List { position : Position }, gridWidth : Int, gridHeight : Int, hostId : String, scores : Dict String Int, leaderId : Maybe String }
toGameState state =
    { snakes =
        Dict.values state.snakes
            |> List.filter (\snakeData -> snakeData.status /= Dead) -- Don't render dead snakes
            |> List.map
                (\snakeData ->
                    let
                        snake =
                            snakeData.snake

                        -- Set state string based on status for CSS
                        stateStr =
                            case snakeData.status of
                                Orphaned ->
                                    "orphaned"

                                _ ->
                                    "alive"
                    in
                    { snake
                        | isInvincible = state.currentTick < snakeData.invincibleUntilTick
                        , state = stateStr
                    }
                )
    , apples = List.map (\apple -> { position = apple.position }) state.apples
    , gridWidth = state.grid.width
    , gridHeight = state.grid.height
    , hostId = state.hostId
    , scores = state.scores
    , leaderId = findLeader state.scores
    }


{-| Find the leader (player with highest score). Ties broken by lexicographic ID.
-}
findLeader : Dict String Int -> Maybe String
findLeader scores =
    Dict.toList scores
        |> List.sortWith
            (\( id1, score1 ) ( id2, score2 ) ->
                case compare score2 score1 of
                    EQ ->
                        compare id1 id2  -- Tiebreaker: lower ID wins

                    other ->
                        other
            )
        |> List.head
        |> Maybe.map Tuple.first


{-| Get all occupied positions (all snakes + apples).
-}
getOccupiedPositions : HostGameState -> List Position
getOccupiedPositions state =
    let
        snakePositions =
            Dict.values state.snakes
                |> List.concatMap (\data -> data.snake.body)

        applePositions =
            List.map .position state.apples
    in
    snakePositions ++ applePositions


{-| Add an apple to the game state.
-}
addApple : Apple -> HostGameState -> HostGameState
addApple apple state =
    { state | apples = apple :: state.apples }


{-| Respawn a snake at a given position.
-}
respawnSnake : String -> Position -> HostGameState -> HostGameState
respawnSnake playerId pos state =
    case Dict.get playerId state.snakes of
        Nothing ->
            state

        Just snakeData ->
            let
                snake =
                    snakeData.snake

                respawnedSnake =
                    { snake
                        | body = [ pos, { x = pos.x - 1, y = pos.y }, { x = pos.x - 2, y = pos.y } ]
                        , direction = Right
                        , pendingGrowth = 0
                        , isInvincible = True
                    }

                respawnedData =
                    { snakeData
                        | snake = respawnedSnake
                        , invincibleUntilTick = state.currentTick + 15
                        , needsRespawn = False
                        , status = Active
                    }
            in
            { state | snakes = Dict.insert playerId respawnedData state.snakes }


{-| Create HostGameState from ClientGameState during host migration.
    The client becomes the new host using the last known game state.
-}
fromClientState : String -> Int -> Dict String ClientGame.SnakeState -> List Protocol.AppleState -> Dict String Int -> HostGameState
fromClientState newHostId lastTick snakes apples scores =
    let
        grid =
            Grid.defaultDimensions

        -- Convert client snake states to host snake data
        hostSnakes =
            Dict.map
                (\id snakeState ->
                    let
                        snake =
                            { id = id
                            , body = snakeState.body
                            , direction = snakeState.direction
                            , color = snakeState.color
                            , name = snakeState.name
                            , isInvincible = snakeState.isInvincible
                            , state = "alive"
                            , pendingGrowth = 0
                            }

                        status =
                            if snakeState.isDisconnected then
                                Orphaned

                            else
                                Active
                    in
                    { snake = snake
                    , invincibleUntilTick =
                        if snakeState.isInvincible then
                            lastTick + 15

                        else
                            0
                    , needsRespawn = False
                    , status = status
                    }
                )
                snakes

        -- Convert apple states
        hostApples =
            List.map
                (\appleState ->
                    { position = appleState.position
                    , expiresAtTick = appleState.expiresAtTick
                    }
                )
                apples
    in
    { snakes = hostSnakes
    , apples = hostApples
    , grid = grid
    , scores = scores
    , currentTick = lastTick
    , hostId = newHostId
    , pendingInputs = Dict.empty
    , disconnectedPlayers = Dict.empty
    }
