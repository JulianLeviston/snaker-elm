module View.ConnectionLostScreen exposing (view)

import Html exposing (Html, button, div, h1, p, text)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)


view : { onCreateRoom : msg, onGoHome : msg } -> Html msg
view config =
    div [ class "game-container connection-lost-page", style "padding" "20px", style "text-align" "center" ]
        [ h1 [] [ text "Connection Lost" ]
        , p [ style "margin" "20px 0", style "color" "#666" ]
            [ text "Lost connection to all players." ]
        , div [ class "connection-lost-buttons", style "display" "flex", style "gap" "12px", style "justify-content" "center" ]
            [ button [ class "btn-create", onClick config.onCreateRoom ]
                [ text "Create New Room" ]
            , button [ class "btn-cancel", onClick config.onGoHome ]
                [ text "Go Home" ]
            ]
        ]
