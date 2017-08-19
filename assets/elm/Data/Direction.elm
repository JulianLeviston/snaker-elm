module Data.Direction exposing (Direction(..), keyCodeToMaybeDirection)

import Keyboard


type Direction
    = North
    | East
    | West
    | South


keyCodeToMaybeDirection : Keyboard.KeyCode -> Maybe Direction
keyCodeToMaybeDirection keyCode =
    case keyCode of
        38 ->
            Just North

        37 ->
            Just West

        39 ->
            Just East

        40 ->
            Just South

        _ ->
            Nothing
