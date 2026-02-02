module View.ConnectionUI exposing
    ( P2PConnectionState(..)
    , P2PRole(..)
    , view
    )

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)


{-| P2P connection state machine
-}
type P2PConnectionState
    = P2PNotConnected
    | P2PCreatingRoom
    | P2PJoiningRoom String -- room code being joined
    | P2PConnected P2PRole String -- role and room code


{-| Role in P2P game (host runs game logic, client syncs)
-}
type P2PRole
    = Host
    | Client


{-| View function for connection UI.
Renders different UI based on current P2P state.
-}
view :
    { p2pState : P2PConnectionState
    , roomCodeInput : String
    , showCopiedFeedback : Bool
    , onCreateRoom : msg
    , onJoinRoom : msg
    , onLeaveRoom : msg
    , onRoomCodeInput : String -> msg
    , onCopyRoomCode : msg
    }
    -> Html msg
view config =
    div [ class "connection-panel" ]
        [ case config.p2pState of
            P2PNotConnected ->
                viewNotConnected config

            P2PCreatingRoom ->
                viewCreating config

            P2PJoiningRoom code ->
                viewJoining code config

            P2PConnected Host roomCode ->
                viewConnectedHost roomCode config

            P2PConnected Client roomCode ->
                viewConnectedClient roomCode config
        ]


{-| View when not connected - shows Create/Join buttons and room code input.
-}
viewNotConnected :
    { a
        | roomCodeInput : String
        , onCreateRoom : msg
        , onJoinRoom : msg
        , onRoomCodeInput : String -> msg
    }
    -> Html msg
viewNotConnected config =
    div []
        [ div [ class "connection-buttons" ]
            [ button
                [ class "btn-create"
                , onClick config.onCreateRoom
                ]
                [ text "Create Room" ]
            , button
                [ class "btn-join"
                , onClick config.onJoinRoom
                ]
                [ text "Join Room" ]
            ]
        , div [ class "room-code-input-container" ]
            [ input
                [ class "room-code-input"
                , type_ "text"
                , placeholder "ABCD"
                , maxlength 4
                , value config.roomCodeInput
                , onInput config.onRoomCodeInput
                ]
                []
            , span [ class "room-code-hint" ]
                [ text "Enter 4-letter room code to join" ]
            ]
        ]


{-| View when creating a room - shows spinner.
-}
viewCreating :
    { a | onLeaveRoom : msg }
    -> Html msg
viewCreating config =
    div [ class "connecting-state" ]
        [ span [ class "spinner" ] []
        , span [] [ text "Creating room..." ]
        , button
            [ class "btn-cancel"
            , onClick config.onLeaveRoom
            ]
            [ text "Cancel" ]
        ]


{-| View when joining a room - shows spinner and room code.
-}
viewJoining :
    String
    -> { a | onLeaveRoom : msg }
    -> Html msg
viewJoining code config =
    div [ class "connecting-state" ]
        [ span [ class "spinner" ] []
        , span [] [ text ("Joining " ++ code ++ "...") ]
        , button
            [ class "btn-cancel"
            , onClick config.onLeaveRoom
            ]
            [ text "Cancel" ]
        ]


{-| View when connected as host - shows large room code with copy button.
-}
viewConnectedHost :
    String
    -> { a | showCopiedFeedback : Bool, onCopyRoomCode : msg, onLeaveRoom : msg }
    -> Html msg
viewConnectedHost roomCode config =
    div []
        [ div [ class "room-code-display" ]
            [ span [ class "room-code" ] [ text roomCode ]
            , if config.showCopiedFeedback then
                span [ class "copied-feedback" ] [ text "Copied!" ]

              else
                button
                    [ class "copy-button"
                    , onClick config.onCopyRoomCode
                    ]
                    [ text "Copy" ]
            ]
        , div [ class "connection-status connected" ]
            [ text ("Hosting room " ++ roomCode) ]
        , div [ class "connection-actions" ]
            [ button
                [ class "btn-leave"
                , onClick config.onLeaveRoom
                ]
                [ text "Leave Room" ]
            ]
        ]


{-| View when connected as client - shows status.
-}
viewConnectedClient :
    String
    -> { a | onLeaveRoom : msg }
    -> Html msg
viewConnectedClient roomCode config =
    div []
        [ div [ class "connection-status connected" ]
            [ text ("Connected to " ++ roomCode) ]
        , div [ class "connection-actions" ]
            [ button
                [ class "btn-leave"
                , onClick config.onLeaveRoom
                ]
                [ text "Leave Room" ]
            ]
        ]
