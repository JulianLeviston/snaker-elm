module Data.Player exposing (Player, PlayerColour, init, initWithIdNameAndColour)


type alias Player =
    { playerId : Int
    , name : String
    , colour : PlayerColour
    }


type alias PlayerColour =
    String


init : Player
init =
    { playerId = 1
    , name = "Snakey"
    , colour = "69E582"
    }


initWithIdNameAndColour : Int -> String -> String -> Player
initWithIdNameAndColour id name colour =
    { init
        | playerId = id
        , name = name
        , colour = colour
    }
