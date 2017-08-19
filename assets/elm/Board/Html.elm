module Board.Html exposing (view)

import Dict
import Html exposing (Html, text)
import Html.Attributes exposing (style)
import Data.Position as Position exposing (gridDimensions)
import Data.Snake as Snake
import Data.Board as Board
    exposing
        ( Board
        , Msg
        , TileType(..)
        , update
        , tileTypeFromPositionTileTypePairs
        , convertToKVPair
        )


view : Board -> Html Msg
view board =
    Html.div []
        [ mkGrid board
        , text <| "Score: " ++ toString (Board.score board)
        ]


tileSideLength : Int
tileSideLength =
    20


tileLengthPixels : String
tileLengthPixels =
    toString tileSideLength ++ "px"


mkTile : TileType -> List (Html Msg) -> Html Msg
mkTile tileType contents =
    let
        backgroundColor =
            case tileType of
                SnakeSegment playerColour ->
                    "#" ++ playerColour

                AppleTile ->
                    "#C40000"

                EmptyTile ->
                    "transparent"
    in
        Html.div
            [ style
                [ ( "width", tileLengthPixels )
                , ( "height", tileLengthPixels )
                , ( "border", "1px solid #EEEEEE" )
                , ( "float", "left" )
                , ( "margin", "-1px" )
                , ( "font-size", "8px" )
                , ( "background-color", backgroundColor )
                ]
            ]
            contents


mkGrid : Board -> Html Msg
mkGrid { snake, apples } =
    let
        dim =
            gridDimensions

        appleTilePositions =
            List.map (\apple -> ( apple.position, AppleTile )) apples

        snakeTilePositions =
            let
                colour =
                    Snake.colour snake
            in
                List.map (\snakeSegment -> ( snakeSegment, SnakeSegment colour )) snake.body

        positionTilePairs =
            List.concat [ appleTilePositions, snakeTilePositions ]

        renderables =
            Dict.fromList (List.map convertToKVPair positionTilePairs)

        tileTypeForPosn =
            tileTypeFromPositionTileTypePairs renderables

        tileTypeFor x y =
            tileTypeForPosn { x = x, y = y }

        row y =
            Html.div
                [ style
                    [ ( "width"
                      , toString (tileSideLength * dim.x)
                            ++ "px"
                      )
                    ]
                ]
            <|
                (List.range 1 dim.x
                    |> List.map
                        (\x ->
                            mkTile (tileTypeFor x y) []
                        )
                )

        grid =
            List.range 1 dim.y |> List.reverse |> List.map row
    in
        Html.div [] grid
