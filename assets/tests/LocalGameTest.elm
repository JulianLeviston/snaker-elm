module LocalGameTest exposing (..)

import Dict
import Engine.VenomType exposing (VenomType(..))
import Expect
import LocalGame exposing (LocalGameState)
import Random
import Snake exposing (Direction(..))
import Test exposing (..)


{-| Create a deterministic LocalGameState for testing.
-}
makeState : LocalGameState
makeState =
    let
        startPos =
            { x = 15, y = 20 }
    in
    { snake =
        { id = "local"
        , body =
            [ startPos
            , { x = 14, y = 20 }
            , { x = 13, y = 20 }
            , { x = 12, y = 20 }
            , { x = 11, y = 20 }
            ]
        , direction = Right
        , pendingGrowth = 0
        , color = "00ff00"
        , name = "Test Snake"
        , isInvincible = False
        , state = "alive"
        }
    , apples = []
    , grid = { width = 30, height = 40 }
    , inputBuffer = Nothing
    , score = 0
    , currentTick = 100
    , invincibleUntilTick = 0
    , needsRespawn = False
    , penaltyState = Nothing
    , projectiles = []
    , shootCooldowns = Dict.empty
    , pendingShot = False
    , venomType = StandardVenom
    , randomSeed = Random.initialSeed 42
    }


suite : Test
suite =
    describe "LocalGame integration"
        [ describe "standard venom shooting"
            [ test "bufferShot + tick creates a standard venom projectile" <|
                \_ ->
                    let
                        state =
                            makeState

                        stateWithShot =
                            LocalGame.bufferShot state

                        result =
                            LocalGame.tick stateWithShot
                    in
                    Expect.equal 1 (List.length result.state.projectiles)
            , test "standard venom projectile has correct type" <|
                \_ ->
                    let
                        state =
                            makeState

                        stateWithShot =
                            LocalGame.bufferShot state

                        result =
                            LocalGame.tick stateWithShot

                        projStates =
                            LocalGame.toProjectileStates result.state
                    in
                    case projStates of
                        [ ps ] ->
                            Expect.equal "standard" ps.venomType

                        _ ->
                            Expect.fail ("Expected 1 projectile state, got " ++ String.fromInt (List.length projStates))
            , test "standard venom projectile position is in bounds" <|
                \_ ->
                    let
                        state =
                            makeState

                        stateWithShot =
                            LocalGame.bufferShot state

                        result =
                            LocalGame.tick stateWithShot
                    in
                    case result.state.projectiles of
                        [ p ] ->
                            if p.position.x >= 0 && p.position.x < 30 && p.position.y >= 0 && p.position.y < 40 then
                                Expect.pass

                            else
                                Expect.fail ("Out of bounds: " ++ Debug.toString p.position)

                        _ ->
                            Expect.fail "Expected 1 projectile"
            ]
        , describe "ball venom shooting"
            [ test "bufferShot + tick creates a ball venom projectile" <|
                \_ ->
                    let
                        state =
                            { makeState | venomType = BallVenom }

                        stateWithShot =
                            LocalGame.bufferShot state

                        result =
                            LocalGame.tick stateWithShot
                    in
                    Expect.equal 1 (List.length result.state.projectiles)
            , test "ball venom projectile has BallVenom venomType internally" <|
                \_ ->
                    let
                        state =
                            { makeState | venomType = BallVenom }

                        stateWithShot =
                            LocalGame.bufferShot state

                        result =
                            LocalGame.tick stateWithShot
                    in
                    case result.state.projectiles of
                        [ p ] ->
                            Expect.equal BallVenom p.venomType

                        _ ->
                            Expect.fail "Expected 1 projectile"
            , test "ball venom projectile converts to 'ball' string for rendering" <|
                \_ ->
                    let
                        state =
                            { makeState | venomType = BallVenom }

                        stateWithShot =
                            LocalGame.bufferShot state

                        result =
                            LocalGame.tick stateWithShot

                        projStates =
                            LocalGame.toProjectileStates result.state
                    in
                    case projStates of
                        [ ps ] ->
                            Expect.equal "ball" ps.venomType

                        _ ->
                            Expect.fail ("Expected 1 projectile state, got " ++ String.fromInt (List.length projStates))
            , test "ball venom projectile position is in bounds" <|
                \_ ->
                    let
                        state =
                            { makeState | venomType = BallVenom }

                        stateWithShot =
                            LocalGame.bufferShot state

                        result =
                            LocalGame.tick stateWithShot
                    in
                    case result.state.projectiles of
                        [ p ] ->
                            if p.position.x >= 0 && p.position.x < 30 && p.position.y >= 0 && p.position.y < 40 then
                                Expect.pass

                            else
                                Expect.fail ("Out of bounds: " ++ Debug.toString p.position)

                        _ ->
                            Expect.fail "Expected 1 projectile"
            , test "ball venom projectile survives multiple ticks" <|
                \_ ->
                    let
                        state =
                            { makeState | venomType = BallVenom }

                        stateWithShot =
                            LocalGame.bufferShot state

                        -- Tick once to create the projectile
                        afterFirstTick =
                            LocalGame.tick stateWithShot

                        -- Then tick 9 more times (no more shots)
                        after10Ticks =
                            List.foldl
                                (\_ s -> (LocalGame.tick s).state)
                                afterFirstTick.state
                                (List.range 1 9)
                    in
                    -- Ball venom lifetime is 30, so after 10 ticks it should still be alive
                    if List.length after10Ticks.projectiles > 0 then
                        Expect.pass

                    else
                        Expect.fail "Ball venom projectile expired too early (should survive 30 ticks)"
            , test "ball venom stays in bounds over its full lifetime" <|
                \_ ->
                    let
                        state =
                            { makeState | venomType = BallVenom }

                        stateWithShot =
                            LocalGame.bufferShot state

                        -- Tick once to create, then track positions for 29 more ticks
                        afterFirstTick =
                            LocalGame.tick stateWithShot

                        allPositions =
                            List.foldl
                                (\_ ( s, posAcc ) ->
                                    let
                                        result =
                                            LocalGame.tick s

                                        newPositions =
                                            List.map .position result.state.projectiles
                                    in
                                    ( result.state, posAcc ++ newPositions )
                                )
                                ( afterFirstTick.state, List.map .position afterFirstTick.state.projectiles )
                                (List.range 1 29)

                        ( _, trackedPositions ) =
                            allPositions

                        outOfBounds =
                            List.filter
                                (\pos ->
                                    pos.x < 0 || pos.x >= 30 || pos.y < 0 || pos.y >= 40
                                )
                                trackedPositions
                    in
                    if List.isEmpty outOfBounds then
                        Expect.pass

                    else
                        Expect.fail ("Ball went out of bounds: " ++ Debug.toString outOfBounds)
            ]
        , describe "edge cases"
            [ test "ball venom from right edge snake" <|
                \_ ->
                    let
                        state =
                            { makeState
                                | venomType = BallVenom
                                , snake =
                                    { id = "local"
                                    , body =
                                        [ { x = 29, y = 20 }
                                        , { x = 28, y = 20 }
                                        , { x = 27, y = 20 }
                                        , { x = 26, y = 20 }
                                        , { x = 25, y = 20 }
                                        ]
                                    , direction = Right
                                    , pendingGrowth = 0
                                    , color = "00ff00"
                                    , name = "Edge Snake"
                                    , isInvincible = False
                                    , state = "alive"
                                    }
                            }

                        stateWithShot =
                            LocalGame.bufferShot state

                        result =
                            LocalGame.tick stateWithShot
                    in
                    case result.state.projectiles of
                        [ p ] ->
                            Expect.all
                                [ \proj ->
                                    if proj.position.x >= 0 && proj.position.x < 30 then
                                        Expect.pass

                                    else
                                        Expect.fail ("x out of bounds: " ++ String.fromInt proj.position.x)
                                , \proj -> Expect.equal BallVenom proj.venomType
                                ]
                                p

                        _ ->
                            Expect.fail ("Expected 1 projectile, got " ++ String.fromInt (List.length result.state.projectiles))
            , test "ball venom from top edge snake" <|
                \_ ->
                    let
                        state =
                            { makeState
                                | venomType = BallVenom
                                , snake =
                                    { id = "local"
                                    , body =
                                        [ { x = 15, y = 0 }
                                        , { x = 15, y = 1 }
                                        , { x = 15, y = 2 }
                                        , { x = 15, y = 3 }
                                        , { x = 15, y = 4 }
                                        ]
                                    , direction = Up
                                    , pendingGrowth = 0
                                    , color = "00ff00"
                                    , name = "Top Snake"
                                    , isInvincible = False
                                    , state = "alive"
                                    }
                            }

                        stateWithShot =
                            LocalGame.bufferShot state

                        result =
                            LocalGame.tick stateWithShot
                    in
                    case result.state.projectiles of
                        [ p ] ->
                            if p.position.y >= 0 && p.position.y < 40 then
                                Expect.pass

                            else
                                Expect.fail ("y out of bounds: " ++ String.fromInt p.position.y)

                        _ ->
                            Expect.fail ("Expected 1 projectile, got " ++ String.fromInt (List.length result.state.projectiles))
            ]
        ]
