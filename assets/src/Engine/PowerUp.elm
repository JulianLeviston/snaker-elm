module Engine.PowerUp exposing
    ( PowerUpKind(..)
    , PowerUpDrop
    , spawnIntervalMin
    , spawnIntervalMax
    , maxDrops
    , shouldSpawn
    , spawnIntervalGenerator
    , randomKind
    , checkEaten
    , kindToString
    , kindFromString
    , randomSafePosition
    )

{-| Power-up drop logic for collectible items on the board.

Power-up drops appear periodically and grant the eating snake
a venom type. Two kinds:
- BallVenomPowerUp ("B") — bouncing ball venom
- StandardVenomPowerUp ("V") — straight-line venom
Both also grant 1 segment of growth.
-}

import Engine.Apple
import Random
import Snake exposing (Position)


{-| Types of power-up drops available.
-}
type PowerUpKind
    = BallVenomPowerUp
    | StandardVenomPowerUp


{-| A power-up drop on the board.
-}
type alias PowerUpDrop =
    { position : Position
    , kind : PowerUpKind
    , spawnedAtTick : Int
    }


{-| Minimum ticks between power-up spawns (10 seconds at 100ms/tick).
-}
spawnIntervalMin : Int
spawnIntervalMin =
    100


{-| Maximum ticks between power-up spawns (30 seconds at 100ms/tick).
-}
spawnIntervalMax : Int
spawnIntervalMax =
    300


{-| Maximum number of power-up drops on the board at once.
-}
maxDrops : Int
maxDrops =
    2


{-| Check if a new power-up should spawn.

Returns True when enough time has passed since the cooldown started
and there's room for another drop.
-}
shouldSpawn : Int -> Int -> Int -> Bool
shouldSpawn currentTick cooldownUntilTick currentCount =
    currentTick >= cooldownUntilTick && currentCount < maxDrops


{-| Generator for random spawn interval between min and max.
-}
spawnIntervalGenerator : Random.Generator Int
spawnIntervalGenerator =
    Random.int spawnIntervalMin spawnIntervalMax


{-| Check if a snake head has eaten any power-up drop.

Returns the eaten drop (if any) and the remaining drops.
-}
checkEaten : Position -> List PowerUpDrop -> { eaten : Maybe PowerUpDrop, remaining : List PowerUpDrop }
checkEaten headPos drops =
    let
        ( eaten, remaining ) =
            List.partition (\drop -> drop.position == headPos) drops
    in
    { eaten = List.head eaten
    , remaining = remaining
    }


{-| Convert PowerUpKind to string for network encoding.
-}
kindToString : PowerUpKind -> String
kindToString kind =
    case kind of
        BallVenomPowerUp ->
            "ball_venom"

        StandardVenomPowerUp ->
            "standard_venom"


{-| Parse a string into a PowerUpKind. Returns Nothing for unknown kinds.
-}
kindFromString : String -> Maybe PowerUpKind
kindFromString str =
    case str of
        "ball_venom" ->
            Just BallVenomPowerUp

        "standard_venom" ->
            Just StandardVenomPowerUp

        _ ->
            Nothing


{-| Randomly pick a power-up kind (50/50 B or V).
-}
randomKind : Random.Generator PowerUpKind
randomKind =
    Random.uniform BallVenomPowerUp [ StandardVenomPowerUp ]


{-| Generate a random safe position for a power-up drop.

Delegates to Apple.randomSafePosition to reuse the retry logic.
-}
randomSafePosition : List Position -> { width : Int, height : Int } -> Random.Generator Position
randomSafePosition occupied grid =
    Engine.Apple.randomSafePosition occupied grid
