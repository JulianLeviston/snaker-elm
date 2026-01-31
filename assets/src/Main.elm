module Main exposing (main)

import Browser
import Browser.Events
import Game exposing (GameState)
import Html exposing (Html, div, h1, text)
import Html.Attributes exposing (class, style)
import Input
import Json.Decode as JD
import Json.Encode as JE
import Ports
import Process
import Snake exposing (Direction(..))
import Task
import View.Board as Board
import View.Notifications as Notifications
import View.Scoreboard as Scoreboard


type alias Model =
    { gameState : Maybe GameState
    , playerId : Maybe String
    , currentDirection : Direction
    , connectionStatus : ConnectionStatus
    , error : Maybe String
    , notification : Maybe String
    }


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


init : () -> ( Model, Cmd Msg )
init _ =
    ( { gameState = Nothing
      , playerId = Nothing
      , currentDirection = Right
      , connectionStatus = Connecting
      , error = Nothing
      , notification = Nothing
      }
    , Ports.joinGame (JE.object [])
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        JoinGame ->
            ( { model | connectionStatus = Connecting }
            , Ports.joinGame (JE.object [])
            )

        KeyPressed maybeDir ->
            case maybeDir of
                Just dir ->
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
                        -- Only show notification if this isn't our own join
                        notificationMsg =
                            if model.playerId == Nothing then
                                -- This is our join, don't show notification
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
                    in
                    ( { model
                        | playerId = Just playerData.id
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
        , div [ class "game-status" ]
            [ text ("Status: " ++ connectionStatusToString model.connectionStatus)
            , case model.playerId of
                Just pid ->
                    text (" | Player ID: " ++ pid)

                Nothing ->
                    text ""
            ]
        , case model.error of
            Just err ->
                div [ style "color" "red" ] [ text ("Error: " ++ err) ]

            Nothing ->
                text ""
        , case model.gameState of
            Just state ->
                div [ class "game-layout" ]
                    [ Board.view state model.playerId
                    , Scoreboard.view state.snakes model.playerId
                    ]

            Nothing ->
                div [] [ text "Waiting for game state..." ]
        , Notifications.view model.notification
        ]


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
subscriptions _ =
    Sub.batch
        [ Browser.Events.onKeyDown (JD.map KeyPressed Input.keyDecoder)
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
