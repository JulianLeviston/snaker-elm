module Engine.Apple exposing
    ( Apple
    , checkEaten
    , spawnIfNeeded
    , tickExpiredApples
    , growthAmount
    , minApples
    , ticksUntilExpiry
    , randomSafePosition
    )

{-| Apple spawning, eating, and expiration logic.

Matches Elixir Game.Apple behavior with addition of expiration.
-}

import Random
import Snake exposing (Position)


{-| Apple with position and expiration tick.
-}
type alias Apple =
    { position : Position
    , expiresAtTick : Int
    }


{-| Minimum number of apples that should always be on the board.
Matches Elixir @min_apples.
-}
minApples : Int
minApples =
    3


{-| Segments added to snake when eating an apple.
Matches Elixir @growth_per_apple.
-}
growthAmount : Int
growthAmount =
    3


{-| Number of ticks before an apple expires and respawns.
10 seconds at 100ms per tick.
-}
ticksUntilExpiry : Int
ticksUntilExpiry =
    100


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


{-| Check for expired apples and separate them from remaining.

Returns apples that have expired (need respawning) and those still valid.
-}
tickExpiredApples : Int -> List Apple -> { expired : List Apple, remaining : List Apple }
tickExpiredApples currentTick apples =
    let
        ( expired, remaining ) =
            List.partition (\apple -> currentTick >= apple.expiresAtTick) apples
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
