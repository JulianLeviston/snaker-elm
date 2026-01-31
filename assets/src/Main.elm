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
import Snake exposing (Direction(..))


type alias Model =
    { gameState : Maybe GameState
    , playerId : Maybe String
    , currentDirection : Direction
    , connectionStatus : ConnectionStatus
    , error : Maybe String
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


init : () -> ( Model, Cmd Msg )
init _ =
    ( { gameState = Nothing
      , playerId = Nothing
      , currentDirection = Right
      , connectionStatus = Disconnected
      , error = Nothing
      }
    , Cmd.none
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
                    let
                        _ =
                            Debug.log "Direction change" (Snake.directionToString dir)
                    in
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

                Err err ->
                    let
                        _ =
                            Debug.log "Decode error" (JD.errorToString err)
                    in
                    ( model, Cmd.none )

        GotError errorMsg ->
            ( { model | error = Just errorMsg }, Cmd.none )

        PlayerJoined _ ->
            -- Will handle in Phase 3
            ( model, Cmd.none )

        PlayerLeft _ ->
            -- Will handle in Phase 3
            ( model, Cmd.none )

        GotTick value ->
            -- Will handle in Phase 3
            let
                _ =
                    Debug.log "Tick received" value
            in
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    div [ class "game-container", style "padding" "20px" ]
        [ h1 [] [ text "Snaker - Elm 0.19.1" ]
        , div []
            [ text ("Status: " ++ connectionStatusToString model.connectionStatus) ]
        , div []
            [ text ("Direction: " ++ Snake.directionToString model.currentDirection) ]
        , case model.error of
            Just err ->
                div [ style "color" "red" ] [ text ("Error: " ++ err) ]

            Nothing ->
                text ""
        , case model.gameState of
            Just state ->
                div []
                    [ text ("Snakes: " ++ String.fromInt (List.length state.snakes))
                    , text (", Apples: " ++ String.fromInt (List.length state.apples))
                    ]

            Nothing ->
                div [] [ text "Waiting for game state..." ]
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
