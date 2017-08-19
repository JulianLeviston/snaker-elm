module Data.Player
    exposing
        ( Player
        , PlayerColour
        , PlayerId
        , init
        , id
        , colour
        , initWithIdNameAndColour
        )


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


colour : Player -> PlayerColour
colour player =
    player.colour


initWithIdNameAndColour : Int -> String -> String -> Player
initWithIdNameAndColour id name colour =
    { init
        | playerId = id
        , name = name
        , colour = colour
    }
