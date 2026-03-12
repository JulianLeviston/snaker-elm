module Main exposing (main)

import Browser
import Browser.Events
import Dict
import Engine.Apple as Apple exposing (Apple)
import Engine.PowerUp as PowerUp
import Engine.Spawn as Spawn
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
import View.ConnectionLostScreen
import View.ConnectionUI as ConnectionUI exposing (P2PConnectionState(..), P2PRole(..))
import View.GameScreen
import View.InfoScreen
import View.ModeSelection as ModeSelection
import View.SettingsScreen
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
                            [ Random.generate NewSpawnPosition (Spawn.randomPosition newState.grid)
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
                                    , Spawn.spawnAppleCommands NewApplePosition applesNeeded (LocalGame.getOccupiedPositions newState) newState.grid
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
                    Spawn.spawnAppleCommands NewApplePosition applesNeeded (LocalGame.getOccupiedPositions localState) localState.grid
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
                    Spawn.spawnAppleCommands NewHostApplePosition applesNeeded (HostGame.getOccupiedPositions hostState) hostState.grid
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
                                , Spawn.spawnAppleCommands NewHostApplePosition applesNeeded (HostGame.getOccupiedPositions newState) newState.grid
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
                                 , Random.generate (NewHostSpawnPosition playerId) (Spawn.randomPosition newState.grid)
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
                                (Apple.randomSafePosition (HostGame.getOccupiedPositions hostState) hostState.grid)
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
            let
                selectedModeForView =
                    case model.selectedMode of
                        Just P2PSelected ->
                            Just View.SettingsScreen.P2PSelected

                        Just PhoenixSelected ->
                            Just View.SettingsScreen.PhoenixSelected

                        Nothing ->
                            Nothing
            in
            View.SettingsScreen.view
                { hostGame = model.hostGame
                , selectedMode = selectedModeForView
                , onToggleVenom = ToggleVenomMode
                , onChangeMode = ChangeMode
                , onClose = CloseSettings
                }

        GameScreen ->
            let
                selectedModeForView =
                    case model.selectedMode of
                        Just P2PSelected ->
                            Just View.GameScreen.P2PSelected

                        Just PhoenixSelected ->
                            Just View.GameScreen.PhoenixSelected

                        Nothing ->
                            Nothing

                gameModeForView =
                    case model.gameMode of
                        LocalMode ->
                            View.GameScreen.LocalMode

                        OnlineMode ->
                            View.GameScreen.OnlineMode

                connectionStatusForView =
                    case model.connectionStatus of
                        Disconnected ->
                            View.GameScreen.Disconnected

                        Connecting ->
                            View.GameScreen.Connecting

                        Connected ->
                            View.GameScreen.Connected
            in
            View.GameScreen.view
                { hostGame = model.hostGame
                , clientGame = model.clientGame
                , localGame = model.localGame
                , gameState = model.gameState
                , gameMode = gameModeForView
                , myPeerId = model.myPeerId
                , myId = model.playerId
                , selectedMode = selectedModeForView
                , p2pState = model.p2p.p2pState
                , roomCodeInput = model.p2p.roomCodeInput
                , showCopiedFeedback = model.p2p.showCopiedFeedback
                , qrCodeDataUrl = model.p2p.qrCodeDataUrl
                , connectionPanelCollapsed = model.p2p.connectionPanelCollapsed
                , showingCollision = model.showingCollision
                , connectionStatus = connectionStatusForView
                , error = model.error
                , notification = Notifications.view model.notification
                , copyCodeState = model.p2p.copyCodeState
                , copyUrlState = model.p2p.copyUrlState
                , onOpenInfo = OpenInfo
                , onOpenSettings = OpenSettings
                , onToggleConnectionPanel = P2PMsg P2P.ToggleConnectionPanel
                , onP2PMsg = P2PMsg
                , onError = GotError
                }

        ConnectionLostScreen ->
            View.ConnectionLostScreen.view { onCreateRoom = CreateNewRoom, onGoHome = GoHome }

        InfoScreen ->
            View.InfoScreen.view CloseInfo


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
