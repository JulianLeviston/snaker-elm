module View.GameScreen exposing (ConnectionStatus(..), GameMode(..), SelectedMode(..), view)

import Dict
import Engine.VenomType as VenomType
import Game exposing (GameState)
import Html exposing (Html, button, div, h1, img, span, text)
import Html.Attributes exposing (alt, class, src, style)
import Html.Events exposing (onClick)
import LocalGame exposing (LocalGameState)
import Network.ClientGame as ClientGame exposing (ClientGameState)
import Network.HostGame as HostGame exposing (HostGameState)
import P2P.Connection as P2P
import Snake exposing (Position)
import View.Board as Board
import View.ConnectionUI as ConnectionUI exposing (P2PConnectionState(..), P2PRole(..))
import View.Notifications as Notifications
import View.Scoreboard as Scoreboard
import View.ShareUI as ShareUI exposing (CopyState)


type alias Config msg =
    { hostGame : Maybe HostGameState
    , clientGame : Maybe ClientGameState
    , localGame : Maybe LocalGameState
    , gameState : Maybe GameState
    , gameMode : GameMode
    , myPeerId : Maybe String
    , myId : Maybe String
    , selectedMode : Maybe SelectedMode
    , p2pState : P2PConnectionState
    , roomCodeInput : String
    , showCopiedFeedback : Bool
    , qrCodeDataUrl : Maybe String
    , connectionPanelCollapsed : Bool
    , showingCollision : Bool
    , connectionStatus : ConnectionStatus
    , error : Maybe String
    , notification : Html msg
    , copyCodeState : CopyState
    , copyUrlState : CopyState
    , onOpenInfo : msg
    , onOpenSettings : msg
    , onToggleConnectionPanel : msg
    , onP2PMsg : P2P.Msg -> msg
    , onError : String -> msg
    }


type GameMode
    = LocalMode
    | OnlineMode


type SelectedMode
    = P2PSelected
    | PhoenixSelected


type ConnectionStatus
    = Disconnected
    | Connecting
    | Connected


view : Config msg -> Html msg
view config =
    let
        p2p =
            { p2pState = config.p2pState
            , roomCodeInput = config.roomCodeInput
            , showCopiedFeedback = config.showCopiedFeedback
            , qrCodeDataUrl = config.qrCodeDataUrl
            , connectionPanelCollapsed = config.connectionPanelCollapsed
            }

        -- Get room code if connected
        maybeRoomCode =
            case config.p2pState of
                P2PConnected _ code ->
                    Just code

                _ ->
                    Nothing

        -- Collapse toggle icon
        collapseIcon =
            if config.connectionPanelCollapsed then
                "▼"

            else
                "▲"
    in
    div [ class "game-container", style "padding" "20px" ]
        [ div [ class "game-header" ]
            [ h1 [] [ text "Snaker v2.2" ]
            , -- Mobile room code badge (visible when connected)
              case maybeRoomCode of
                Just code ->
                    button
                        [ class "room-badge"
                        , onClick config.onToggleConnectionPanel
                        ]
                        [ text ("Room: " ++ code ++ " " ++ collapseIcon) ]

                Nothing ->
                    text ""
            , div [ class "header-buttons" ]
                [ button [ class "btn-info", onClick config.onOpenInfo ]
                    [ text "?" ]
                , button [ class "btn-settings", onClick config.onOpenSettings ]
                    [ text "Settings" ]
                ]
            ]
        , -- Only show P2P connection UI in P2P mode (collapsible on mobile)
          case config.selectedMode of
            Just P2PSelected ->
                div
                    [ class
                        (if config.connectionPanelCollapsed then
                            "connection-panel-wrapper collapsed"

                         else
                            "connection-panel-wrapper"
                        )
                    ]
                    [ Html.map config.onP2PMsg
                        (ConnectionUI.view
                            { p2pState = config.p2pState
                            , roomCodeInput = config.roomCodeInput
                            , showCopiedFeedback = config.showCopiedFeedback
                            , onCreateRoom = P2P.CreateRoom
                            , onJoinRoom = P2P.JoinRoom
                            , onLeaveRoom = P2P.LeaveRoom
                            , onRoomCodeInput = P2P.RoomCodeInputChanged
                            , onCopyRoomCode = P2P.CopyRoomCode
                            }
                        )
                    ]

            Just PhoenixSelected ->
                div [ class "connection-status" ]
                    [ text ("Phoenix: " ++ connectionStatusToString config.connectionStatus) ]

            Nothing ->
                text ""
        , viewStatus config
        , case config.error of
            Just err ->
                div [ style "color" "red" ] [ text ("Error: " ++ err) ]

            Nothing ->
                text ""
        , viewGame config
        , -- Show ShareUI BELOW the board when connected as host
          case ( config.selectedMode, config.p2pState ) of
            ( Just P2PSelected, P2PConnected Host roomCode ) ->
                Html.map config.onP2PMsg
                    (ShareUI.view
                        { roomCode = roomCode
                        , qrCodeDataUrl = config.qrCodeDataUrl
                        , copyCodeState = config.copyCodeState
                        , copyUrlState = config.copyUrlState
                        , onCopyCode = P2P.CopyRoomCode
                        , onCopyUrl = P2P.CopyRoomUrl
                        }
                    )

            _ ->
                text ""
        , config.notification
        ]


viewStatus : Config msg -> Html msg
viewStatus config =
    div [ class "game-status" ]
        [ case config.hostGame of
            Just hostState ->
                let
                    playerCount =
                        Dict.size hostState.snakes

                    hostScore =
                        Dict.get hostState.hostId hostState.scores |> Maybe.withDefault 0
                in
                span []
                    [ text "Mode: Host (P2P)"
                    , text (" | Players: " ++ String.fromInt playerCount)
                    , text (" | Tick: " ++ String.fromInt hostState.currentTick)
                    , text (" | Score: " ++ String.fromInt hostScore)
                    ]

            Nothing ->
                case config.clientGame of
                    Just clientState ->
                        let
                            playerCount =
                                Dict.size clientState.snakes

                            myScore =
                                Dict.get clientState.myId clientState.scores |> Maybe.withDefault 0
                        in
                        span []
                            [ text "Mode: Client (P2P)"
                            , text (" | Players: " ++ String.fromInt playerCount)
                            , text (" | Tick: " ++ String.fromInt clientState.lastHostTick)
                            , text (" | Score: " ++ String.fromInt myScore)
                            ]

                    Nothing ->
                        span []
                            [ case config.gameMode of
                                LocalMode ->
                                    text "Mode: Local (offline)"

                                OnlineMode ->
                                    text ("Status: " ++ connectionStatusToString config.connectionStatus)
                            , case config.myId of
                                Just pid ->
                                    text (" | Player ID: " ++ pid)

                                Nothing ->
                                    text ""
                            , case config.localGame of
                                Just localState ->
                                    span []
                                        [ text (" | Tick: " ++ String.fromInt localState.currentTick)
                                        , text (" | Score: " ++ String.fromInt localState.score)
                                        ]

                                Nothing ->
                                    text ""
                            ]
        ]


viewGame : Config msg -> Html msg
viewGame config =
    let
        -- Wrap game board with collision shake class if collision is happening
        wrapWithShake content =
            if config.showingCollision then
                div [ class "game-board-wrapper collision-shake" ] [ content ]

            else
                content

        -- QR code watermark overlay (only shown for host)
        qrWatermark =
            case config.qrCodeDataUrl of
                Just dataUrl ->
                    img
                        [ class "qr-watermark"
                        , src dataUrl
                        , alt "Scan to join"
                        ]
                        []

                Nothing ->
                    text ""

        -- Check if we should show QR watermark (host with room)
        showQrWatermark =
            case config.p2pState of
                P2PConnected Host _ ->
                    True

                _ ->
                    False
    in
    -- Check if hosting P2P game first
    case config.hostGame of
        Just hostState ->
            let
                gameState =
                    HostGame.toGameState hostState

                projectileStates =
                    List.map
                        (\p ->
                            { position = p.position
                            , direction = p.direction
                            , ownerId = p.ownerId
                            , venomType = VenomType.toString p.venomType
                            }
                        )
                        hostState.projectiles
            in
            div [ class "game-layout" ]
                [ div [ class "game-board-container" ]
                    [ if showQrWatermark then qrWatermark else text ""
                    , wrapWithShake (Board.viewWithProjectiles gameState config.myPeerId gameState.leaderId projectileStates gameState.snakes gameState.powerUpDrops)
                    ]
                , Scoreboard.view gameState.snakes gameState.scores config.myPeerId
                ]

        Nothing ->
            -- Check if we're a client
            case config.clientGame of
                Just clientState ->
                    let
                        gameState =
                            ClientGame.toGameState clientState
                    in
                    div [ class "game-layout" ]
                        [ div [ class "game-board-container" ]
                            [ wrapWithShake (Board.viewWithProjectiles gameState config.myPeerId gameState.leaderId clientState.projectiles gameState.snakes gameState.powerUpDrops)
                            ]
                        , Scoreboard.view gameState.snakes gameState.scores config.myPeerId
                        ]

                Nothing ->
                    case config.gameMode of
                        LocalMode ->
                            case config.localGame of
                                Just localState ->
                                    let
                                        gameState =
                                            LocalGame.toGameState localState

                                        projectileStates =
                                            LocalGame.toProjectileStates localState
                                    in
                                    div [ class "game-layout" ]
                                        [ div [ class "game-board-container" ]
                                            [ wrapWithShake (Board.viewWithProjectiles gameState config.myId Nothing projectileStates gameState.snakes [])
                                            ]
                                        , Scoreboard.view gameState.snakes Dict.empty config.myId
                                        ]

                                Nothing ->
                                    -- No game yet - user needs to create or join a room
                                    text ""

                        OnlineMode ->
                            case config.gameState of
                                Just state ->
                                    div [ class "game-layout" ]
                                        [ div [ class "game-board-container" ]
                                            [ wrapWithShake (Board.view state config.myId)
                                            ]
                                        , Scoreboard.view state.snakes Dict.empty config.myId
                                        ]

                                Nothing ->
                                    div [] [ text "Waiting for game state..." ]


connectionStatusToString : ConnectionStatus -> String
connectionStatusToString status =
    case status of
        Disconnected ->
            "Disconnected"

        Connecting ->
            "Connecting..."

        Connected ->
            "Connected"
