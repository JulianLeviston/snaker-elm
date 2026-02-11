module ProjectileTest exposing (..)

import Dict
import Engine.Grid as Grid
import Engine.Projectile as Projectile exposing (Projectile)
import Engine.VenomType exposing (VenomType(..))
import Expect
import Random
import Snake exposing (Direction(..))
import Test exposing (..)


grid : { width : Int, height : Int }
grid =
    Grid.defaultDimensions


seed0 : Random.Seed
seed0 =
    Random.initialSeed 42


makeSnake : Int -> Int -> Direction -> Int -> Snake.Snake
makeSnake x y dir bodyLen =
    let
        head =
            { x = x, y = y }

        body =
            head
                :: List.map (\i -> { x = x - i, y = y }) (List.range 1 (bodyLen - 1))
    in
    { id = "test"
    , body = body
    , direction = dir
    , pendingGrowth = 0
    , color = "00ff00"
    , name = "Test Snake"
    , isInvincible = False
    , state = "alive"
    }


{-| Helper to make a projectile with velocity for tests.
-}
makeProj : Int -> Int -> Direction -> VenomType -> Projectile
makeProj x y dir vt =
    { position = { x = x, y = y }
    , direction = dir
    , ownerId = "p1"
    , spawnedAtTick = 0
    , venomType = vt
    , velocity = dirToVel dir
    }


dirToVel : Direction -> { dx : Int, dy : Int }
dirToVel dir =
    case dir of
        Up ->
            { dx = 0, dy = -1 }

        Down ->
            { dx = 0, dy = 1 }

        Left ->
            { dx = -1, dy = 0 }

        Right ->
            { dx = 1, dy = 0 }


{-| Make a ball projectile with explicit velocity (for diagonal tests).
-}
makeBallWithVelocity : Int -> Int -> Int -> Int -> Projectile
makeBallWithVelocity x y dx dy =
    { position = { x = x, y = y }
    , direction = Right
    , ownerId = "p1"
    , spawnedAtTick = 0
    , venomType = BallVenom
    , velocity = { dx = dx, dy = dy }
    }


suite : Test
suite =
    describe "Projectile system"
        [ describe "create"
            [ test "standard venom: creates projectile one cell ahead of head" <|
                \_ ->
                    let
                        result =
                            Projectile.create "p1" (makeSnake 10 10 Right 5) 0 Dict.empty StandardVenom grid
                    in
                    case result of
                        Just ( proj, _, _ ) ->
                            Expect.all
                                [ \p -> Expect.equal { x = 11, y = 10 } p.position
                                , \p -> Expect.equal Right p.direction
                                , \p -> Expect.equal StandardVenom p.venomType
                                ]
                                proj

                        Nothing ->
                            Expect.fail "Should create a projectile"
            , test "ball venom: creates with initial cardinal velocity" <|
                \_ ->
                    let
                        result =
                            Projectile.create "p1" (makeSnake 10 10 Right 5) 0 Dict.empty BallVenom grid
                    in
                    case result of
                        Just ( proj, _, _ ) ->
                            Expect.all
                                [ \p -> Expect.equal { x = 11, y = 10 } p.position
                                , \p -> Expect.equal BallVenom p.venomType
                                , \p -> Expect.equal { dx = 1, dy = 0 } p.velocity
                                ]
                                proj

                        Nothing ->
                            Expect.fail "Should create a projectile"
            , test "spawn wraps when head is at right edge facing right" <|
                \_ ->
                    let
                        result =
                            Projectile.create "p1" (makeSnake 29 10 Right 5) 0 Dict.empty BallVenom grid
                    in
                    case result of
                        Just ( proj, _, _ ) ->
                            Expect.equal 0 proj.position.x

                        Nothing ->
                            Expect.fail "Should create a projectile"
            , test "spawn wraps when head is at top edge facing up" <|
                \_ ->
                    let
                        result =
                            Projectile.create "p1" (makeSnake 10 0 Up 5) 0 Dict.empty BallVenom grid
                    in
                    case result of
                        Just ( proj, _, _ ) ->
                            Expect.equal (grid.height - 1) proj.position.y

                        Nothing ->
                            Expect.fail "Should create a projectile"
            , test "too short snake cannot fire" <|
                \_ ->
                    Expect.equal Nothing
                        (Projectile.create "p1" (makeSnake 10 10 Right 2) 0 Dict.empty StandardVenom grid)
            , test "cooldown prevents rapid fire" <|
                \_ ->
                    Expect.equal Nothing
                        (Projectile.create "p1" (makeSnake 10 10 Right 5) 3 (Dict.singleton "p1" 0) StandardVenom grid)
            ]
        , describe "movement - standard venom"
            [ test "moves 2 cells in direction per tick" <|
                \_ ->
                    case Projectile.moveAll grid seed0 [ makeProj 10 10 Right StandardVenom ] of
                        ( [ p ], _ ) ->
                            Expect.equal { x = 12, y = 10 } p.position

                        _ ->
                            Expect.fail "Expected exactly one projectile"
            , test "wraps around right edge" <|
                \_ ->
                    case Projectile.moveAll grid seed0 [ makeProj 29 10 Right StandardVenom ] of
                        ( [ p ], _ ) ->
                            Expect.equal { x = 1, y = 10 } p.position

                        _ ->
                            Expect.fail "Expected exactly one projectile"
            ]
        , describe "movement - ball venom cardinal"
            [ test "moves 2 cells in open space" <|
                \_ ->
                    case Projectile.moveAll grid seed0 [ makeProj 10 10 Right BallVenom ] of
                        ( [ p ], _ ) ->
                            Expect.equal { x = 12, y = 10 } p.position

                        _ ->
                            Expect.fail "Expected exactly one projectile"
            , test "ball stays in bounds after bouncing off right wall" <|
                \_ ->
                    case Projectile.moveAll grid seed0 [ makeProj 29 10 Right BallVenom ] of
                        ( [ p ], _ ) ->
                            if p.position.x >= 0 && p.position.x < grid.width && p.position.y >= 0 && p.position.y < grid.height then
                                Expect.pass

                            else
                                Expect.fail ("Out of bounds: " ++ Debug.toString p.position)

                        _ ->
                            Expect.fail "Expected exactly one projectile"
            , test "cardinal ball gains diagonal velocity after wall bounce" <|
                \_ ->
                    -- Ball at x=29 moving Right will hit wall, should gain dy component
                    case Projectile.moveAll grid seed0 [ makeProj 29 10 Right BallVenom ] of
                        ( [ p ], _ ) ->
                            if p.velocity.dx /= 0 && p.velocity.dy /= 0 then
                                Expect.pass

                            else
                                Expect.fail
                                    ("Expected diagonal velocity after bounce, got dx="
                                        ++ String.fromInt p.velocity.dx
                                        ++ " dy="
                                        ++ String.fromInt p.velocity.dy
                                    )

                        _ ->
                            Expect.fail "Expected exactly one projectile"
            ]
        , describe "movement - ball venom diagonal"
            [ test "diagonal ball moves diagonally in open space" <|
                \_ ->
                    case Projectile.moveAll grid seed0 [ makeBallWithVelocity 10 10 1 1 ] of
                        ( [ p ], _ ) ->
                            Expect.equal { x = 12, y = 12 } p.position

                        _ ->
                            Expect.fail "Expected exactly one projectile"
            , test "diagonal ball reflects off right wall" <|
                \_ ->
                    -- Ball at x=29 with velocity (1, 1) hits right wall
                    case Projectile.moveAll grid seed0 [ makeBallWithVelocity 29 10 1 1 ] of
                        ( [ p ], _ ) ->
                            Expect.all
                                [ \proj ->
                                    if proj.position.x >= 0 && proj.position.x < grid.width then
                                        Expect.pass

                                    else
                                        Expect.fail ("x out of bounds: " ++ String.fromInt proj.position.x)
                                , \proj ->
                                    -- dx should have flipped to -1
                                    Expect.equal -1 proj.velocity.dx
                                , \proj ->
                                    -- dy should stay 1 (didn't hit horizontal wall)
                                    Expect.equal 1 proj.velocity.dy
                                ]
                                p

                        _ ->
                            Expect.fail "Expected exactly one projectile"
            , test "diagonal ball reflects off top wall" <|
                \_ ->
                    -- Ball at y=0 with velocity (1, -1) hits top wall
                    case Projectile.moveAll grid seed0 [ makeBallWithVelocity 10 0 1 -1 ] of
                        ( [ p ], _ ) ->
                            Expect.all
                                [ \proj ->
                                    if proj.position.y >= 0 && proj.position.y < grid.height then
                                        Expect.pass

                                    else
                                        Expect.fail ("y out of bounds: " ++ String.fromInt proj.position.y)
                                , \proj ->
                                    -- dy should have flipped to 1
                                    Expect.equal 1 proj.velocity.dy
                                , \proj ->
                                    -- dx should stay 1
                                    Expect.equal 1 proj.velocity.dx
                                ]
                                p

                        _ ->
                            Expect.fail "Expected exactly one projectile"
            , test "diagonal ball reflects off corner" <|
                \_ ->
                    -- Ball at (29, 0) with velocity (1, -1) hits corner
                    case Projectile.moveAll grid seed0 [ makeBallWithVelocity 29 0 1 -1 ] of
                        ( [ p ], _ ) ->
                            Expect.all
                                [ \proj ->
                                    if proj.position.x >= 0 && proj.position.x < grid.width && proj.position.y >= 0 && proj.position.y < grid.height then
                                        Expect.pass

                                    else
                                        Expect.fail ("Out of bounds: " ++ Debug.toString proj.position)
                                , \proj -> Expect.equal -1 proj.velocity.dx
                                , \proj -> Expect.equal 1 proj.velocity.dy
                                ]
                                p

                        _ ->
                            Expect.fail "Expected exactly one projectile"
            , test "diagonal ball stays in bounds over 30 ticks" <|
                \_ ->
                    let
                        proj =
                            makeBallWithVelocity 5 5 1 1

                        ( finalProjs, _ ) =
                            List.foldl
                                (\_ ( projs, s ) -> Projectile.moveAll grid s projs)
                                ( [ proj ], seed0 )
                                (List.range 1 30)
                    in
                    case finalProjs of
                        [ p ] ->
                            if p.position.x >= 0 && p.position.x < grid.width && p.position.y >= 0 && p.position.y < grid.height then
                                Expect.pass

                            else
                                Expect.fail ("Out of bounds after 30 ticks: " ++ Debug.toString p.position)

                        _ ->
                            Expect.fail ("Expected 1 projectile, got " ++ String.fromInt (List.length finalProjs))
            , test "diagonal ball traces show Y movement (not just horizontal)" <|
                \_ ->
                    let
                        -- Start diagonal from the middle
                        proj =
                            makeBallWithVelocity 15 20 1 1

                        ( positions, _ ) =
                            List.foldl
                                (\_ ( posAcc, ( projs, s ) ) ->
                                    let
                                        ( moved, newSeed ) =
                                            Projectile.moveAll grid s projs
                                    in
                                    case moved of
                                        [ p ] ->
                                            ( p.position :: posAcc, ( moved, newSeed ) )

                                        _ ->
                                            ( posAcc, ( moved, newSeed ) )
                                )
                                ( [ proj.position ], ( [ proj ], seed0 ) )
                                (List.range 1 5)

                        yValues =
                            List.map .y positions

                        uniqueYs =
                            List.foldl
                                (\v acc ->
                                    if List.member v acc then
                                        acc

                                    else
                                        v :: acc
                                )
                                []
                                yValues
                    in
                    if List.length uniqueYs > 1 then
                        Expect.pass

                    else
                        Expect.fail
                            ("Ball Y never changed - not diagonal! Y values: "
                                ++ Debug.toString yValues
                            )
            ]
        , describe "expiration"
            [ test "standard venom expires after 15 ticks" <|
                \_ ->
                    let
                        proj =
                            makeProj 10 10 Right StandardVenom
                    in
                    Expect.all
                        [ \_ -> Expect.equal 1 (List.length (Projectile.removeExpired 14 [ proj ]))
                        , \_ -> Expect.equal 0 (List.length (Projectile.removeExpired 15 [ proj ]))
                        ]
                        ()
            , test "ball venom expires after 30 ticks" <|
                \_ ->
                    let
                        proj =
                            makeProj 10 10 Right BallVenom
                    in
                    Expect.all
                        [ \_ -> Expect.equal 1 (List.length (Projectile.removeExpired 29 [ proj ]))
                        , \_ -> Expect.equal 0 (List.length (Projectile.removeExpired 30 [ proj ]))
                        ]
                        ()
            ]
        , describe "full lifecycle"
            [ test "ball fired near wall bounces diagonally" <|
                \_ ->
                    let
                        -- Snake at x=27 facing Right → ball spawns at x=28, one cell from right wall
                        createResult =
                            Projectile.create "p1" (makeSnake 27 20 Right 5) 0 Dict.empty BallVenom grid
                    in
                    case createResult of
                        Just ( proj, _, _ ) ->
                            let
                                -- Collect positions over 10 ticks
                                ( allPositions, _ ) =
                                    List.foldl
                                        (\_ ( posAcc, ( projs, s ) ) ->
                                            let
                                                ( moved, newSeed ) =
                                                    Projectile.moveAll grid s projs
                                            in
                                            case moved of
                                                [ p ] ->
                                                    ( p.position :: posAcc, ( moved, newSeed ) )

                                                _ ->
                                                    ( posAcc, ( moved, newSeed ) )
                                        )
                                        ( [ proj.position ], ( [ proj ], seed0 ) )
                                        (List.range 1 10)

                                yValues =
                                    List.map .y allPositions

                                uniqueYs =
                                    List.foldl
                                        (\v acc ->
                                            if List.member v acc then
                                                acc

                                            else
                                                v :: acc
                                        )
                                        []
                                        yValues

                                outOfBounds =
                                    List.filter
                                        (\pos -> pos.x < 0 || pos.x >= grid.width || pos.y < 0 || pos.y >= grid.height)
                                        allPositions
                            in
                            Expect.all
                                [ \_ ->
                                    if List.isEmpty outOfBounds then
                                        Expect.pass

                                    else
                                        Expect.fail ("Out of bounds: " ++ Debug.toString outOfBounds)
                                , \_ ->
                                    if List.length uniqueYs > 1 then
                                        Expect.pass

                                    else
                                        Expect.fail "Ball never moved vertically after bounce - expected diagonal"
                                ]
                                ()

                        Nothing ->
                            Expect.fail "Should create projectile"
            , test "render pipeline produces 'ball' venomType string" <|
                \_ ->
                    let
                        createResult =
                            Projectile.create "p1" (makeSnake 15 20 Right 5) 100 Dict.empty BallVenom grid
                    in
                    case createResult of
                        Just ( proj, _, _ ) ->
                            let
                                ( moved, _ ) =
                                    Projectile.moveAll grid seed0 [ proj ]

                                alive =
                                    Projectile.removeExpired 100 moved

                                renderStates =
                                    List.map
                                        (\p ->
                                            { venomType = Engine.VenomType.toString p.venomType
                                            , inBounds =
                                                p.position.x >= 0 && p.position.x < grid.width && p.position.y >= 0 && p.position.y < grid.height
                                            }
                                        )
                                        alive
                            in
                            case renderStates of
                                [ state ] ->
                                    Expect.all
                                        [ \s -> Expect.equal "ball" s.venomType
                                        , \s -> Expect.equal True s.inBounds
                                        ]
                                        state

                                _ ->
                                    Expect.fail ("Expected 1 projectile, got " ++ String.fromInt (List.length renderStates))

                        Nothing ->
                            Expect.fail "Should create projectile"
            ]
        ]
