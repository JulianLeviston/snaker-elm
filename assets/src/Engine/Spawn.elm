module Engine.Spawn exposing
    ( spawnAppleCommands
    , randomPosition
    )

import Engine.Apple as Apple
import Random
import Snake exposing (Position)


{-| Generate commands to spawn multiple apples with a custom message constructor.
The provided constructor will be called for each spawned apple position.
-}
spawnAppleCommands : (Position -> msg) -> Int -> List Position -> { width : Int, height : Int } -> Cmd msg
spawnAppleCommands toMsg count occupied grid =
    if count <= 0 then
        Cmd.none

    else
        List.range 1 count
            |> List.map (\_ -> Random.generate toMsg (Apple.randomSafePosition occupied grid))
            |> Cmd.batch


{-| Generate a random position within grid bounds.
-}
randomPosition : { width : Int, height : Int } -> Random.Generator Position
randomPosition grid =
    Random.map2 Position
        (Random.int 2 (grid.width - 1))
        (Random.int 0 (grid.height - 1))
