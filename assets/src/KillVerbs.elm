module KillVerbs exposing (generate, generateVenom)

{-| Generate dramatic kill verbs for notifications.
-}

import Array exposing (Array)
import Random


{-| Generate a random dramatic verb for kill notifications.
-}
generate : Random.Generator String
generate =
    randomElement verbs


randomElement : Array String -> Random.Generator String
randomElement arr =
    Random.int 0 (Array.length arr - 1)
        |> Random.map (\i -> Array.get i arr |> Maybe.withDefault "eliminated")


{-| Generate a random venom-specific verb for kill notifications.
-}
generateVenom : Random.Generator String
generateVenom =
    randomElement venomVerbs


venomVerbs : Array String
venomVerbs =
    Array.fromList
        [ "venomized"
        , "poisoned"
        , "spat on"
        , "corroded"
        , "envenomed"
        , "dissolved"
        , "melted"
        , "toxified"
        , "infected"
        , "stung"
        ]


verbs : Array String
verbs =
    Array.fromList
        [ "obliterated"
        , "dominated"
        , "destroyed"
        , "annihilated"
        , "eliminated"
        , "crushed"
        , "demolished"
        , "vanquished"
        , "conquered"
        , "wrecked"
        , "steamrolled"
        , "flattened"
        , "pulverized"
        , "smashed"
        , "toppled"
        , "outplayed"
        , "overwhelmed"
        , "decimated"
        , "terminated"
        , "ended"
        ]
