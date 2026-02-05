module NameGenerator exposing (generate)

{-| Generate whimsical player names like "Fuzzy Banana" or "Electric Penguin".
-}

import Array exposing (Array)
import Random


{-| Generate a random whimsical name.
-}
generate : Random.Generator String
generate =
    Random.map2 combineName
        (randomElement adjectives)
        (randomElement nouns)


combineName : String -> String -> String
combineName adj noun =
    adj ++ " " ++ noun


randomElement : Array String -> Random.Generator String
randomElement arr =
    Random.int 0 (Array.length arr - 1)
        |> Random.map (\i -> Array.get i arr |> Maybe.withDefault "Mystery")


adjectives : Array String
adjectives =
    Array.fromList
        [ "Fuzzy"
        , "Electric"
        , "Cosmic"
        , "Sneaky"
        , "Bouncy"
        , "Sparkly"
        , "Mighty"
        , "Sleepy"
        , "Dizzy"
        , "Zippy"
        , "Wobbly"
        , "Jumpy"
        , "Twirly"
        , "Groovy"
        , "Snappy"
        , "Peppy"
        , "Zesty"
        , "Cheeky"
        , "Fluffy"
        , "Crispy"
        , "Squishy"
        , "Wiggly"
        , "Giggly"
        , "Bubbly"
        , "Sassy"
        , "Dapper"
        , "Quirky"
        , "Wacky"
        , "Jolly"
        , "Spunky"
        ]


nouns : Array String
nouns =
    Array.fromList
        [ "Banana"
        , "Penguin"
        , "Noodle"
        , "Pickle"
        , "Waffle"
        , "Muffin"
        , "Potato"
        , "Taco"
        , "Nugget"
        , "Biscuit"
        , "Pancake"
        , "Pretzel"
        , "Dumpling"
        , "Turnip"
        , "Radish"
        , "Panda"
        , "Llama"
        , "Otter"
        , "Gecko"
        , "Hamster"
        , "Wombat"
        , "Koala"
        , "Sloth"
        , "Narwhal"
        , "Walrus"
        , "Falcon"
        , "Badger"
        , "Wizard"
        , "Ninja"
        , "Pirate"
        ]
