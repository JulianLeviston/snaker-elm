module Engine.Projectile exposing
    ( Projectile
    , cooldownTicks
    , maxLifetime
    , create
    , moveAll
    , removeExpired
    , getMovementPath
    )

{-| Venom projectile logic for the venom spitting mechanic.

Projectiles travel at 2 cells/tick in the snake's facing direction.
Firing costs 1 segment (minimum length 3 to fire).
5-tick cooldown between shots per snake.
15-tick maximum lifetime.
-}

import Dict exposing (Dict)
import Engine.Grid as Grid
import Snake exposing (Direction, Position, Snake)


{-| A venom projectile on the board.
-}
type alias Projectile =
    { position : Position
    , direction : Direction
    , ownerId : String
    , spawnedAtTick : Int
    }


{-| Cooldown ticks between shots per snake.
-}
cooldownTicks : Int
cooldownTicks =
    5


{-| Maximum lifetime of a projectile in ticks.
-}
maxLifetime : Int
maxLifetime =
    15


{-| Create a projectile from a snake, if allowed.

Returns the new projectile and the shortened snake, or Nothing if:
- Snake length <= 2 (need minimum 3 to fire, surviving length 2)
- Snake is on cooldown
-}
create : String -> Snake -> Int -> Dict String Int -> Maybe ( Projectile, Snake, Dict String Int )
create playerId snake currentTick cooldowns =
    let
        canFire =
            case Dict.get playerId cooldowns of
                Just lastFireTick ->
                    (currentTick - lastFireTick) >= cooldownTicks

                Nothing ->
                    True

        tooShort =
            List.length snake.body < 3
    in
    if tooShort || not canFire then
        Nothing

    else
        case Snake.head snake of
            Nothing ->
                Nothing

            Just headPos ->
                let
                    spawnPos =
                        Grid.nextPosition headPos snake.direction

                    projectile =
                        { position = spawnPos
                        , direction = snake.direction
                        , ownerId = playerId
                        , spawnedAtTick = currentTick
                        }

                    -- Remove last segment (cost of firing)
                    shortenedBody =
                        List.take (List.length snake.body - 1) snake.body

                    shortenedSnake =
                        { snake | body = shortenedBody }

                    newCooldowns =
                        Dict.insert playerId currentTick cooldowns
                in
                Just ( projectile, shortenedSnake, newCooldowns )


{-| Move all projectiles 2 cells in their direction with wrapping.
-}
moveAll : { width : Int, height : Int } -> List Projectile -> List Projectile
moveAll grid projectiles =
    List.map (move grid) projectiles


{-| Move a single projectile 2 cells in its direction.
-}
move : { width : Int, height : Int } -> Projectile -> Projectile
move grid projectile =
    let
        pos1 =
            Grid.nextPosition projectile.position projectile.direction

        pos2 =
            Grid.nextPosition pos1 projectile.direction

        wrappedPos =
            Grid.wrapPosition pos2 grid
    in
    { projectile | position = wrappedPos }


{-| Remove projectiles that have exceeded their lifetime.
-}
removeExpired : Int -> List Projectile -> List Projectile
removeExpired currentTick projectiles =
    List.filter (\p -> (currentTick - p.spawnedAtTick) < maxLifetime) projectiles


{-| Get the movement path for a projectile (2 cells in direction).

Returns [intermediate, final] positions for path-aware hit detection.
This prevents projectiles from skipping over cells at speed 2.
-}
getMovementPath : { width : Int, height : Int } -> Projectile -> List Position
getMovementPath grid projectile =
    let
        pos1 =
            Grid.nextPosition projectile.position projectile.direction
                |> (\p -> Grid.wrapPosition p grid)

        pos2 =
            Grid.nextPosition pos1 projectile.direction
                |> (\p -> Grid.wrapPosition p grid)
    in
    [ pos1, pos2 ]
