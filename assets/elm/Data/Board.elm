module Data.Board
    exposing
        ( Board
        , Msg(..)
        , TileType(..)
        , init
        , update
        , score
        , tickDuration
        , tileTypeFromPositionTileTypePairs
        , convertToKVPair
        , toChangeDirectionMsg
        , tickBoardMsg
        )

import Time exposing (Time, second)
import Dict exposing (Dict)
import Random
import Data.Direction exposing (Direction(..))
import Data.Position
    exposing
        ( Position
        , Dimensions
        , gridDimensions
        , nextPositionInDirection
        )
import Data.Apple exposing (Apple, randomApple, expireApples)
import Data.Player exposing (PlayerColour)
import Data.Snake
    exposing
        ( Snake
        , initialSnake
        , moveSnake
        , growSnake
        , eatApples
        , changeSnakeDirection
        )


type alias Board =
    { time : Time
    , snake : Snake
    , apples : List Apple
    }


type TileType
    = EmptyTile
    | SnakeSegment PlayerColour
    | AppleTile


init : Board
init =
    { time = 0
    , snake = initialSnake
    , apples = []
    }


oneHundredMillis : Time
oneHundredMillis =
    100 * Time.millisecond


tickDuration : Time
tickDuration =
    oneHundredMillis


type Msg
    = Tick Time
    | ChangeDirection Direction
    | AddApple Apple


update : Msg -> Board -> ( Board, Cmd Msg )
update msg ({ snake, apples, time } as model) =
    case msg of
        Tick newTime ->
            let
                ( newSnake, newApples ) =
                    nextSnakeAndApples newTime snake apples
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


toChangeDirectionMsg : Direction -> Msg
toChangeDirectionMsg =
    ChangeDirection


tickBoardMsg : Time -> Msg
tickBoardMsg =
    Tick


nextSnakeAndApples : Time -> Snake -> List Apple -> ( Snake, List Apple )
nextSnakeAndApples time snake apples =
    let
        newApples =
            apples
                |> eatApples snake
                |> expireApples time

        newSnake =
            snake
                |> growSnake apples
                |> moveSnake
    in
        ( newSnake, newApples )


score : Board -> Int
score { snake } =
    List.length snake.body


convertToKVPair : ( Position, TileType ) -> ( ( Int, Int ), TileType )
convertToKVPair ( pos, tileType ) =
    ( ( pos.x, pos.y ), tileType )


tileTypeFromPositionTileTypePairs : Dict ( Int, Int ) TileType -> Position -> TileType
tileTypeFromPositionTileTypePairs renderables tilePosition =
    Dict.get ( tilePosition.x, tilePosition.y ) renderables
        |> Maybe.withDefault EmptyTile
