import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode exposing (map2, map3, map7)
import Url.Builder as Url


-- MAIN

main =
  Browser.element
    {
      init = init,
      update = update,
      subscriptions = subscriptions,
      view = view
    }


-- MODEL

type alias Model =
  {
    query : String,
    citations : CitationResponse,
    citationQuery : String,
    substances : SubstanceResponse,
    substanceQuery : String,
    error : String,
    searchEntity : String,
    loading : Bool
  }

init : () -> (Model, Cmd Msg)
init _ =
  (
    Model "" (CitationResponse 0 []) "" (SubstanceResponse 0 []) "" "" "citation" False,
    Cmd.none
  )


-- UPDATE

type Msg
  = GetCitationResponse (Result Http.Error CitationResponse)
  | GetSubstanceResponse (Result Http.Error SubstanceResponse)
  | CitationInputHandler String
  | SubstanceInputHandler String
  | SubmitHandler
  | SearchEntityChange String
  | UpdateCitationQuery String

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GetCitationResponse result ->
      case result of
        Ok citations ->
          (
            {model | citations = citations, error = "", loading = False},
            Cmd.none
          )

        Err error ->
          (
            {model | error = "Error on request", loading = False},
            Cmd.none
          )

    GetSubstanceResponse result ->
      case result of
        Ok substances ->
          (
            {model | substances = substances, error = "", loading = False},
            Cmd.none
          )

        Err error ->
          (
            {model | error = "Error on request", loading = False},
            Cmd.none
          )

    CitationInputHandler query ->
      (
        {model | citationQuery = query},
        Cmd.none
      )

    SubstanceInputHandler query ->
      (
        {model | substanceQuery = query},
        Cmd.none
      )

    SubmitHandler ->
      (
        {model | loading = True},
        getResponse model
      )

    SearchEntityChange searchEntity ->
      (
        {model | searchEntity = searchEntity},
        Cmd.none
      )

    UpdateCitationQuery query ->
      (
        {model | citationQuery = query},
        Cmd.none
      )


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


-- VIEW

view : Model -> Html Msg
view model =
  div []
    [
      select [onInput SearchEntityChange] [
        option [value "citation"] [text "Citation"],
        option [value "substance"] [text "Substance"]
      ],
      viewValidation model,
      button [onClick SubmitHandler] [text "Get results"],
      loading model.loading,
      br [] [],
      renderResults model
    ]

renderResults : Model -> Html Msg
renderResults model =
  if model.searchEntity == "citation"
  then div [] [
    input [type_ "text", value model.citationQuery, onInput CitationInputHandler, autofocus True] [],
    text ("I found " ++ (String.fromInt model.citations.totalHits) ++ " results"),
    div [] (List.map renderCitationEntities model.citations.entities)
  ]
  else div [] [
    input [type_ "text", value model.substanceQuery, onInput SubstanceInputHandler, autofocus True] [],
    text ("I found " ++ (String.fromInt model.substances.totalHits) ++ " results"),
    div [] (List.map renderSubstanceEntities model.substances.entities)
  ]

listStringRender : String -> Html msg
listStringRender word =
  div [] [
    text word
  ]

renderCitationEntities : Citation -> Html Msg
renderCitationEntities entity =
  div [] [
    h2 [] [text entity.title],
    h3 [] [text "Abstract"],
    div [] [text entity.abstract],
    h3 [] [text "Keywords"],
    div [] (List.map listStringRender (Maybe.withDefault [] entity.keywords)),
    h3 [] [text "Journal Title"],
    div [] [text entity.publicationDetail.publicationname],
    h3 [] [text "Year"],
    div [] [text (String.fromInt entity.publicationDetail.hasPublicationYear)],
    h3 [] [text "Authors"],
    div [] (List.map listStringRender (Maybe.withDefault [] entity.authors)),
    h3 [] [text "Source"],
    div [] [text entity.source],
    h3 [] [text "PUI"],
    div [] [text entity.pui],
    hr [] []
  ]

renderSubstanceEntities : Substance -> Html Msg
renderSubstanceEntities entity =
  div [] [
    h2 [] [text entity.title],
    h3 [] [text "Synonyms"],
    div [] (List.map listStringRender entity.synonyms),
    h3 [] [text "Melting Points"],
    div [] (List.map listStringRender (Maybe.withDefault [] entity.meltingPoints)),
    hr [] []
  ]

viewValidation : Model -> Html Msg
viewValidation model =
  if String.length model.error > 0
  then div [style "color" "red"] [text model.error]
  else div [] []

loading : Bool -> Html Msg
loading showLoading =
  if showLoading
  then div [
    style "position" "absolute",
    style "top" "0",
    style "right" "0",
    style "bottom" "0",
    style "left" "0",
    style "display" "flex",
    style "justify-content" "center",
    style "align-items" "center",
    style "background" "gray",
    style "opacity" "0.7",
    style "color" "white",
    style "font-size" "40px"
  ] [text "loading"]
  else div [style "position" "absolute"] []


-- HTTP

getResponse : Model -> Cmd Msg
getResponse model =
  if model.searchEntity == "citation"
  then Http.send GetCitationResponse (Http.get (prepareCitationQuery model.citationQuery) citationResponseDecoder)
  else Http.send GetSubstanceResponse (Http.get (prepareSubstanceQuery model.substanceQuery) substanceResponseDecoder)

prepareCitationQuery : String -> String
prepareCitationQuery query =
  Url.crossOrigin "http://localhost:4200" ["search/", "citation", "search"]
    [
      Url.int "_from" 0,
      Url.int "_size" 20,
      Url.string "abstract" query,
      Url.string "keywords" query,
      Url.string "title" query
    ]


prepareSubstanceQuery : String -> String
prepareSubstanceQuery query =
  Url.crossOrigin "http://localhost:4200" ["search/", "substance", "search"]
    [
      Url.int "_from" 0,
      Url.int "_size" 20,
      Url.string "displayName.name" query,
      Url.string "substanceNames.name" query
    ]

--CITATION

type alias Citation =
  {
    title : String,
    abstract : String,
    keywords : Maybe (List String),
    publicationDetail : PublicationDetails,
    authors : Maybe (List String),
    source : String,
    pui : String
  }

keywordsDecode : Decode.Decoder (List String)
keywordsDecode =
  Decode.list Decode.string

type alias PublicationDetails = {publicationname : String, hasPublicationYear : Int}

publicationDetailDecode : Decode.Decoder PublicationDetails
publicationDetailDecode =
  map2 PublicationDetails
    (Decode.field "publicationname" Decode.string)
    (Decode.field "hasPublicationYear" Decode.int)

creatorDecode : Decode.Decoder (List String)
creatorDecode =
  Decode.list (Decode.field "name" Decode.string)

citationDecode : Decode.Decoder Citation
citationDecode =
  map7 Citation
    (Decode.field "title" Decode.string)
    (Decode.field "abstract" Decode.string)
    (Decode.maybe (Decode.field "keywords" keywordsDecode))
    (Decode.field "publicationDetail" publicationDetailDecode)
    (Decode.maybe (Decode.field "creator" creatorDecode))
    (Decode.field "provenance" (Decode.field "supplier" (Decode.field "name" Decode.string)))
    (Decode.field "pui" Decode.string)

citationEntitiesDecoder : Decode.Decoder (List Citation)
citationEntitiesDecoder =
  Decode.list citationDecode

type alias CitationResponse = {totalHits : Int, entities : List Citation}

citationResponseDecoder : Decode.Decoder CitationResponse
citationResponseDecoder =
  map2 CitationResponse
    (Decode.field "totalHits" Decode.int)
    (Decode.field "entities" citationEntitiesDecoder)


--SUBSTANCE

type alias Substance =
  {
    title : String,
    synonyms : List String,
    meltingPoints : Maybe (List String)
  }

substanceNamesDecode : Decode.Decoder (List String)
substanceNamesDecode =
  Decode.list (Decode.field "name" Decode.string)

meltingPointsDecode : Decode.Decoder (List String)
meltingPointsDecode =
  Decode.list (Decode.field "temperature" (Decode.field "displayValue" Decode.string))

substanceDecode : Decode.Decoder Substance
substanceDecode =
  map3 Substance
    (Decode.field "displayName" (Decode.field "name" Decode.string))
    (Decode.field "substanceNames" substanceNamesDecode)
    (Decode.maybe (Decode.field "meltingPoint" meltingPointsDecode))

substanceEntitiesDecoder : Decode.Decoder (List Substance)
substanceEntitiesDecoder =
  Decode.list substanceDecode

type alias SubstanceResponse = {totalHits : Int, entities : List Substance}

substanceResponseDecoder : Decode.Decoder SubstanceResponse
substanceResponseDecoder =
  map2 SubstanceResponse
    (Decode.field "totalHits" Decode.int)
    (Decode.field "entities" substanceEntitiesDecoder)
