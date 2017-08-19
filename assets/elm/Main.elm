module Main exposing (main)

import Html exposing (Html, text)
import Html.Attributes exposing (style)
import Time
import Keyboard
import Random
import Dict exposing (Dict)
import Data.Direction as Direction
import Data.Board as Board exposing (Board)
import Board.Html


-- model


type alias Model =
    { board : Board
    }


init : ( Model, Cmd Msg )
init =
    ( { board = Board.init
      }
    , Cmd.none
    )



-- update


type Msg
    = BoardMsg Board.Msg
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

        Noop ->
            ( model, Cmd.none )



-- subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every Board.tickDuration (BoardMsg << Board.tickBoardMsg)
        , Keyboard.ups keyCodeToChangeDirectionMsg
        ]


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
