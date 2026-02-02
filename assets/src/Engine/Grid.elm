module Engine.Grid exposing
    ( wrapPosition
    , nextPosition
    , defaultDimensions
    )

{-| Grid utilities for position wrapping and movement.

Mirrors Elixir Snaker.Game.Grid behavior.
-}

import Snake exposing (Direction(..), Position)


{-| Default grid dimensions matching Elixir server.
-}
defaultDimensions : { width : Int, height : Int }
defaultDimensions =
    { width = 30, height = 40 }


{-| Wrap a position around grid edges.

Uses `modBy` with pre-addition to handle negative values correctly:
-1 wraps to width-1 (or height-1), width wraps to 0, etc.
-}
wrapPosition : Position -> { width : Int, height : Int } -> Position
wrapPosition pos grid =
    { x = modBy grid.width (pos.x + grid.width)
    , y = modBy grid.height (pos.y + grid.height)
    }


{-| Calculate the next position in a given direction.

Does NOT wrap - caller should apply wrapPosition after.

Coordinate system:
- x increases to the right
- y increases downward (standard screen coordinates)
-}
nextPosition : Position -> Direction -> Position
nextPosition pos direction =
    case direction of
        Up ->
            { pos | y = pos.y - 1 }

        Down ->
            { pos | y = pos.y + 1 }

        Left ->
            { pos | x = pos.x - 1 }

        Right ->
            { pos | x = pos.x + 1 }
