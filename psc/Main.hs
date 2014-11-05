-----------------------------------------------------------------------------
--
-- Module      :  Main
-- Copyright   :  (c) Phil Freeman 2013
-- License     :  MIT
--
-- Maintainer  :  Phil Freeman <paf31@cantab.net>
-- Stability   :  experimental
-- Portability :
--
-- |
--
-----------------------------------------------------------------------------

{-# LANGUAGE DataKinds, GeneralizedNewtypeDeriving, TupleSections, RecordWildCards #-}

module Main where

import Control.Applicative
import Control.Monad.Error

import Data.Bool (bool)
import Data.Version (showVersion)

import System.Console.CmdTheLine
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory)
import System.Exit (exitSuccess, exitFailure)
import System.IO (stderr)

import qualified Language.PureScript as P
import qualified Paths_purescript as Paths
import qualified System.IO.UTF8 as U

data InputOptions = InputOptions
  { ioNoPrelude   :: Bool
  , ioUseStdIn    :: Bool
  , ioInputFiles  :: [FilePath]
  }

readInput :: InputOptions -> IO [(Maybe FilePath, String)]
readInput InputOptions{..}
  | ioUseStdIn = return . (Nothing ,) <$> getContents
  | otherwise = do content <- forM ioInputFiles $ \inputFile -> (Just inputFile, ) <$> U.readFile inputFile
                   return $ bool ((Nothing, P.prelude) :) id ioNoPrelude content

compile :: P.Options P.Compile -> Bool -> [FilePath] -> Maybe FilePath -> Maybe FilePath -> Bool -> IO ()
compile opts stdin input output externs usePrefix = do
  modules <- P.parseModulesFromFiles <$> readInput (InputOptions (P.optionsNoPrelude opts) stdin input)
  case modules of
    Left err -> do
      U.hPutStr stderr $ show err
      exitFailure
    Right ms -> do
      case P.compile opts (map snd ms) prefix of
        Left err -> do
          U.hPutStrLn stderr err
          exitFailure
        Right (js, exts, _) -> do
          case output of
            Just path -> mkdirp path >> U.writeFile path js
            Nothing -> U.putStrLn js
          case externs of
            Just path -> mkdirp path >> U.writeFile path exts
            Nothing -> return ()
          exitSuccess
  where
  prefix = if usePrefix
              then ["Generated by psc version " ++ showVersion Paths.version]
              else []

mkdirp :: FilePath -> IO ()
mkdirp = createDirectoryIfMissing True . takeDirectory

useStdIn :: Term Bool
useStdIn = value . flag $ (optInfo [ "s", "stdin" ])
     { optDoc = "Read from standard input" }

inputFiles :: Term [FilePath]
inputFiles = value $ posAny [] $ posInfo
     { posDoc = "The input .ps files" }

outputFile :: Term (Maybe FilePath)
outputFile = value $ opt Nothing $ (optInfo [ "o", "output" ])
     { optDoc = "The output .js file" }

externsFile :: Term (Maybe FilePath)
externsFile = value $ opt Nothing $ (optInfo [ "e", "externs" ])
     { optDoc = "The output .e.ps file" }

noTco :: Term Bool
noTco = value $ flag $ (optInfo [ "no-tco" ])
     { optDoc = "Disable tail call optimizations" }

noPrelude :: Term Bool
noPrelude = value $ flag $ (optInfo [ "no-prelude" ])
     { optDoc = "Omit the Prelude" }

noMagicDo :: Term Bool
noMagicDo = value $ flag $ (optInfo [ "no-magic-do" ])
     { optDoc = "Disable the optimization that overloads the do keyword to generate efficient code specifically for the Eff monad." }

runMain :: Term (Maybe String)
runMain = value $ defaultOpt (Just "Main") Nothing $ (optInfo [ "main" ])
     { optDoc = "Generate code to run the main method in the specified module." }

noOpts :: Term Bool
noOpts = value $ flag $ (optInfo [ "no-opts" ])
     { optDoc = "Skip the optimization phase." }

browserNamespace :: Term String
browserNamespace = value $ opt "PS" $ (optInfo [ "browser-namespace" ])
     { optDoc = "Specify the namespace that PureScript modules will be exported to when running in the browser." }

dceModules :: Term [String]
dceModules = value $ optAll [] $ (optInfo [ "m", "module" ])
     { optDoc = "Enables dead code elimination, all code which is not a transitive dependency of a specified module will be removed. This argument can be used multiple times." }

codeGenModules :: Term [String]
codeGenModules = value $ optAll [] $ (optInfo [ "codegen" ])
     { optDoc = "A list of modules for which Javascript and externs should be generated. This argument can be used multiple times." }

verboseErrors :: Term Bool
verboseErrors = value $ flag $ (optInfo [ "v", "verbose-errors" ])
     { optDoc = "Display verbose error messages" }

noPrefix :: Term Bool
noPrefix = value $ flag $ (optInfo ["no-prefix" ])
     { optDoc = "Do not include comment header"}

options :: Term (P.Options P.Compile)
options = P.Options <$> noPrelude <*> noTco <*> noMagicDo <*> runMain <*> noOpts <*> verboseErrors <*> additionalOptions
  where
  additionalOptions = P.CompileOptions <$> browserNamespace <*> dceModules <*> codeGenModules

term :: Term (IO ())
term = compile <$> options <*> useStdIn <*> inputFiles <*> outputFile <*> externsFile <*> (not <$> noPrefix)

termInfo :: TermInfo
termInfo = defTI
  { termName = "psc"
  , version  = showVersion Paths.version
  , termDoc  = "Compiles PureScript to Javascript"
  }

main :: IO ()
main = run (term, termInfo)


