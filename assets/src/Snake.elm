module Snake exposing
    ( Snake
    , Position
    , Direction(..)
    , directionToString
    , decoder
    , positionDecoder
    , head
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


type alias Snake =
    { id : String
    , body : List Position
    , direction : Direction
    , color : String
    , name : String
    , isInvincible : Bool
    , state : String
    }


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
    JD.map7 Snake
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


head : Snake -> Maybe Position
head snake =
    List.head snake.body
