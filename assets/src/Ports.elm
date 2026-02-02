port module Ports exposing
    ( joinGame
    , leaveGame
    , sendDirection
    , receiveGameState
    , receiveError
    , playerJoined
    , playerLeft
    , receiveTick
      -- P2P ports (PeerJS)
    , createRoom
    , joinRoom
    , leaveRoom
    , copyToClipboard
    , roomCreated
    , peerConnected
    , peerDisconnected
    , connectionError
    , clipboardCopySuccess
    )

import Json.Decode as JD
import Json.Encode as JE


-- Outgoing ports (Commands to JS)


port joinGame : JE.Value -> Cmd msg


port leaveGame : () -> Cmd msg


port sendDirection : JE.Value -> Cmd msg



-- P2P Outgoing ports (Commands to JS)


port createRoom : () -> Cmd msg


port joinRoom : String -> Cmd msg


port leaveRoom : () -> Cmd msg


port copyToClipboard : String -> Cmd msg



-- Incoming ports (Subscriptions from JS)


port receiveGameState : (JD.Value -> msg) -> Sub msg


port receiveError : (String -> msg) -> Sub msg


port playerJoined : (JD.Value -> msg) -> Sub msg


port playerLeft : (JD.Value -> msg) -> Sub msg


port receiveTick : (JD.Value -> msg) -> Sub msg



-- P2P Incoming ports (Subscriptions from JS)


port roomCreated : (String -> msg) -> Sub msg


port peerConnected : (JD.Value -> msg) -> Sub msg


port peerDisconnected : (String -> msg) -> Sub msg


port connectionError : (String -> msg) -> Sub msg


port clipboardCopySuccess : (() -> msg) -> Sub msg
