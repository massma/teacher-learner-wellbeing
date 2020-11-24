{-# OPTIONS_GHC -Wall #-}
{-# OPTIONS_GHC -Wcompat #-}
{-# OPTIONS_GHC -Wincomplete-record-updates #-}
{-# OPTIONS_GHC -Wincomplete-uni-patterns #-}
{-# OPTIONS_GHC -Wredundant-constraints #-}

module Main
  ( main,
  )
where

import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as CL
import qualified Data.Char as C
import qualified Data.Map as Map
import qualified Data.Maybe as M
import qualified Data.Time as Time
import Development.Shake
import Development.Shake.Command
import Development.Shake.FilePath
import Development.Shake.Util
import qualified Text.ParserCombinators.ReadP as RP

css :: FilePath
css = "pandoc.css"

replaceAll ::
  -- | String to search for
  CL.ByteString ->
  -- | String to repalce
  CL.ByteString ->
  -- | string to search
  CL.ByteString ->
  CL.ByteString
replaceAll s r xs = go xs
  where
    l = CL.length s
    go ys = case CL.splitAt l ys of
      (h, rest)
        | h == s -> r <> go rest
        | CL.null rest -> h
        | otherwise -> CL.cons (CL.head h) (go (CL.drop 1 ys))

websitePandoc ::
  -- | input FilePath
  FilePath ->
  -- | output FilePath
  FilePath ->
  Action ()
websitePandoc input output
  | outExt /= ".html" =
    error ("called websitePandoc on non-html output: " <> output)
  | inExt == ".md" = cmd__ "markdown"
  | inExt == ".org" = cmd__ "org"
  | otherwise = error ("called websitePandoc on unsported input: " <> input)
  where
    inExt = takeExtension input
    outExt = takeExtension output
    cmd__ fromType =
      need
        [ input,
          "public_html" </> dropDirectory1 (takeDirectory output) </> css,
          "Shakefile.hs"
        ]
        >> liftIO (CL.readFile input) >>= \str ->
          cmd_
            "pandoc"
            (StdinBS (replaceAll (CL.pack ".md") (CL.pack ".html") str))
            [ "--standalone",
              "-o",
              output,
              "-c",
              css,
              "--from",
              fromType,
              "--to",
              "html5"
            ]

htmlFromSource :: FilePath -> FilePath
htmlFromSource = (-<.> ".html") . ("public_html" </>) . dropDirectory1

data Person = Person
  { firstName :: String,
    lastName :: String,
    email :: String
  }
  deriving (Show)

data LCConfig = LCConfig
  { facilitators :: [Person],
    date1 :: Time.UTCTime,
    date2 :: Time.UTCTime,
    communityLink :: String,
    hooksLink :: String
  }
  deriving (Show)

defaultLCConfig =
  LCConfig
    { facilitators =
        [ Person
            { firstName = "Abby",
              lastName = "Schroering",
              email = "abby.schroering@columbia.edu"
            },
          Person
            { firstName = "Adam",
              lastName = "Massmann",
              email = "akm2203@columbia.edu"
            }
        ],
      date1 =
        Time.UTCTime
          (Time.fromGregorian 2020 10 21)
          (Time.timeOfDayToTime (Time.TimeOfDay 14 40 0)),
      date2 =
        Time.UTCTime
          (Time.fromGregorian 2020 10 28)
          (Time.timeOfDayToTime (Time.TimeOfDay 14 40 0)),
      communityLink = "https://docs.google.com/document/d/1Q1T8TvVuFR5UGB3tkQnRpxviP8BKMS9X3j1uNLw5QFA/edit?usp=sharing",
      hooksLink = "https://www.routledge.com/Teaching-to-Transgress-Education-as-the-Practice-of-Freedom/hooks/p/book/9780415908085"
    }

parseConfig :: String -> Maybe LCConfig
parseConfig s = (parseMap . Map.fromListWith (<>) . fmap f) xs
  where
    xs :: [(String, String)]
    xs = case parseConfig' s of
      Nothing -> error "failed to parse config"
      Just xs' -> xs'
    headMaybe [] = Nothing
    headMaybe (x : _) = Just x
    f :: (String, String) -> (String, [String])
    f (key, val) = (key, [val])
    parseMap :: Map.Map String [String] -> Maybe LCConfig
    parseMap m = do
      ps <- mapM (maybeParse parseFacilitator) =<< (m Map.!? "facilitator")
      t1 <- parseTime =<< headMaybe =<< (m Map.!? "first session time")
      t2 <- parseTime =<< headMaybe =<< (m Map.!? "second session time")
      ca <- headMaybe =<< (m Map.!? "community agreement link")
      h <- headMaybe =<< (m Map.!? "hooks link")
      return
        ( LCConfig
            { facilitators = ps,
              date1 = t1,
              date2 = t2,
              communityLink = ca,
              hooksLink = h
            }
        )
    -- Time.parseTimeM False Time.defaultTimeLocale "%Y-%m-%d"
    parseTime :: String -> Maybe Time.UTCTime
    parseTime =
      Time.parseTimeM True Time.defaultTimeLocale "%Y-%-m-%-d %-H:%-M"
    parseFacilitator :: RP.ReadP Person
    parseFacilitator = do
      _ <- RP.skipSpaces
      first <- RP.munch1 C.isAlpha
      _ <- RP.skipSpaces
      last' <- RP.munch1 C.isAlpha
      _ <- RP.skipSpaces >> RP.char '('
      email' <- RP.munch1 (/= ')')
      _ <- RP.char ')' >> RP.skipSpaces
      return (Person {firstName = first, lastName = last', email = email'})

maybeParse :: RP.ReadP a -> String -> Maybe a
maybeParse p s = case RP.readP_to_S p s of
  (x, "") : [] -> Just x
  (_x, _xs) : _ -> Nothing
  _ -> Nothing

parseConfig' :: String -> Maybe [(String, String)]
parseConfig' s = maybeParse parser s
  where
    row = do
      key <- RP.munch1 (/= ':')
      _ <- RP.char ':'
      _ <- RP.skipSpaces
      value <- RP.many1 (RP.satisfy (/= '\n'))
      _ <- RP.char '\n'
      return (key, value)

    parser = do
      _ <- RP.skipSpaces
      xs <- RP.many1 row
      _ <- RP.skipSpaces >> RP.eof
      return xs

test :: String
test =
  "facilitator: Abby Schroering (abby.schroering@columbia.edu)\nfacilitator: Adam Massmann (akm2203@columbia.edu)\nfirst session time: 2020-10-21 14:40\nsecond session time: 2020-10-28 14:40\ncommunity agreement link: https://docs.google.com/document/d/1Q1T8TvVuFR5UGB3tkQnRpxviP8BKMS9X3j1uNLw5QFA/edit?usp=sharing\nhooks link: https://www.routledge.com/Teaching-to-Transgress-Education-as-the-Practice-of-Freedom/hooks/p/book/9780415908085\n"

main :: IO ()
main = shakeArgs shakeOptions {shakeFiles = "_build"} $ do
  action $ do
    inputs <-
      fmap ("website-src" </>)
        <$> getDirectoryFiles "website-src" ["//*.org", "//*.md", "//*.html"]
    need (fmap htmlFromSource inputs)

  "public_html//*.html" %> \out -> do
    let possibleSources =
          fmap
            (("website-src" </> dropDirectory1 out) -<.>)
            ["html", "md", "org"]
    sources <-
      mapM (\x -> doesFileExist x >>= \bool -> return (bool, x)) possibleSources
    case sources of
      (True, html) : _rest -> need [html] >> cmd_ "cp" [html, out]
      _ : (True, md) : _rest -> websitePandoc md out
      _ : _ : (True, org) : _rest -> websitePandoc org out
      _ -> error ("No html, md, or org source file for: " <> out)

  "public_html//*.css" %> \out -> do
    let input = "website-src" </> css
    need [input]
    cmd_ "cp" [input, out]

  phony "clean" $ do
    putInfo "Cleaning files in _build"
    removeFilesAfter "_build" ["//*"]
