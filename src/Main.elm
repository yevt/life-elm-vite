port module Main exposing (Model, Mode, Msg, main)

import Html exposing (Html, button, div, input, text, label)
import Html.Attributes exposing (class, style, value, id)
import Html.Events exposing (onClick, onInput)
import Time
import Browser

port screenSize : ((Int, Int) -> msg) -> Sub msg


main : Program String Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type Mode
    = Setup
    | Simulation


type alias Model =
    { mode : Mode
    , worldWidth : Int
    , worldHeight : Int
    , cells : List Int
    , tick : Int -- iteration counter
    , tickDuration: Int -- ms
    , screenWidth: Int
    , screenHeight: Int
    , cellWidth: Int
    , cellHeight: Int
    }



-- INITIAL FIELD



init : String -> ( Model, Cmd Msg )
init _ =
    (
        { mode = Setup
        , worldWidth = 0 -- cells
        , worldHeight = 0
        , cells = []
        , tick = 0 -- iteration counter
        , tickDuration = 1000 -- ms
        , screenWidth = 0 -- px
        , screenHeight = 0
        , cellWidth = 25
        , cellHeight = 25
        }
        , Cmd.none
    )






-- UPDATE


type Msg
    = StartSimulation
    | Tick Time.Posix
    | SetTickDuration String
    | ToggleCell Int
    | ScreenSize (Int, Int)


evolve : Int -> Int -> List Int -> List Int
evolve width height cells =
    let
        indexedCells : List {x : Int, y : Int, content : Int}
        indexedCells =
            List.indexedMap
                (\index cell ->
                    -- { x = index % width
                    { x = remainderBy width index
                    , y = index // width
                    , content = cell
                    }
                )
                cells

        isAdjacent target other =
            let
                xDiff =
                    abs (target.x - other.x)

                yDiff =
                    abs (target.y - other.y)

                xMax =
                    width - 1

                yMax =
                    height - 1
            in
            (xDiff <= 1 || xDiff == xMax) && (yDiff <= 1 || yDiff == yMax) && not (xDiff == 0 && yDiff == 0)

        cellsWithAdjacent =
            List.map
                (\target ->
                    let
                        adjacentCells =
                            List.filter (\other -> isAdjacent target other) indexedCells

                        adjacentCount =
                            List.map (\cell -> cell.content) adjacentCells |> List.sum
                    in
                    { x = target.x
                    , y = target.y
                    , content = target.content
                    , adjacentCount = adjacentCount
                    , adjacentCells = adjacentCells
                    }
                )
                indexedCells
    in
    List.map
        (\target ->
            if target.adjacentCount == 3 then
                1
            else if target.adjacentCount == 2 then
                target.content
            else
                0
        )
        cellsWithAdjacent


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StartSimulation ->
            ( { model | mode = Simulation }, Cmd.none )

        Tick time ->
            ( { model
                | tick = model.tick + 1
                , cells = evolve model.worldWidth model.worldHeight model.cells
              }
            , Cmd.none
            )



        ToggleCell index ->
            ( { model | cells = List.indexedMap (\i v -> 
                if i == index then
                    if v == 1 then 0 else 1
                else
                    v
              ) model.cells }
            , Cmd.none
            )

        SetTickDuration duration ->
            let 
                parsedTickDuration =
                    case String.toInt duration of
                        Nothing -> 
                            200
                        Just d ->
                            d
            in
                ( { model | tickDuration = parsedTickDuration}
                , Cmd.none
                )        

        ScreenSize (w, h) -> 
            let 
                ww = w // model.cellWidth + 1
                wh = h // model.cellHeight + 1
            in
                ( { model 
                        | screenWidth = ww * model.cellWidth
                        , screenHeight = wh * model.cellHeight
                        , worldWidth = ww
                        , worldHeight = wh
                        , cells = List.repeat (ww * wh) 0
                    }
                , Cmd.none 
                )
        
        -- ScreenSize (w, h) -> ( model, Cmd.none )
        




-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [
        case model.mode of
            Simulation ->
                Time.every (toFloat model.tickDuration) Tick

            Setup ->
                Sub.none

        , screenSize ScreenSize
    ]



-- VIEW

viewCell : Int -> Int -> Model -> Html Msg
viewCell index value model =
    let
        color =
            case value of
                1 ->
                    "green"

                _ ->
                    "grey"
            
    in
    Html.div [ 
        style "backgroundColor" color,
        style "width" (String.fromInt model.cellWidth ++ "px"),
        style "height" (String.fromInt model.cellHeight ++ "px")
        -- style
        --     [ ( "backgroundColor", color )
        --     , ( "width", String.fromInt model.cellWidth ++ "px" )
        --     , ( "height", String.fromInt model.cellHeight ++ "px" )
        --     ]
        , onClick ( ToggleCell index )
    ] []


-- transformIntMsgToStringMsg : (Int -> Msg) -> (String -> Msg)
-- transformIntMsgToStringMsg intMsg =
--     \value -> intMsg (Result.withDefault 0 (String.toInt value))

-- transformIntMsgToStringMsg : (Int -> Msg) -> (String -> Msg)
-- transformIntMsgToStringMsg floatMsg =
--     \string -> floatMsg (Result.withDefault 0 (String.toFloat string))



stylesheet : Html Msg
stylesheet =
    Html.node "link" [ Html.Attributes.rel "stylesheet", Html.Attributes.href "style.css" ] []

worldStyle model =
    style "width" ((String.fromInt model.screenWidth) ++ "px")


view : Model -> Html Msg
view model =
    Html.div []
        [ stylesheet
        , div [ class "settings", id "settings"]
            [
            label [] [text "Tick (ms): "] 
            , input
                [ class "tick-duration"
                , value (String.fromInt model.tickDuration)
                , onInput SetTickDuration
                ]
                []
            , div [ class "controls" ]
                [ button [ onClick StartSimulation ] [ text "Start Simulation" ]
                ]
            ]
        , div
            [ class "world"
            , id "world"
            , worldStyle model
            ]
            (List.indexedMap (\i v -> viewCell i v model) model.cells) 
        ]
