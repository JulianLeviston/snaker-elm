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
import Data.Player exposing (PlayerColour, PlayerId)
import Data.Snake as Snake
    exposing
        ( Snake
        , initialSnake
        , moveSnake
        , growSnake
        , eatApples
        , changeSnakeDirection
        )


type alias Board =
    { currentPlayerId : PlayerId
    , time : Time
    , snakes : Dict PlayerId Snake
    , apples : List Apple
    }


type TileType
    = EmptyTile
    | SnakeSegment PlayerColour
    | AppleTile


init : Board
init =
    let
        playerId =
            Snake.id initialSnake
    in
        { currentPlayerId = 1
        , time = 0
        , snakes = Dict.fromList [ ( playerId, initialSnake ) ]
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


updateSnakeAndApples : PlayerId -> Board -> Board
updateSnakeAndApples playerId ({ snakes, apples, time } as board) =
    let
        ( newSnakes, newApples ) =
            case Dict.get playerId snakes of
                Nothing ->
                    ( snakes, apples )

                Just snake ->
                    let
                        ( newSnake, newApples_ ) =
                            nextSnakeAndApples time snake apples
                    in
                        ( Dict.insert playerId newSnake snakes, newApples_ )
    in
        { board
            | snakes = newSnakes
            , apples = newApples
        }


update : Msg -> Board -> ( Board, Cmd Msg )
update msg ({ currentPlayerId, snakes, apples, time } as model) =
    case msg of
        Tick newTime ->
            let
                playerIds =
                    Dict.keys snakes

                newBoard =
                    List.foldl updateSnakeAndApples { model | time = newTime } playerIds
            in
                ( newBoard
                , if newBoard.apples == [] then
                    Random.generate AddApple (randomApple newTime)
                  else
                    Cmd.none
                )

        ChangeDirection direction ->
            ( { model | snakes = Dict.update currentPlayerId (Maybe.map (changeSnakeDirection direction)) snakes }, Cmd.none )

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
score { currentPlayerId, snakes } =
    case Dict.get currentPlayerId snakes of
        Nothing ->
            0

        Just snake ->
            List.length snake.body


convertToKVPair : ( Position, TileType ) -> ( ( Int, Int ), TileType )
convertToKVPair ( pos, tileType ) =
    ( ( pos.x, pos.y ), tileType )


tileTypeFromPositionTileTypePairs : Dict ( Int, Int ) TileType -> Position -> TileType
tileTypeFromPositionTileTypePairs renderables tilePosition =
    Dict.get ( tilePosition.x, tilePosition.y ) renderables
        |> Maybe.withDefault EmptyTile
