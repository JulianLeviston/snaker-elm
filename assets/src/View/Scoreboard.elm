module View.Scoreboard exposing (view)

import Dict exposing (Dict)
import Html exposing (Html, div, h3, span, text)
import Html.Attributes exposing (class, style)
import Snake exposing (Snake)


view : List Snake -> Dict String Int -> Maybe String -> Html msg
view snakes scores maybePlayerId =
    let
        -- Sort by score (from scores dict), falling back to 0
        sortedSnakes =
            List.sortBy (\s -> negate (Dict.get s.id scores |> Maybe.withDefault 0)) snakes
    in
    div [ class "scoreboard" ]
        [ h3 [] [ text "Leaderboard" ]
        , div [ class "player-list" ]
            (List.map (renderPlayerEntry scores maybePlayerId) sortedSnakes)
        ]


renderPlayerEntry : Dict String Int -> Maybe String -> Snake -> Html msg
renderPlayerEntry scores maybePlayerId snake =
    let
        isYou =
            Just snake.id == maybePlayerId

        score =
            Dict.get snake.id scores |> Maybe.withDefault 0

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
