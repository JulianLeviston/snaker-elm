module Snake exposing
    ( Snake
    , Position
    , Direction(..)
    , PenaltyState
    , directionToString
    , decoder
    , positionDecoder
    , head
    , isOppositeDirection
    , validDirectionChange
    , defaultSnake
    )

import Json.Decode as JD


type Direction
    = Up
    | Down
    | Left
    | Right


type alias Position =
    { x : Int
    , y : Int
    }


{-| Penalty state for skull eating animation.

Animation timeline (6 ticks = 600ms):
- Ticks 0-1: Flash 1 (doomed segments highlighted red, opacity pulse)
- Ticks 2-3: Flash 2
- Ticks 4-5: Flash 3 + jitter effect
- Tick 6: Actually remove segments and halve score
-}
type alias PenaltyState =
    { segmentsToRemove : Int
    , flashPhase : Int -- 0-6 (flash 3x at 2 ticks each)
    }


type alias Snake =
    { id : String
    , body : List Position
    , direction : Direction
    , color : String
    , name : String
    , isInvincible : Bool
    , state : String
    , pendingGrowth : Int
    }


{-| Create a default snake for local game initialization.
-}
defaultSnake : Position -> Snake
defaultSnake startPos =
    { id = "local"
    , body = [ startPos, { x = startPos.x - 1, y = startPos.y }, { x = startPos.x - 2, y = startPos.y } ]
    , direction = Right
    , color = "67a387"
    , name = "Player"
    , isInvincible = False
    , state = "alive"
    , pendingGrowth = 0
    }


{-| Check if two directions are opposites.
-}
isOppositeDirection : Direction -> Direction -> Bool
isOppositeDirection dir1 dir2 =
    case ( dir1, dir2 ) of
        ( Up, Down ) ->
            True

        ( Down, Up ) ->
            True

        ( Left, Right ) ->
            True

        ( Right, Left ) ->
            True

        _ ->
            False


{-| Check if a direction change is valid (not reversing).
-}
validDirectionChange : Direction -> Direction -> Bool
validDirectionChange current new =
    not (isOppositeDirection current new)


directionToString : Direction -> String
directionToString dir =
    case dir of
        Up ->
            "up"

        Down ->
            "down"

        Left ->
            "left"

        Right ->
            "right"


positionDecoder : JD.Decoder Position
positionDecoder =
    JD.map2 Position
        (JD.field "x" JD.int)
        (JD.field "y" JD.int)


directionDecoder : JD.Decoder Direction
directionDecoder =
    JD.string
        |> JD.andThen
            (\str ->
                case str of
                    "up" ->
                        JD.succeed Up

                    "down" ->
                        JD.succeed Down

                    "left" ->
                        JD.succeed Left

                    "right" ->
                        JD.succeed Right

                    _ ->
                        JD.fail ("Unknown direction: " ++ str)
            )


decoder : JD.Decoder Snake
decoder =
    JD.map8 Snake
        (JD.field "id" JD.string)
        (JD.field "body" (JD.list positionDecoder))
        (JD.field "direction" directionDecoder)
        (JD.field "color" JD.string)
        (JD.field "name" JD.string)
        (JD.field "is_invincible" JD.bool)
        (JD.oneOf
            [ JD.field "state" JD.string
            , JD.succeed "alive"
            ]
        )
        (JD.oneOf
            [ JD.field "pending_growth" JD.int
            , JD.succeed 0
            ]
        )


head : Snake -> Maybe Position
head snake =
    List.head snake.body
