module Data.Player exposing (Player, PlayerColour, init)


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
