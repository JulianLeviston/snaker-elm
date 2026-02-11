module Engine.VenomType exposing
    ( VenomType(..)
    , toString
    , fromString
    , maxLifetime
    )

{-| Venom type variants for different projectile behaviors.

StandardVenom travels in a straight line and wraps around edges.
BallVenom bounces off walls with randomized angles.
-}


{-| The type of venom a snake currently has.
-}
type VenomType
    = StandardVenom
    | BallVenom


{-| Convert VenomType to string for network encoding.
-}
toString : VenomType -> String
toString venomType =
    case venomType of
        StandardVenom ->
            "standard"

        BallVenom ->
            "ball"


{-| Parse a string into a VenomType, defaulting to StandardVenom.
-}
fromString : String -> VenomType
fromString str =
    case str of
        "ball" ->
            BallVenom

        _ ->
            StandardVenom


{-| Maximum lifetime of a projectile in ticks, by venom type.

StandardVenom: 15 ticks (fast, straight-line)
BallVenom: 50 ticks (bouncing covers less ground per tick)
-}
maxLifetime : VenomType -> Int
maxLifetime venomType =
    case venomType of
        StandardVenom ->
            15

        BallVenom ->
            50
