module Input exposing
    ( InputAction(..)
    , keyDecoder
    , keyDecoderWithPreventDefault
    )

import Json.Decode as JD
import Snake exposing (Direction(..))


{-| Input actions from keyboard or touch.
-}
type InputAction
    = DirectionInput Direction
    | ShootInput
    | NoInput


{-| Decode keyboard events to input actions.
Handles Arrow keys, WASD, and Shift for shooting.
Ignores key repeat events.
-}
keyDecoder : JD.Decoder InputAction
keyDecoder =
    JD.map2 Tuple.pair
        (JD.field "key" JD.string)
        (JD.field "repeat" JD.bool)
        |> JD.andThen
            (\( key, isRepeat ) ->
                if isRepeat then
                    JD.succeed NoInput

                else
                    JD.succeed (keyToAction key)
            )


{-| Decoder for use with preventDefaultOn.
Returns (msg, shouldPreventDefault) tuple.
Prevents default for arrow keys and spacebar.
-}
keyDecoderWithPreventDefault : (InputAction -> msg) -> JD.Decoder ( msg, Bool )
keyDecoderWithPreventDefault toMsg =
    JD.map2 Tuple.pair
        (JD.field "key" JD.string)
        (JD.field "repeat" JD.bool)
        |> JD.map
            (\( key, isRepeat ) ->
                let
                    action =
                        if isRepeat then
                            NoInput
                        else
                            keyToAction key

                    shouldPreventDefault =
                        isGameKey key
                in
                ( toMsg action, shouldPreventDefault )
            )


isGameKey : String -> Bool
isGameKey key =
    isArrowKey key || key == "Shift"


isArrowKey : String -> Bool
isArrowKey key =
    case key of
        "ArrowUp" -> True
        "ArrowDown" -> True
        "ArrowLeft" -> True
        "ArrowRight" -> True
        _ -> False


keyToAction : String -> InputAction
keyToAction key =
    case key of
        "Shift" ->
            ShootInput

        _ ->
            case keyToDirection key of
                Just dir ->
                    DirectionInput dir

                Nothing ->
                    NoInput


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
