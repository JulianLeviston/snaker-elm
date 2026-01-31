module View.Scoreboard exposing (view)

import Html exposing (Html, div, h3, span, text)
import Html.Attributes exposing (class, style)
import Snake exposing (Snake)


view : List Snake -> Maybe String -> Html msg
view snakes maybePlayerId =
    let
        sortedSnakes =
            List.sortBy (\s -> negate (List.length s.body)) snakes
    in
    div [ class "scoreboard" ]
        [ h3 [] [ text "Leaderboard" ]
        , div [ class "player-list" ]
            (List.map (renderPlayerEntry maybePlayerId) sortedSnakes)
        ]


renderPlayerEntry : Maybe String -> Snake -> Html msg
renderPlayerEntry maybePlayerId snake =
    let
        isYou =
            Just snake.id == maybePlayerId

        score =
            List.length snake.body

        displayName =
            if isYou then
                snake.name ++ " (You)"

            else
                snake.name
    in
    div [ class "player-entry" ]
        [ div
            [ class "player-color"
            , style "background-color" ("#" ++ snake.color)
            ]
            []
        , span [ class "player-name" ] [ text displayName ]
        , span [ class "player-score" ] [ text (String.fromInt score) ]
        ]
