#!/usr/bin/runhaskell -Wall
{-
This program assembles the Senior Design report.

Written in 2011 by Steven Robertson <steven@strobe.cc>, and hereby released
into the public domain.
-}

module Main where

import Control.Applicative
import Control.Monad
import System.FilePath
import System.Directory
import System.Exit
import System.Process
import System.IO

import Text.Pandoc
import Text.Pandoc.Shared
import Text.Pandoc.Biblio
import Text.CSL

parseFile refs fn = readFunc startState . filter (/= '\r') <$> readFile fn
  where
    readFunc = case takeExtension fn of
                    ".rst"  -> readRST
                    _       -> readMarkdown
    startState = defaultParserState
        { stateSmart = True
        , stateCitations = map refId refs
        }

renderLaTeX :: FilePath -> [(String, String)] -> Pandoc -> String
renderLaTeX tmpl vars = writeLaTeX writeOpts
  where
    defVars = writerVariables defaultWriterOptions
    writeOpts = defaultWriterOptions
        { writerStandalone = True
        , writerTemplate = tmpl
        , writerVariables = vars ++ defVars
        , writerTableOfContents = True
        , writerXeTeX = True
        , writerNumberSections = True
        , writerSourceDirectory = "."
        , writerCiteMethod = Citeproc
        , writerChapters = True
        }

joinDocs docs = normalize $ Pandoc (meta $ head docs) (concat $ map blocks docs)
  where
    meta (Pandoc m _) = m
    blocks (Pandoc _ b) = b

renderPDF :: FilePath -> FilePath -> IO ExitCode
renderPDF tmpdir inpath =
    rawSystem "xelatex"
        [ "-output-directory", tmpdir
        , "-interaction", "nonstopmode"
        , inpath ]

-- Fix links in bibliography. Could be better.
urlize (Str "Available:":Space:Str u:xs) =
    LineBreak : Link [Str u] ("", u) : urlize xs
urlize x = x

biblioAtEnd = False

main = do
    refs <- readBiblioFile "mendeley.bib"
    sourcePaths <- lines <$> readFile "order.txt"
    sources <- mapM (parseFile refs) sourcePaths

    topmatter <- readFile "topmatter.tex"
    template <- readFile "../latex.template"

    let doBib = processBiblio "../ieee.csl" refs
    joined <- if biblioAtEnd
                 then doBib $ joinDocs sources
                 else joinDocs <$> mapM doBib sources

    let vars = [("report", "1"), ("include-before", topmatter)]
        latex = renderLaTeX template vars $ bottomUp urlize joined

    tmpdir <- fmap (</> "pandoc_report") getTemporaryDirectory
    createDirectoryIfMissing False tmpdir

    let tex = tmpdir </> "report.tex"
        pdf = tmpdir </> "report.pdf"

    writeFile tex latex

    errCode <- renderPDF tmpdir tex
    putStrLn "Running xelatex again to update TOC"
    _ <- renderPDF tmpdir tex

    haveOutput <- doesFileExist pdf
    if haveOutput
       then do
            withBinaryFile pdf ReadMode $ \srch ->
                withBinaryFile "report.pdf" WriteMode $ \dsth ->
                    hPutStr dsth =<< hGetContents srch
            removeFile pdf  -- don't let old reports confuse us
            putStrLn "\n\nDone. Output file is at report.pdf."
            unless (errCode == ExitSuccess) $
                putStrLn $ "NOTE: xelatex exited with errors. "
                        ++ "You may wish to verify the output."
       else putStrLn "ERROR: xelatex did not create an output file."

