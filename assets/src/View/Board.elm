module View.Board exposing (view, viewWithLeader, viewWithTick, viewWithTickAndLeader)

import Engine.Apple as Apple
import Game exposing (GameState)
import Html exposing (Html)
import Html.Attributes
import Svg.Keyed
import Snake exposing (Position, Snake)
import Svg exposing (Svg, circle, g, line, rect, svg, text_)
import Svg.Attributes as SA


cellSize : Int
cellSize =
    15


{-| Apple representation for rendering with aging info.
-}
type alias RenderApple =
    { position : Position
    , spawnedAtTick : Int
    }


{-| Safari has a bug where setting className property on SVG elements fails
because SVGAnimatedString is readonly. Use setAttribute via `attribute` instead.
-}
svgClass : String -> Svg.Attribute msg
svgClass name =
    Html.Attributes.attribute "class" name


{-| Render the game board with snakes and apples (legacy, no aging).
-}
view : { a | snakes : List Snake, apples : List { position : Position }, gridWidth : Int, gridHeight : Int } -> Maybe String -> Html msg
view gameState maybePlayerId =
    viewWithLeader gameState maybePlayerId Nothing


{-| Render the game board with leader indicator (pulsing head on highest scorer).
    Uses extensible record types to accept any record with required fields.
-}
viewWithLeader : { a | snakes : List Snake, apples : List { position : Position }, gridWidth : Int, gridHeight : Int } -> Maybe String -> Maybe String -> Html msg
viewWithLeader gameState maybePlayerId maybeLeaderId =
    let
        width =
            gameState.gridWidth * cellSize

        height =
            gameState.gridHeight * cellSize
    in
    svg
        [ SA.viewBox ("0 0 " ++ String.fromInt width ++ " " ++ String.fromInt height)
        , svgClass "game-board"
        ]
        [ background width height
        , renderApplesSimple gameState.apples
        , renderSnakes gameState.snakes maybePlayerId maybeLeaderId Nothing
        ]


{-| Render the game board with tick for apple aging.
-}
viewWithTick : { a | snakes : List Snake, apples : List { position : Position, spawnedAtTick : Int }, gridWidth : Int, gridHeight : Int, currentTick : Int, penaltyState : Maybe Snake.PenaltyState } -> Maybe String -> Html msg
viewWithTick gameState maybePlayerId =
    let
        width =
            gameState.gridWidth * cellSize

        height =
            gameState.gridHeight * cellSize
    in
    svg
        [ SA.viewBox ("0 0 " ++ String.fromInt width ++ " " ++ String.fromInt height)
        , svgClass "game-board"
        ]
        [ background width height
        , renderApples gameState.currentTick gameState.apples
        , renderSnakes gameState.snakes maybePlayerId Nothing gameState.penaltyState
        ]


{-| Render the game board with tick for apple aging and leader indicator.
-}
viewWithTickAndLeader : { a | snakes : List Snake, apples : List { position : Position, spawnedAtTick : Int }, gridWidth : Int, gridHeight : Int, currentTick : Int } -> Maybe String -> Maybe String -> Html msg
viewWithTickAndLeader gameState maybePlayerId maybeLeaderId =
    let
        width =
            gameState.gridWidth * cellSize

        height =
            gameState.gridHeight * cellSize
    in
    svg
        [ SA.viewBox ("0 0 " ++ String.fromInt width ++ " " ++ String.fromInt height)
        , svgClass "game-board"
        ]
        [ background width height
        , renderApples gameState.currentTick gameState.apples
        , renderSnakes gameState.snakes maybePlayerId maybeLeaderId Nothing
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


{-| Render apples with aging (uses currentTick).
-}
renderApples : Int -> List { position : Position, spawnedAtTick : Int } -> Svg msg
renderApples currentTick apples =
    g [ svgClass "apples" ]
        (List.map (renderApple currentTick) apples)


{-| Render apples without aging (legacy).
-}
renderApplesSimple : List { position : Position } -> Svg msg
renderApplesSimple apples =
    g [ svgClass "apples" ]
        (List.map renderAppleSimple apples)


{-| Render a simple apple (no aging, red color).
-}
renderAppleSimple : { position : Position } -> Svg msg
renderAppleSimple apple =
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


{-| Render an apple with aging color based on stage.
-}
renderApple : Int -> { position : Position, spawnedAtTick : Int } -> Svg msg
renderApple currentTick apple =
    let
        -- Create Apple record for getStage
        appleRecord =
            { position = apple.position
            , spawnedAtTick = apple.spawnedAtTick
            }

        stage =
            Apple.getStage currentTick appleRecord

        cx_ =
            apple.position.x * cellSize + cellSize // 2

        cy_ =
            apple.position.y * cellSize + cellSize // 2

        radius =
            cellSize // 2 - 2
    in
    case stage of
        Apple.Skull ->
            renderSkull cx_ cy_ radius

        _ ->
            renderNormalApple stage cx_ cy_ radius


{-| Get color for apple stage.
-}
stageColor : Apple.AppleStage -> String
stageColor stage =
    case stage of
        Apple.Fresh ->
            "#4ade80"  -- Green

        Apple.Aging ->
            "#facc15"  -- Yellow

        Apple.Old ->
            "#ef4444"  -- Red

        Apple.Expiring ->
            "#ef4444"  -- Red (with pulse animation via CSS)

        Apple.Skull ->
            "#ffffff"  -- White


{-| Render a normal apple (Fresh, Aging, Old, Expiring).
-}
renderNormalApple : Apple.AppleStage -> Int -> Int -> Int -> Svg msg
renderNormalApple stage cx_ cy_ radius =
    let
        color =
            stageColor stage

        classes =
            case stage of
                Apple.Expiring ->
                    "apple apple-expiring"

                _ ->
                    "apple"
    in
    g []
        [ circle
            [ SA.cx (String.fromInt cx_)
            , SA.cy (String.fromInt cy_)
            , SA.r (String.fromInt radius)
            , SA.fill color
            , svgClass classes
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


{-| Render a skull (expired apple).
-}
renderSkull : Int -> Int -> Int -> Svg msg
renderSkull cx_ cy_ radius =
    let
        eyeRadius =
            2

        eyeOffsetX =
            3

        eyeOffsetY =
            2

        -- Teeth: small rectangles at the bottom
        teethY =
            cy_ + 3
    in
    g [ svgClass "apple apple-skull" ]
        [ -- Skull head (white circle)
          circle
            [ SA.cx (String.fromInt cx_)
            , SA.cy (String.fromInt cy_)
            , SA.r (String.fromInt radius)
            , SA.fill "#ffffff"
            ]
            []
        , -- Left eye (black circle)
          circle
            [ SA.cx (String.fromInt (cx_ - eyeOffsetX))
            , SA.cy (String.fromInt (cy_ - eyeOffsetY))
            , SA.r (String.fromInt eyeRadius)
            , SA.fill "#000000"
            ]
            []
        , -- Right eye (black circle)
          circle
            [ SA.cx (String.fromInt (cx_ + eyeOffsetX))
            , SA.cy (String.fromInt (cy_ - eyeOffsetY))
            , SA.r (String.fromInt eyeRadius)
            , SA.fill "#000000"
            ]
            []
        , -- Nose (small triangle approximated by a line)
          line
            [ SA.x1 (String.fromInt cx_)
            , SA.y1 (String.fromInt cy_)
            , SA.x2 (String.fromInt cx_)
            , SA.y2 (String.fromInt (cy_ + 2))
            , SA.stroke "#000000"
            , SA.strokeWidth "1"
            ]
            []
        , -- Teeth (horizontal line with gaps)
          line
            [ SA.x1 (String.fromInt (cx_ - 4))
            , SA.y1 (String.fromInt teethY)
            , SA.x2 (String.fromInt (cx_ + 4))
            , SA.y2 (String.fromInt teethY)
            , SA.stroke "#000000"
            , SA.strokeWidth "1"
            ]
            []
        ]


renderSnakes : List Snake -> Maybe String -> Maybe String -> Maybe Snake.PenaltyState -> Svg msg
renderSnakes snakes maybePlayerId maybeLeaderId maybePenalty =
    Svg.Keyed.node "g"
        [ svgClass "snakes" ]
        (List.map (keyedSnake maybePlayerId maybeLeaderId maybePenalty) snakes)


keyedSnake : Maybe String -> Maybe String -> Maybe Snake.PenaltyState -> Snake -> ( String, Svg msg )
keyedSnake maybePlayerId maybeLeaderId maybePenalty snake =
    ( snake.id, renderSnake snake maybePlayerId maybeLeaderId maybePenalty )


renderSnake : Snake -> Maybe String -> Maybe String -> Maybe Snake.PenaltyState -> Svg msg
renderSnake snake maybePlayerId maybeLeaderId maybePenalty =
    let
        isYou =
            Just snake.id == maybePlayerId

        isLeader =
            Just snake.id == maybeLeaderId

        isOrphaned =
            snake.state == "orphaned"

        -- Check if we're in penalty animation (only for "you" snake)
        isPenalizing =
            isYou && maybePenalty /= Nothing

        -- Should we show jitter? (flash phases 4-5)
        showJitter =
            case maybePenalty of
                Just penalty ->
                    isYou && penalty.flashPhase >= 4

                Nothing ->
                    False

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
            , if isPenalizing then
                "penalty-active"

              else
                ""
            , if showJitter then
                "penalty-jitter"

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

        -- Calculate doomed segments for penalty visualization
        doomedCount =
            case maybePenalty of
                Just penalty ->
                    if isYou then
                        penalty.segmentsToRemove

                    else
                        0

                Nothing ->
                    0
    in
    g [ svgClass classes, colorStyle, opacityAttr ]
        (renderSnakeBodyWithPenalty snake isLeader doomedCount)


renderSnakeBody : Snake -> Bool -> List (Svg msg)
renderSnakeBody snake isLeader =
    renderSnakeBodyWithPenalty snake isLeader 0


{-| Render snake body with penalty visualization.
    doomedCount indicates how many segments from the tail should be highlighted.
-}
renderSnakeBodyWithPenalty : Snake -> Bool -> Int -> List (Svg msg)
renderSnakeBodyWithPenalty snake isLeader doomedCount =
    case snake.body of
        [] ->
            []

        headPos :: tailPositions ->
            let
                totalSegments =
                    List.length tailPositions

                -- Calculate which segments are doomed (from the tail)
                doomedStartIndex =
                    totalSegments - doomedCount
            in
            renderSnakeHead snake headPos isLeader
                :: List.indexedMap (renderBodySegmentWithPenalty snake doomedStartIndex) tailPositions


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


{-| Render a body segment, checking if it's doomed.
-}
renderBodySegmentWithPenalty : Snake -> Int -> Int -> Position -> Svg msg
renderBodySegmentWithPenalty snake doomedStartIndex index pos =
    let
        cx_ =
            pos.x * cellSize + cellSize // 2

        cy_ =
            pos.y * cellSize + cellSize // 2

        segmentRadius =
            cellSize // 2 - 2

        isDoomed =
            index >= doomedStartIndex

        segmentClass =
            if isDoomed then
                "snake-segment penalty-doomed"

            else
                "snake-segment"
    in
    circle
        [ SA.cx (String.fromInt cx_)
        , SA.cy (String.fromInt cy_)
        , SA.r (String.fromInt segmentRadius)
        , SA.fill ("#" ++ snake.color)
        , svgClass segmentClass
        ]
        []


renderBodySegment : Snake -> Int -> Position -> Svg msg
renderBodySegment snake index pos =
    renderBodySegmentWithPenalty snake 99999 index pos
