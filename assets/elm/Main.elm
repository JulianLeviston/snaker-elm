module Main exposing (main)

import Html exposing (Html, text)
import Html.Attributes exposing (style)
import Time
import Keyboard
import Random
import Dict exposing (Dict)
import Data.Direction as Direction
import Data.Board as Board exposing (Board)
import Data.Player as Player exposing (Player, PlayerId)
import Board.Html
import Phoenix.Socket as Socket exposing (Socket)
import Phoenix.Channel as Channel
import Phoenix.Push as Push
import Json.Encode as JE
import Json.Decode as JD


-- model


type alias Model =
    { board : Board
    , phxSocket : Socket Msg
    }


type ServerMsg
    = JoinGame
    | NewPlayerJoined
    | PlayerLeft


init : ( Model, Cmd Msg )
init =
    let
        initialSocket =
            Socket.init "ws://Stagger:4000/socket/websocket"
                |> Socket.withDebug
                |> Socket.on "join" "game:snake" (DispatchServerMsg JoinGame)
                |> Socket.on "player:join" "game:snake" (DispatchServerMsg NewPlayerJoined)
                |> Socket.on "player:leave" "game:snake" (DispatchServerMsg PlayerLeft)

        channel =
            Channel.init "game:snake"

        ( phxSocket, cmd ) =
            Socket.join channel initialSocket
    in
        ( { board = Board.init
          , phxSocket = phxSocket
          }
        , Cmd.map PhoenixMsg cmd
        )



-- update


type Msg
    = BoardMsg Board.Msg
    | PhoenixMsg (Socket.Msg Msg)
    | DispatchServerMsg ServerMsg JE.Value
    | Noop


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        BoardMsg boardMsg ->
            let
                ( newBoard, boardCmds ) =
                    Board.update boardMsg model.board
            in
                ( { model | board = newBoard }
                , Cmd.map BoardMsg boardCmds
                )

        PhoenixMsg msg ->
            let
                ( phxSocket, phxCmd ) =
                    Socket.update msg model.phxSocket
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg phxCmd
                )

        DispatchServerMsg msg jsonEncodeValue ->
            serverUpdate msg jsonEncodeValue model

        Noop ->
            ( model, Cmd.none )


serverUpdate : ServerMsg -> JE.Value -> Model -> ( Model, Cmd Msg )
serverUpdate msg raw model =
    case msg of
        JoinGame ->
            case JD.decodeValue joinGameDecoder raw of
                Ok ( player, playersDict ) ->
                    let
                        ( newBoard1, boardCmd1 ) =
                            Board.update (Board.toSetCurrentPlayerMsg player) model.board

                        newCmd1 =
                            Cmd.map BoardMsg boardCmd1

                        ( newBoard2, boardCmd2 ) =
                            Board.update (Board.toSetupPlayersMsg playersDict) newBoard1

                        newCmd2 =
                            Cmd.map BoardMsg boardCmd2

                        newModel =
                            { model | board = newBoard2 }
                    in
                        ( newModel, Cmd.batch [ newCmd1, newCmd2 ] )

                Err _ ->
                    ( model, Cmd.none )

        NewPlayerJoined ->
            case JD.decodeValue objectWithPlayerDecoder raw of
                Ok player ->
                    let
                        ( newBoard, boardCmd ) =
                            Board.update (Board.toSetupNewPlayerMsg player) model.board
                    in
                        ( { model | board = newBoard }, Cmd.map BoardMsg boardCmd )

                Err _ ->
                    ( model, Cmd.none )

        PlayerLeft ->
            case JD.decodeValue objectWithPlayerDecoder raw of
                Ok player ->
                    let
                        ( newBoard, boardCmd ) =
                            Board.update (Board.toRemovePlayerMsg player) model.board
                    in
                        ( { model | board = newBoard }, Cmd.map BoardMsg boardCmd )

                Err _ ->
                    ( model, Cmd.none )


joinGameDecoder : JD.Decoder ( Player, Dict PlayerId Player )
joinGameDecoder =
    JD.map2 (,)
        (JD.field "player" Player.playerDecoder)
        (JD.field "players" Player.playerDictDecoder)


objectWithPlayerDecoder : JD.Decoder Player
objectWithPlayerDecoder =
    JD.field "player" Player.playerDecoder



-- subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ tickBoardSubscription
        , keyboardBoardControlSubscription
        , Socket.listen model.phxSocket PhoenixMsg
        ]


tickBoardSubscription : Sub Msg
tickBoardSubscription =
    Time.every Board.tickDuration (BoardMsg << Board.tickBoardMsg)


keyboardBoardControlSubscription : Sub Msg
keyboardBoardControlSubscription =
    Keyboard.ups keyCodeToChangeDirectionMsg


keyCodeToChangeDirectionMsg : Keyboard.KeyCode -> Msg
keyCodeToChangeDirectionMsg keyCode =
    let
        maybeDirection =
            Direction.keyCodeToMaybeDirection keyCode
    in
        case maybeDirection of
            Nothing ->
                Noop

            Just direction ->
                BoardMsg (Board.toChangeDirectionMsg direction)



-- view


view : Model -> Html Msg
view { board } =
    Html.map BoardMsg <| Board.Html.view board



-- main


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
