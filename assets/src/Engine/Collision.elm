module Engine.Collision exposing
    ( collidesWithSelf
    , collidesWithOther
    , findCollisionIndex
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


{-| Find the index of a position in a body list.

Returns the first matching index, or Nothing if no match.
Used for projectile hit detection to find where to truncate.
-}
findCollisionIndex : Position -> List Position -> Maybe Int
findCollisionIndex pos body =
    findCollisionIndexHelper pos body 0


findCollisionIndexHelper : Position -> List Position -> Int -> Maybe Int
findCollisionIndexHelper pos body index =
    case body of
        [] ->
            Nothing

        segment :: rest ->
            if segment == pos then
                Just index

            else
                findCollisionIndexHelper pos rest (index + 1)
