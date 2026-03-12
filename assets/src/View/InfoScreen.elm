module View.InfoScreen exposing (view)

import Html exposing (Html, a, button, div, h1, h2, h3, li, p, span, text, ul)
import Html.Attributes exposing (class, href, style, target)
import Html.Events exposing (onClick)


view : msg -> Html msg
view onClose =
    div [ class "game-container info-page", style "padding" "20px" ]
        [ div [ class "info-header" ]
            [ h1 [] [ text "About Snaker" ]
            , button [ class "btn-back", onClick onClose ]
                [ text "Back" ]
            ]
        , div [ class "info-content" ]
            [ div [ class "info-section" ]
                [ h2 [] [ text "What is Snaker?" ]
                , p []
                    [ text "Snaker is a multiplayer snake game that lets you play with friends in real-time, "
                    , text "directly in your browser. No accounts, no downloads - just share a room code and start playing!"
                    ]
                , p []
                    [ text "The game uses peer-to-peer WebRTC connections, meaning you can play together "
                    , text "without needing a central game server. One player hosts, others join with a 4-letter code."
                    ]
                ]
            , div [ class "info-section" ]
                [ h2 [] [ text "Changelog" ]
                , div [ class "changelog" ]
                    [ div [ class "changelog-entry" ]
                        [ h3 [] [ text "v2.2 - Venom & Power-ups - 2026-02-06" ]
                        , ul []
                            [ li [] [ text "Venom power-up drops: V (purple, straight) and B (blue, ball) grant venom type + 1 segment growth" ]
                            , li [] [ text "Ball venom mode with diagonal bouncing off walls (5s lifetime, randomized bounce angles)" ]
                            , li [] [ text "Local mode venom support" ]
                            , li [] [ text "Shoot key changed from spacebar to Shift" ]
                            , li [] [ text "Ball projectile visibility and spawn wrapping fixes" ]
                            ]
                        ]
                    , div [ class "changelog-entry" ]
                        [ h3 [] [ text "v2.1 - Post-Launch Patches - 2026-02-05" ]
                        , ul []
                            [ li [] [ text "Apple aging lifecycle with skull penalty" ]
                            , li [] [ text "Mobile fullscreen layout with QR watermark" ]
                            , li [] [ text "Auto-join room from URL" ]
                            , li [] [ text "Apple sync and max count fixes" ]
                            ]
                        ]
                    , div [ class "changelog-entry" ]
                        [ h3 [] [ text "v2.0 - P2P WebRTC Mode - 2026-02-03" ]
                        , ul []
                            [ li [] [ text "Direct peer-to-peer multiplayer (no server needed)" ]
                            , li [] [ text "Room codes for easy game sharing" ]
                            , li [] [ text "QR code support for mobile joining" ]
                            , li [] [ text "Host migration when host leaves" ]
                            , li [] [ text "Touch controls for mobile devices" ]
                            ]
                        ]
                    , div [ class "changelog-entry" ]
                        [ h3 [] [ text "v1.0 - Multiplayer Upgrade - 2017-08-15" ]
                        , ul []
                            [ li [] [ text "Phoenix server-based multiplayer" ]
                            , li [] [ text "Real-time game synchronization" ]
                            , li [] [ text "Player collision and death animations" ]
                            , li [] [ text "Live scoreboard" ]
                            ]
                        ]
                    ]
                ]
            , div [ class "info-section about-section" ]
                [ h2 [] [ text "Credits" ]
                , p []
                    [ text "Created by "
                    , a [ href "https://www.getcontented.com.au", target "_blank" ]
                        [ text "Get Contented" ]
                    ]
                , p [ class "about-motivation" ]
                    [ text "Built as an experiment in real-time multiplayer game development with Elm and WebRTC. "
                    , text "The goal was to create a fun, accessible game that works everywhere - "
                    , text "no app store, no login, just instant play with friends."
                    ]
                ]
            ]
        ]
