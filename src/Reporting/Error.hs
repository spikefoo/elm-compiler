{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE OverloadedStrings #-}
module Reporting.Error where

import Data.Aeson ((.=))
import qualified Data.Aeson as Json
import Prelude hiding (print)

import qualified Reporting.Annotation as A
import qualified Reporting.Error.Canonicalize as Canonicalize
import qualified Reporting.Error.Syntax as Syntax
import qualified Reporting.Error.Type as Type
import qualified Reporting.PrettyPrint as P
import qualified Reporting.Report as Report


-- ALL POSSIBLE ERRORS

data Error
    = Syntax Syntax.Error
    | Canonicalize Canonicalize.Error
    | Type Type.Error


-- TO REPORT

toReport :: P.Dealiaser -> Error -> Report.Report
toReport dealiaser err =
  case err of
    Syntax syntaxError ->
        Syntax.toReport dealiaser syntaxError

    Canonicalize canonicalizeError ->
        Canonicalize.toReport dealiaser canonicalizeError

    Type typeError ->
        Type.toReport dealiaser typeError


-- TO STRING

toString :: P.Dealiaser -> String -> String -> A.Located Error -> String
toString dealiaser location source (A.A region err) =
  Report.toString location region (toReport dealiaser err) source


print :: P.Dealiaser -> String -> String -> A.Located Error -> IO ()
print dealiaser location source (A.A region err) =
  Report.printError location region (toReport dealiaser err) source


-- TO JSON

toJson :: P.Dealiaser -> FilePath -> A.Located Error -> Json.Value
toJson dealiaser filePath (A.A region err) =
  let
    (maybeRegion, additionalFields) =
        case err of
          Syntax syntaxError ->
              Report.toJson [] (Syntax.toReport dealiaser syntaxError)

          Canonicalize canonicalizeError ->
              let
                suggestions =
                  maybe []
                      (\s -> ["suggestions" .= s])
                      (Canonicalize.extractSuggestions canonicalizeError)
              in
                Report.toJson suggestions (Canonicalize.toReport dealiaser canonicalizeError)

          Type typeError ->
              Report.toJson [] (Type.toReport dealiaser typeError)
  in
      Json.object $
        [ "file" .= filePath
        , "region" .= maybe region id maybeRegion
        , "type" .= ("error" :: String)
        ]
        ++ additionalFields
