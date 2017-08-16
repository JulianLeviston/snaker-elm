module Main exposing (main)

import Html exposing (Html, text)
import Html.Attributes exposing (style)
import Time exposing (Time, second)
import Keyboard
import Random
import Dict exposing (Dict)
import Data.Direction exposing (Direction(..))
import Data.Position
    exposing
        ( Position
        , Dimensions
        , gridDimensions
        , nextPositionInDirection
        )
import Data.Apple exposing (Apple, randomApple, expireApples)
import Data.Snake
    exposing
        ( Snake
        , initialSnake
        , moveSnake
        , growSnake
        , eatApples
        , changeSnakeDirection
        )


-- model


type alias Model =
    { time : Time
    , snake : Snake
    , apples : List Apple
    }


init : ( Model, Cmd Msg )
init =
    let
        initialDirection =
            East
    in
        ( { time = 0
          , snake = initialSnake
          , apples = []
          }
        , Cmd.none
        )



-- update


type Msg
    = Tick Time
    | ChangeDirection Direction
    | AddApple Apple
    | Noop


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ snake, apples, time } as model) =
    case msg of
        Tick newTime ->
            let
                newApples =
                    apples
                        |> eatApples snake
                        |> expireApples newTime

                newSnake =
                    snake
                        |> growSnake apples
                        |> moveSnake
            in
                ( { model
                    | time = newTime
                    , snake = newSnake
                    , apples = newApples
                  }
                , if newApples == [] then
                    Random.generate AddApple (randomApple newTime)
                  else
                    Cmd.none
                )

        ChangeDirection direction ->
            ( { model | snake = changeSnakeDirection snake direction }, Cmd.none )

        AddApple apple ->
            ( { model | apples = apple :: model.apples }
            , Cmd.none
            )

        Noop ->
            ( model, Cmd.none )



-- subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every oneHundredMillis Tick
        , Keyboard.ups keyCodeToChangeDirectionMsg
        ]


oneHundredMillis =
    100 * Time.millisecond


keyCodeToChangeDirectionMsg : Keyboard.KeyCode -> Msg
keyCodeToChangeDirectionMsg keyCode =
    case keyCode of
        38 ->
            ChangeDirection North

        37 ->
            ChangeDirection West

        39 ->
            ChangeDirection East

        40 ->
            ChangeDirection South

        _ ->
            Noop



-- view


view : Model -> Html Msg
view model =
    Html.div []
        [ mkGrid model
        , text <| "Score: " ++ toString (score model)
        ]


score : Model -> Int
score { snake } =
    List.length snake.body


tileSideLength : Int
tileSideLength =
    20


tileLengthPixels : String
tileLengthPixels =
    toString tileSideLength ++ "px"


mkTile : TileType -> List (Html Msg) -> Html Msg
mkTile tileType contents =
    let
        backgroundColor =
            case tileType of
                SnakeSegment ->
                    "#69E582"

                AppleTile ->
                    "#C40000"

                EmptyTile ->
                    "transparent"
    in
        Html.div
            [ style
                [ ( "width", tileLengthPixels )
                , ( "height", tileLengthPixels )
                , ( "border", "1px solid #EEEEEE" )
                , ( "float", "left" )
                , ( "margin", "-1px" )
                , ( "font-size", "8px" )
                , ( "background-color", backgroundColor )
                ]
            ]
            contents


mkGrid : Model -> Html Msg
mkGrid { snake, apples } =
    let
        dim =
            gridDimensions

        appleTilePositions =
            List.map (\apple -> ( apple.position, AppleTile )) apples

        snakeTilePositions =
            List.map (\snakeSegment -> ( snakeSegment, SnakeSegment )) snake.body

        positionTilePairs =
            List.concat [ appleTilePositions, snakeTilePositions ]

        renderables =
            Dict.fromList (List.map convertToKVPair positionTilePairs)

        tileTypeForPosn =
            tileTypeFromPositionTileTypePairs renderables

        tileTypeFor x y =
            tileTypeForPosn { x = x, y = y }

        row y =
            Html.div
                [ style
                    [ ( "width"
                      , toString (tileSideLength * dim.x)
                            ++ "px"
                      )
                    ]
                ]
            <|
                (List.range 1 dim.x
                    |> List.map
                        (\x ->
                            mkTile (tileTypeFor x y) []
                        )
                )

        grid =
            List.range 1 dim.y |> List.reverse |> List.map row
    in
        Html.div [] grid


type TileType
    = EmptyTile
    | SnakeSegment
    | AppleTile


convertToKVPair : ( Position, TileType ) -> ( ( Int, Int ), TileType )
convertToKVPair ( pos, tileType ) =
    ( ( pos.x, pos.y ), tileType )


tileTypeFromPositionTileTypePairs : Dict ( Int, Int ) TileType -> Position -> TileType
tileTypeFromPositionTileTypePairs renderables tilePosition =
    Dict.get ( tilePosition.x, tilePosition.y ) renderables
        |> Maybe.withDefault EmptyTile



-- main


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
