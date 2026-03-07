module Main exposing (main)

import Browser
import Browser.Events
import Dict
import Engine.Apple as Apple exposing (Apple)
import Engine.PowerUp as PowerUp
import Engine.VenomType as VenomType
import Game exposing (GameState)
import Html exposing (Html, button, div, h1, h2, h3, p, span, text)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import Input
import Json.Decode as JD
import KillVerbs
import Json.Encode as JE
import LocalGame exposing (LocalGameState)
import Network.ClientGame as ClientGame exposing (ClientGameState)
import Network.HostGame as HostGame exposing (HostGameState)
import Network.Protocol as Protocol
import P2P.Connection as P2P
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
    , roomCode : Maybe String
    }


{-| Current screen being displayed.
-}
type Screen
    = ModeSelectionScreen
    | GameScreen
    | SettingsScreen
    | ConnectionLostScreen
    | InfoScreen


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
    , pendingPowerUpSpawns : Int -- Track in-flight power-up spawn calls
    , showingCollision : Bool  -- For collision shake animation
    -- Screen routing
    , screen : Screen
    , selectedMode : Maybe SelectedMode
    -- P2P connection state
    , p2p : P2P.Model
    }


type GameMode
    = LocalMode
    | OnlineMode


type ConnectionStatus
    = Disconnected
    | Connecting
    | Connected


type Msg
    = GameInput Input.InputAction
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
      -- P2P connection messages
    | P2PMsg P2P.Msg
      -- Host game messages
    | InitHostGame HostGameState
    | HostTick Time.Posix
    | NewHostSpawnPosition String Position
    | NewHostApplePosition Position
    | NewHostPowerUpPosition Position
    | GotInputP2P String
    | ShowKillNotification String String String  -- killer, verb, victim
    | ShowSelfKillNotification String String  -- victim, verb
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
      -- Game settings messages
    | ToggleVenomMode
      -- Info screen messages
    | OpenInfo
    | CloseInfo


init : Flags -> ( Model, Cmd Msg )
init flags =
    -- Check for room code in URL - if present, go to P2P mode
    -- (JS will trigger the actual join after ports are subscribed)
    case flags.roomCode of
        Just _ ->
            -- Room code in URL: go to P2P mode, JS will trigger join
            initWithMode flags.baseUrl P2PSelected

        Nothing ->
            -- No room code, check for saved mode
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
      , pendingPowerUpSpawns = 0
      , showingCollision = False
      , screen = ModeSelectionScreen
      , selectedMode = Nothing
      , p2p = P2P.init baseUrl
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
              , pendingPowerUpSpawns = 0
              , showingCollision = False
              , screen = GameScreen
              , selectedMode = Just P2PSelected
              , p2p = P2P.init baseUrl
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
              , pendingPowerUpSpawns = 0
              , showingCollision = False
              , screen = GameScreen
              , selectedMode = Just PhoenixSelected
              , p2p = P2P.init baseUrl
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
                                max 0 (Apple.minApples - effectiveAppleCount)
                                    |> min (Apple.maxApples - effectiveAppleCount)
                                    |> max 0

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
                            , spawnedAtTick = localState.currentTick
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

        GameInput action ->
            case action of
                Input.NoInput ->
                    ( model, Cmd.none )

                Input.DirectionInput dir ->
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

                                        inputMsg =
                                            Protocol.encodeGameMessage
                                                (Protocol.InputMessage
                                                    { playerId = clientState.myId
                                                    , direction = dir
                                                    , tick = clientState.lastHostTick
                                                    }
                                                )

                                        inputJson =
                                            JE.encode 0 inputMsg
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

                Input.ShootInput ->
                    -- Check if we're hosting a P2P game
                    case model.hostGame of
                        Just hostState ->
                            -- Host: buffer shot for own snake
                            let
                                newState =
                                    HostGame.bufferShot hostState.hostId hostState
                            in
                            ( { model | hostGame = Just newState }, Cmd.none )

                        Nothing ->
                            -- Check if we're a P2P client
                            case model.clientGame of
                                Just clientState ->
                                    -- Client: send shoot message to host
                                    let
                                        shootMsg =
                                            Protocol.encodeGameMessage
                                                (Protocol.ShootMessage
                                                    { playerId = clientState.myId
                                                    , tick = clientState.lastHostTick
                                                    }
                                                )

                                        shootJson =
                                            JE.encode 0 shootMsg
                                    in
                                    ( model, Ports.sendInputP2P shootJson )

                                Nothing ->
                                    -- Local mode: buffer shot
                                    case model.localGame of
                                        Just localState ->
                                            ( { model | localGame = Just (LocalGame.bufferShot localState) }, Cmd.none )

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

        ShowKillNotification killerName verb victimName ->
            ( { model | notification = Just (killerName ++ " " ++ verb ++ " " ++ victimName ++ "!") }
            , Process.sleep 3000 |> Task.perform (\_ -> ClearNotification)
            )

        ShowSelfKillNotification victimName verb ->
            ( { model | notification = Just (victimName ++ " " ++ verb ++ " themselves!") }
            , Process.sleep 3000 |> Task.perform (\_ -> ClearNotification)
            )

        -- P2P connection messages
        P2PMsg p2pMsg ->
            let
                ( newP2P, p2pCmd, effects ) =
                    P2P.update p2pMsg model.p2p

                modelWithP2P =
                    { model | p2p = newP2P }

                ( modelAfterEffects, effectCmds ) =
                    List.foldl applyP2PEffect ( modelWithP2P, [] ) effects
            in
            ( modelAfterEffects
            , Cmd.batch
                [ Cmd.map P2PMsg p2pCmd
                , Cmd.batch effectCmds
                ]
            )

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
                            max 0 (Apple.minApples - effectiveAppleCount)
                                |> min (Apple.maxApples - effectiveAppleCount)
                                |> max 0

                        ( newPendingCount, spawnCmd ) =
                            if applesNeeded > 0 then
                                ( model.pendingAppleSpawns + applesNeeded
                                , spawnHostAppleCommands applesNeeded (HostGame.getOccupiedPositions newState) newState.grid
                                )

                            else
                                ( model.pendingAppleSpawns, Cmd.none )

                        -- Check if we need to spawn a power-up
                        ( newPendingPowerUpCount, powerUpSpawnCmd ) =
                            if tickResult.needsPowerUpSpawn && model.pendingPowerUpSpawns == 0 then
                                ( model.pendingPowerUpSpawns + 1
                                , Random.generate NewHostPowerUpPosition (PowerUp.randomSafePosition (HostGame.getOccupiedPositions newState) newState.grid)
                                )

                            else
                                ( model.pendingPowerUpSpawns, Cmd.none )

                        -- ALWAYS broadcast state to all connected peers (even during respawn ticks)
                        stateJson =
                            Protocol.encodeStateSync tickResult.stateSync |> JE.encode 0

                        broadcastCmd =
                            Ports.broadcastGameState stateJson

                        -- Generate kill notifications for any kills this tick
                        killCmds =
                            tickResult.kills
                                |> List.map
                                    (\kill ->
                                        let
                                            verbGenerator =
                                                if kill.isVenomKill then
                                                    KillVerbs.generateVenom

                                                else
                                                    KillVerbs.generate
                                        in
                                        case kill.killerName of
                                            Just killerName ->
                                                Random.generate (\verb -> ShowKillNotification killerName verb kill.victimName) verbGenerator

                                            Nothing ->
                                                -- Self-kill
                                                Random.generate (\verb -> ShowSelfKillNotification kill.victimName verb) verbGenerator
                                    )
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
                                , pendingPowerUpSpawns = newPendingPowerUpCount
                              }
                            , Cmd.batch
                                ([ broadcastCmd
                                 , Random.generate (NewHostSpawnPosition playerId) (randomPosition newState.grid)
                                 , Process.sleep 300 |> Task.perform (\_ -> ClearCollisionShake)
                                 , spawnCmd
                                 , powerUpSpawnCmd
                                 ]
                                    ++ killCmds
                                )
                            )

                        Nothing ->
                            ( { model
                                | hostGame = Just newState
                                , pendingAppleSpawns = newPendingCount
                                , pendingPowerUpSpawns = newPendingPowerUpCount
                              }
                            , Cmd.batch ([ broadcastCmd, spawnCmd, powerUpSpawnCmd ] ++ killCmds)
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
                            , spawnedAtTick = hostState.currentTick
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

        NewHostPowerUpPosition pos ->
            case model.hostGame of
                Just hostState ->
                    let
                        ( kind, newSeed ) =
                            Random.step PowerUp.randomKind hostState.randomSeed

                        drop =
                            { position = pos
                            , kind = kind
                            , spawnedAtTick = hostState.currentTick
                            }

                        stateWithSeed =
                            { hostState | randomSeed = newSeed }

                        newState =
                            HostGame.addPowerUpDrop drop stateWithSeed
                    in
                    ( { model
                        | hostGame = Just newState
                        , pendingPowerUpSpawns = max 0 (model.pendingPowerUpSpawns - 1)
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        GotInputP2P jsonString ->
            -- Host receives input from client (direction or shoot)
            case model.hostGame of
                Just hostState ->
                    case JD.decodeString Protocol.decodeGameMessage jsonString of
                        Ok (Protocol.InputMessage inputPayload) ->
                            let
                                newState =
                                    HostGame.bufferInput inputPayload.playerId inputPayload.direction hostState
                            in
                            ( { model | hostGame = Just newState }, Cmd.none )

                        Ok (Protocol.ShootMessage shootPayload) ->
                            let
                                newState =
                                    HostGame.bufferShot shootPayload.playerId hostState
                            in
                            ( { model | hostGame = Just newState }, Cmd.none )

                        _ ->
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

                                -- Generate kill notifications for any kills this tick
                                killCmds =
                                    stateSync.kills
                                        |> List.map
                                            (\kill ->
                                                let
                                                    verbGenerator =
                                                        if kill.isVenomKill then
                                                            KillVerbs.generateVenom

                                                        else
                                                            KillVerbs.generate
                                                in
                                                case kill.killerName of
                                                    Just killerName ->
                                                        Random.generate (\verb -> ShowKillNotification killerName verb kill.victimName) verbGenerator

                                                    Nothing ->
                                                        -- Self-kill
                                                        Random.generate (\verb -> ShowSelfKillNotification kill.victimName verb) verbGenerator
                                            )
                            in
                            ( { model | clientGame = Just newClientState }
                            , Cmd.batch killCmds
                            )

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

                                        -- Preserve the original room code from when we joined
                                        originalRoomCode =
                                            case model.p2p.p2pState of
                                                P2PConnected _ roomCode ->
                                                    roomCode

                                                _ ->
                                                    myPeerId

                                        -- Generate QR code using original room code
                                        joinUrl =
                                            model.p2p.baseUrl ++ "?room=" ++ originalRoomCode

                                        qrCmd =
                                            Ports.generateQRCode joinUrl
                                    in
                                    let
                                        p2p =
                                            model.p2p
                                    in
                                    ( { model
                                        | hostGame = Just hostState
                                        , clientGame = Nothing
                                        , p2p = { p2p | p2pState = P2PConnected Host originalRoomCode, qrCodeDataUrl = Nothing }
                                        , myPeerId = Just myPeerId
                                        , notification = Just "You are now the host"
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
                                , p2p = P2P.reset model.p2p
                              }
                            , Cmd.none
                            )

                Err _ ->
                    ( model, Cmd.none )

        CreateNewRoom ->
            -- From connection lost screen, create a new room
            ( { model
                | screen = GameScreen
                , p2p = P2P.startCreating model.p2p
              }
            , Ports.createRoom ()
            )

        GoHome ->
            -- From connection lost screen, go back to mode selection
            ( { model
                | screen = ModeSelectionScreen
                , p2p = P2P.reset model.p2p
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
                                , p2p = P2P.reset model.p2p
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
                                , p2p = P2P.reset model.p2p
                                , connectionStatus = Connecting
                              }
                            , Ports.joinGame (JE.object [])
                            )
            in
            ( newModel
            , Cmd.batch [ Ports.saveMode modeStr, initCmd ]
            )

        ToggleVenomMode ->
            case model.hostGame of
                Just hostState ->
                    ( { model | hostGame = Just (HostGame.toggleVenomMode hostState) }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        OpenInfo ->
            ( { model | screen = InfoScreen }, Cmd.none )

        CloseInfo ->
            -- Return to ModeSelectionScreen if no mode selected, otherwise GameScreen
            let
                previousScreen =
                    case model.selectedMode of
                        Nothing ->
                            ModeSelectionScreen

                        Just _ ->
                            GameScreen
            in
            ( { model | screen = previousScreen }, Cmd.none )



{-| Apply a P2P effect to the main model, returning updated model and any commands.
-}
applyP2PEffect : P2P.Effect -> ( Model, List (Cmd Msg) ) -> ( Model, List (Cmd Msg) )
applyP2PEffect effect ( model, cmds ) =
    case effect of
        P2P.NoEffect ->
            ( model, cmds )

        P2P.RoomCreated roomCode ->
            ( { model
                | myPeerId = Just roomCode
                , localGame = Nothing
              }
            , Random.generate InitHostGame (HostGame.init roomCode) :: cmds
            )

        P2P.PeerConnectedAsHost peerId ->
            case model.hostGame of
                Just hostState ->
                    let
                        spawnGenerator =
                            Random.map2
                                (\pos name -> ( pos, name ))
                                (randomSafePosition (HostGame.getOccupiedPositions hostState) hostState.grid)
                                HostGame.generatePlayerName
                    in
                    ( model
                    , Random.generate (\( pos, name ) -> NewPlayerSpawn peerId pos name) spawnGenerator :: cmds
                    )

                Nothing ->
                    ( model, cmds )

        P2P.PeerConnectedAsClient roomCode myPeerId ->
            ( { model
                | clientGame = Just (ClientGame.init myPeerId)
                , myPeerId = Just myPeerId
                , localGame = Nothing
              }
            , cmds
            )

        P2P.PeerDisconnected peerId ->
            case model.hostGame of
                Just hostState ->
                    -- We're host: remove the player
                    let
                        newState =
                            HostGame.removePlayer peerId hostState
                    in
                    ( { model
                        | hostGame = Just newState
                        , notification = Just "Player left"
                      }
                    , (Process.sleep 3000 |> Task.perform (\_ -> ClearNotification)) :: cmds
                    )

                Nothing ->
                    -- We're client: disconnected from host
                    let
                        p2p =
                            model.p2p
                    in
                    ( { model
                        | p2p = P2P.reset p2p
                        , clientGame = Nothing
                        , notification = Just "Disconnected from host"
                      }
                    , (Process.sleep 3000 |> Task.perform (\_ -> ClearNotification)) :: cmds
                    )

        P2P.Notify message durationMs ->
            ( { model | notification = Just message }
            , (Process.sleep durationMs |> Task.perform (\_ -> ClearNotification)) :: cmds
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

        InfoScreen ->
            viewInfoScreen


{-| Mode selection screen (first visit).
-}
viewModeSelectionScreen : Html Msg
viewModeSelectionScreen =
    div [ class "game-container mode-selection-page", style "padding" "20px" ]
        [ h1 [] [ text "Snaker" ]
        , ModeSelection.view { onSelectMode = SelectMode }
        , div [ class "mode-selection-footer" ]
            [ button [ class "btn-info-link", onClick OpenInfo ]
                [ text "About this game" ]
            ]
        ]


{-| Settings screen for changing mode preference.
-}
viewSettingsScreen : Model -> Html Msg
viewSettingsScreen model =
    let
        venomEnabled =
            case model.hostGame of
                Just hostState ->
                    hostState.settings.venomMode

                Nothing ->
                    False
    in
    div [ class "game-container settings-page", style "padding" "20px" ]
        [ h1 [] [ text "Settings" ]
        , div [ class "settings-content" ]
            [ -- Game settings section (host only, P2P mode)
              case model.hostGame of
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
                                , onClick ToggleVenomMode
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


{-| Info screen with changelog and about sections.
-}
viewInfoScreen : Html Msg
viewInfoScreen =
    div [ class "game-container info-page", style "padding" "20px" ]
        [ div [ class "info-header" ]
            [ h1 [] [ text "About Snaker" ]
            , button [ class "btn-back", onClick CloseInfo ]
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
                        , Html.ul []
                            [ Html.li [] [ text "Venom power-up drops: V (purple, straight) and B (blue, ball) grant venom type + 1 segment growth" ]
                            , Html.li [] [ text "Ball venom mode with diagonal bouncing off walls (5s lifetime, randomized bounce angles)" ]
                            , Html.li [] [ text "Local mode venom support" ]
                            , Html.li [] [ text "Shoot key changed from spacebar to Shift" ]
                            , Html.li [] [ text "Ball projectile visibility and spawn wrapping fixes" ]
                            ]
                        ]
                    , div [ class "changelog-entry" ]
                        [ h3 [] [ text "v2.1 - Post-Launch Patches - 2026-02-05" ]
                        , Html.ul []
                            [ Html.li [] [ text "Apple aging lifecycle with skull penalty" ]
                            , Html.li [] [ text "Mobile fullscreen layout with QR watermark" ]
                            , Html.li [] [ text "Auto-join room from URL" ]
                            , Html.li [] [ text "Apple sync and max count fixes" ]
                            ]
                        ]
                    , div [ class "changelog-entry" ]
                        [ h3 [] [ text "v2.0 - P2P WebRTC Mode - 2026-02-03" ]
                        , Html.ul []
                            [ Html.li [] [ text "Direct peer-to-peer multiplayer (no server needed)" ]
                            , Html.li [] [ text "Room codes for easy game sharing" ]
                            , Html.li [] [ text "QR code support for mobile joining" ]
                            , Html.li [] [ text "Host migration when host leaves" ]
                            , Html.li [] [ text "Touch controls for mobile devices" ]
                            ]
                        ]
                    , div [ class "changelog-entry" ]
                        [ h3 [] [ text "v1.0 - Multiplayer Upgrade - 2017-08-15" ]
                        , Html.ul []
                            [ Html.li [] [ text "Phoenix server-based multiplayer" ]
                            , Html.li [] [ text "Real-time game synchronization" ]
                            , Html.li [] [ text "Player collision and death animations" ]
                            , Html.li [] [ text "Live scoreboard" ]
                            ]
                        ]
                    ]
                ]
            , div [ class "info-section about-section" ]
                [ h2 [] [ text "Credits" ]
                , p []
                    [ text "Created by "
                    , Html.a [ Html.Attributes.href "https://www.getcontented.com.au", Html.Attributes.target "_blank" ]
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


{-| Main game screen with connection UI and game board.
-}
viewGameScreen : Model -> Html Msg
viewGameScreen model =
    let
        p2p =
            model.p2p

        -- Get room code if connected
        maybeRoomCode =
            case p2p.p2pState of
                P2PConnected _ code ->
                    Just code

                _ ->
                    Nothing

        -- Collapse toggle icon
        collapseIcon =
            if p2p.connectionPanelCollapsed then
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
                        , onClick (P2PMsg P2P.ToggleConnectionPanel)
                        ]
                        [ text ("Room: " ++ code ++ " " ++ collapseIcon) ]

                Nothing ->
                    text ""
            , div [ class "header-buttons" ]
                [ button [ class "btn-info", onClick OpenInfo ]
                    [ text "?" ]
                , button [ class "btn-settings", onClick OpenSettings ]
                    [ text "Settings" ]
                ]
            ]
        , -- Only show P2P connection UI in P2P mode (collapsible on mobile)
          case model.selectedMode of
            Just P2PSelected ->
                div
                    [ class
                        (if p2p.connectionPanelCollapsed then
                            "connection-panel-wrapper collapsed"

                         else
                            "connection-panel-wrapper"
                        )
                    ]
                    [ Html.map P2PMsg
                        (ConnectionUI.view
                            { p2pState = p2p.p2pState
                            , roomCodeInput = p2p.roomCodeInput
                            , showCopiedFeedback = p2p.showCopiedFeedback
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
          case ( model.selectedMode, p2p.p2pState ) of
            ( Just P2PSelected, P2PConnected Host roomCode ) ->
                Html.map P2PMsg
                    (ShareUI.view
                        { roomCode = roomCode
                        , qrCodeDataUrl = p2p.qrCodeDataUrl
                        , copyCodeState = p2p.copyCodeState
                        , copyUrlState = p2p.copyUrlState
                        , onCopyCode = P2P.CopyRoomCode
                        , onCopyUrl = P2P.CopyRoomUrl
                        }
                    )

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

        -- QR code watermark overlay (only shown for host)
        qrWatermark =
            case model.p2p.qrCodeDataUrl of
                Just dataUrl ->
                    Html.img
                        [ class "qr-watermark"
                        , Html.Attributes.src dataUrl
                        , Html.Attributes.alt "Scan to join"
                        ]
                        []

                Nothing ->
                    text ""

        -- Check if we should show QR watermark (host with room)
        showQrWatermark =
            case model.p2p.p2pState of
                P2PConnected Host _ ->
                    True

                _ ->
                    False
    in
    -- Check if hosting P2P game first
    case model.hostGame of
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
                    , wrapWithShake (Board.viewWithProjectiles gameState model.myPeerId gameState.leaderId projectileStates gameState.snakes gameState.powerUpDrops)
                    ]
                , Scoreboard.view gameState.snakes gameState.scores model.myPeerId
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
                        [ div [ class "game-board-container" ]
                            [ wrapWithShake (Board.viewWithProjectiles gameState model.myPeerId gameState.leaderId clientState.projectiles gameState.snakes gameState.powerUpDrops)
                            ]
                        , Scoreboard.view gameState.snakes gameState.scores model.myPeerId
                        ]

                Nothing ->
                    case model.gameMode of
                        LocalMode ->
                            case model.localGame of
                                Just localState ->
                                    let
                                        gameState =
                                            LocalGame.toGameState localState

                                        projectileStates =
                                            LocalGame.toProjectileStates localState
                                    in
                                    div [ class "game-layout" ]
                                        [ div [ class "game-board-container" ]
                                            [ wrapWithShake (Board.viewWithProjectiles gameState model.playerId Nothing projectileStates gameState.snakes [])
                                            ]
                                        , Scoreboard.view gameState.snakes Dict.empty model.playerId
                                        ]

                                Nothing ->
                                    -- No game yet - user needs to create or join a room
                                    text ""

                        OnlineMode ->
                            case model.gameState of
                                Just state ->
                                    div [ class "game-layout" ]
                                        [ div [ class "game-board-container" ]
                                            [ wrapWithShake (Board.view state model.playerId)
                                            ]
                                        , Scoreboard.view state.snakes Dict.empty model.playerId
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
        [ Browser.Events.onKeyDown (JD.map GameInput Input.keyDecoder)
          -- Tick subscription depends on game mode and P2P state
        , case model.p2p.p2pState of
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
          -- P2P connection subscriptions
        , Sub.map P2PMsg P2P.subscriptions
          -- P2P game subscriptions (not part of connection module)
        , Ports.receiveInputP2P GotInputP2P
        , Ports.receiveGameStateP2P GotGameStateP2P
          -- Host migration
        , Ports.hostMigration GotHostMigration
          -- Touch controls
        , Ports.receiveTouchDirection (stringToInputAction >> GameInput)
        ]


{-| Convert string from touch controls to InputAction.
-}
stringToInputAction : String -> Input.InputAction
stringToInputAction str =
    case str of
        "up" ->
            Input.DirectionInput Up

        "down" ->
            Input.DirectionInput Down

        "left" ->
            Input.DirectionInput Left

        "right" ->
            Input.DirectionInput Right

        "shoot" ->
            Input.ShootInput

        _ ->
            Input.NoInput


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


{-| Decoder for Flags from JavaScript.
    Handles the nullable savedMode string, baseUrl, and nullable roomCode.
-}
flagsDecoder : JD.Decoder Flags
flagsDecoder =
    JD.map3 Flags
        (JD.field "savedMode" (JD.nullable JD.string))
        (JD.field "baseUrl" JD.string)
        (JD.field "roomCode" (JD.nullable JD.string))
