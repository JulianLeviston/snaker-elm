module Data.Position
    exposing
        ( Position
        , randomPosition
        , wrapPosition
        , Dimensions
        , gridDimensions
        , nextPositionInDirection
        )

import Random exposing (Generator)
import Data.Direction exposing (Direction(..))


-- General Utils


wrapVal : Int -> Int -> Int -> Int
wrapVal minVal maxVal val =
    if (max val (maxVal + 1)) == val then
        minVal
    else if (min val (minVal - 1)) == val then
        maxVal
    else
        val



-- Positions


type alias Position =
    { x : Int, y : Int }


nextPositionInDirection : Direction -> Position -> Position
nextPositionInDirection direction { x, y } =
    wrapPosition <|
        case direction of
            North ->
                { x = x, y = y + 1 }

            East ->
                { x = x + 1, y = y }

            West ->
                { x = x - 1, y = y }

            South ->
                { x = x, y = y - 1 }


randomPosition : Generator Position
randomPosition =
    Random.map2
        (\x y -> { x = x, y = y })
        (Random.int 1 gridDimensions.x)
        (Random.int 1 gridDimensions.y)


wrapPosition : Position -> Position
wrapPosition { x, y } =
    let
        newX =
            wrapVal 1 (gridDimensions.x + 0) x

        newY =
            wrapVal 1 (gridDimensions.y + 0) y
    in
        { x = newX, y = newY }



-- Dimensions


type alias Dimensions =
    { x : Int, y : Int }


gridDimensions : Dimensions
gridDimensions =
    { x = 40, y = 30 }
