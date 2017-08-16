module Data.Apple exposing (Apple, randomApple, expireApples, eatApplesAt)

import Random exposing (Generator)
import Time exposing (Time)
import Data.Position as Position exposing (Position)


type alias Apple =
    { expiresAt : Time
    , position : Position
    }


minAppleMillis : Time
minAppleMillis =
    3000


maxAppleMillis : Time
maxAppleMillis =
    8000


randomApple : Time -> Generator Apple
randomApple currentTime =
    Random.map2
        (\position expiresAt ->
            { position = position, expiresAt = expiresAt }
        )
        Position.randomPosition
        (Random.float (currentTime + minAppleMillis) (currentTime + minAppleMillis + maxAppleMillis))


expireApples : Time -> List Apple -> List Apple
expireApples time =
    List.filter (\{ expiresAt } -> expiresAt > time)


eatApplesAt : Position -> List Apple -> List Apple
eatApplesAt removeAtPosition apples =
    List.filter
        (\{ position } ->
            position /= removeAtPosition
        )
        apples
