module Input exposing
    ( keyDecoder
    )

import Json.Decode as JD
import Snake exposing (Direction(..))


{-| Decode keyboard events to direction changes.
Handles both Arrow keys and WASD.
Ignores key repeat events.
-}
keyDecoder : JD.Decoder (Maybe Direction)
keyDecoder =
    JD.map2 Tuple.pair
        (JD.field "key" JD.string)
        (JD.field "repeat" JD.bool)
        |> JD.andThen
            (\( key, isRepeat ) ->
                if isRepeat then
                    JD.succeed Nothing

                else
                    JD.succeed (keyToDirection key)
            )


keyToDirection : String -> Maybe Direction
keyToDirection key =
    case key of
        "ArrowUp" ->
            Just Up

        "w" ->
            Just Up

        "W" ->
            Just Up

        "ArrowDown" ->
            Just Down

        "s" ->
            Just Down

        "S" ->
            Just Down

        "ArrowLeft" ->
            Just Left

        "a" ->
            Just Left

        "A" ->
            Just Left

        "ArrowRight" ->
            Just Right

        "d" ->
            Just Right

        "D" ->
            Just Right

        _ ->
            Nothing
