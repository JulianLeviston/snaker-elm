module Main exposing (main)

import Browser
import Browser.Events
import Dict
import Engine.Apple as Apple exposing (Apple)
import Game exposing (GameState)
import Html exposing (Html, button, div, h1, h2, p, span, text)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import Input
import Json.Decode as JD
import Json.Encode as JE
import LocalGame exposing (LocalGameState)
import Network.ClientGame as ClientGame exposing (ClientGameState)
import Network.HostGame as HostGame exposing (HostGameState)
import Network.Protocol as Protocol
import Ports
import Process
import Random
import Snake exposing (Direction(..), Position)
import Task
import Time
import View.Board as Board
import View.ConnectionUI as ConnectionUI exposing (P2PConnectionState(..), P2PRole(..))
import View.ModeSelection as ModeSelection
import View.Notifications as Notifications
import View.Scoreboard as Scoreboard
import View.ShareUI as ShareUI


{-| Flags passed from JavaScript on init.
-}
type alias Flags =
    { savedMode : Maybe String
    , baseUrl : String
    }


{-| Current screen being displayed.
-}
type Screen
    = ModeSelectionScreen
    | GameScreen
    | SettingsScreen
    | ConnectionLostScreen


{-| Selected game mode (P2P or Phoenix).
-}
type SelectedMode
    = P2PSelected
    | PhoenixSelected


type alias Model =
    { gameState : Maybe GameState
    , localGame : Maybe LocalGameState
    , hostGame : Maybe HostGameState
    , clientGame : Maybe ClientGameState
    , playerId : Maybe String
    , myPeerId : Maybe String
    , currentDirection : Direction
    , connectionStatus : ConnectionStatus
    , error : Maybe String
    , notification : Maybe String
    , gameMode : GameMode
    , pendingAppleSpawns : Int  -- Track in-flight Random.generate calls
    -- P2P connection state
    , p2pState : P2PConnectionState
    , roomCodeInput : String
    , showCopiedFeedback : Bool
    , showingCollision : Bool  -- For collision shake animation
    -- Screen routing
    , screen : Screen
    , selectedMode : Maybe SelectedMode
    -- Share UI state
    , baseUrl : String
    , qrCodeDataUrl : Maybe String
    , copyCodeState : ShareUI.CopyState
    , copyUrlState : ShareUI.CopyState
    }


type GameMode
    = LocalMode
    | OnlineMode


type ConnectionStatus
    = Disconnected
    | Connecting
    | Connected


type Msg
    = KeyPressed (Maybe Direction)
    | GotGameState JD.Value
    | GotError String
    | PlayerJoined JD.Value
    | PlayerLeft JD.Value
    | GotTick JD.Value
    | JoinGame
    | ClearNotification
      -- Local game messages
    | Tick Time.Posix
    | InitGame LocalGameState
    | NewSpawnPosition Position
    | NewApplePosition Position
      -- P2P messages
    | CreateRoom
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
      -- Host game messages
    | InitHostGame HostGameState
    | HostTick Time.Posix
    | NewHostSpawnPosition String Position
    | NewHostApplePosition Position
    | GotInputP2P String
      -- Client game messages
    | GotGameStateP2P String
    | NewPlayerSpawn String Position String
    | ClearCollisionShake
      -- Host migration messages
    | GotHostMigration JD.Value
    | CreateNewRoom
    | GoHome
      -- Mode selection messages
    | SelectMode ModeSelection.Mode
    | OpenSettings
    | CloseSettings
    | ChangeMode ModeSelection.Mode


init : Flags -> ( Model, Cmd Msg )
init flags =
    -- Check for saved mode in flags
    case flags.savedMode |> Maybe.andThen ModeSelection.modeFromString of
        Just ModeSelection.P2PMode ->
            -- Skip to P2P mode (show P2P connection UI)
            initWithMode flags.baseUrl P2PSelected

        Just ModeSelection.PhoenixMode ->
            -- Skip to Phoenix mode (show Phoenix UI)
            initWithMode flags.baseUrl PhoenixSelected

        Nothing ->
            -- First visit: show mode selection
            initModeSelection flags.baseUrl


{-| Initialize with mode selection screen (first visit).
-}
initModeSelection : String -> ( Model, Cmd Msg )
initModeSelection baseUrl =
    ( { gameState = Nothing
      , localGame = Nothing
      , hostGame = Nothing
      , clientGame = Nothing
      , playerId = Nothing
      , myPeerId = Nothing
      , currentDirection = Right
      , connectionStatus = Disconnected
      , error = Nothing
      , notification = Nothing
      , gameMode = LocalMode
      , pendingAppleSpawns = 0
      , p2pState = P2PNotConnected
      , roomCodeInput = ""
      , showCopiedFeedback = False
      , showingCollision = False
      , screen = ModeSelectionScreen
      , selectedMode = Nothing
      , baseUrl = baseUrl
      , qrCodeDataUrl = Nothing
      , copyCodeState = ShareUI.Ready
      , copyUrlState = ShareUI.Ready
      }
    , Cmd.none
    )


{-| Initialize with a specific mode already selected (returning visitor).
-}
initWithMode : String -> SelectedMode -> ( Model, Cmd Msg )
initWithMode baseUrl mode =
    case mode of
        P2PSelected ->
            -- P2P mode: show connection UI, no local game running yet
            ( { gameState = Nothing
              , localGame = Nothing
              , hostGame = Nothing
              , clientGame = Nothing
              , playerId = Nothing
              , myPeerId = Nothing
              , currentDirection = Right
              , connectionStatus = Disconnected
              , error = Nothing
              , notification = Nothing
              , gameMode = LocalMode
              , pendingAppleSpawns = 0
              , p2pState = P2PNotConnected
              , roomCodeInput = ""
              , showCopiedFeedback = False
              , showingCollision = False
              , screen = GameScreen
              , selectedMode = Just P2PSelected
              , baseUrl = baseUrl
              , qrCodeDataUrl = Nothing
              , copyCodeState = ShareUI.Ready
              , copyUrlState = ShareUI.Ready
              }
            , Cmd.none
            )

        PhoenixSelected ->
            -- Phoenix mode: start local game for now (Phoenix socket handled separately)
            ( { gameState = Nothing
              , localGame = Nothing
              , hostGame = Nothing
              , clientGame = Nothing
              , playerId = Just "local"
              , myPeerId = Nothing
              , currentDirection = Right
              , connectionStatus = Connected
              , error = Nothing
              , notification = Nothing
              , gameMode = OnlineMode
              , pendingAppleSpawns = 0
              , p2pState = P2PNotConnected
              , roomCodeInput = ""
              , showCopiedFeedback = False
              , showingCollision = False
              , screen = GameScreen
              , selectedMode = Just PhoenixSelected
              , baseUrl = baseUrl
              , qrCodeDataUrl = Nothing
              , copyCodeState = ShareUI.Ready
              , copyUrlState = ShareUI.Ready
              }
            , Ports.joinGame (JE.object [])
            )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- Local game tick
        Tick _ ->
            case model.localGame of
                Just localState ->
                    let
                        tickResult =
                            LocalGame.tick localState

                        newState =
                            tickResult.state
                    in
                    if newState.needsRespawn then
                        -- Need random respawn position, trigger collision shake
                        ( { model
                            | localGame = Just newState
                            , showingCollision = True
                          }
                        , Cmd.batch
                            [ Random.generate NewSpawnPosition (randomPosition newState.grid)
                            , Process.sleep 300 |> Task.perform (\_ -> ClearCollisionShake)
                            ]
                        )

                    else
                        -- Check if we need to spawn apples
                        let
                            -- Account for pending spawns to avoid race conditions
                            effectiveAppleCount =
                                List.length newState.apples + model.pendingAppleSpawns

                            applesNeeded =
                                max 0 (Apple.minApples - effectiveAppleCount + List.length tickResult.expiredApples)

                            ( newPendingCount, spawnCmd ) =
                                if applesNeeded > 0 then
                                    ( model.pendingAppleSpawns + applesNeeded
                                    , spawnAppleCommands applesNeeded (LocalGame.getOccupiedPositions newState) newState.grid
                                    )

                                else
                                    ( model.pendingAppleSpawns, Cmd.none )
                        in
                        ( { model
                            | localGame = Just newState
                            , pendingAppleSpawns = newPendingCount
                          }
                        , spawnCmd
                        )

                Nothing ->
                    ( model, Cmd.none )

        InitGame localState ->
            -- Game initialized, spawn initial apples
            let
                applesNeeded =
                    Apple.minApples

                spawnCmd =
                    spawnAppleCommands applesNeeded (LocalGame.getOccupiedPositions localState) localState.grid
            in
            ( { model
                | localGame = Just localState
                , pendingAppleSpawns = applesNeeded
              }
            , spawnCmd
            )

        NewSpawnPosition pos ->
            case model.localGame of
                Just localState ->
                    let
                        newState =
                            LocalGame.respawnSnake pos localState
                    in
                    ( { model | localGame = Just newState }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        NewApplePosition pos ->
            case model.localGame of
                Just localState ->
                    let
                        apple =
                            { position = pos
                            , expiresAtTick = localState.currentTick + Apple.ticksUntilExpiry
                            }

                        newState =
                            LocalGame.addApple apple localState
                    in
                    ( { model
                        | localGame = Just newState
                        , pendingAppleSpawns = max 0 (model.pendingAppleSpawns - 1)
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        JoinGame ->
            ( { model | connectionStatus = Connecting }
            , Ports.joinGame (JE.object [])
            )

        KeyPressed maybeDir ->
            case maybeDir of
                Just dir ->
                    -- Check if we're hosting a P2P game first
                    case model.hostGame of
                        Just hostState ->
                            -- Host: apply direction to own snake
                            let
                                newState =
                                    HostGame.changeHostDirection dir hostState
                            in
                            ( { model | hostGame = Just newState, currentDirection = dir }
                            , Cmd.none
                            )

                        Nothing ->
                            -- Check if we're a P2P client
                            case model.clientGame of
                                Just clientState ->
                                    -- Client: buffer optimistic input and send to host
                                    let
                                        newClientState =
                                            ClientGame.bufferLocalInput dir clientState

                                        inputPayload =
                                            Protocol.encodeInput
                                                { playerId = clientState.myId
                                                , direction = dir
                                                , tick = clientState.lastHostTick
                                                }

                                        inputJson =
                                            JE.encode 0 inputPayload
                                    in
                                    ( { model | clientGame = Just newClientState, currentDirection = dir }
                                    , Ports.sendInputP2P inputJson
                                    )

                                Nothing ->
                                    case model.gameMode of
                                        LocalMode ->
                                            -- Update local game with direction change
                                            case model.localGame of
                                                Just localState ->
                                                    let
                                                        newState =
                                                            LocalGame.changeDirection dir localState
                                                    in
                                                    ( { model | localGame = Just newState, currentDirection = dir }
                                                    , Cmd.none
                                                    )

                                                Nothing ->
                                                    ( model, Cmd.none )

                                        OnlineMode ->
                                            -- Send to server (existing behavior)
                                            ( { model | currentDirection = dir }
                                            , Ports.sendDirection
                                                (JE.object [ ( "direction", JE.string (Snake.directionToString dir) ) ])
                                            )

                Nothing ->
                    ( model, Cmd.none )

        GotGameState value ->
            case JD.decodeValue Game.decoder value of
                Ok state ->
                    ( { model
                        | gameState = Just state
                        , connectionStatus = Connected
                      }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        GotError errorMsg ->
            ( { model | error = Just errorMsg }, Cmd.none )

        PlayerJoined value ->
            case JD.decodeValue playerJoinedDecoder value of
                Ok playerData ->
                    let
                        isOwnJoin =
                            model.playerId == Nothing

                        -- Only show notification if this isn't our own join
                        notificationMsg =
                            if isOwnJoin then
                                Nothing

                            else
                                Just (playerData.name ++ " joined")

                        clearCmd =
                            case notificationMsg of
                                Just _ ->
                                    Process.sleep 3000
                                        |> Task.perform (\_ -> ClearNotification)

                                Nothing ->
                                    Cmd.none

                        -- Only set playerId on our own join
                        newPlayerId =
                            if isOwnJoin then
                                Just playerData.id

                            else
                                model.playerId
                    in
                    ( { model
                        | playerId = newPlayerId
                        , notification = notificationMsg
                      }
                    , clearCmd
                    )

                Err _ ->
                    ( model, Cmd.none )

        PlayerLeft _ ->
            ( { model | notification = Just "Player left" }
            , Process.sleep 3000
                |> Task.perform (\_ -> ClearNotification)
            )

        GotTick value ->
            -- Merge tick delta (snakes, apples) into existing state
            -- Grid dimensions come from initial game_state, tick only has entity updates
            case JD.decodeValue tickDecoder value of
                Ok tickData ->
                    ( { model
                        | gameState =
                            Maybe.map
                                (\gs -> { gs | snakes = tickData.snakes, apples = tickData.apples })
                                model.gameState
                      }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        ClearNotification ->
            ( { model | notification = Nothing }, Cmd.none )

        ClearCollisionShake ->
            ( { model | showingCollision = False }, Cmd.none )

        -- P2P message handlers
        CreateRoom ->
            ( { model | p2pState = P2PCreatingRoom }
            , Ports.createRoom ()
            )

        JoinRoom ->
            let
                roomCode =
                    String.toUpper model.roomCodeInput
            in
            if String.length roomCode == 4 then
                ( { model | p2pState = P2PJoiningRoom roomCode }
                , Ports.joinRoom roomCode
                )

            else
                ( model, Cmd.none )

        LeaveRoom ->
            ( { model | p2pState = P2PNotConnected }
            , Ports.leaveRoom ()
            )

        RoomCodeInputChanged str ->
            let
                -- Uppercase and limit to 4 characters
                normalized =
                    str
                        |> String.toUpper
                        |> String.filter Char.isAlpha
                        |> String.left 4

                -- Auto-join if we have exactly 4 characters
                ( newState, cmd ) =
                    if String.length normalized == 4 then
                        ( { model
                            | roomCodeInput = normalized
                            , p2pState = P2PJoiningRoom normalized
                          }
                        , Ports.joinRoom normalized
                        )

                    else
                        ( { model | roomCodeInput = normalized }
                        , Cmd.none
                        )
            in
            ( newState, cmd )

        GotRoomCreated roomCode ->
            -- Host: Initialize host game with roomCode as our peerId
            -- Also generate QR code for the room URL
            let
                roomUrl =
                    model.baseUrl ++ "?room=" ++ roomCode
            in
            ( { model
                | p2pState = P2PConnected Host roomCode
                , myPeerId = Just roomCode
                , localGame = Nothing  -- Clear local game
                , qrCodeDataUrl = Nothing  -- Reset QR code (will be generated)
                , copyCodeState = ShareUI.Ready
                , copyUrlState = ShareUI.Ready
              }
            , Cmd.batch
                [ Random.generate InitHostGame (HostGame.init roomCode)
                , Ports.generateQRCode roomUrl
                ]
            )

        GotPeerConnected value ->
            case JD.decodeValue peerConnectedDecoder value of
                Ok data ->
                    case data.role of
                        Host ->
                            -- A client connected to us (we are host)
                            -- Note: The host is already running game loop, add the player
                            case model.hostGame of
                                Just hostState ->
                                    -- Generate spawn position and name for new player
                                    let
                                        spawnGenerator =
                                            Random.map2
                                                (\pos name -> ( pos, name ))
                                                (randomSafePosition (HostGame.getOccupiedPositions hostState) hostState.grid)
                                                HostGame.generatePlayerName
                                    in
                                    ( model
                                    , Random.generate (\( pos, name ) -> NewPlayerSpawn data.roomCode pos name) spawnGenerator
                                    )

                                Nothing ->
                                    ( model, Cmd.none )

                        Client ->
                            -- We connected to host as a client
                            ( { model
                                | p2pState = P2PConnected Client data.roomCode
                                , clientGame = Just (ClientGame.init data.myPeerId)
                                , myPeerId = Just data.myPeerId
                                , localGame = Nothing  -- Clear local game when joining as client
                              }
                            , Cmd.none
                            )

                Err _ ->
                    ( model, Cmd.none )

        GotPeerDisconnected peerId ->
            -- Check if we're host (a client left) or client (we disconnected)
            case model.hostGame of
                Just hostState ->
                    -- We're host: mark player as disconnected (grace period starts)
                    let
                        newState =
                            HostGame.removePlayer peerId hostState
                    in
                    ( { model
                        | hostGame = Just newState
                        , notification = Just "Player left"
                      }
                    , Process.sleep 3000
                        |> Task.perform (\_ -> ClearNotification)
                    )

                Nothing ->
                    -- We're client: we got disconnected from host
                    ( { model
                        | p2pState = P2PNotConnected
                        , clientGame = Nothing
                        , notification = Just "Disconnected from host"
                      }
                    , Process.sleep 3000
                        |> Task.perform (\_ -> ClearNotification)
                    )

        GotConnectionError errorMsg ->
            let
                -- Reset state based on what we were trying to do
                newP2PState =
                    case model.p2pState of
                        P2PCreatingRoom ->
                            P2PNotConnected

                        P2PJoiningRoom _ ->
                            P2PNotConnected

                        _ ->
                            model.p2pState
            in
            ( { model
                | p2pState = newP2PState
                , notification = Just errorMsg
              }
            , Process.sleep 5000
                |> Task.perform (\_ -> ClearNotification)
            )

        CopyRoomCode ->
            case model.p2pState of
                P2PConnected _ roomCode ->
                    ( { model | copyCodeState = ShareUI.Copied }
                    , Cmd.batch
                        [ Ports.copyToClipboard roomCode
                        , Process.sleep 2000 |> Task.perform (\_ -> HideCopiedCodeFeedback)
                        ]
                    )

                _ ->
                    ( model, Cmd.none )

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
                    )

                _ ->
                    ( model, Cmd.none )

        GotClipboardCopySuccess _ ->
            -- Feedback is now handled by the individual copy handlers
            ( model, Cmd.none )

        HideCopiedCodeFeedback ->
            ( { model | copyCodeState = ShareUI.Ready, showCopiedFeedback = False }, Cmd.none )

        HideCopiedUrlFeedback ->
            ( { model | copyUrlState = ShareUI.Ready }, Cmd.none )

        GotQRCodeGenerated value ->
            -- Decode QR code generation result
            case JD.decodeValue qrCodeResultDecoder value of
                Ok result ->
                    if result.success then
                        ( { model | qrCodeDataUrl = result.dataUrl }, Cmd.none )

                    else
                        -- QR generation failed, log but don't crash
                        ( model, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        -- Host game message handlers
        InitHostGame hostState ->
            -- Host game initialized, spawn initial apples
            let
                applesNeeded =
                    Apple.minApples

                spawnCmd =
                    spawnHostAppleCommands applesNeeded (HostGame.getOccupiedPositions hostState) hostState.grid
            in
            ( { model
                | hostGame = Just hostState
                , pendingAppleSpawns = applesNeeded
              }
            , spawnCmd
            )

        HostTick _ ->
            case model.hostGame of
                Just hostState ->
                    let
                        tickResult =
                            HostGame.tick hostState

                        newState =
                            tickResult.state

                        -- Check if any snake needs respawn
                        snakesNeedingRespawn =
                            Dict.filter (\_ data -> data.needsRespawn) newState.snakes
                                |> Dict.keys

                        -- Check if we need to spawn apples
                        effectiveAppleCount =
                            List.length newState.apples + model.pendingAppleSpawns

                        applesNeeded =
                            max 0 (Apple.minApples - effectiveAppleCount + List.length tickResult.expiredApples)

                        ( newPendingCount, spawnCmd ) =
                            if applesNeeded > 0 then
                                ( model.pendingAppleSpawns + applesNeeded
                                , spawnHostAppleCommands applesNeeded (HostGame.getOccupiedPositions newState) newState.grid
                                )

                            else
                                ( model.pendingAppleSpawns, Cmd.none )

                        -- ALWAYS broadcast state to all connected peers (even during respawn ticks)
                        stateJson =
                            Protocol.encodeStateSync tickResult.stateSync |> JE.encode 0

                        broadcastCmd =
                            Ports.broadcastGameState stateJson
                    in
                    case List.head snakesNeedingRespawn of
                        Just playerId ->
                            -- Need random respawn position for this snake
                            -- Trigger collision shake animation
                            -- Still broadcast so clients see the death immediately
                            ( { model
                                | hostGame = Just newState
                                , showingCollision = True
                                , pendingAppleSpawns = newPendingCount
                              }
                            , Cmd.batch
                                [ broadcastCmd
                                , Random.generate (NewHostSpawnPosition playerId) (randomPosition newState.grid)
                                , Process.sleep 300 |> Task.perform (\_ -> ClearCollisionShake)
                                , spawnCmd
                                ]
                            )

                        Nothing ->
                            ( { model
                                | hostGame = Just newState
                                , pendingAppleSpawns = newPendingCount
                              }
                            , Cmd.batch [ broadcastCmd, spawnCmd ]
                            )

                Nothing ->
                    ( model, Cmd.none )

        NewHostSpawnPosition playerId pos ->
            case model.hostGame of
                Just hostState ->
                    let
                        newState =
                            HostGame.respawnSnake playerId pos hostState

                        -- Broadcast immediately after respawn so clients see the new state
                        stateSync =
                            HostGame.toStateSyncPayload False newState

                        stateJson =
                            Protocol.encodeStateSync stateSync |> JE.encode 0

                        broadcastCmd =
                            Ports.broadcastGameState stateJson
                    in
                    ( { model | hostGame = Just newState }, broadcastCmd )

                Nothing ->
                    ( model, Cmd.none )

        NewHostApplePosition pos ->
            case model.hostGame of
                Just hostState ->
                    let
                        apple =
                            { position = pos
                            , expiresAtTick = hostState.currentTick + Apple.ticksUntilExpiry
                            }

                        newState =
                            HostGame.addApple apple hostState
                    in
                    ( { model
                        | hostGame = Just newState
                        , pendingAppleSpawns = max 0 (model.pendingAppleSpawns - 1)
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        GotInputP2P jsonString ->
            -- Host receives input from client
            case model.hostGame of
                Just hostState ->
                    case JD.decodeString Protocol.decodeInput jsonString of
                        Ok inputPayload ->
                            let
                                newState =
                                    HostGame.bufferInput inputPayload.playerId inputPayload.direction hostState
                            in
                            ( { model | hostGame = Just newState }, Cmd.none )

                        Err _ ->
                            ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        GotGameStateP2P jsonString ->
            -- Client receives state from host
            case model.clientGame of
                Just clientState ->
                    case JD.decodeString Protocol.decodeStateSync jsonString of
                        Ok stateSync ->
                            let
                                newClientState =
                                    ClientGame.applyHostState stateSync clientState
                            in
                            ( { model | clientGame = Just newClientState }, Cmd.none )

                        Err _ ->
                            ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        NewPlayerSpawn peerId pos playerName ->
            -- Host: add a new player at the spawned position with whimsical name
            case model.hostGame of
                Just hostState ->
                    let
                        newState =
                            HostGame.addPlayer peerId playerName pos hostState

                        -- Broadcast immediately so new player and all clients see the state
                        stateSync =
                            HostGame.toStateSyncPayload True newState -- Full sync for new player

                        stateJson =
                            Protocol.encodeStateSync stateSync |> JE.encode 0

                        broadcastCmd =
                            Ports.broadcastGameState stateJson
                    in
                    ( { model
                        | hostGame = Just newState
                        , notification = Just (playerName ++ " joined!")
                      }
                    , Cmd.batch
                        [ broadcastCmd
                        , Process.sleep 3000 |> Task.perform (\_ -> ClearNotification)
                        ]
                    )

                Nothing ->
                    ( model, Cmd.none )

        -- Host migration messages
        GotHostMigration value ->
            case JD.decodeValue Protocol.decodeHostMigration value of
                Ok migration ->
                    case migration of
                        Protocol.BecomeHost { myPeerId, peers } ->
                            -- Transition from client to host
                            case model.clientGame of
                                Just clientState ->
                                    let
                                        hostState =
                                            HostGame.fromClientState
                                                myPeerId
                                                clientState.lastHostTick
                                                clientState.snakes
                                                clientState.apples
                                                clientState.scores

                                        -- Generate QR code for new host's room
                                        joinUrl =
                                            model.baseUrl ++ "?room=" ++ myPeerId

                                        qrCmd =
                                            Ports.generateQRCode joinUrl
                                    in
                                    ( { model
                                        | hostGame = Just hostState
                                        , clientGame = Nothing
                                        , p2pState = P2PConnected Host myPeerId
                                        , myPeerId = Just myPeerId
                                        , notification = Just "You are now the host"
                                        , qrCodeDataUrl = Nothing -- Reset to show loading while generating
                                      }
                                    , Cmd.batch
                                        [ qrCmd
                                        , Process.sleep 3000 |> Task.perform (\_ -> ClearNotification)
                                        ]
                                    )

                                Nothing ->
                                    -- No client game state, can't migrate
                                    ( model, Cmd.none )

                        Protocol.NewHost { newHostId } ->
                            -- Wait for new host to start broadcasting
                            -- Connection will be re-established automatically
                            ( { model
                                | notification = Just "Reconnecting to new host..."
                              }
                            , Process.sleep 3000 |> Task.perform (\_ -> ClearNotification)
                            )

                        Protocol.ConnectionLost ->
                            -- Show connection lost screen
                            ( { model
                                | screen = ConnectionLostScreen
                                , clientGame = Nothing
                                , hostGame = Nothing
                                , p2pState = P2PNotConnected
                              }
                            , Cmd.none
                            )

                Err _ ->
                    ( model, Cmd.none )

        CreateNewRoom ->
            -- From connection lost screen, create a new room
            ( { model
                | screen = GameScreen
                , p2pState = P2PCreatingRoom
              }
            , Ports.createRoom ()
            )

        GoHome ->
            -- From connection lost screen, go back to mode selection
            ( { model
                | screen = ModeSelectionScreen
                , p2pState = P2PNotConnected
                , selectedMode = Nothing
              }
            , Cmd.none
            )

        -- Mode selection messages
        SelectMode mode ->
            let
                selectedMode =
                    case mode of
                        ModeSelection.P2PMode ->
                            P2PSelected

                        ModeSelection.PhoenixMode ->
                            PhoenixSelected

                modeStr =
                    ModeSelection.modeToString mode

                -- Initialize based on selected mode
                ( newModel, initCmd ) =
                    case selectedMode of
                        P2PSelected ->
                            -- P2P: show connection UI, no game running yet
                            ( { model
                                | screen = GameScreen
                                , selectedMode = Just P2PSelected
                                , gameMode = LocalMode
                              }
                            , Cmd.none
                            )

                        PhoenixSelected ->
                            -- Phoenix: join online game
                            ( { model
                                | screen = GameScreen
                                , selectedMode = Just PhoenixSelected
                                , gameMode = OnlineMode
                                , connectionStatus = Connecting
                              }
                            , Ports.joinGame (JE.object [])
                            )
            in
            ( newModel
            , Cmd.batch [ Ports.saveMode modeStr, initCmd ]
            )

        OpenSettings ->
            ( { model | screen = SettingsScreen }, Cmd.none )

        CloseSettings ->
            ( { model | screen = GameScreen }, Cmd.none )

        ChangeMode mode ->
            let
                selectedMode =
                    case mode of
                        ModeSelection.P2PMode ->
                            P2PSelected

                        ModeSelection.PhoenixMode ->
                            PhoenixSelected

                modeStr =
                    ModeSelection.modeToString mode

                -- Reset game state when changing modes
                ( newModel, initCmd ) =
                    case selectedMode of
                        P2PSelected ->
                            -- Switch to P2P: reset game state
                            ( { model
                                | screen = GameScreen
                                , selectedMode = Just P2PSelected
                                , gameMode = LocalMode
                                , gameState = Nothing
                                , localGame = Nothing
                                , hostGame = Nothing
                                , clientGame = Nothing
                                , p2pState = P2PNotConnected
                                , connectionStatus = Disconnected
                              }
                            , Cmd.none
                            )

                        PhoenixSelected ->
                            -- Switch to Phoenix: join online game
                            ( { model
                                | screen = GameScreen
                                , selectedMode = Just PhoenixSelected
                                , gameMode = OnlineMode
                                , gameState = Nothing
                                , localGame = Nothing
                                , hostGame = Nothing
                                , clientGame = Nothing
                                , p2pState = P2PNotConnected
                                , connectionStatus = Connecting
                              }
                            , Ports.joinGame (JE.object [])
                            )
            in
            ( newModel
            , Cmd.batch [ Ports.saveMode modeStr, initCmd ]
            )


{-| Generate commands to spawn multiple apples for host game.
-}
spawnHostAppleCommands : Int -> List Position -> { width : Int, height : Int } -> Cmd Msg
spawnHostAppleCommands count occupied grid =
    if count <= 0 then
        Cmd.none

    else
        List.range 1 count
            |> List.map (\_ -> Random.generate NewHostApplePosition (Apple.randomSafePosition occupied grid))
            |> Cmd.batch


{-| Generate commands to spawn multiple apples.
-}
spawnAppleCommands : Int -> List Position -> { width : Int, height : Int } -> Cmd Msg
spawnAppleCommands count occupied grid =
    if count <= 0 then
        Cmd.none

    else
        List.range 1 count
            |> List.map (\_ -> Random.generate NewApplePosition (Apple.randomSafePosition occupied grid))
            |> Cmd.batch


{-| Generate a random position within grid bounds.
-}
randomPosition : { width : Int, height : Int } -> Random.Generator Position
randomPosition grid =
    Random.map2 Position
        (Random.int 2 (grid.width - 1))
        (Random.int 0 (grid.height - 1))


{-| Generate a random position that avoids occupied positions.
Uses Apple.randomSafePosition for consistency.
-}
randomSafePosition : List Position -> { width : Int, height : Int } -> Random.Generator Position
randomSafePosition occupied grid =
    Apple.randomSafePosition occupied grid


type alias PlayerJoinedData =
    { id : String
    , name : String
    }


playerJoinedDecoder : JD.Decoder PlayerJoinedData
playerJoinedDecoder =
    JD.field "player"
        (JD.map2 PlayerJoinedData
            (JD.field "id" (JD.map String.fromInt JD.int))
            (JD.field "name" JD.string)
        )


type alias TickData =
    { snakes : List Snake.Snake
    , apples : List Game.Apple
    }


tickDecoder : JD.Decoder TickData
tickDecoder =
    JD.map2 TickData
        (JD.field "snakes" (JD.list Snake.decoder))
        (JD.field "apples" (JD.list Game.appleDecoder))


{-| Result from QR code generation port.
-}
type alias QRCodeResult =
    { success : Bool
    , dataUrl : Maybe String
    }


qrCodeResultDecoder : JD.Decoder QRCodeResult
qrCodeResultDecoder =
    JD.map2 QRCodeResult
        (JD.field "success" JD.bool)
        (JD.maybe (JD.field "dataUrl" JD.string))


{-| Decoder for peerConnected events from JavaScript.
    Host receives: { role: "host", peerId: "XXXX" } - peerId is the connecting client
    Client receives: { role: "client", roomCode: "XXXX", myPeerId: "..." } - myPeerId is our own ID
-}
peerConnectedDecoder : JD.Decoder { role : P2PRole, roomCode : String, myPeerId : String }
peerConnectedDecoder =
    JD.map3 (\role roomCode myPeerId -> { role = role, roomCode = roomCode, myPeerId = myPeerId })
        (JD.field "role" (JD.string |> JD.andThen roleDecoder))
        (JD.oneOf
            [ JD.field "roomCode" JD.string
            , JD.field "peerId" JD.string  -- host receives peerId from connecting client
            ]
        )
        (JD.oneOf
            [ JD.field "myPeerId" JD.string
            , JD.succeed ""  -- host doesn't send myPeerId, use empty string
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


view : Model -> Html Msg
view model =
    case model.screen of
        ModeSelectionScreen ->
            viewModeSelectionScreen

        SettingsScreen ->
            viewSettingsScreen model

        GameScreen ->
            viewGameScreen model

        ConnectionLostScreen ->
            viewConnectionLostScreen


{-| Mode selection screen (first visit).
-}
viewModeSelectionScreen : Html Msg
viewModeSelectionScreen =
    div [ class "game-container mode-selection-page", style "padding" "20px" ]
        [ h1 [] [ text "Snaker" ]
        , ModeSelection.view { onSelectMode = SelectMode }
        ]


{-| Settings screen for changing mode preference.
-}
viewSettingsScreen : Model -> Html Msg
viewSettingsScreen model =
    div [ class "game-container settings-page", style "padding" "20px" ]
        [ h1 [] [ text "Settings" ]
        , div [ class "settings-content" ]
            [ h2 [] [ text "Game Mode" ]
            , p [ class "current-mode" ]
                [ text "Current mode: "
                , text
                    (case model.selectedMode of
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
                        (if model.selectedMode == Just P2PSelected then
                            "mode-option-button selected"

                         else
                            "mode-option-button"
                        )
                    , onClick (ChangeMode ModeSelection.P2PMode)
                    ]
                    [ text "Direct Connect" ]
                , button
                    [ class
                        (if model.selectedMode == Just PhoenixSelected then
                            "mode-option-button selected"

                         else
                            "mode-option-button"
                        )
                    , onClick (ChangeMode ModeSelection.PhoenixMode)
                    ]
                    [ text "Classic Online" ]
                ]
            , button [ class "btn-back", onClick CloseSettings ]
                [ text "Back to Game" ]
            ]
        ]


{-| Connection lost screen when all peers disconnect.
-}
viewConnectionLostScreen : Html Msg
viewConnectionLostScreen =
    div [ class "game-container connection-lost-page", style "padding" "20px", style "text-align" "center" ]
        [ h1 [] [ text "Connection Lost" ]
        , p [ style "margin" "20px 0", style "color" "#666" ]
            [ text "Lost connection to all players." ]
        , div [ class "connection-lost-buttons", style "display" "flex", style "gap" "12px", style "justify-content" "center" ]
            [ button [ class "btn-create", onClick CreateNewRoom ]
                [ text "Create New Room" ]
            , button [ class "btn-cancel", onClick GoHome ]
                [ text "Go Home" ]
            ]
        ]


{-| Main game screen with connection UI and game board.
-}
viewGameScreen : Model -> Html Msg
viewGameScreen model =
    div [ class "game-container", style "padding" "20px" ]
        [ div [ class "game-header" ]
            [ h1 [] [ text "Snaker - Elm 0.19.1" ]
            , button [ class "btn-settings", onClick OpenSettings ]
                [ text "Settings" ]
            ]
        , -- Only show P2P connection UI in P2P mode
          case model.selectedMode of
            Just P2PSelected ->
                ConnectionUI.view
                    { p2pState = model.p2pState
                    , roomCodeInput = model.roomCodeInput
                    , showCopiedFeedback = model.showCopiedFeedback
                    , onCreateRoom = CreateRoom
                    , onJoinRoom = JoinRoom
                    , onLeaveRoom = LeaveRoom
                    , onRoomCodeInput = RoomCodeInputChanged
                    , onCopyRoomCode = CopyRoomCode
                    }

            Just PhoenixSelected ->
                div [ class "connection-status" ]
                    [ text ("Phoenix: " ++ connectionStatusToString model.connectionStatus) ]

            Nothing ->
                text ""
        , viewStatus model
        , case model.error of
            Just err ->
                div [ style "color" "red" ] [ text ("Error: " ++ err) ]

            Nothing ->
                text ""
        , viewGame model
        , -- Show ShareUI BELOW the board when connected as host
          case ( model.selectedMode, model.p2pState ) of
            ( Just P2PSelected, P2PConnected Host roomCode ) ->
                ShareUI.view
                    { roomCode = roomCode
                    , qrCodeDataUrl = model.qrCodeDataUrl
                    , copyCodeState = model.copyCodeState
                    , copyUrlState = model.copyUrlState
                    , onCopyCode = CopyRoomCode
                    , onCopyUrl = CopyRoomUrl
                    }

            _ ->
                text ""
        , Notifications.view model.notification
        ]


viewStatus : Model -> Html Msg
viewStatus model =
    div [ class "game-status" ]
        [ case model.hostGame of
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
                case model.clientGame of
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
                            [ case model.gameMode of
                                LocalMode ->
                                    text "Mode: Local (offline)"

                                OnlineMode ->
                                    text ("Status: " ++ connectionStatusToString model.connectionStatus)
                            , case model.playerId of
                                Just pid ->
                                    text (" | Player ID: " ++ pid)

                                Nothing ->
                                    text ""
                            , case model.localGame of
                                Just localState ->
                                    span []
                                        [ text (" | Tick: " ++ String.fromInt localState.currentTick)
                                        , text (" | Score: " ++ String.fromInt localState.score)
                                        ]

                                Nothing ->
                                    text ""
                            ]
        ]


viewGame : Model -> Html Msg
viewGame model =
    let
        -- Wrap game board with collision shake class if collision is happening
        wrapWithShake content =
            if model.showingCollision then
                div [ class "game-board-wrapper collision-shake" ] [ content ]

            else
                content
    in
    -- Check if hosting P2P game first
    case model.hostGame of
        Just hostState ->
            let
                gameState =
                    HostGame.toGameState hostState
            in
            div [ class "game-layout" ]
                [ wrapWithShake (Board.viewWithLeader gameState model.myPeerId gameState.leaderId)
                , Scoreboard.view gameState.snakes model.myPeerId
                ]

        Nothing ->
            -- Check if we're a client
            case model.clientGame of
                Just clientState ->
                    let
                        gameState =
                            ClientGame.toGameState clientState
                    in
                    div [ class "game-layout" ]
                        [ wrapWithShake (Board.viewWithLeader gameState model.myPeerId gameState.leaderId)
                        , Scoreboard.view gameState.snakes model.myPeerId
                        ]

                Nothing ->
                    case model.gameMode of
                        LocalMode ->
                            case model.localGame of
                                Just localState ->
                                    let
                                        gameState =
                                            LocalGame.toGameState localState
                                    in
                                    div [ class "game-layout" ]
                                        [ wrapWithShake (Board.view gameState model.playerId)
                                        , Scoreboard.view gameState.snakes model.playerId
                                        ]

                                Nothing ->
                                    -- No game yet - user needs to create or join a room
                                    text ""

                        OnlineMode ->
                            case model.gameState of
                                Just state ->
                                    div [ class "game-layout" ]
                                        [ wrapWithShake (Board.view state model.playerId)
                                        , Scoreboard.view state.snakes model.playerId
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


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Browser.Events.onKeyDown (JD.map KeyPressed Input.keyDecoder)
          -- Tick subscription depends on game mode and P2P state
        , case model.p2pState of
            P2PConnected Host _ ->
                -- Host: use HostTick for multi-player game loop
                Time.every 100 HostTick

            P2PConnected Client _ ->
                -- Client: no tick (host drives the loop), just receive state
                Sub.none

            _ ->
                case model.gameMode of
                    LocalMode ->
                        -- Local game tick at 100ms intervals
                        Time.every 100 Tick

                    OnlineMode ->
                        Sub.none
        , Ports.receiveGameState GotGameState
        , Ports.receiveError GotError
        , Ports.playerJoined PlayerJoined
        , Ports.playerLeft PlayerLeft
        , Ports.receiveTick GotTick
          -- P2P subscriptions
        , Ports.roomCreated GotRoomCreated
        , Ports.peerConnected GotPeerConnected
        , Ports.peerDisconnected GotPeerDisconnected
        , Ports.connectionError GotConnectionError
        , Ports.clipboardCopySuccess (\_ -> GotClipboardCopySuccess ShareUI.CopyCode)
        , Ports.receiveInputP2P GotInputP2P
        , Ports.receiveGameStateP2P GotGameStateP2P
          -- Host migration
        , Ports.hostMigration GotHostMigration
          -- QR code generation
        , Ports.qrCodeGenerated GotQRCodeGenerated
          -- Touch controls
        , Ports.receiveTouchDirection (stringToDirection >> KeyPressed)
        ]


{-| Convert string direction from touch controls to Maybe Direction.
-}
stringToDirection : String -> Maybe Direction
stringToDirection str =
    case str of
        "up" ->
            Just Up

        "down" ->
            Just Down

        "left" ->
            Just Left

        "right" ->
            Just Right

        _ ->
            Nothing


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


{-| Decoder for Flags from JavaScript.
    Handles the nullable savedMode string and baseUrl.
-}
flagsDecoder : JD.Decoder Flags
flagsDecoder =
    JD.map2 Flags
        (JD.field "savedMode" (JD.nullable JD.string))
        (JD.field "baseUrl" JD.string)
