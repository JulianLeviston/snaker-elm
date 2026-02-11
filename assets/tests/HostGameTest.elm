module HostGameTest exposing (..)

import Dict
import Engine.Grid as Grid
import Engine.VenomType exposing (VenomType(..))
import Expect
import Network.HostGame as HostGame exposing (HostGameState, SnakeData, SnakeStatus(..))
import Network.Protocol as Protocol
import Random
import Snake exposing (Direction(..))
import Test exposing (..)


{-| Create a deterministic HostGameState for testing.
-}
makeHostState : HostGameState
makeHostState =
    let
        grid =
            Grid.defaultDimensions

        hostSnake =
            { id = "host1"
            , body =
                [ { x = 15, y = 20 }
                , { x = 14, y = 20 }
                , { x = 13, y = 20 }
                , { x = 12, y = 20 }
                , { x = 11, y = 20 }
                ]
            , direction = Right
            , pendingGrowth = 0
            , color = "00ff00"
            , name = "Test Host"
            , isInvincible = False
            , state = "alive"
            }

        hostData : SnakeData
        hostData =
            { snake = hostSnake
            , invincibleUntilTick = 0
            , needsRespawn = False
            , status = Active
            , venomType = StandardVenom
            }
    in
    { snakes = Dict.singleton "host1" hostData
    , apples = []
    , grid = grid
    , scores = Dict.singleton "host1" 0
    , currentTick = 100
    , hostId = "host1"
    , pendingInputs = Dict.empty
    , disconnectedPlayers = Dict.empty
    , settings = { venomMode = True }
    , projectiles = []
    , shootCooldowns = Dict.empty
    , pendingShots = []
    , powerUpDrops = []
    , powerUpSpawnCooldown = 999999
    , randomSeed = Random.initialSeed 42
    }


suite : Test
suite =
    describe "HostGame integration"
        [ describe "standard venom in host mode"
            [ test "bufferShot + tick creates standard venom projectile" <|
                \_ ->
                    let
                        state =
                            HostGame.bufferShot "host1" makeHostState

                        result =
                            HostGame.tick state
                    in
                    Expect.equal 1 (List.length result.state.projectiles)
            , test "standard venom in stateSync has type 'standard'" <|
                \_ ->
                    let
                        state =
                            HostGame.bufferShot "host1" makeHostState

                        result =
                            HostGame.tick state
                    in
                    case result.stateSync.projectiles of
                        [ ps ] ->
                            Expect.equal "standard" ps.venomType

                        _ ->
                            Expect.fail ("Expected 1 projectile in sync, got " ++ String.fromInt (List.length result.stateSync.projectiles))
            ]
        , describe "ball venom in host mode"
            [ test "bufferShot with BallVenom snakeData creates ball projectile" <|
                \_ ->
                    let
                        -- Manually set snakeData.venomType = BallVenom
                        hostData =
                            { snake =
                                { id = "host1"
                                , body =
                                    [ { x = 15, y = 20 }
                                    , { x = 14, y = 20 }
                                    , { x = 13, y = 20 }
                                    , { x = 12, y = 20 }
                                    , { x = 11, y = 20 }
                                    ]
                                , direction = Right
                                , pendingGrowth = 0
                                , color = "00ff00"
                                , name = "Test Host"
                                , isInvincible = False
                                , state = "alive"
                                }
                            , invincibleUntilTick = 0
                            , needsRespawn = False
                            , status = Active
                            , venomType = BallVenom
                            }

                        state =
                            { makeHostState | snakes = Dict.singleton "host1" hostData }

                        stateWithShot =
                            HostGame.bufferShot "host1" state

                        result =
                            HostGame.tick stateWithShot
                    in
                    Expect.equal 1 (List.length result.state.projectiles)
            , test "ball venom projectile has BallVenom type internally" <|
                \_ ->
                    let
                        hostData =
                            { snake =
                                { id = "host1"
                                , body =
                                    [ { x = 15, y = 20 }
                                    , { x = 14, y = 20 }
                                    , { x = 13, y = 20 }
                                    , { x = 12, y = 20 }
                                    , { x = 11, y = 20 }
                                    ]
                                , direction = Right
                                , pendingGrowth = 0
                                , color = "00ff00"
                                , name = "Test Host"
                                , isInvincible = False
                                , state = "alive"
                                }
                            , invincibleUntilTick = 0
                            , needsRespawn = False
                            , status = Active
                            , venomType = BallVenom
                            }

                        state =
                            { makeHostState | snakes = Dict.singleton "host1" hostData }

                        stateWithShot =
                            HostGame.bufferShot "host1" state

                        result =
                            HostGame.tick stateWithShot
                    in
                    case result.state.projectiles of
                        [ p ] ->
                            Expect.equal BallVenom p.venomType

                        _ ->
                            Expect.fail ("Expected 1 projectile, got " ++ String.fromInt (List.length result.state.projectiles))
            , test "ball venom in stateSync has type 'ball'" <|
                \_ ->
                    let
                        hostData =
                            { snake =
                                { id = "host1"
                                , body =
                                    [ { x = 15, y = 20 }
                                    , { x = 14, y = 20 }
                                    , { x = 13, y = 20 }
                                    , { x = 12, y = 20 }
                                    , { x = 11, y = 20 }
                                    ]
                                , direction = Right
                                , pendingGrowth = 0
                                , color = "00ff00"
                                , name = "Test Host"
                                , isInvincible = False
                                , state = "alive"
                                }
                            , invincibleUntilTick = 0
                            , needsRespawn = False
                            , status = Active
                            , venomType = BallVenom
                            }

                        state =
                            { makeHostState | snakes = Dict.singleton "host1" hostData }

                        stateWithShot =
                            HostGame.bufferShot "host1" state

                        result =
                            HostGame.tick stateWithShot
                    in
                    case result.stateSync.projectiles of
                        [ ps ] ->
                            Expect.equal "ball" ps.venomType

                        _ ->
                            Expect.fail ("Expected 1 projectile in sync, got " ++ String.fromInt (List.length result.stateSync.projectiles))
            , test "ball venom projectile survives multiple ticks" <|
                \_ ->
                    let
                        hostData =
                            { snake =
                                { id = "host1"
                                , body =
                                    [ { x = 15, y = 20 }
                                    , { x = 14, y = 20 }
                                    , { x = 13, y = 20 }
                                    , { x = 12, y = 20 }
                                    , { x = 11, y = 20 }
                                    ]
                                , direction = Right
                                , pendingGrowth = 0
                                , color = "00ff00"
                                , name = "Test Host"
                                , isInvincible = False
                                , state = "alive"
                                }
                            , invincibleUntilTick = 0
                            , needsRespawn = False
                            , status = Active
                            , venomType = BallVenom
                            }

                        state =
                            { makeHostState | snakes = Dict.singleton "host1" hostData }

                        stateWithShot =
                            HostGame.bufferShot "host1" state

                        -- Tick once to create
                        afterFirstTick =
                            HostGame.tick stateWithShot

                        -- Tick 9 more times
                        after10Ticks =
                            List.foldl
                                (\_ s -> (HostGame.tick s).state)
                                afterFirstTick.state
                                (List.range 1 9)
                    in
                    if List.length after10Ticks.projectiles > 0 then
                        Expect.pass

                    else
                        Expect.fail "Ball venom died too early in HostGame"
            , test "ball venom position stays in bounds over lifetime" <|
                \_ ->
                    let
                        hostData =
                            { snake =
                                { id = "host1"
                                , body =
                                    [ { x = 15, y = 20 }
                                    , { x = 14, y = 20 }
                                    , { x = 13, y = 20 }
                                    , { x = 12, y = 20 }
                                    , { x = 11, y = 20 }
                                    ]
                                , direction = Right
                                , pendingGrowth = 0
                                , color = "00ff00"
                                , name = "Test Host"
                                , isInvincible = False
                                , state = "alive"
                                }
                            , invincibleUntilTick = 0
                            , needsRespawn = False
                            , status = Active
                            , venomType = BallVenom
                            }

                        state =
                            { makeHostState | snakes = Dict.singleton "host1" hostData }

                        stateWithShot =
                            HostGame.bufferShot "host1" state

                        afterFirst =
                            HostGame.tick stateWithShot

                        -- Collect projectile positions over 29 more ticks
                        ( _, allPositions ) =
                            List.foldl
                                (\_ ( s, posAcc ) ->
                                    let
                                        result =
                                            HostGame.tick s

                                        newPos =
                                            List.map .position result.state.projectiles
                                    in
                                    ( result.state, posAcc ++ newPos )
                                )
                                ( afterFirst.state, List.map .position afterFirst.state.projectiles )
                                (List.range 1 29)

                        outOfBounds =
                            List.filter
                                (\pos ->
                                    pos.x < 0 || pos.x >= 30 || pos.y < 0 || pos.y >= 40
                                )
                                allPositions
                    in
                    if List.isEmpty outOfBounds then
                        Expect.pass

                    else
                        Expect.fail ("Out of bounds: " ++ Debug.toString outOfBounds)
            ]
        ]
