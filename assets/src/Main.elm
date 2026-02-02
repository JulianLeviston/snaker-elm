module Main exposing (main)

import Browser
import Browser.Events
import Engine.Apple as Apple exposing (Apple)
import Game exposing (GameState)
import Html exposing (Html, div, h1, span, text)
import Html.Attributes exposing (class, style)
import Input
import Json.Decode as JD
import Json.Encode as JE
import LocalGame exposing (LocalGameState)
import Ports
import Process
import Random
import Snake exposing (Direction(..), Position)
import Task
import Time
import View.Board as Board
import View.Notifications as Notifications
import View.Scoreboard as Scoreboard


type alias Model =
    { gameState : Maybe GameState
    , localGame : Maybe LocalGameState
    , playerId : Maybe String
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
    }


{-| P2P connection state machine
-}
type P2PConnectionState
    = P2PNotConnected
    | P2PCreatingRoom
    | P2PJoiningRoom String  -- room code being joined
    | P2PConnected P2PRole String  -- role and room code


{-| Role in P2P game (host runs game logic, client syncs)
-}
type P2PRole
    = Host
    | Client


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
    | GotClipboardCopySuccess
    | HideCopiedFeedback


init : () -> ( Model, Cmd Msg )
init _ =
    -- Start in local mode by default (online mode will be phase 7)
    ( { gameState = Nothing
      , localGame = Nothing
      , playerId = Just "local"
      , currentDirection = Right
      , connectionStatus = Connected
      , error = Nothing
      , notification = Nothing
      , gameMode = LocalMode
      , pendingAppleSpawns = 0
      -- P2P initial state
      , p2pState = P2PNotConnected
      , roomCodeInput = ""
      , showCopiedFeedback = False
      }
    , Random.generate InitGame LocalGame.init
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
                        -- Need random respawn position
                        ( { model | localGame = Just newState }
                        , Random.generate NewSpawnPosition (randomPosition newState.grid)
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
            ( { model | p2pState = P2PConnected Host roomCode }
            , Cmd.none
            )

        GotPeerConnected value ->
            case JD.decodeValue peerConnectedDecoder value of
                Ok data ->
                    ( { model | p2pState = P2PConnected data.role data.roomCode }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        GotPeerDisconnected _ ->
            ( { model
                | p2pState = P2PNotConnected
                , notification = Just "Disconnected"
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
                    ( model, Ports.copyToClipboard roomCode )

                _ ->
                    ( model, Cmd.none )

        GotClipboardCopySuccess ->
            ( { model | showCopiedFeedback = True }
            , Process.sleep 2000
                |> Task.perform (\_ -> HideCopiedFeedback)
            )

        HideCopiedFeedback ->
            ( { model | showCopiedFeedback = False }, Cmd.none )


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
        (Random.int 0 (grid.width - 1))
        (Random.int 0 (grid.height - 1))


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


{-| Decoder for peerConnected events from JavaScript.
    Host receives: { role: "host", peerId: "XXXX" }
    Client receives: { role: "client", roomCode: "XXXX" }
-}
peerConnectedDecoder : JD.Decoder { role : P2PRole, roomCode : String }
peerConnectedDecoder =
    JD.map2 (\role roomCode -> { role = role, roomCode = roomCode })
        (JD.field "role" (JD.string |> JD.andThen roleDecoder))
        (JD.oneOf
            [ JD.field "roomCode" JD.string
            , JD.field "peerId" JD.string  -- host receives peerId from connecting client
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
    div [ class "game-container", style "padding" "20px" ]
        [ h1 [] [ text "Snaker - Elm 0.19.1" ]
        , viewStatus model
        , case model.error of
            Just err ->
                div [ style "color" "red" ] [ text ("Error: " ++ err) ]

            Nothing ->
                text ""
        , viewGame model
        , Notifications.view model.notification
        ]


viewStatus : Model -> Html Msg
viewStatus model =
    div [ class "game-status" ]
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


viewGame : Model -> Html Msg
viewGame model =
    case model.gameMode of
        LocalMode ->
            case model.localGame of
                Just localState ->
                    let
                        gameState =
                            LocalGame.toGameState localState
                    in
                    div [ class "game-layout" ]
                        [ Board.view gameState model.playerId
                        , Scoreboard.view gameState.snakes model.playerId
                        ]

                Nothing ->
                    div [] [ text "Initializing game..." ]

        OnlineMode ->
            case model.gameState of
                Just state ->
                    div [ class "game-layout" ]
                        [ Board.view state model.playerId
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
        , case model.gameMode of
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
        , Ports.clipboardCopySuccess (\_ -> GotClipboardCopySuccess)
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
