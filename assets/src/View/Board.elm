module View.Board exposing (view)

import Game exposing (Apple, GameState)
import Html exposing (Html)
import Html.Attributes
import Html.Keyed
import Snake exposing (Position, Snake)
import Svg exposing (Svg, circle, g, rect, svg, text_)
import Svg.Attributes exposing (..)


cellSize : Int
cellSize =
    20


view : GameState -> Maybe String -> Html msg
view gameState maybePlayerId =
    let
        width =
            gameState.gridWidth * cellSize

        height =
            gameState.gridHeight * cellSize
    in
    svg
        [ Svg.Attributes.width (String.fromInt width)
        , Svg.Attributes.height (String.fromInt height)
        , viewBox ("0 0 " ++ String.fromInt width ++ " " ++ String.fromInt height)
        , Html.Attributes.class "game-board"
        ]
        [ background width height
        , renderApples gameState.apples
        , renderSnakes gameState.snakes maybePlayerId
        ]


background : Int -> Int -> Svg msg
background width height =
    rect
        [ x "0"
        , y "0"
        , Svg.Attributes.width (String.fromInt width)
        , Svg.Attributes.height (String.fromInt height)
        , fill "#1a1a2e"
        ]
        []


renderApples : List Apple -> Svg msg
renderApples apples =
    g [ class "apples" ]
        (List.map renderApple apples)


renderApple : Apple -> Svg msg
renderApple apple =
    let
        cx_ =
            apple.position.x * cellSize + cellSize // 2

        cy_ =
            apple.position.y * cellSize + cellSize // 2
    in
    g []
        [ circle
            [ cx (String.fromInt cx_)
            , cy (String.fromInt cy_)
            , r (String.fromInt (cellSize // 2 - 2))
            , fill "#ff6b6b"
            , class "apple"
            ]
            []
        , text_
            [ x (String.fromInt cx_)
            , y (String.fromInt (cy_ + 4))
            , textAnchor "middle"
            , fontSize "14"
            ]
            [ Svg.text "+" ]
        ]


renderSnakes : List Snake -> Maybe String -> Svg msg
renderSnakes snakes maybePlayerId =
    Html.Keyed.node "g"
        [ class "snakes" ]
        (List.map (keyedSnake maybePlayerId) snakes)


keyedSnake : Maybe String -> Snake -> ( String, Svg msg )
keyedSnake maybePlayerId snake =
    ( snake.id, renderSnake snake maybePlayerId )


renderSnake : Snake -> Maybe String -> Svg msg
renderSnake snake maybePlayerId =
    let
        isYou =
            Just snake.id == maybePlayerId

        classes =
            [ "snake"
            , if snake.isInvincible then
                "invincible"

              else
                ""
            , if snake.state == "dying" then
                "dying"

              else
                ""
            , if isYou then
                "you"

              else
                ""
            ]
                |> List.filter (not << String.isEmpty)
                |> String.join " "
    in
    g [ class classes ]
        (renderSnakeBody snake)


renderSnakeBody : Snake -> List (Svg msg)
renderSnakeBody snake =
    case snake.body of
        [] ->
            []

        headPos :: tailPositions ->
            renderSnakeHead snake headPos
                :: List.indexedMap (renderBodySegment snake) tailPositions


renderSnakeHead : Snake -> Position -> Svg msg
renderSnakeHead snake pos =
    let
        cx_ =
            pos.x * cellSize + cellSize // 2

        cy_ =
            pos.y * cellSize + cellSize // 2

        headRadius =
            cellSize // 2

        eyeOffset =
            4

        eyeRadius =
            2

        ( eyeX1, eyeX2, eyeY1, eyeY2 ) =
            case snake.direction of
                Snake.Up ->
                    ( cx_ - eyeOffset, cx_ + eyeOffset, cy_ - eyeOffset, cy_ - eyeOffset )

                Snake.Down ->
                    ( cx_ - eyeOffset, cx_ + eyeOffset, cy_ + eyeOffset, cy_ + eyeOffset )

                Snake.Left ->
                    ( cx_ - eyeOffset, cx_ - eyeOffset, cy_ - eyeOffset, cy_ + eyeOffset )

                Snake.Right ->
                    ( cx_ + eyeOffset, cx_ + eyeOffset, cy_ - eyeOffset, cy_ + eyeOffset )
    in
    g [ class "snake-head" ]
        [ circle
            [ cx (String.fromInt cx_)
            , cy (String.fromInt cy_)
            , r (String.fromInt headRadius)
            , fill ("#" ++ snake.color)
            ]
            []
        , circle
            [ cx (String.fromInt eyeX1)
            , cy (String.fromInt eyeY1)
            , r (String.fromInt eyeRadius)
            , fill "#ffffff"
            ]
            []
        , circle
            [ cx (String.fromInt eyeX2)
            , cy (String.fromInt eyeY2)
            , r (String.fromInt eyeRadius)
            , fill "#ffffff"
            ]
            []
        ]


renderBodySegment : Snake -> Int -> Position -> Svg msg
renderBodySegment snake index pos =
    let
        cx_ =
            pos.x * cellSize + cellSize // 2

        cy_ =
            pos.y * cellSize + cellSize // 2

        segmentRadius =
            cellSize // 2 - 2
    in
    circle
        [ cx (String.fromInt cx_)
        , cy (String.fromInt cy_)
        , r (String.fromInt segmentRadius)
        , fill ("#" ++ snake.color)
        , class "snake-segment"
        ]
        []
