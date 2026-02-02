port module Ports exposing
    ( joinGame
    , leaveGame
    , sendDirection
    , receiveGameState
    , receiveError
    , playerJoined
    , playerLeft
    , receiveTick
    )

import Json.Decode as JD
import Json.Encode as JE


-- Outgoing ports (Commands to JS)


port joinGame : JE.Value -> Cmd msg


port leaveGame : () -> Cmd msg


port sendDirection : JE.Value -> Cmd msg



-- Incoming ports (Subscriptions from JS)


port receiveGameState : (JD.Value -> msg) -> Sub msg


port receiveError : (String -> msg) -> Sub msg


port playerJoined : (JD.Value -> msg) -> Sub msg


port playerLeft : (JD.Value -> msg) -> Sub msg


port receiveTick : (JD.Value -> msg) -> Sub msg
