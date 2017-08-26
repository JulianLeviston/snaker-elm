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
        , currentPlayerId
        , toChangeDirectionMsg
        , toSetCurrentPlayerMsg
        , toSetupPlayersMsg
        , toSetupNewPlayerMsg
        , toRemovePlayerMsg
        , tickBoardMsg
        , toMovePlayerMsg
        )

import Html
import Time exposing (Time, second)
import Dict exposing (Dict)
import Random
import Data.Direction exposing (Direction(..))
import Data.Player as Player exposing (Player, PlayerId)
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
    { currentPlayerId = 0
    , time = 0
    , snakes = Dict.fromList []
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
    | SetCurrentPlayer Player
    | SetupPlayers (Dict PlayerId Player)
    | SetupNewPlayer Player
    | RemovePlayer Player
    | ChangeDirectionOfPlayer PlayerId Direction


toMovePlayerMsg : PlayerId -> Direction -> Msg
toMovePlayerMsg =
    ChangeDirectionOfPlayer


currentPlayerId : Board -> PlayerId
currentPlayerId =
    .currentPlayerId


toSetCurrentPlayerMsg : Player -> Msg
toSetCurrentPlayerMsg =
    SetCurrentPlayer


toSetupPlayersMsg : Dict PlayerId Player -> Msg
toSetupPlayersMsg =
    SetupPlayers


toSetupNewPlayerMsg : Player -> Msg
toSetupNewPlayerMsg =
    SetupNewPlayer


toRemovePlayerMsg : Player -> Msg
toRemovePlayerMsg =
    RemovePlayer


progressBoard : Time -> PlayerId -> Board -> Board
progressBoard nextTime playerId ({ snakes, apples } as board) =
    let
        ( nextSnakes, nextApples ) =
            case Dict.get playerId snakes of
                Nothing ->
                    ( snakes, apples )

                Just snake ->
                    let
                        ( newSnake, newApples ) =
                            nextSnakeAndApples nextTime snake apples
                    in
                        ( Dict.insert playerId newSnake snakes, newApples )
    in
        { board
            | time = nextTime
            , snakes = nextSnakes
            , apples = nextApples
        }


update : Msg -> Board -> ( Board, Cmd Msg )
update msg ({ currentPlayerId, snakes, apples, time } as model) =
    case msg of
        Tick newTime ->
            let
                playerIds =
                    Dict.keys snakes

                newBoard =
                    List.foldl (progressBoard newTime) model playerIds
            in
                ( newBoard
                , if newBoard.apples == [] then
                    Random.generate AddApple (randomApple newTime)
                  else
                    Cmd.none
                )

        ChangeDirection direction ->
            ( { model | snakes = Dict.update currentPlayerId (Maybe.map (changeSnakeDirection direction)) snakes }, Cmd.none )

        ChangeDirectionOfPlayer playerId direction ->
            ( { model | snakes = Dict.update playerId (Maybe.map (changeSnakeDirection direction)) snakes }, Cmd.none )

        AddApple apple ->
            ( { model | apples = apple :: model.apples }, Cmd.none )

        SetCurrentPlayer player ->
            let
                playerId =
                    Player.id player

                playerSnake =
                    Snake.initialSnake
                        |> Snake.setPlayer player

                newSnakes =
                    model.snakes
                        |> Dict.insert playerId playerSnake
            in
                ( { model | currentPlayerId = playerId, snakes = newSnakes }, Cmd.none )

        SetupPlayers playersDict ->
            let
                newSnakes =
                    Dict.map (\_ player -> Snake.setPlayer player (Snake.initialSnake)) playersDict
            in
                ( { model | snakes = newSnakes }, Cmd.none )

        SetupNewPlayer player ->
            let
                newSnake =
                    Snake.setPlayer player (Snake.initialSnake)

                newSnakes =
                    Dict.insert (Snake.id newSnake) newSnake snakes
            in
                ( { model | snakes = newSnakes }, Cmd.none )

        RemovePlayer { playerId } ->
            let
                newSnakes =
                    Dict.remove playerId snakes
            in
                ( { model | snakes = newSnakes }, Cmd.none )


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
