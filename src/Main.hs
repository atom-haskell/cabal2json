{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.List
import Distribution.Package
import Distribution.PackageDescription
import Distribution.PackageDescription.Parsec (parseGenericPackageDescriptionMaybe)
import Distribution.ModuleName (ModuleName, toFilePath)
import Distribution.Types.UnqualComponentName
import Distribution.Types.Version

import System.Environment (getArgs)
import System.FilePath
import Data.Maybe

import Data.Aeson
import qualified Data.ByteString.Lazy.Char8 as BL
import qualified Data.ByteString as BS

import Distribution.Compat.Lens ((^.))
import qualified Distribution.Types.BuildInfo.Lens as BIL

main :: IO ()
main = do
  args <- getArgs
  Just gdesc <- parseGenericPackageDescriptionMaybe <$> BS.getContents
  case args of
    [] -> do
      BL.putStrLn . encode $ parseDotCabal gdesc
    [file] -> do
      BL.putStrLn . encode $ getComponentFromFile gdesc file
    _ -> fail "Too many arguments"

parseDotCabal :: GenericPackageDescription -> Value
parseDotCabal gpkg
  = let pkg     = package (packageDescription gpkg)
        name    = unPackageName $ pkgName    pkg
        version = versionNumbers $ pkgVersion pkg
        mkobj :: String -> String -> String -> Value
        mkobj p t n = object [
            "type" .= t
          , "name" .= n
          , "target" .= (p ++ n)
          ]
        mkobj' p t = mkobj p t . unUnqualComponentName . fst
        targets = concat [
            [mkobj "lib:" "library" name | isJust $ condLibrary gpkg]
          , mkobj' "lib:" "library" `map` condSubLibraries gpkg
          , mkobj' "exe:" "executable" `map` condExecutables gpkg
          , mkobj' "test:" "test-suite" `map` condTestSuites gpkg
          , mkobj' "bench:" "benchmark" `map` condBenchmarks gpkg
          ]

        descr = object [
            "name"    .= name
          , "version" .= version
          , "targets" .= targets
          ]

    in descr

getComponentFromFile :: GenericPackageDescription -> FilePath -> [String]
getComponentFromFile gpkg file =
  let pkg     = package (packageDescription gpkg)
      name    = unPackageName $ pkgName    pkg
      lookupFile :: BIL.HasBuildInfo a2 => String
                      -> (a1 -> [Either ModuleName FilePath])
                      -> (a2 -> a1)
                      -> String
                      -> CondTree v c a2
                      -> [String]
      lookupFile prefix fjoin ffirst name' tree =
        let
          tr = condTreeData tree
          mainmod = ffirst tr
          info = tr ^. BIL.buildInfo
          omod = otherModules info
          sourceDirs = hsSourceDirs info
          modules = map Left omod ++ fjoin mainmod
          genFP f = map (normalise . (</> f)) sourceDirs
          check = any (
            either (any (`isPrefixOf` file) . genFP . toFilePath)
                   (elem file . genFP))
            modules
          in
            [prefix ++ name' | check]
      lookupFile' p j f (n, t) = lookupFile p j f (unUnqualComponentName n) t
      list = concat $ concat [
                flip map (maybeToList $ condLibrary gpkg) $
                  lookupFile "lib:" (map Left) exposedModules name
              , flip map (condSubLibraries gpkg) $
                  lookupFile' "lib:" (map Left) exposedModules
              , flip map (condExecutables gpkg) $
                  lookupFile' "exe:" (return . Right) modulePath
              , flip map (condTestSuites gpkg) $
                  let
                    ti (TestSuiteExeV10 _version fp) = [Right fp]
                    ti (TestSuiteLibV09 _version mp) = [Left mp]
                    ti (TestSuiteUnsupported _) = []
                  in lookupFile' "test:" id (ti . testInterface)
              , flip map (condBenchmarks gpkg) $
                  let
                    bi (BenchmarkExeV10 _version fp) = [Right fp]
                    bi (BenchmarkUnsupported _) = []
                  in lookupFile' "bench:" id (bi . benchmarkInterface)
              ]
  in list
