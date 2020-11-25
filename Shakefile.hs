{-# OPTIONS_GHC -Wall #-}
{-# OPTIONS_GHC -Wcompat #-}
{-# OPTIONS_GHC -Wincomplete-record-updates #-}
{-# OPTIONS_GHC -Wincomplete-uni-patterns #-}
{-# OPTIONS_GHC -Wredundant-constraints #-}

module Main
  ( main,
  )
where

import Control.Applicative ((<|>))
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as CL
import qualified Data.Char as C
import qualified Data.List as L
import qualified Data.Map as Map
import qualified Data.Maybe as M
import qualified Data.Time as Time
import Development.Shake
import Development.Shake.Command
import Development.Shake.FilePath
import Development.Shake.Util
import qualified Text.ParserCombinators.ReadP as RP
import Text.Printf

css :: FilePath
css = "pandoc.css"

replaceAllBS ::
  -- | String to search for
  CL.ByteString ->
  -- | String to repalce
  CL.ByteString ->
  -- | string to search
  CL.ByteString ->
  CL.ByteString
replaceAllBS s r xs = go xs
  where
    l = CL.length s
    go ys = case CL.splitAt l ys of
      (h, rest)
        | h == s -> r <> go rest
        | CL.null rest -> h
        | otherwise -> CL.cons (CL.head h) (go (CL.drop 1 ys))

replaceAll ::
  -- | String to search for
  String ->
  -- | String to repalce
  String ->
  -- | string to search
  String ->
  String
replaceAll s r xs = go xs
  where
    l = length s
    go ys = case splitAt l ys of
      (h, rest)
        | h == s -> r <> go rest
        | null rest -> h
        | otherwise -> (head h) : (go (drop 1 ys))

websitePandoc ::
  -- | config
  LCConfig ->
  -- | input FilePath
  FilePath ->
  -- | output FilePath
  FilePath ->
  Action ()
websitePandoc lc input output
  | outExt /= ".html" =
    error ("called websitePandoc on non-html output: " <> output)
  | inExt == ".md" = cmd__ "markdown"
  | inExt == ".org" = cmd__ "org"
  | otherwise = error ("called websitePandoc on unsported input: " <> input)
  where
    inExt = takeExtension input
    outExt = takeExtension output
    isInstruction = (== ["instructions"]) . take 1 . drop 1 . splitDirectories
    writer =
      if isInstruction input && not (fillInstructions lc)
        then writeVerbatim
        else writeMarkdown lc
    cmd__ fromType =
      need
        [ input,
          "public_html" </> dropDirectory1 (takeDirectory output) </> css,
          "Shakefile.hs"
        ]
        >> liftIO (readFile input) >>= \str ->
          cmd_
            "pandoc"
            ( Stdin
                ( ( M.fromMaybe str
                      . (\s -> writer <$> maybeParse parseMarkdown s)
                      . replaceAll ".md" ".html"
                  )
                    str
                )
            )
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
  { firstName :: !String,
    lastName :: !String,
    email :: !String
  }
  deriving (Show)

data LCConfig = LCConfig
  { facilitators :: ![Person],
    date1 :: !Time.UTCTime,
    date2 :: !Time.UTCTime,
    location :: !String,
    communityLink :: !String,
    hooksLink :: !String,
    feedbackLink :: !String,
    discussionLink :: !String,
    collab1Link :: !String,
    collab2Link :: !String,
    fillInstructions :: !Bool
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
      location = "<ZOOM LINK>",
      communityLink = "https://docs.google.com/document/d/1Q1T8TvVuFR5UGB3tkQnRpxviP8BKMS9X3j1uNLw5QFA/edit?usp=sharing",
      hooksLink = "https://www.routledge.com/Teaching-to-Transgress-Education-as-the-Practice-of-Freedom/hooks/p/book/9780415908085",
      feedbackLink = "https://pollev.com/adammassmann443",
      discussionLink = "https://github.com/massma/teacher-learner-wellbeing/issues",
      collab1Link = "https://docs.google.com/document/d/1MNI5cris19PANJOVwfO1ulTDXVTP5QNcTBtEP239o5M/edit?usp=sharing",
      collab2Link = "https://docs.google.com/document/d/10Kguon2fR8t5W1ILTJdXRxIScIaJ9GrUkJHxeQkuUeQ/edit?usp=sharing",
      fillInstructions = False
    }

testT :: Time.UTCTime
testT =
  Time.UTCTime
    (Time.fromGregorian 2020 10 21)
    (Time.timeOfDayToTime (Time.TimeOfDay 14 40 0))

data ParsedMarkdown = Text !String | WildCard ![String] deriving (Show)

parseMarkdown :: RP.ReadP [ParsedMarkdown]
parseMarkdown = do
  xs <- RP.many (t <|> wildcard)
  _ <- RP.eof
  return xs
  where
    t = Text <$> RP.munch1 (/= '`')
    wildcard = do
      _ <- RP.char '`'
      words <-
        RP.sepBy1
          (RP.munch1 (\x -> C.isAlphaNum x || (x == '\'')))
          (RP.munch1 C.isSpace)
      _ <- RP.char '`'
      return (WildCard words)

writeVerbatim :: [ParsedMarkdown] -> String
writeVerbatim = concat . fmap f
  where
    f (Text x) = x
    f (WildCard xs) =
      (('`' :) . (<> "`") . concat . L.intersperse " ") xs

writeMarkdown :: LCConfig -> [ParsedMarkdown] -> String
writeMarkdown lc = foldMap f
  where
    timePrinter = Time.formatTime Time.defaultTimeLocale "%A, %B %-d at %-I:%M %P"
    dayPrinter = Time.formatTime Time.defaultTimeLocale "%A"
    concatPeople = foldr g ""
      where
        g x "" = x
        g x y = x <> " and " <> y
    emailPrinter =
      concatPeople . fmap (\p -> printf "%s (%s)" (firstName p) (email p))
    linkPrinter x = "<" <> x <> ">"
    f (Text x) = x
    f (WildCard ["DATE", "OF", "WORKSHOP", "PART", "1"]) = timePrinter (date1 lc)
    f (WildCard ["DATE", "OF", "WORKSHOP", "PART", "2"]) = timePrinter (date2 lc)
    f (WildCard ["DAY", "OF", "WORKSHOP", "PART", "1"]) = dayPrinter (date1 lc)
    f (WildCard ["DAY", "OF", "WORKSHOP", "PART", "2"]) = dayPrinter (date2 lc)
    f (WildCard ["LOCATION"]) = location lc
    f (WildCard ["FACILITATORS'", "EMAIL"]) = emailPrinter (facilitators lc)
    f (WildCard ["FACILITATORS'", "NAME"]) =
      (concatPeople . fmap firstName . facilitators) lc
    f (WildCard ["LINK", "TO", "COMMUNITY", "AGREEMENT"]) =
      linkPrinter (communityLink lc)
    f (WildCard ["LINK", "TO", "HOOKS"]) =
      linkPrinter (hooksLink lc)
    f (WildCard ["LINK", "TO", "FEEDBACK", "SURVEY"]) =
      linkPrinter (feedbackLink lc)
    f (WildCard ["LINK", "TO", "DISCUSSION", "BOARD"]) =
      linkPrinter (discussionLink lc)
    f (WildCard ["LINK", "TO", "COLLABORATIVE", "DOC", "1"]) =
      linkPrinter (collab1Link lc)
    f (WildCard ["LINK", "TO", "COLLABORATIVE", "DOC", "2"]) =
      linkPrinter (collab2Link lc)
    f (WildCard x) = error ("unimplemented key in markdown: " <> show x)

test :: String
test = ":asdlfkjl;asdkjf \nasdflkj; `WILDCARD' BY\n ADAM`\nasdflk;j"

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
      l <- g "location"
      ca <- g "community agreement link"
      h <- g "hooks link"
      fl <- g "feedback link"
      dl <- g "discussion link"
      cd1 <- g "collab doc 1 link"
      cd2 <- g "collab doc 2 link"
      fill <- maybeParse parseBool =<< headMaybe =<< (m Map.!? "fill instructions")
      -- let fill = False
      return
        ( LCConfig
            { facilitators = ps,
              date1 = t1,
              date2 = t2,
              location = l,
              communityLink = ca,
              hooksLink = h,
              feedbackLink = fl,
              discussionLink = dl,
              collab1Link = cd1,
              collab2Link = cd2,
              fillInstructions = fill
            }
        )
      where
        g x = headMaybe =<< (m Map.!? x)
    -- Time.parseTimeM False Time.defaultTimeLocale "%Y-%m-%d"
    parseBool :: RP.ReadP Bool
    parseBool = RP.readS_to_P reads
    parseTime :: String -> Maybe Time.UTCTime
    parseTime =
      Time.parseTimeM True Time.defaultTimeLocale "%Y-%-m-%-d %-H:%-M"
    parseFacilitator :: RP.ReadP Person
    parseFacilitator = do
      _ <- RP.skipSpaces
      first' <- RP.munch1 C.isAlpha
      _ <- RP.skipSpaces
      last' <- RP.munch1 C.isAlpha
      _ <- RP.skipSpaces >> RP.char '('
      email' <- RP.munch1 (/= ')')
      _ <- RP.char ')' >> RP.skipSpaces
      return (Person {firstName = first', lastName = last', email = email'})

maybeParse :: RP.ReadP a -> String -> Maybe a
maybeParse p s = case RP.readP_to_S p s of
  (x, "") : [] -> Just x
  (_x, _xs) : _ -> Nothing
  [] -> Nothing

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

-- htmlRule lc =

-- shakeArgsWith is what we want
-- return config'

main :: IO ()
main = shakeArgs shakeOptions {shakeFiles = "_build"} $ do
  let configPath = "abby-adam.config"

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
    lcConfig <-
      M.fromMaybe defaultLCConfig . parseConfig <$> readFile' configPath
    sources <-
      mapM (\x -> doesFileExist x >>= \bool -> return (bool, x)) possibleSources
    case sources of
      (True, html) : _rest -> need [html] >> cmd_ "cp" [html, out]
      _ : (True, md) : _rest -> websitePandoc lcConfig md out
      _ : _ : (True, org) : _rest -> websitePandoc lcConfig org out
      _ -> error ("No html, md, or org source file for: " <> out)

  "public_html//*.css" %> \out -> do
    let input = "website-src" </> css
    need [input]
    cmd_ "cp" [input, out]

  phony "clean" $ do
    putInfo "Cleaning files in _build"
    removeFilesAfter "_build" ["//*"]
