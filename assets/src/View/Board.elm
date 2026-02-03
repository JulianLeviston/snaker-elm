module View.Board exposing (view, viewWithLeader)

import Game exposing (Apple, GameState)
import Html exposing (Html)
import Html.Attributes
import Svg.Keyed
import Snake exposing (Position, Snake)
import Svg exposing (Svg, circle, g, rect, svg, text_)
import Svg.Attributes as SA


cellSize : Int
cellSize =
    15


{-| Safari has a bug where setting className property on SVG elements fails
because SVGAnimatedString is readonly. Use setAttribute via `attribute` instead.
-}
svgClass : String -> Svg.Attribute msg
svgClass name =
    Html.Attributes.attribute "class" name


{-| Render the game board with snakes and apples.
-}
view : { a | snakes : List Snake, apples : List Apple, gridWidth : Int, gridHeight : Int } -> Maybe String -> Html msg
view gameState maybePlayerId =
    viewWithLeader gameState maybePlayerId Nothing


{-| Render the game board with leader indicator (pulsing head on highest scorer).
    Uses extensible record types to accept any record with required fields.
-}
viewWithLeader : { a | snakes : List Snake, apples : List Apple, gridWidth : Int, gridHeight : Int } -> Maybe String -> Maybe String -> Html msg
viewWithLeader gameState maybePlayerId maybeLeaderId =
    let
        width =
            gameState.gridWidth * cellSize

        height =
            gameState.gridHeight * cellSize
    in
    svg
        [ SA.width (String.fromInt width)
        , SA.height (String.fromInt height)
        , SA.viewBox ("0 0 " ++ String.fromInt width ++ " " ++ String.fromInt height)
        , svgClass "game-board"
        ]
        [ background width height
        , renderApples gameState.apples
        , renderSnakes gameState.snakes maybePlayerId maybeLeaderId
        ]


background : Int -> Int -> Svg msg
background width height =
    rect
        [ SA.x "0"
        , SA.y "0"
        , SA.width (String.fromInt width)
        , SA.height (String.fromInt height)
        , SA.fill "#1a1a2e"
        ]
        []


renderApples : List Apple -> Svg msg
renderApples apples =
    g [ svgClass "apples" ]
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
            [ SA.cx (String.fromInt cx_)
            , SA.cy (String.fromInt cy_)
            , SA.r (String.fromInt (cellSize // 2 - 2))
            , SA.fill "#ff6b6b"
            , svgClass "apple"
            ]
            []
        , text_
            [ SA.x (String.fromInt cx_)
            , SA.y (String.fromInt (cy_ + 4))
            , SA.textAnchor "middle"
            , SA.fontSize "14"
            ]
            [ Svg.text "+" ]
        ]


renderSnakes : List Snake -> Maybe String -> Maybe String -> Svg msg
renderSnakes snakes maybePlayerId maybeLeaderId =
    Svg.Keyed.node "g"
        [ svgClass "snakes" ]
        (List.map (keyedSnake maybePlayerId maybeLeaderId) snakes)


keyedSnake : Maybe String -> Maybe String -> Snake -> ( String, Svg msg )
keyedSnake maybePlayerId maybeLeaderId snake =
    ( snake.id, renderSnake snake maybePlayerId maybeLeaderId )


renderSnake : Snake -> Maybe String -> Maybe String -> Svg msg
renderSnake snake maybePlayerId maybeLeaderId =
    let
        isYou =
            Just snake.id == maybePlayerId

        isLeader =
            Just snake.id == maybeLeaderId

        isOrphaned =
            snake.state == "orphaned"

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
            , if isOrphaned then
                "orphaned"

              else
                ""
            , if isYou then
                "you"

              else
                ""
            ]
                |> List.filter (not << String.isEmpty)
                |> String.join " "

        -- Set CSS color property to snake color for currentColor in drop-shadow filters
        colorStyle =
            SA.style ("color: #" ++ snake.color)

        -- Apply SVG opacity directly for orphaned snakes (CSS opacity doesn't work well on SVG groups)
        opacityAttr =
            if isOrphaned then
                SA.opacity "0.5"

            else
                SA.opacity "1"
    in
    g [ svgClass classes, colorStyle, opacityAttr ]
        (renderSnakeBody snake isLeader)


renderSnakeBody : Snake -> Bool -> List (Svg msg)
renderSnakeBody snake isLeader =
    case snake.body of
        [] ->
            []

        headPos :: tailPositions ->
            renderSnakeHead snake headPos isLeader
                :: List.indexedMap (renderBodySegment snake) tailPositions


renderSnakeHead : Snake -> Position -> Bool -> Svg msg
renderSnakeHead snake pos isLeader =
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

        ( eyeX1, eyeY1 ) =
            case snake.direction of
                Snake.Up ->
                    ( cx_ - eyeOffset, cy_ - eyeOffset )

                Snake.Down ->
                    ( cx_ - eyeOffset, cy_ + eyeOffset )

                Snake.Left ->
                    ( cx_ - eyeOffset, cy_ - eyeOffset )

                Snake.Right ->
                    ( cx_ + eyeOffset, cy_ - eyeOffset )

        ( eyeX2, eyeY2 ) =
            case snake.direction of
                Snake.Up ->
                    ( cx_ + eyeOffset, cy_ - eyeOffset )

                Snake.Down ->
                    ( cx_ + eyeOffset, cy_ + eyeOffset )

                Snake.Left ->
                    ( cx_ - eyeOffset, cy_ + eyeOffset )

                Snake.Right ->
                    ( cx_ + eyeOffset, cy_ + eyeOffset )

        -- Add leader-head class if this is the leader for pulsing animation
        headClass =
            if isLeader then
                "snake-head leader-head"

            else
                "snake-head"
    in
    g [ svgClass headClass ]
        [ circle
            [ SA.cx (String.fromInt cx_)
            , SA.cy (String.fromInt cy_)
            , SA.r (String.fromInt headRadius)
            , SA.fill ("#" ++ snake.color)
            ]
            []
        , circle
            [ SA.cx (String.fromInt eyeX1)
            , SA.cy (String.fromInt eyeY1)
            , SA.r (String.fromInt eyeRadius)
            , SA.fill "#ffffff"
            ]
            []
        , circle
            [ SA.cx (String.fromInt eyeX2)
            , SA.cy (String.fromInt eyeY2)
            , SA.r (String.fromInt eyeRadius)
            , SA.fill "#ffffff"
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
        [ SA.cx (String.fromInt cx_)
        , SA.cy (String.fromInt cy_)
        , SA.r (String.fromInt segmentRadius)
        , SA.fill ("#" ++ snake.color)
        , svgClass "snake-segment"
        ]
        []
