module View.Notifications exposing (view)

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)


view : Maybe String -> Html msg
view maybeMessage =
    case maybeMessage of
        Just message ->
            div [ class "toast" ] [ text message ]

        Nothing ->
            text ""
