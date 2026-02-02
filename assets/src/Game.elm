module Game exposing
    ( GameState
    , Apple
    , Player
    , decoder
    , appleDecoder
    , playerDecoder
    )

import Json.Decode as JD
import Snake exposing (Position, Snake)


type alias Apple =
    { position : Position
    }


type alias Player =
    { id : String
    , snake : Snake
    }


type alias GameState =
    { snakes : List Snake
    , apples : List Apple
    , gridWidth : Int
    , gridHeight : Int
    }


appleDecoder : JD.Decoder Apple
appleDecoder =
    JD.map Apple Snake.positionDecoder


playerDecoder : JD.Decoder Player
playerDecoder =
    JD.map2 Player
        (JD.field "id" JD.string)
        (JD.field "snake" Snake.decoder)


decoder : JD.Decoder GameState
decoder =
    JD.map4 GameState
        (JD.field "snakes" (JD.list Snake.decoder))
        (JD.field "apples" (JD.list appleDecoder))
        (JD.field "grid_width" JD.int)
        (JD.field "grid_height" JD.int)
