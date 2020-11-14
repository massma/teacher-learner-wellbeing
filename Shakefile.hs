{-# OPTIONS_GHC -Wall #-}
{-# OPTIONS_GHC -Wcompat #-}
{-# OPTIONS_GHC -Wincomplete-record-updates #-}
{-# OPTIONS_GHC -Wincomplete-uni-patterns #-}
{-# OPTIONS_GHC -Wredundant-constraints #-}

module Main
  ( main,
  )
where

import Development.Shake
import Development.Shake.Command
import Development.Shake.FilePath
import Development.Shake.Util

css :: FilePath
css = "pandoc.css"

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
      need [input, "public_html" </> css, "Shakefile.hs"]
        >> cmd_
          "pandoc"
          [ "--standalone",
            "-o",
            output,
            "-c",
            css,
            "--from",
            fromType,
            "--to",
            "html5",
            input
          ]

main :: IO ()
main = shakeArgs shakeOptions {shakeFiles = "_build"} $ do
  action $ need (fmap ("public_html" </>) ["index.html"])

  "public_html/*.html" %> \out -> do
    let possibleSources =
          fmap
            (("website-src" </> takeFileName out) -<.>)
            ["html", "md", "org"]
    sources <-
      mapM (\x -> doesFileExist x >>= \bool -> return (bool, x)) possibleSources
    case sources of
      (True, html) : _rest -> need [html] >> cmd_ "cp" [html, out]
      _ : (True, md) : _rest -> websitePandoc md out
      _ : _ : (True, org) : _rest -> websitePandoc org out
      _ -> error ("No html, md, or org source file for: " <> out)

  "public_html/*.css" %> \out -> do
    let input = "website-src" </> takeFileName out
    need [input]
    cmd_ "cp" [input, out]

  phony "clean" $ do
    putInfo "Cleaning files in _build"
    removeFilesAfter "_build" ["//*"]
