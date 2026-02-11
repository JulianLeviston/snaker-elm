module Network.Protocol exposing
    ( GameMessage(..)
    , GameSettings
    , StateSyncPayload
    , SnakeState
    , SnakeStatus(..)
    , AppleState
    , ProjectileState
    , PowerUpDropState
    , KillEvent
    , InputPayload
    , ShootPayload
    , PlayerJoinPayload
    , PlayerLeavePayload
    , HostMigrationPayload(..)
    , defaultGameSettings
    , encodeGameMessage
    , decodeGameMessage
    , encodeStateSync
    , decodeStateSync
    , encodeGameSettings
    , decodeGameSettings
    , encodeInput
    , decodeInput
    , encodeDirection
    , decodeDirection
    , decodeHostMigration
    )

{-| P2P game message protocol for host-client communication.

Defines message types and JSON codecs for game state synchronization.
-}

import Dict exposing (Dict)
import Json.Decode as JD
import Json.Encode as JE
import Snake exposing (Direction(..), Position)


{-| Game settings configurable by the host.
-}
type alias GameSettings =
    { venomMode : Bool
    }


{-| Default game settings (all features off).
-}
defaultGameSettings : GameSettings
defaultGameSettings =
    { venomMode = False
    }


{-| Top-level game message types for P2P communication.
-}
type GameMessage
    = StateSync StateSyncPayload -- Host -> Client: full/delta state
    | InputMessage InputPayload -- Client -> Host: direction input
    | ShootMessage ShootPayload -- Client -> Host: fire venom
    | PlayerJoin PlayerJoinPayload -- Bidirectional: player joining
    | PlayerLeave PlayerLeavePayload -- Bidirectional: player leaving
    | HostMigrated { newHostId : String, tick : Int } -- Migration event


{-| Snake status for tracking active vs orphaned snakes.
-}
type SnakeStatus
    = Active
    | Orphaned
    | Dead


{-| Host migration payload from JavaScript.
-}
type HostMigrationPayload
    = BecomeHost { myPeerId : String, peers : List String }
    | NewHost { newHostId : String }
    | ConnectionLost


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
    , kills : List KillEvent -- Kills that happened this tick
    , settings : GameSettings
    , projectiles : List ProjectileState
    , powerUpDrops : List PowerUpDropState
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
    , status : SnakeStatus -- Active, Orphaned, or Dead
    }


{-| Apple state for network transmission.
-}
type alias AppleState =
    { position : Position
    , spawnedAtTick : Int
    }


{-| Kill event for notifications.
-}
type alias KillEvent =
    { victimName : String
    , killerName : Maybe String -- Nothing if self-kill
    , isVenomKill : Bool
    }


{-| Projectile state for network transmission.
-}
type alias ProjectileState =
    { position : Position
    , direction : Direction
    , ownerId : String
    , venomType : String
    }


{-| Power-up drop state for network transmission.
-}
type alias PowerUpDropState =
    { position : Position
    , kind : String
    }


{-| Shoot payload from client to host.
-}
type alias ShootPayload =
    { playerId : String
    , tick : Int
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

        ShootMessage payload ->
            JE.object
                [ ( "type", JE.string "shoot" )
                , ( "payload", encodeShoot payload )
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

        HostMigrated payload ->
            JE.object
                [ ( "type", JE.string "host_migrated" )
                , ( "payload"
                  , JE.object
                        [ ( "new_host_id", JE.string payload.newHostId )
                        , ( "tick", JE.int payload.tick )
                        ]
                  )
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
        , ( "kills", JE.list encodeKillEvent payload.kills )
        , ( "settings", encodeGameSettings payload.settings )
        , ( "projectiles", JE.list encodeProjectileState payload.projectiles )
        , ( "power_up_drops", JE.list encodePowerUpDropState payload.powerUpDrops )
        ]


{-| Encode a ProjectileState to JSON.
-}
encodeProjectileState : ProjectileState -> JE.Value
encodeProjectileState proj =
    JE.object
        [ ( "position", encodePosition proj.position )
        , ( "direction", encodeDirection proj.direction )
        , ( "owner_id", JE.string proj.ownerId )
        , ( "venom_type", JE.string proj.venomType )
        ]


{-| Encode a PowerUpDropState to JSON.
-}
encodePowerUpDropState : PowerUpDropState -> JE.Value
encodePowerUpDropState drop =
    JE.object
        [ ( "position", encodePosition drop.position )
        , ( "kind", JE.string drop.kind )
        ]


{-| Encode a ShootPayload to JSON.
-}
encodeShoot : ShootPayload -> JE.Value
encodeShoot payload =
    JE.object
        [ ( "player_id", JE.string payload.playerId )
        , ( "tick", JE.int payload.tick )
        ]


{-| Encode GameSettings to JSON.
-}
encodeGameSettings : GameSettings -> JE.Value
encodeGameSettings settings =
    JE.object
        [ ( "venom_mode", JE.bool settings.venomMode )
        ]


{-| Encode a KillEvent to JSON.
-}
encodeKillEvent : KillEvent -> JE.Value
encodeKillEvent kill =
    JE.object
        [ ( "victim_name", JE.string kill.victimName )
        , ( "killer_name"
          , case kill.killerName of
                Just name ->
                    JE.string name

                Nothing ->
                    JE.null
          )
        , ( "is_venom_kill", JE.bool kill.isVenomKill )
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
        , ( "status", encodeSnakeStatus snake.status )
        ]


{-| Encode a SnakeStatus to JSON.
-}
encodeSnakeStatus : SnakeStatus -> JE.Value
encodeSnakeStatus status =
    JE.string
        (case status of
            Active ->
                "active"

            Orphaned ->
                "orphaned"

            Dead ->
                "dead"
        )


{-| Encode an AppleState to JSON.
-}
encodeAppleState : AppleState -> JE.Value
encodeAppleState apple =
    JE.object
        [ ( "position", encodePosition apple.position )
        , ( "spawned_at_tick", JE.int apple.spawnedAtTick )
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

                    "shoot" ->
                        JD.field "payload" decodeShoot
                            |> JD.map ShootMessage

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

Uses pipeline pattern (succeed + andMap) instead of map8 to support 9+ fields.
-}
decodeStateSync : JD.Decoder StateSyncPayload
decodeStateSync =
    JD.succeed StateSyncPayload
        |> andMap (JD.field "snakes" (JD.list decodeSnakeState))
        |> andMap (JD.field "apples" (JD.list decodeAppleState))
        |> andMap (JD.field "scores" decodeScores)
        |> andMap (JD.field "tick" JD.int)
        |> andMap (JD.field "is_full" JD.bool)
        |> andMap (JD.field "kills" (JD.list decodeKillEvent))
        |> andMap
            (JD.oneOf
                [ JD.field "settings" decodeGameSettings
                , JD.succeed defaultGameSettings
                ]
            )
        |> andMap
            (JD.oneOf
                [ JD.field "projectiles" (JD.list decodeProjectileState)
                , JD.succeed []
                ]
            )
        |> andMap
            (JD.oneOf
                [ JD.field "power_up_drops" (JD.list decodePowerUpDropState)
                , JD.succeed []
                ]
            )


{-| Pipeline helper: apply a decoder to a decoder of a function.
-}
andMap : JD.Decoder a -> JD.Decoder (a -> b) -> JD.Decoder b
andMap =
    JD.map2 (|>)


{-| Decode GameSettings from JSON.
-}
decodeGameSettings : JD.Decoder GameSettings
decodeGameSettings =
    JD.map GameSettings
        (JD.oneOf
            [ JD.field "venom_mode" JD.bool
            , JD.succeed False
            ]
        )


{-| Decode a ProjectileState from JSON.
-}
decodeProjectileState : JD.Decoder ProjectileState
decodeProjectileState =
    JD.map4 ProjectileState
        (JD.field "position" decodePosition)
        (JD.field "direction" decodeDirection)
        (JD.field "owner_id" JD.string)
        (JD.oneOf
            [ JD.field "venom_type" JD.string
            , JD.succeed "standard"
            ]
        )


{-| Decode a PowerUpDropState from JSON.
-}
decodePowerUpDropState : JD.Decoder PowerUpDropState
decodePowerUpDropState =
    JD.map2 PowerUpDropState
        (JD.field "position" decodePosition)
        (JD.field "kind" JD.string)


{-| Decode a ShootPayload from JSON.
-}
decodeShoot : JD.Decoder ShootPayload
decodeShoot =
    JD.map2 ShootPayload
        (JD.field "player_id" JD.string)
        (JD.field "tick" JD.int)


{-| Decode a KillEvent from JSON.
-}
decodeKillEvent : JD.Decoder KillEvent
decodeKillEvent =
    JD.map3 KillEvent
        (JD.field "victim_name" JD.string)
        (JD.field "killer_name" (JD.nullable JD.string))
        (JD.oneOf
            [ JD.field "is_venom_kill" JD.bool
            , JD.succeed False
            ]
        )


{-| Decode a SnakeState from JSON.
-}
decodeSnakeState : JD.Decoder SnakeState
decodeSnakeState =
    JD.map7 SnakeState
        (JD.field "id" JD.string)
        (JD.field "body" (JD.list decodePosition))
        (JD.field "direction" decodeDirection)
        (JD.field "color" JD.string)
        (JD.field "name" JD.string)
        (JD.field "is_invincible" JD.bool)
        (JD.field "status" decodeSnakeStatus)


{-| Decode a SnakeStatus from JSON.
-}
decodeSnakeStatus : JD.Decoder SnakeStatus
decodeSnakeStatus =
    JD.string
        |> JD.andThen
            (\str ->
                case str of
                    "active" ->
                        JD.succeed Active

                    "orphaned" ->
                        JD.succeed Orphaned

                    "dead" ->
                        JD.succeed Dead

                    _ ->
                        JD.fail ("Unknown snake status: " ++ str)
            )


{-| Decode an AppleState from JSON.
-}
decodeAppleState : JD.Decoder AppleState
decodeAppleState =
    JD.map2 AppleState
        (JD.field "position" decodePosition)
        (JD.field "spawned_at_tick" JD.int)


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


{-| Decode host migration payload from JavaScript port.
-}
decodeHostMigration : JD.Decoder HostMigrationPayload
decodeHostMigration =
    JD.field "type" JD.string
        |> JD.andThen
            (\migType ->
                case migType of
                    "become_host" ->
                        JD.map2 (\pid peers -> BecomeHost { myPeerId = pid, peers = peers })
                            (JD.field "myPeerId" JD.string)
                            (JD.field "peers" (JD.list JD.string))

                    "new_host" ->
                        JD.map (\hid -> NewHost { newHostId = hid })
                            (JD.field "newHostId" JD.string)

                    "connection_lost" ->
                        JD.succeed ConnectionLost

                    _ ->
                        JD.fail ("Unknown migration type: " ++ migType)
            )
