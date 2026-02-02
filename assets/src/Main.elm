module Main exposing (main)

import Browser
import Browser.Events
import Game exposing (GameState)
import Html exposing (Html, div, h1, text)
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
                        newState =
                            LocalGame.tick localState
                    in
                    if newState.needsRespawn then
                        -- Need random respawn position
                        ( { model | localGame = Just newState }
                        , Random.generate NewSpawnPosition (randomPosition newState.grid)
                        )

                    else
                        ( { model | localGame = Just newState }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        InitGame localState ->
            ( { model | localGame = Just localState }, Cmd.none )

        NewSpawnPosition pos ->
            case model.localGame of
                Just localState ->
                    let
                        snake =
                            localState.snake

                        respawnedSnake =
                            { snake
                                | body = [ pos ]
                                , direction = Right
                                , pendingGrowth = 0
                                , isInvincible = True
                            }

                        newState =
                            { localState
                                | snake = respawnedSnake
                                , invincibleUntilTick = localState.currentTick + 15
                                , needsRespawn = False
                            }
                    in
                    ( { model | localGame = Just newState }, Cmd.none )

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
                text (" | Tick: " ++ String.fromInt localState.currentTick)

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
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
