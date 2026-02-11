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
Lifetime depends on venom type (15 standard, 50 ball).

Ball venom uses velocity-based movement and bounces off walls at angles:
- Starts moving cardinally (matching snake direction)
- On wall bounce, flips the wall-perpendicular velocity component
  and gains a random perpendicular component if moving cardinally
- Result: balls quickly become diagonal and bounce naturally
- Corner hits: reverse both components
-}

import Dict exposing (Dict)
import Engine.Grid as Grid
import Engine.VenomType as VenomType exposing (VenomType(..))
import Random
import Snake exposing (Direction(..), Position, Snake)


{-| A venom projectile on the board.

`velocity` is used by ball venom for diagonal bouncing (dx/dy each -1, 0, or 1).
Standard venom ignores velocity and uses `direction` with Grid.nextPosition.
-}
type alias Projectile =
    { position : Position
    , direction : Direction
    , ownerId : String
    , spawnedAtTick : Int
    , venomType : VenomType
    , velocity : { dx : Int, dy : Int }
    }


{-| Cooldown ticks between shots per snake.
-}
cooldownTicks : Int
cooldownTicks =
    5


{-| Maximum lifetime of a projectile in ticks (standard venom).
-}
maxLifetime : Int
maxLifetime =
    15


{-| Convert a direction to an initial velocity vector.
-}
directionToVelocity : Direction -> { dx : Int, dy : Int }
directionToVelocity dir =
    case dir of
        Up ->
            { dx = 0, dy = -1 }

        Down ->
            { dx = 0, dy = 1 }

        Left ->
            { dx = -1, dy = 0 }

        Right ->
            { dx = 1, dy = 0 }


{-| Create a projectile from a snake, if allowed.

Returns the new projectile and the shortened snake, or Nothing if:
- Snake length <= 2 (need minimum 3 to fire, surviving length 2)
- Snake is on cooldown
-}
create : String -> Snake -> Int -> Dict String Int -> VenomType -> { width : Int, height : Int } -> Maybe ( Projectile, Snake, Dict String Int )
create playerId snake currentTick cooldowns venomType grid =
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
                            |> (\p -> Grid.wrapPosition p grid)

                    projectile =
                        { position = spawnPos
                        , direction = snake.direction
                        , ownerId = playerId
                        , spawnedAtTick = currentTick
                        , venomType = venomType
                        , velocity = directionToVelocity snake.direction
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

Ball venom projectiles bounce off walls using a Random.Seed for direction randomization.
Returns updated projectiles and the new seed.
-}
moveAll : { width : Int, height : Int } -> Random.Seed -> List Projectile -> ( List Projectile, Random.Seed )
moveAll grid seed projectiles =
    List.foldl
        (\proj ( acc, currentSeed ) ->
            let
                ( movedProj, newSeed ) =
                    moveProjectile grid currentSeed proj
            in
            ( movedProj :: acc, newSeed )
        )
        ( [], seed )
        projectiles
        |> (\( reversed, finalSeed ) -> ( List.reverse reversed, finalSeed ))


{-| Move a single projectile based on its venom type.
-}
moveProjectile : { width : Int, height : Int } -> Random.Seed -> Projectile -> ( Projectile, Random.Seed )
moveProjectile grid seed projectile =
    case projectile.venomType of
        StandardVenom ->
            ( moveStandard grid projectile, seed )

        BallVenom ->
            moveBall grid seed projectile


{-| Move a standard projectile 2 cells in its direction (original behavior).
-}
moveStandard : { width : Int, height : Int } -> Projectile -> Projectile
moveStandard grid projectile =
    let
        pos1 =
            Grid.nextPosition projectile.position projectile.direction

        pos2 =
            Grid.nextPosition pos1 projectile.direction

        wrappedPos =
            Grid.wrapPosition pos2 grid
    in
    { projectile | position = wrappedPos }


{-| Move a ball venom projectile with velocity-based wall bouncing.

Ball moves 2 steps per tick using its velocity vector (dx, dy).
Each component is -1, 0, or +1.

On wall bounce:
- Flip the component perpendicular to the wall
- If the parallel component is 0 (cardinal hit), add random +1/-1
  so the ball deflects to a diagonal
- Corner: flip both, ensure diagonal

Result: balls start cardinal, quickly become diagonal, and bounce
at natural angles off walls.
-}
moveBall : { width : Int, height : Int } -> Random.Seed -> Projectile -> ( Projectile, Random.Seed )
moveBall grid seed projectile =
    let
        -- Step 1
        ( proj1, seed1 ) =
            moveBallOneStep grid seed projectile

        -- Step 2
        ( proj2, seed2 ) =
            moveBallOneStep grid seed1 proj1
    in
    ( proj2, seed2 )


{-| Move a ball one step using velocity, bouncing off walls if needed.

When hitting a wall:
- Flip the velocity component going into the wall
- If the other component is 0, randomize it to ±1 (creates diagonal)
- Ball stays in place on bounce (spends that step changing direction)
-}
moveBallOneStep : { width : Int, height : Int } -> Random.Seed -> Projectile -> ( Projectile, Random.Seed )
moveBallOneStep grid seed projectile =
    let
        vel =
            projectile.velocity

        nextX =
            projectile.position.x + vel.dx

        nextY =
            projectile.position.y + vel.dy

        hitWallX =
            nextX < 0 || nextX >= grid.width

        hitWallY =
            nextY < 0 || nextY >= grid.height
    in
    if hitWallX && hitWallY then
        -- Corner hit: flip both, ensure diagonal
        let
            ( newDy, seed1 ) =
                if vel.dy == 0 then
                    randomSign seed

                else
                    ( negate vel.dy, seed )

            ( newDx, seed2 ) =
                if vel.dx == 0 then
                    randomSign seed1

                else
                    ( negate vel.dx, seed1 )

            -- 25% chance to randomize each component for less predictable corners
            ( roll1, seed3 ) =
                Random.step (Random.float 0 1) seed2

            ( finalDx, seed4 ) =
                if roll1 < 0.25 then
                    randomSign seed3

                else
                    ( newDx, seed3 )

            ( roll2, seed5 ) =
                Random.step (Random.float 0 1) seed4

            ( finalDy, seed6 ) =
                if roll2 < 0.25 then
                    randomSign seed5

                else
                    ( newDy, seed5 )
        in
        ( { projectile | velocity = { dx = finalDx, dy = finalDy } }, seed6 )

    else if hitWallX then
        -- Hit left/right wall: flip dx, ensure dy is non-zero
        let
            newDx =
                negate vel.dx

            ( newDy, seed1 ) =
                if vel.dy == 0 then
                    randomSign seed

                else
                    ( vel.dy, seed )

            -- 25% chance to randomize dy for less predictable bounces
            ( roll, seed2 ) =
                Random.step (Random.float 0 1) seed1

            ( finalDy, seed3 ) =
                if roll < 0.25 then
                    randomSign seed2

                else
                    ( newDy, seed2 )
        in
        ( { projectile | velocity = { dx = newDx, dy = finalDy } }, seed3 )

    else if hitWallY then
        -- Hit top/bottom wall: flip dy, ensure dx is non-zero
        let
            newDy =
                negate vel.dy

            ( newDx, seed1 ) =
                if vel.dx == 0 then
                    randomSign seed

                else
                    ( vel.dx, seed )

            -- 25% chance to randomize dx for less predictable bounces
            ( roll, seed2 ) =
                Random.step (Random.float 0 1) seed1

            ( finalDx, seed3 ) =
                if roll < 0.25 then
                    randomSign seed2

                else
                    ( newDx, seed2 )
        in
        ( { projectile | velocity = { dx = finalDx, dy = newDy } }, seed3 )

    else
        -- No wall: move normally
        ( { projectile | position = { x = nextX, y = nextY } }, seed )


{-| Generate a random sign: +1 or -1.
-}
randomSign : Random.Seed -> ( Int, Random.Seed )
randomSign seed =
    let
        ( bit, newSeed ) =
            Random.step (Random.int 0 1) seed
    in
    if bit == 0 then
        ( -1, newSeed )

    else
        ( 1, newSeed )


{-| Remove projectiles that have exceeded their lifetime.

Uses per-projectile VenomType.maxLifetime instead of a fixed constant.
-}
removeExpired : Int -> List Projectile -> List Projectile
removeExpired currentTick projectiles =
    List.filter (\p -> (currentTick - p.spawnedAtTick) < VenomType.maxLifetime p.venomType) projectiles


{-| Get the movement path for a projectile (2 cells in direction).

Returns ( [intermediate, final] positions, updatedSeed ) for path-aware hit detection.
For standard venom, seed is returned unchanged.
For ball venom, seed is consumed for bounce randomization.
-}
getMovementPath : { width : Int, height : Int } -> Random.Seed -> Projectile -> ( List Position, Random.Seed )
getMovementPath grid seed projectile =
    case projectile.venomType of
        StandardVenom ->
            let
                pos1 =
                    Grid.nextPosition projectile.position projectile.direction
                        |> (\p -> Grid.wrapPosition p grid)

                pos2 =
                    Grid.nextPosition pos1 projectile.direction
                        |> (\p -> Grid.wrapPosition p grid)
            in
            ( [ pos1, pos2 ], seed )

        BallVenom ->
            let
                -- Step 1
                ( proj1, seed1 ) =
                    moveBallOneStep grid seed projectile

                pos1 =
                    proj1.position

                -- Step 2
                ( proj2, seed2 ) =
                    moveBallOneStep grid seed1 proj1

                pos2 =
                    proj2.position
            in
            ( [ pos1, pos2 ], seed2 )
