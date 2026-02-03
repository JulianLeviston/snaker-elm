module View.ModeSelection exposing
    ( Mode(..)
    , modeFromString
    , modeToString
    , view
    )

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)


{-| Game mode: P2P (direct connect) or Phoenix (server-based).
-}
type Mode
    = P2PMode
    | PhoenixMode


{-| Convert mode to string for localStorage persistence.
-}
modeToString : Mode -> String
modeToString mode =
    case mode of
        P2PMode ->
            "p2p"

        PhoenixMode ->
            "phoenix"


{-| Parse mode from string (localStorage value).
-}
modeFromString : String -> Maybe Mode
modeFromString str =
    case str of
        "p2p" ->
            Just P2PMode

        "phoenix" ->
            Just PhoenixMode

        _ ->
            Nothing


{-| Configuration for the mode selection view.
-}
type alias Config msg =
    { onSelectMode : Mode -> msg
    }


{-| Mode selection view. Shows two mode options with P2P as primary.
-}
view : Config msg -> Html msg
view config =
    div [ class "mode-selection-container" ]
        [ h2 [ class "mode-selection-title" ] [ text "Choose your mode" ]
        , div [ class "mode-buttons" ]
            [ viewModeButton
                { mode = P2PMode
                , title = "Direct Connect"
                , description = "Play directly with friends - no server needed"
                , isPrimary = True
                , onSelect = config.onSelectMode
                }
            , viewModeButton
                { mode = PhoenixMode
                , title = "Classic Online"
                , description = "Connect through our game server"
                , isPrimary = False
                , onSelect = config.onSelectMode
                }
            ]
        ]


{-| View a single mode button.
-}
viewModeButton :
    { mode : Mode
    , title : String
    , description : String
    , isPrimary : Bool
    , onSelect : Mode -> msg
    }
    -> Html msg
viewModeButton { mode, title, description, isPrimary, onSelect } =
    button
        [ class
            (if isPrimary then
                "mode-button mode-button-primary"

             else
                "mode-button mode-button-secondary"
            )
        , onClick (onSelect mode)
        ]
        [ span [ class "mode-button-title" ] [ text title ]
        , span [ class "mode-button-description" ] [ text description ]
        ]
