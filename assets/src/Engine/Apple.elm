module Engine.Apple exposing
    ( Apple
    , AppleStage(..)
    , checkEaten
    , checkEatenWithStage
    , getStage
    , stageValues
    , spawnIfNeeded
    , tickExpiredApples
    , minApples
    , maxApples
    , ticksUntilExpiry
    , randomSafePosition
    )

{-| Apple spawning, eating, and expiration logic.

Apples progress through aging stages:
- Fresh (0-24 ticks): Green, +1 score, +1 growth
- Aging (25-49 ticks): Yellow, +2 score, +2 growth
- Old (50-79 ticks): Red, +3 score, +3 growth
- Expiring (80-99 ticks): Red + pulse, +3 score, +3 growth
- Skull (100+ ticks): White skull, -50% score, -50% length
-}

import Engine.Grid
import Random
import Snake exposing (Position)


{-| Apple with position and spawn tick for age calculation.
-}
type alias Apple =
    { position : Position
    , spawnedAtTick : Int
    }


{-| Apple aging stage determines appearance and reward.
-}
type AppleStage
    = Fresh -- Green, ticks 0-24
    | Aging -- Yellow, ticks 25-49
    | Old -- Red, ticks 50-79
    | Expiring -- Red + pulse, ticks 80-99
    | Skull -- White skull, ticks 100+


{-| Minimum number of apples that should always be on the board.
Matches Elixir @min_apples.
-}
minApples : Int
minApples =
    3


{-| Maximum number of apples allowed on the board.
Safety cap to prevent unbounded growth from timing edge cases.
30% of default grid area.
-}
maxApples : Int
maxApples =
    Engine.Grid.defaultDimensions.width * Engine.Grid.defaultDimensions.height * 30 // 100


{-| Number of ticks before an apple becomes a skull.
10 seconds at 100ms per tick.
-}
ticksUntilExpiry : Int
ticksUntilExpiry =
    100


{-| Determine the stage of an apple based on its age.
-}
getStage : Int -> Apple -> AppleStage
getStage currentTick apple =
    let
        age =
            currentTick - apple.spawnedAtTick
    in
    if age <= 24 then
        Fresh

    else if age <= 49 then
        Aging

    else if age <= 79 then
        Old

    else if age <= 99 then
        Expiring

    else
        Skull


{-| Get score and growth values for a stage.
Returns score, growth, and whether it's a skull (penalty).
-}
stageValues : AppleStage -> { score : Int, growth : Int, isSkull : Bool }
stageValues stage =
    case stage of
        Fresh ->
            { score = 1, growth = 1, isSkull = False }

        Aging ->
            { score = 2, growth = 2, isSkull = False }

        Old ->
            { score = 3, growth = 3, isSkull = False }

        Expiring ->
            { score = 3, growth = 3, isSkull = False }

        Skull ->
            { score = 0, growth = 0, isSkull = True }


{-| Check if snake head has eaten any apple.

Returns whether an apple was eaten, the remaining apples, and the eaten apple.
-}
checkEaten : Position -> List Apple -> { eaten : Bool, remaining : List Apple, eatenApple : Maybe Apple }
checkEaten snakeHead apples =
    let
        ( eaten, remaining ) =
            List.partition (\apple -> apple.position == snakeHead) apples
    in
    case eaten of
        eatenApple :: _ ->
            { eaten = True
            , remaining = remaining
            , eatenApple = Just eatenApple
            }

        [] ->
            { eaten = False
            , remaining = apples
            , eatenApple = Nothing
            }


{-| Check if snake head has eaten any apple, returning stage-based values.

Returns score/growth based on apple stage, and whether skull penalty applies.
-}
checkEatenWithStage : Int -> Position -> List Apple -> { eaten : Bool, remaining : List Apple, score : Int, growth : Int, isSkull : Bool }
checkEatenWithStage currentTick snakeHead apples =
    let
        ( eaten, remaining ) =
            List.partition (\apple -> apple.position == snakeHead) apples
    in
    case eaten of
        eatenApple :: _ ->
            let
                stage =
                    getStage currentTick eatenApple

                values =
                    stageValues stage
            in
            { eaten = True
            , remaining = remaining
            , score = values.score
            , growth = values.growth
            , isSkull = values.isSkull
            }

        [] ->
            { eaten = False
            , remaining = apples
            , score = 0
            , growth = 0
            , isSkull = False
            }


{-| Check for truly expired apples (skulls that have been around too long).

Skulls stay on the board for 50 more ticks (5 seconds) after becoming skulls,
then they expire and respawn as fresh apples.
-}
tickExpiredApples : Int -> List Apple -> { expired : List Apple, remaining : List Apple }
tickExpiredApples currentTick apples =
    let
        -- Skulls (age >= 100) stay for another 50 ticks before expiring
        -- Total lifespan: 150 ticks = 15 seconds
        maxAge =
            ticksUntilExpiry + 50

        ( expired, remaining ) =
            List.partition (\apple -> (currentTick - apple.spawnedAtTick) >= maxAge) apples
    in
    { expired = expired, remaining = remaining }


{-| Returns the count of apples needed to reach minimum.

Used by Main.elm to know how many spawn commands to issue.
-}
spawnIfNeeded : List Apple -> Int
spawnIfNeeded apples =
    let
        needed =
            minApples - List.length apples
    in
    max 0 needed


{-| Generate a random position that is not in the occupied list.

Uses retry approach: generates position, checks if safe, retries if not.
Limited to 100 retries to prevent infinite loops on full boards.
-}
randomSafePosition : List Position -> { width : Int, height : Int } -> Random.Generator Position
randomSafePosition occupied grid =
    let
        randomPos =
            Random.map2 Position
                (Random.int 0 (grid.width - 1))
                (Random.int 0 (grid.height - 1))

        trySpawn : Int -> Random.Generator Position
        trySpawn attemptsLeft =
            randomPos
                |> Random.andThen
                    (\pos ->
                        if not (List.member pos occupied) then
                            Random.constant pos

                        else if attemptsLeft > 0 then
                            trySpawn (attemptsLeft - 1)

                        else
                            -- Fallback: return random position anyway
                            -- Board should never be this full in practice
                            randomPos
                    )
    in
    trySpawn 100
