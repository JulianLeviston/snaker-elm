module Main exposing (main)

import Html exposing (Html, text)
import Html.Attributes exposing (style)
import Time
import Keyboard
import Random
import Dict exposing (Dict)
import Data.Direction as Direction exposing (Direction(..))
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
    | PlayerChangedDirection
    | SendChangeDirection


init : ( Model, Cmd Msg )
init =
    let
        initialSocket =
            Socket.init "ws://localhost:4000/socket/websocket"
                |> Socket.withDebug
                |> Socket.on "join" "game:snake" (DispatchServerMsg JoinGame)
                |> Socket.on "player:join" "game:snake" (DispatchServerMsg NewPlayerJoined)
                |> Socket.on "player:leave" "game:snake" (DispatchServerMsg PlayerLeft)
                |> Socket.on "player:change_direction" "game:snake" (DispatchServerMsg PlayerChangedDirection)

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

                updatedModel =
                    { model | board = newBoard }

                ( newModel, newCmd ) =
                    case boardMsg of
                        Board.ChangeDirection direction ->
                            updateToServer SendChangeDirection updatedModel

                        _ ->
                            ( updatedModel, Cmd.none )
            in
                ( newModel
                , Cmd.batch [ Cmd.map BoardMsg boardCmds, newCmd ]
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
            updateFromServer msg jsonEncodeValue model

        Noop ->
            ( model, Cmd.none )


updateFromServer : ServerMsg -> JE.Value -> Model -> ( Model, Cmd Msg )
updateFromServer msg raw model =
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

        PlayerChangedDirection ->
            case JD.decodeValue playerChangedDirectionDecoder raw of
                Ok ( playerId, direction ) ->
                    let
                        ( newBoard, boardCmd ) =
                            Board.update (Board.toChangePlayerDirectionMsg playerId direction) model.board
                    in
                        ( { model | board = newBoard }, Cmd.map BoardMsg boardCmd )

                Err _ ->
                    ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )


updateToServer : ServerMsg -> Model -> ( Model, Cmd Msg )
updateToServer msg model =
    case msg of
        SendChangeDirection ->
            let
                currentPlayerId =
                    Board.currentPlayerId model.board

                maybeCurrentDirection =
                    Board.directionOfPlayer currentPlayerId model.board
            in
                case maybeCurrentDirection of
                    Nothing ->
                        ( model, Cmd.none )

                    Just direction ->
                        let
                            stringDirection =
                                toString direction

                            payload =
                                JE.object
                                    [ ( "player_id", JE.int currentPlayerId )
                                    , ( "direction", JE.string stringDirection )
                                    ]

                            push_ =
                                Push.init "player:change_direction" "game:snake"
                                    |> Push.withPayload payload

                            ( phxSocket, phxCmd ) =
                                Socket.push push_ model.phxSocket
                        in
                            ( { model | phxSocket = phxSocket }, Cmd.map PhoenixMsg phxCmd )

        _ ->
            ( model, Cmd.none )


joinGameDecoder : JD.Decoder ( Player, Dict PlayerId Player )
joinGameDecoder =
    JD.map2 (,)
        (JD.field "player" Player.playerDecoder)
        (JD.field "players" Player.playerDictDecoder)


objectWithPlayerDecoder : JD.Decoder Player
objectWithPlayerDecoder =
    JD.field "player" Player.playerDecoder


playerChangedDirectionDecoder : JD.Decoder ( PlayerId, Direction )
playerChangedDirectionDecoder =
    JD.map2 (,)
        (JD.field "player_id" JD.int)
        (JD.field "direction"
            (JD.string
                |> JD.andThen
                    (\string ->
                        case Direction.fromString string of
                            Just direction ->
                                JD.succeed direction

                            Nothing ->
                                JD.fail "Direction not supplied"
                    )
            )
        )



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
