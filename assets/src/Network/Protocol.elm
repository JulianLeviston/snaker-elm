module Network.Protocol exposing
    ( GameMessage(..)
    , StateSyncPayload
    , SnakeState
    , AppleState
    , InputPayload
    , PlayerJoinPayload
    , PlayerLeavePayload
    , encodeGameMessage
    , decodeGameMessage
    , encodeStateSync
    , decodeStateSync
    , encodeInput
    , decodeInput
    , encodeDirection
    , decodeDirection
    )

{-| P2P game message protocol for host-client communication.

Defines message types and JSON codecs for game state synchronization.
-}

import Dict exposing (Dict)
import Json.Decode as JD
import Json.Encode as JE
import Snake exposing (Direction(..), Position)


{-| Top-level game message types for P2P communication.
-}
type GameMessage
    = StateSync StateSyncPayload -- Host -> Client: full/delta state
    | InputMessage InputPayload -- Client -> Host: direction input
    | PlayerJoin PlayerJoinPayload -- Bidirectional: player joining
    | PlayerLeave PlayerLeavePayload -- Bidirectional: player leaving


{-| Full or delta state synchronization payload.

Note: Grid dimensions are not included - both host and client use
Engine.Grid.defaultDimensions (30x40) which never changes during gameplay.
-}
type alias StateSyncPayload =
    { snakes : List SnakeState
    , apples : List AppleState
    , scores : Dict String Int
    , tick : Int
    , isFull : Bool -- True for full sync, False for delta
    }


{-| Snake state for network transmission.
-}
type alias SnakeState =
    { id : String
    , body : List Position
    , direction : Direction
    , color : String
    , name : String
    , isInvincible : Bool
    }


{-| Apple state for network transmission.
-}
type alias AppleState =
    { position : Position
    , expiresAtTick : Int
    }


{-| Input payload from client to host.
-}
type alias InputPayload =
    { playerId : String
    , direction : Direction
    , tick : Int -- Client's local tick for ordering
    }


{-| Player join payload.
-}
type alias PlayerJoinPayload =
    { playerId : String
    , name : String
    }


{-| Player leave payload.
-}
type alias PlayerLeavePayload =
    { playerId : String
    }



-- ENCODERS


{-| Encode a GameMessage to JSON.
-}
encodeGameMessage : GameMessage -> JE.Value
encodeGameMessage msg =
    case msg of
        StateSync payload ->
            JE.object
                [ ( "type", JE.string "state_sync" )
                , ( "payload", encodeStateSync payload )
                ]

        InputMessage payload ->
            JE.object
                [ ( "type", JE.string "input" )
                , ( "payload", encodeInput payload )
                ]

        PlayerJoin payload ->
            JE.object
                [ ( "type", JE.string "player_join" )
                , ( "payload", encodePlayerJoin payload )
                ]

        PlayerLeave payload ->
            JE.object
                [ ( "type", JE.string "player_leave" )
                , ( "payload", encodePlayerLeave payload )
                ]


{-| Encode a StateSyncPayload to JSON.
-}
encodeStateSync : StateSyncPayload -> JE.Value
encodeStateSync payload =
    JE.object
        [ ( "snakes", JE.list encodeSnakeState payload.snakes )
        , ( "apples", JE.list encodeAppleState payload.apples )
        , ( "scores", encodeScores payload.scores )
        , ( "tick", JE.int payload.tick )
        , ( "is_full", JE.bool payload.isFull )
        ]


{-| Encode a SnakeState to JSON.
-}
encodeSnakeState : SnakeState -> JE.Value
encodeSnakeState snake =
    JE.object
        [ ( "id", JE.string snake.id )
        , ( "body", JE.list encodePosition snake.body )
        , ( "direction", encodeDirection snake.direction )
        , ( "color", JE.string snake.color )
        , ( "name", JE.string snake.name )
        , ( "is_invincible", JE.bool snake.isInvincible )
        ]


{-| Encode an AppleState to JSON.
-}
encodeAppleState : AppleState -> JE.Value
encodeAppleState apple =
    JE.object
        [ ( "position", encodePosition apple.position )
        , ( "expires_at_tick", JE.int apple.expiresAtTick )
        ]


{-| Encode an InputPayload to JSON.
-}
encodeInput : InputPayload -> JE.Value
encodeInput payload =
    JE.object
        [ ( "player_id", JE.string payload.playerId )
        , ( "direction", encodeDirection payload.direction )
        , ( "tick", JE.int payload.tick )
        ]


{-| Encode a PlayerJoinPayload to JSON.
-}
encodePlayerJoin : PlayerJoinPayload -> JE.Value
encodePlayerJoin payload =
    JE.object
        [ ( "player_id", JE.string payload.playerId )
        , ( "name", JE.string payload.name )
        ]


{-| Encode a PlayerLeavePayload to JSON.
-}
encodePlayerLeave : PlayerLeavePayload -> JE.Value
encodePlayerLeave payload =
    JE.object
        [ ( "player_id", JE.string payload.playerId )
        ]


{-| Encode a Position to JSON.
-}
encodePosition : Position -> JE.Value
encodePosition pos =
    JE.object
        [ ( "x", JE.int pos.x )
        , ( "y", JE.int pos.y )
        ]


{-| Encode a Direction to JSON.
-}
encodeDirection : Direction -> JE.Value
encodeDirection dir =
    JE.string (directionToString dir)


{-| Encode scores dictionary to JSON.
-}
encodeScores : Dict String Int -> JE.Value
encodeScores scores =
    scores
        |> Dict.toList
        |> List.map (\( k, v ) -> ( k, JE.int v ))
        |> JE.object



-- DECODERS


{-| Decode a GameMessage from JSON.
-}
decodeGameMessage : JD.Decoder GameMessage
decodeGameMessage =
    JD.field "type" JD.string
        |> JD.andThen
            (\msgType ->
                case msgType of
                    "state_sync" ->
                        JD.field "payload" decodeStateSync
                            |> JD.map StateSync

                    "input" ->
                        JD.field "payload" decodeInput
                            |> JD.map InputMessage

                    "player_join" ->
                        JD.field "payload" decodePlayerJoin
                            |> JD.map PlayerJoin

                    "player_leave" ->
                        JD.field "payload" decodePlayerLeave
                            |> JD.map PlayerLeave

                    _ ->
                        JD.fail ("Unknown message type: " ++ msgType)
            )


{-| Decode a StateSyncPayload from JSON.
-}
decodeStateSync : JD.Decoder StateSyncPayload
decodeStateSync =
    JD.map5 StateSyncPayload
        (JD.field "snakes" (JD.list decodeSnakeState))
        (JD.field "apples" (JD.list decodeAppleState))
        (JD.field "scores" decodeScores)
        (JD.field "tick" JD.int)
        (JD.field "is_full" JD.bool)


{-| Decode a SnakeState from JSON.
-}
decodeSnakeState : JD.Decoder SnakeState
decodeSnakeState =
    JD.map6 SnakeState
        (JD.field "id" JD.string)
        (JD.field "body" (JD.list decodePosition))
        (JD.field "direction" decodeDirection)
        (JD.field "color" JD.string)
        (JD.field "name" JD.string)
        (JD.field "is_invincible" JD.bool)


{-| Decode an AppleState from JSON.
-}
decodeAppleState : JD.Decoder AppleState
decodeAppleState =
    JD.map2 AppleState
        (JD.field "position" decodePosition)
        (JD.field "expires_at_tick" JD.int)


{-| Decode an InputPayload from JSON.
-}
decodeInput : JD.Decoder InputPayload
decodeInput =
    JD.map3 InputPayload
        (JD.field "player_id" JD.string)
        (JD.field "direction" decodeDirection)
        (JD.field "tick" JD.int)


{-| Decode a PlayerJoinPayload from JSON.
-}
decodePlayerJoin : JD.Decoder PlayerJoinPayload
decodePlayerJoin =
    JD.map2 PlayerJoinPayload
        (JD.field "player_id" JD.string)
        (JD.field "name" JD.string)


{-| Decode a PlayerLeavePayload from JSON.
-}
decodePlayerLeave : JD.Decoder PlayerLeavePayload
decodePlayerLeave =
    JD.map PlayerLeavePayload
        (JD.field "player_id" JD.string)


{-| Decode a Position from JSON.
-}
decodePosition : JD.Decoder Position
decodePosition =
    JD.map2 Position
        (JD.field "x" JD.int)
        (JD.field "y" JD.int)


{-| Decode a Direction from JSON.
-}
decodeDirection : JD.Decoder Direction
decodeDirection =
    JD.string
        |> JD.andThen
            (\str ->
                case str of
                    "up" ->
                        JD.succeed Up

                    "down" ->
                        JD.succeed Down

                    "left" ->
                        JD.succeed Left

                    "right" ->
                        JD.succeed Right

                    _ ->
                        JD.fail ("Unknown direction: " ++ str)
            )


{-| Decode scores dictionary from JSON.
-}
decodeScores : JD.Decoder (Dict String Int)
decodeScores =
    JD.dict JD.int



-- HELPERS


{-| Convert Direction to string for JSON encoding.
-}
directionToString : Direction -> String
directionToString dir =
    case dir of
        Up ->
            "up"

        Down ->
            "down"

        Left ->
            "left"

        Right ->
            "right"
