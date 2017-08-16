module Data.Snake exposing (Snake, initialSnake, moveSnake, growSnake, eatApples, changeSnakeDirection)

import Data.Direction exposing (Direction(..))
import Data.Position exposing (Position, gridDimensions, nextPositionInDirection)
import Data.Apple exposing (Apple, eatApplesAt)


type alias Snake =
    { direction : Direction
    , body : List Position
    }


initialSnake : Snake
initialSnake =
    let
        initialDirection =
            East

        tailDirection =
            West

        x =
            gridDimensions.x // 2

        y =
            gridDimensions.y // 2

        initialSegment =
            { x = x, y = y }

        subsequentSegment =
            nextPositionInDirection tailDirection initialSegment

        lastSegment =
            nextPositionInDirection tailDirection subsequentSegment
    in
        { body =
            [ initialSegment
            , subsequentSegment
            , lastSegment
            ]
        , direction = initialDirection
        }


moveSnake : Snake -> Snake
moveSnake ({ body, direction } as snake) =
    case body of
        [] ->
            snake

        snakeHead :: snakeBody ->
            let
                newHead =
                    nextPositionInDirection direction snakeHead

                newBody =
                    newHead :: (List.take (List.length body - 1) body)
            in
                { snake | body = newBody }


growSnake : List Apple -> Snake -> Snake
growSnake apples ({ body, direction } as snake) =
    case body of
        [] ->
            snake

        snakeHead :: _ ->
            if List.member snakeHead (List.map .position apples) then
                { snake | body = nextPositionInDirection direction snakeHead :: body }
            else
                snake


eatApples : Snake -> List Apple -> List Apple
eatApples { body } apples =
    case body of
        [] ->
            apples

        snakeHead :: _ ->
            eatApplesAt snakeHead apples


changeSnakeDirection : Snake -> Direction -> Snake
changeSnakeDirection originalSnake newDirection =
    let
        changedDirection =
            case ( originalSnake.direction, newDirection ) of
                ( North, South ) ->
                    North

                ( South, North ) ->
                    South

                ( East, West ) ->
                    East

                ( West, East ) ->
                    West

                _ ->
                    newDirection
    in
        { originalSnake | direction = changedDirection }