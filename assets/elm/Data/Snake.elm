module Data.Snake
    exposing
        ( Snake
        , id
        , setId
        , setPlayer
        , colour
        , initialSnake
        , moveSnake
        , growSnake
        , eatApples
        , changeSnakeDirection
        )

import Data.Direction exposing (Direction(..))
import Data.Position exposing (Position, gridDimensions, nextPositionInDirection)
import Data.Apple exposing (Apple, eatApplesAt)
import Data.Player as Player exposing (Player, PlayerId, PlayerColour)


type alias Snake =
    { player : Player
    , direction : Direction
    , body : List Position
    }


colour : Snake -> PlayerColour
colour { player } =
    Player.colour player


id : Snake -> PlayerId
id { player } =
    Player.id player


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
        { player = Player.init
        , body =
            [ initialSegment
            , subsequentSegment
            , lastSegment
            ]
        , direction = initialDirection
        }


setPlayer : Player -> Snake -> Snake
setPlayer player snake =
    { snake | player = player }


setId : PlayerId -> Snake -> Snake
setId id snake =
    let
        player =
            Player.init
                |> Player.setId id
    in
        snake
            |> setPlayer player


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


changeSnakeDirection : Direction -> Snake -> Snake
changeSnakeDirection newDirection originalSnake =
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
