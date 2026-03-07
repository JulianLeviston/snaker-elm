module P2P.Connection exposing
    ( Effect(..)
    , Model
    , Msg(..)
    , init
    , reset
    , startCreating
    , subscriptions
    , update
    )

import Json.Decode as JD
import Ports
import Process
import Task
import View.ConnectionUI exposing (P2PConnectionState(..), P2PRole(..))
import View.ShareUI as ShareUI


{-| P2P connection sub-model.
-}
type alias Model =
    { p2pState : P2PConnectionState
    , roomCodeInput : String
    , showCopiedFeedback : Bool
    , connectionPanelCollapsed : Bool
    , baseUrl : String
    , qrCodeDataUrl : Maybe String
    , copyCodeState : ShareUI.CopyState
    , copyUrlState : ShareUI.CopyState
    }


{-| Initialize the P2P connection model.
-}
init : String -> Model
init baseUrl =
    { p2pState = P2PNotConnected
    , roomCodeInput = ""
    , showCopiedFeedback = False
    , connectionPanelCollapsed = False
    , baseUrl = baseUrl
    , qrCodeDataUrl = Nothing
    , copyCodeState = ShareUI.Ready
    , copyUrlState = ShareUI.Ready
    }


{-| Reset P2P state back to not connected (preserves baseUrl).
-}
reset : Model -> Model
reset model =
    { model
        | p2pState = P2PNotConnected
        , roomCodeInput = ""
        , showCopiedFeedback = False
        , connectionPanelCollapsed = False
        , qrCodeDataUrl = Nothing
        , copyCodeState = ShareUI.Ready
        , copyUrlState = ShareUI.Ready
    }


{-| Set P2P state to creating a room.
-}
startCreating : Model -> Model
startCreating model =
    { model | p2pState = P2PCreatingRoom }


{-| Messages handled by the P2P connection module.
-}
type Msg
    = CreateRoom
    | JoinRoom
    | LeaveRoom
    | RoomCodeInputChanged String
    | GotRoomCreated String
    | GotPeerConnected JD.Value
    | GotPeerDisconnected String
    | GotConnectionError String
    | CopyRoomCode
    | CopyRoomUrl
    | GotClipboardCopySuccess ShareUI.CopyTarget
    | HideCopiedCodeFeedback
    | HideCopiedUrlFeedback
    | GotQRCodeGenerated JD.Value
    | ToggleConnectionPanel
    | TriggerAutoJoin String


{-| Effects that the P2P module needs Main to handle (cross-cutting concerns).
-}
type Effect
    = NoEffect
    | RoomCreated String -- roomCode; Main should init host game and set myPeerId
    | PeerConnectedAsHost String -- peerId of connecting client; Main should spawn player in host game
    | PeerConnectedAsClient String String -- roomCode, myPeerId; Main should init client game
    | PeerDisconnected String -- peerId; Main decides what to do based on its own state
    | Notify String Float -- message, duration in ms


update : Msg -> Model -> ( Model, Cmd Msg, List Effect )
update msg model =
    case msg of
        CreateRoom ->
            ( { model | p2pState = P2PCreatingRoom }
            , Ports.createRoom ()
            , []
            )

        JoinRoom ->
            let
                roomCode =
                    String.toUpper model.roomCodeInput
            in
            if String.length roomCode == 4 then
                ( { model | p2pState = P2PJoiningRoom roomCode }
                , Ports.joinRoom roomCode
                , []
                )

            else
                ( model, Cmd.none, [] )

        LeaveRoom ->
            ( { model | p2pState = P2PNotConnected }
            , Ports.leaveRoom ()
            , []
            )

        RoomCodeInputChanged str ->
            let
                normalized =
                    str
                        |> String.toUpper
                        |> String.filter Char.isAlpha
                        |> String.left 4
            in
            if String.length normalized == 4 then
                ( { model
                    | roomCodeInput = normalized
                    , p2pState = P2PJoiningRoom normalized
                  }
                , Ports.joinRoom normalized
                , []
                )

            else
                ( { model | roomCodeInput = normalized }
                , Cmd.none
                , []
                )

        GotRoomCreated roomCode ->
            let
                roomUrl =
                    model.baseUrl ++ "?room=" ++ roomCode
            in
            ( { model
                | p2pState = P2PConnected Host roomCode
                , qrCodeDataUrl = Nothing
                , copyCodeState = ShareUI.Ready
                , copyUrlState = ShareUI.Ready
                , connectionPanelCollapsed = True
              }
            , Ports.generateQRCode roomUrl
            , [ RoomCreated roomCode ]
            )

        GotPeerConnected value ->
            case JD.decodeValue peerConnectedDecoder value of
                Ok data ->
                    case data.role of
                        Host ->
                            -- A client connected to us (we are host)
                            ( model
                            , Cmd.none
                            , [ PeerConnectedAsHost data.roomCode ]
                            )

                        Client ->
                            -- We connected to host as a client
                            ( { model | p2pState = P2PConnected Client data.roomCode }
                            , Cmd.none
                            , [ PeerConnectedAsClient data.roomCode data.myPeerId ]
                            )

                Err _ ->
                    ( model, Cmd.none, [] )

        GotPeerDisconnected peerId ->
            ( model
            , Cmd.none
            , [ PeerDisconnected peerId ]
            )

        GotConnectionError errorMsg ->
            let
                newP2PState =
                    case model.p2pState of
                        P2PCreatingRoom ->
                            P2PNotConnected

                        P2PJoiningRoom _ ->
                            P2PNotConnected

                        _ ->
                            model.p2pState
            in
            ( { model | p2pState = newP2PState }
            , Cmd.none
            , [ Notify errorMsg 5000 ]
            )

        CopyRoomCode ->
            case model.p2pState of
                P2PConnected _ roomCode ->
                    ( { model | copyCodeState = ShareUI.Copied }
                    , Cmd.batch
                        [ Ports.copyToClipboard roomCode
                        , Process.sleep 2000 |> Task.perform (\_ -> HideCopiedCodeFeedback)
                        ]
                    , []
                    )

                _ ->
                    ( model, Cmd.none, [] )

        CopyRoomUrl ->
            case model.p2pState of
                P2PConnected _ roomCode ->
                    let
                        roomUrl =
                            model.baseUrl ++ "?room=" ++ roomCode
                    in
                    ( { model | copyUrlState = ShareUI.Copied }
                    , Cmd.batch
                        [ Ports.copyToClipboard roomUrl
                        , Process.sleep 2000 |> Task.perform (\_ -> HideCopiedUrlFeedback)
                        ]
                    , []
                    )

                _ ->
                    ( model, Cmd.none, [] )

        GotClipboardCopySuccess _ ->
            ( model, Cmd.none, [] )

        HideCopiedCodeFeedback ->
            ( { model | copyCodeState = ShareUI.Ready, showCopiedFeedback = False }
            , Cmd.none
            , []
            )

        HideCopiedUrlFeedback ->
            ( { model | copyUrlState = ShareUI.Ready }
            , Cmd.none
            , []
            )

        GotQRCodeGenerated value ->
            case JD.decodeValue qrCodeResultDecoder value of
                Ok result ->
                    if result.success then
                        ( { model | qrCodeDataUrl = result.dataUrl }
                        , Cmd.none
                        , []
                        )

                    else
                        ( model, Cmd.none, [] )

                Err _ ->
                    ( model, Cmd.none, [] )

        ToggleConnectionPanel ->
            ( { model | connectionPanelCollapsed = not model.connectionPanelCollapsed }
            , Cmd.none
            , []
            )

        TriggerAutoJoin roomCode ->
            let
                normalizedCode =
                    roomCode
                        |> String.toUpper
                        |> String.filter Char.isAlpha
                        |> String.left 4
            in
            if String.length normalizedCode == 4 then
                ( { model | p2pState = P2PJoiningRoom normalizedCode }
                , Ports.joinRoom normalizedCode
                , []
                )

            else
                ( model
                , Cmd.none
                , [ Notify "Invalid room code" 3000 ]
                )



-- Subscriptions


subscriptions : Sub Msg
subscriptions =
    Sub.batch
        [ Ports.roomCreated GotRoomCreated
        , Ports.peerConnected GotPeerConnected
        , Ports.peerDisconnected GotPeerDisconnected
        , Ports.connectionError GotConnectionError
        , Ports.clipboardCopySuccess (\_ -> GotClipboardCopySuccess ShareUI.CopyCode)
        , Ports.qrCodeGenerated GotQRCodeGenerated
        , Ports.triggerAutoJoin TriggerAutoJoin
        ]



-- Decoders


type alias QRCodeResult =
    { success : Bool
    , dataUrl : Maybe String
    }


qrCodeResultDecoder : JD.Decoder QRCodeResult
qrCodeResultDecoder =
    JD.map2 QRCodeResult
        (JD.field "success" JD.bool)
        (JD.maybe (JD.field "dataUrl" JD.string))


peerConnectedDecoder : JD.Decoder { role : P2PRole, roomCode : String, myPeerId : String }
peerConnectedDecoder =
    JD.map3 (\role roomCode myPeerId -> { role = role, roomCode = roomCode, myPeerId = myPeerId })
        (JD.field "role" (JD.string |> JD.andThen roleDecoder))
        (JD.oneOf
            [ JD.field "roomCode" JD.string
            , JD.field "peerId" JD.string
            ]
        )
        (JD.oneOf
            [ JD.field "myPeerId" JD.string
            , JD.succeed ""
            ]
        )


roleDecoder : String -> JD.Decoder P2PRole
roleDecoder str =
    case str of
        "host" ->
            JD.succeed Host

        "client" ->
            JD.succeed Client

        _ ->
            JD.fail ("Unknown role: " ++ str)
