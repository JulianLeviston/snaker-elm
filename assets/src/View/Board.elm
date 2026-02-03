module View.Board exposing (view, viewWithHostIndicator)

import Game exposing (Apple, GameState)
import Html exposing (Html)
import Html.Attributes
import Svg.Keyed
import Snake exposing (Position, Snake)
import Svg exposing (Svg, circle, g, path, rect, svg, text_)
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


{-| Render the game board with snakes, apples, and optional host indicator.
    maybeHostId is used to show a crown on the host's snake.
-}
view : { a | snakes : List Snake, apples : List Apple, gridWidth : Int, gridHeight : Int } -> Maybe String -> Html msg
view gameState maybePlayerId =
    viewWithHostIndicator gameState maybePlayerId Nothing


{-| Render the game board with explicit host indicator.
    Uses extensible record types to accept any record with required fields.
-}
viewWithHostIndicator : { a | snakes : List Snake, apples : List Apple, gridWidth : Int, gridHeight : Int } -> Maybe String -> Maybe String -> Html msg
viewWithHostIndicator gameState maybePlayerId maybeHostId =
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
        , renderSnakes gameState.snakes maybePlayerId maybeHostId
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
renderSnakes snakes maybePlayerId maybeHostId =
    Svg.Keyed.node "g"
        [ svgClass "snakes" ]
        (List.map (keyedSnake maybePlayerId maybeHostId) snakes)


keyedSnake : Maybe String -> Maybe String -> Snake -> ( String, Svg msg )
keyedSnake maybePlayerId maybeHostId snake =
    ( snake.id, renderSnake snake maybePlayerId maybeHostId )


renderSnake : Snake -> Maybe String -> Maybe String -> Svg msg
renderSnake snake maybePlayerId maybeHostId =
    let
        isYou =
            Just snake.id == maybePlayerId

        isHost =
            Just snake.id == maybeHostId

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
            , if snake.state == "orphaned" then
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
    in
    g [ svgClass classes, colorStyle ]
        (renderSnakeBody snake isHost)


renderSnakeBody : Snake -> Bool -> List (Svg msg)
renderSnakeBody snake isHost =
    case snake.body of
        [] ->
            []

        headPos :: tailPositions ->
            renderSnakeHead snake headPos isHost
                :: List.indexedMap (renderBodySegment snake) tailPositions


renderSnakeHead : Snake -> Position -> Bool -> Svg msg
renderSnakeHead snake pos isHost =
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

        headElements =
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

        -- Add crown if this is the host
        elementsWithCrown =
            if isHost then
                headElements ++ [ renderHostCrown cx_ cy_ ]

            else
                headElements
    in
    g [ svgClass "snake-head" ] elementsWithCrown


{-| Render a small crown icon to indicate the host's snake.
    Crown is positioned above and to the right of the snake head.
-}
renderHostCrown : Int -> Int -> Svg msg
renderHostCrown headCx headCy =
    let
        -- Position crown above and to the right of head
        crownX =
            headCx + 8

        crownY =
            headCy - 12

        -- Scale factor for the crown (make it small)
        scale =
            0.8

        -- Crown path: M 0 8 L 4 0 L 8 8 L 6.5 5 L 4 7 L 1.5 5 Z
        -- Scaled and translated
        crownPath =
            "M " ++ String.fromFloat (toFloat crownX - 4 * scale) ++ " " ++ String.fromFloat (toFloat crownY + 8 * scale)
                ++ " L " ++ String.fromFloat (toFloat crownX) ++ " " ++ String.fromFloat (toFloat crownY)
                ++ " L " ++ String.fromFloat (toFloat crownX + 4 * scale) ++ " " ++ String.fromFloat (toFloat crownY + 8 * scale)
                ++ " L " ++ String.fromFloat (toFloat crownX + 2.5 * scale) ++ " " ++ String.fromFloat (toFloat crownY + 5 * scale)
                ++ " L " ++ String.fromFloat (toFloat crownX) ++ " " ++ String.fromFloat (toFloat crownY + 7 * scale)
                ++ " L " ++ String.fromFloat (toFloat crownX - 2.5 * scale) ++ " " ++ String.fromFloat (toFloat crownY + 5 * scale)
                ++ " Z"
    in
    Svg.path
        [ SA.d crownPath
        , SA.fill "#FFD700"
        , SA.stroke "#000000"
        , SA.strokeWidth "0.5"
        , svgClass "host-indicator"
        ]
        []


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
