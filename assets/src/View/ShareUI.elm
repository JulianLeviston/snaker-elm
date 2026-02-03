module View.ShareUI exposing (CopyState(..), CopyTarget(..), view)

{-| Share UI component for displaying room sharing options.
Includes copy buttons for room code and URL, and QR code display.
-}

import Html exposing (Html, button, div, img, text)
import Html.Attributes exposing (alt, class, src)
import Html.Events exposing (onClick)


{-| Target for copy operation.
-}
type CopyTarget
    = CopyCode
    | CopyUrl


{-| State of a copy button.
-}
type CopyState
    = Ready
    | Copied


{-| Configuration for ShareUI view.
-}
type alias Config msg =
    { roomCode : String
    , qrCodeDataUrl : Maybe String
    , copyCodeState : CopyState
    , copyUrlState : CopyState
    , onCopyCode : msg
    , onCopyUrl : msg
    }


{-| Render the share UI with copy buttons and QR code.
-}
view : Config msg -> Html msg
view config =
    div [ class "share-ui" ]
        [ div [ class "share-buttons" ]
            [ viewCopyButton "Copy Code" config.copyCodeState config.onCopyCode
            , viewCopyButton "Copy Link" config.copyUrlState config.onCopyUrl
            ]
        , viewQRCode config.roomCode config.qrCodeDataUrl
        ]


{-| Render a copy button that shows "Copied!" when in Copied state.
-}
viewCopyButton : String -> CopyState -> msg -> Html msg
viewCopyButton label state onClickMsg =
    case state of
        Ready ->
            button
                [ class "copy-button share-copy-button"
                , onClick onClickMsg
                ]
                [ text label ]

        Copied ->
            button
                [ class "copy-button share-copy-button copied" ]
                [ text "Copied!" ]


{-| Render the QR code image when available.
-}
viewQRCode : String -> Maybe String -> Html msg
viewQRCode roomCode maybeDataUrl =
    case maybeDataUrl of
        Just dataUrl ->
            div [ class "qr-code-container" ]
                [ img
                    [ class "qr-code"
                    , src dataUrl
                    , alt ("Scan to join room " ++ roomCode)
                    ]
                    []
                ]

        Nothing ->
            div [ class "qr-code-container qr-code-loading" ]
                [ text "Generating QR code..." ]
