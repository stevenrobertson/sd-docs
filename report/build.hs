#!/usr/bin/runhaskell -Wall
{-
This program assembles the Senior Design report.

Written in 2011 by Steven Robertson <steven@strobe.cc>, and hereby released
into the public domain.
-}

module Main where

import Control.Applicative
import Control.Arrow
import Control.Monad
import Data.Char (toUpper, isSpace)
import Data.Either
import System.FilePath
import System.Directory
import System.Exit
import System.Process
import System.IO

import Text.Pandoc
import Text.Pandoc.Shared
import Text.Pandoc.Biblio
import Text.Parsec hiding ((<|>), many)
import qualified Text.PrettyPrint as P
import Text.PrettyPrint (Doc, ($$), (<>), nest, vcat, fsep, text, int, colon)
import Text.CSL

data AnnoType = TODO | CITE | CHECK | REF deriving (Eq, Ord, Enum, Show)
data Annotation = Annotation
    { anType    :: AnnoType
    , anPos     :: SourcePos
    , anMsg     :: String
    } deriving (Show)

-- Given a filename (for proper source description) and an input source,
-- return a copy of the input source stripped of annotations and a list of
-- those annotations.
parseAnno :: FilePath -> String -> (String, [Annotation])
parseAnno fn s = either (error . show) (((concat . rights) &&& lefts) . finish)
               $ parse parser fn s
  where
    parser :: Parsec String () [Either Annotation String]
    parser = (:) <$> (anno <|> content) <*> (([] <$ eof) <|> parser)
    anno = try $ between (char '[') (char ']')
               $ Left <$> (Annotation <$> atype <*> getPosition <*> amesg)
    atype = choice [x <$ try (string $ show x) | x <- [TODO ..]]
    amesg = unwords . words <$> (skipMany (char ':') *> many (noneOf "]"))
    content = Right <$> ((:) <$> anyChar <*> many (noneOf "["))
    finish (Right s : Left anno : xs) | isSpace (last s) =
        Right (init s) : Left anno : finish xs
    finish (x:xs) = x : finish xs
    finish [] = []

parseFile :: [Reference] -> FilePath -> IO (Pandoc, [Annotation])
parseFile refs fn =
    first (readFunc startState) . parseAnno fn . filter (/= '\r') <$> readFile fn
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
urlize (Str "Available:":Space:Str u:xs) = Link [Str u] ("", u) : urlize xs
urlize (Str "DOI:":Space:Str u:xs) =
    Link [Str $ "doi:" ++ u] ("", "http://dx.doi.org/" ++ u) : urlize xs
urlize x = x

biblioAtEnd = False

-- Creates a pretty-print document which covers a single file's annotations
pprAnnos :: [Annotation] -> Doc
pprAnnos [] = P.empty
pprAnnos annos = header $$ nest 2 (vcat $ map go annos)
  where
    header = text ("In file '" ++ (sourceName . anPos $ head annos) ++ "':")
    go anno = text "Line " <> int (sourceLine $ anPos anno) <> colon
            $$ nest 10 (msg (typeStr (anType anno)) (anMsg anno))
    typeStr CITE = text "Citation"
    typeStr t = text (show t)
    msg ty [] = ty
    msg ty m = fsep ((ty <> colon) : map text (words m))

main = do
    refs <- readBiblioFile "mendeley.bib"
    sourcePaths <- lines <$> readFile "order.txt"
    (sources, annos) <- unzip <$> mapM (parseFile refs) sourcePaths

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

    putStrLn "\n\nDocument annotations:"
    print . vcat $ map pprAnnos annos

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


