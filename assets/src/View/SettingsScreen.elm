module View.SettingsScreen exposing (SelectedMode(..), view)

import Html exposing (Html, button, div, h1, h2, p, span, text)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import Network.HostGame as HostGame exposing (HostGameState)
import View.ModeSelection as ModeSelection


type alias Config msg =
    { hostGame : Maybe HostGameState
    , selectedMode : Maybe SelectedMode
    , onToggleVenom : msg
    , onChangeMode : ModeSelection.Mode -> msg
    , onClose : msg
    }


type SelectedMode
    = P2PSelected
    | PhoenixSelected


view : Config msg -> Html msg
view config =
    let
        venomEnabled =
            case config.hostGame of
                Just hostState ->
                    hostState.settings.venomMode

                Nothing ->
                    False
    in
    div [ class "game-container settings-page", style "padding" "20px" ]
        [ h1 [] [ text "Settings" ]
        , div [ class "settings-content" ]
            [ -- Game settings section (host only, P2P mode)
              case config.hostGame of
                Just _ ->
                    div [ class "settings-section" ]
                        [ h2 [] [ text "Game Rules" ]
                        , div [ class "setting-row" ]
                            [ span [ class "setting-label" ] [ text "Venom Spitting" ]
                            , button
                                [ class
                                    (if venomEnabled then
                                        "setting-toggle active"

                                     else
                                        "setting-toggle"
                                    )
                                , onClick config.onToggleVenom
                                ]
                                [ text
                                    (if venomEnabled then
                                        "ON"

                                     else
                                        "OFF"
                                    )
                                ]
                            ]
                        , p [ class "setting-description" ]
                            [ text "Eat V (purple) for straight-line venom or B (blue) for bouncing ball venom. Press Shift to fire! Hitting an enemy truncates their tail into apples." ]
                        ]

                Nothing ->
                    text ""
            , h2 [] [ text "Game Mode" ]
            , p [ class "current-mode" ]
                [ text "Current mode: "
                , text
                    (case config.selectedMode of
                        Just P2PSelected ->
                            "Direct Connect (P2P)"

                        Just PhoenixSelected ->
                            "Classic Online (Phoenix)"

                        Nothing ->
                            "Not selected"
                    )
                ]
            , div [ class "mode-change-buttons" ]
                [ button
                    [ class
                        (if config.selectedMode == Just P2PSelected then
                            "mode-option-button selected"

                         else
                            "mode-option-button"
                        )
                    , onClick (config.onChangeMode ModeSelection.P2PMode)
                    ]
                    [ text "Direct Connect" ]
                , button
                    [ class
                        (if config.selectedMode == Just PhoenixSelected then
                            "mode-option-button selected"

                         else
                            "mode-option-button"
                        )
                    , onClick (config.onChangeMode ModeSelection.PhoenixMode)
                    ]
                    [ text "Classic Online" ]
                ]
            , button [ class "btn-back", onClick config.onClose ]
                [ text "Back to Game" ]
            ]
        ]
