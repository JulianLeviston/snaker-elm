module Engine.Collision exposing
    ( collidesWithSelf
    , collidesWithOther
    )

{-| Collision detection for snakes.

Mirrors Elixir Snaker.Game.Snake collision logic.
-}

import Snake exposing (Position)


{-| Check if a snake collides with itself.

Takes the snake body as a list of positions (head first).
Returns True if the head is in the tail.
-}
collidesWithSelf : List Position -> Bool
collidesWithSelf body =
    case body of
        [] ->
            False

        [ _ ] ->
            -- Single segment cannot collide with itself
            False

        head :: tail ->
            List.member head tail


{-| Check if a position collides with any position in a list.

Used for multi-snake collision detection.
-}
collidesWithOther : Position -> List Position -> Bool
collidesWithOther pos otherPositions =
    List.member pos otherPositions
