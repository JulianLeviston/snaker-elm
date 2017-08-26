module Data.Direction
    exposing
        ( Direction(..)
        , fromString
        , keyCodeToMaybeDirection
        )

import Keyboard


type Direction
    = North
    | East
    | West
    | South


fromString : String -> Maybe Direction
fromString string =
    case string of
        "north" ->
            Just North

        "North" ->
            Just North

        "NORTH" ->
            Just North

        "east" ->
            Just East

        "East" ->
            Just East

        "EAST" ->
            Just East

        "west" ->
            Just West

        "West" ->
            Just West

        "WEST" ->
            Just West

        "south" ->
            Just South

        "South" ->
            Just South

        "SOUTH" ->
            Just South

        _ ->
            Nothing


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
