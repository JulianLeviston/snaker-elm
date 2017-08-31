module Data.Player
    exposing
        ( Player
        , PlayerColour
        , PlayerId
        , init
        , id
        , setId
        , colour
        , setColour
        , initWithIdNameAndColour
        , playerDecoder
        , playerDictDecoder
        )

import Dict exposing (Dict)
import Json.Decode as JD


type alias Player =
    { playerId : PlayerId
    , name : String
    , colour : PlayerColour
    }


type alias PlayerId =
    Int


type alias PlayerColour =
    String


init : Player
init =
    { playerId = 1
    , name = "Snakey"
    , colour = "69E582"
    }


id : Player -> PlayerId
id player =
    player.playerId


setId : PlayerId -> Player -> Player
setId id player =
    { player | playerId = id }


colour : Player -> PlayerColour
colour player =
    player.colour


setColour : String -> Player -> Player
setColour colour player =
    { player | colour = colour }


initWithIdNameAndColour : Int -> String -> String -> Player
initWithIdNameAndColour id name colour =
    { init
        | playerId = id
        , name = name
        , colour = colour
    }


playerDecoder : JD.Decoder Player
playerDecoder =
    JD.map3
        initWithIdNameAndColour
        (JD.field "id" JD.int)
        (JD.field "name" JD.string)
        (JD.field "colour" JD.string)


playerDictDecoder : JD.Decoder (Dict PlayerId Player)
playerDictDecoder =
    JD.map
        (\dict ->
            Dict.toList dict
                |> List.map (\( k, v ) -> ( Result.withDefault 0 (String.toInt k), v ))
                |> Dict.fromList
        )
        (JD.dict playerDecoder)
