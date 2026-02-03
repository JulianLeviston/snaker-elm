module Network.ClientGame exposing
    ( ClientGameState
    , SnakeState
    , init
    , applyHostState
    , bufferLocalInput
    , getMySnake
    , toGameState
    )

{-| Client-side game state management for P2P multiplayer.

Responsibilities:
- Store last received host state
- Apply optimistic local input (snake turns immediately)
- Track which snake is "ours" for visual distinction
- Convert to renderable format for Board.view
-}

import Dict exposing (Dict)
import Network.Protocol as Protocol exposing (AppleState, StateSyncPayload)
import Snake exposing (Direction, Position, Snake)


{-| Client-side game state.
-}
type alias ClientGameState =
    { snakes : Dict String SnakeState -- From host
    , apples : List AppleState
    , scores : Dict String Int
    , lastHostTick : Int
    , myId : String -- Our player ID
    , pendingInput : Maybe Direction -- Optimistic local input
    , lastAppliedInput : Maybe Direction -- For interpolation reference
    , gridWidth : Int
    , gridHeight : Int
    }


{-| Snake state from network (mirrors Protocol.SnakeState but with isDisconnected).
-}
type alias SnakeState =
    { body : List Position
    , direction : Direction
    , color : String
    , name : String
    , isInvincible : Bool
    , isDisconnected : Bool -- For ghosted rendering
    }


{-| Initialize client game state with our player ID.
-}
init : String -> ClientGameState
init myId =
    { snakes = Dict.empty
    , apples = []
    , scores = Dict.empty
    , lastHostTick = 0
    , myId = myId
    , pendingInput = Nothing
    , lastAppliedInput = Nothing
    , gridWidth = 30 -- Default dimensions matching Engine.Grid, will be updated from host
    , gridHeight = 40
    }


{-| Apply host state to client state.

Replaces snakes/apples/scores with host data.
Clears pendingInput if it was applied (direction matches).
Updates grid dimensions from host.
-}
applyHostState : StateSyncPayload -> ClientGameState -> ClientGameState
applyHostState stateSync clientState =
    let
        -- Convert Protocol.SnakeState list to Dict String SnakeState
        newSnakes =
            stateSync.snakes
                |> List.map
                    (\s ->
                        ( s.id
                        , { body = s.body
                          , direction = s.direction
                          , color = s.color
                          , name = s.name
                          , isInvincible = s.isInvincible
                          , isDisconnected = False
                          }
                        )
                    )
                |> Dict.fromList

        -- Check if our pending input was applied by comparing direction
        newPendingInput =
            case ( clientState.pendingInput, Dict.get clientState.myId newSnakes ) of
                ( Just pendingDir, Just mySnake ) ->
                    if mySnake.direction == pendingDir then
                        -- Host applied our input, clear pending
                        Nothing

                    else
                        -- Host hasn't applied yet, keep pending
                        clientState.pendingInput

                _ ->
                    clientState.pendingInput
    in
    { clientState
        | snakes = newSnakes
        , apples = stateSync.apples
        , scores = stateSync.scores
        , lastHostTick = stateSync.tick
        , pendingInput = newPendingInput
        , gridWidth = stateSync.gridWidth
        , gridHeight = stateSync.gridHeight
    }


{-| Buffer a local input for optimistic display.
-}
bufferLocalInput : Direction -> ClientGameState -> ClientGameState
bufferLocalInput direction clientState =
    -- Validate direction change before buffering
    case Dict.get clientState.myId clientState.snakes of
        Just mySnake ->
            if Snake.validDirectionChange mySnake.direction direction then
                { clientState
                    | pendingInput = Just direction
                    , lastAppliedInput = Just direction
                }

            else
                clientState

        Nothing ->
            -- No snake yet, still buffer the input
            { clientState
                | pendingInput = Just direction
                , lastAppliedInput = Just direction
            }


{-| Get the player's own snake, applying pending input optimistically.
-}
getMySnake : ClientGameState -> Maybe SnakeState
getMySnake clientState =
    case Dict.get clientState.myId clientState.snakes of
        Just snake ->
            -- Apply pending input optimistically for display
            case clientState.pendingInput of
                Just pendingDir ->
                    Just { snake | direction = pendingDir }

                Nothing ->
                    Just snake

        Nothing ->
            Nothing


{-| Convert ClientGameState to format compatible with Board.view.

Marks our snake appropriately and applies optimistic input.
-}
toGameState : ClientGameState -> { snakes : List Snake, apples : List { position : Position }, gridWidth : Int, gridHeight : Int }
toGameState clientState =
    let
        -- Convert SnakeState to Snake, applying optimistic direction for our snake
        snakeList =
            Dict.toList clientState.snakes
                |> List.map
                    (\( id, snakeState ) ->
                        let
                            -- Apply pending input optimistically for our snake
                            effectiveDirection =
                                if id == clientState.myId then
                                    clientState.pendingInput
                                        |> Maybe.withDefault snakeState.direction

                                else
                                    snakeState.direction

                            -- Determine state string for CSS classes
                            stateStr =
                                if snakeState.isDisconnected then
                                    "disconnected"

                                else
                                    "alive"
                        in
                        { id = id
                        , body = snakeState.body
                        , direction = effectiveDirection
                        , color = snakeState.color
                        , name = snakeState.name
                        , isInvincible = snakeState.isInvincible
                        , state = stateStr
                        , pendingGrowth = 0
                        }
                    )

        -- Convert AppleState to simple position record
        appleList =
            List.map (\a -> { position = a.position }) clientState.apples
    in
    { snakes = snakeList
    , apples = appleList
    , gridWidth = clientState.gridWidth
    , gridHeight = clientState.gridHeight
    }
