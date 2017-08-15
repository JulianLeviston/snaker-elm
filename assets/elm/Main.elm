module Main exposing (main)

import Html exposing (Html, text)
import Html.Attributes exposing (style)
import Time exposing (Time, second)
import Keyboard
import Dict
import Random exposing (Generator)
import Data.Direction exposing (Direction(..))
import Data.Position
    exposing
        ( Position
        , Dimensions
        , gridDimensions
        , nextPositionInDirection
        )


-- model


type alias Model =
    { time : Time
    , snake : Snake
    , apples : List Apple
    }


type alias Apple =
    { expiresAt : Time
    , position : Position
    }


type alias Snake =
    { direction : Direction
    , body : List Position
    }


init : ( Model, Cmd Msg )
init =
    let
        x =
            gridDimensions.x // 2

        y =
            gridDimensions.y // 2

        initialSegment =
            { x = x, y = y }

        subsequentSegment =
            nextPositionInDirection West initialSegment

        lastSegment =
            nextPositionInDirection West subsequentSegment

        initialDirection =
            East
    in
        ( { time = 0
          , snake =
                { body =
                    [ initialSegment
                    , subsequentSegment
                    , lastSegment
                    ]
                , direction = initialDirection
                }
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
                newSnake =
                    snake
                        |> moveSnake
                        |> growSnake apples

                newApples =
                    apples
                        |> eatApples newSnake
                        |> expireApples newTime
            in
                ( { model
                    | time = newTime
                    , snake = newSnake
                    , apples = newApples
                  }
                , if apples == [] then
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


randomApple : Time -> Generator Apple
randomApple currentTime =
    Random.map2
        (\position expiresAt -> { position = position, expiresAt = expiresAt })
        Position.randomPosition
        (Random.float currentTime (currentTime + 5000))


expireApples : Time -> List Apple -> List Apple
expireApples time =
    List.filter (\{ expiresAt } -> expiresAt >= time)


moveSnake : Snake -> Snake
moveSnake ({ body, direction } as snake) =
    case body of
        [] ->
            snake

        snakeHead :: snakeBody ->
            let
                newHead =
                    nextPositionInDirection direction snakeHead

                newBody =
                    newHead :: (List.take (List.length body - 1) body)
            in
                { snake | body = newBody }


growSnake : List Apple -> Snake -> Snake
growSnake apples ({ body, direction } as snake) =
    case body of
        [] ->
            snake

        snakeHead :: _ ->
            if List.member snakeHead (List.map .position apples) then
                { snake | body = nextPositionInDirection direction snakeHead :: body }
            else
                snake


eatApples : Snake -> List Apple -> List Apple
eatApples { body } apples =
    case body of
        [] ->
            apples

        snakeHead :: _ ->
            List.filter (\{ position } -> position /= snakeHead) apples


changeSnakeDirection : Snake -> Direction -> Snake
changeSnakeDirection originalSnake newDirection =
    let
        changedDirection =
            case ( originalSnake.direction, newDirection ) of
                ( North, South ) ->
                    North

                ( South, North ) ->
                    South

                ( East, West ) ->
                    East

                ( West, East ) ->
                    West

                _ ->
                    newDirection
    in
        { originalSnake | direction = changedDirection }


wrapVal : Int -> Int -> Int -> Int
wrapVal minVal maxVal val =
    if (max val (maxVal + 1)) == val then
        minVal
    else if (min val (minVal - 1)) == val then
        maxVal
    else
        val



-- subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every (100 * Time.millisecond) Tick
        , Keyboard.ups keyCodeToChangeDirectionMsg
        ]


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
        , text <| "score: " ++ toString (score model)
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

        tileTypeForPosn =
            tileType positionTilePairs

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


tileType : List ( Position, TileType ) -> Position -> TileType
tileType positionTileTypePairs tilePosition =
    let
        convertToKVPair ( pos, tileType ) =
            ( ( pos.x, pos.y ), tileType )

        renderables =
            Dict.fromList (List.map convertToKVPair positionTileTypePairs)
    in
        case Dict.get ( tilePosition.x, tilePosition.y ) renderables of
            Nothing ->
                EmptyTile

            Just resultantTileType ->
                resultantTileType



-- main


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
