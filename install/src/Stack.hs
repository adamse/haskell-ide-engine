module Stack where

import           Development.Shake
import           Development.Shake.Command
import           Development.Shake.FilePath
import           Control.Monad
import           System.Directory                         ( copyFile )

import           Version
import           Print
import           Env


stackBuildHie :: VersionNumber -> Action ()
stackBuildHie versionNumber = execStackWithGhc_ versionNumber ["build"]
  `actionOnException` liftIO (putStrLn stackBuildFailMsg)

-- | copy the built binaries into the localBinDir
stackInstallHie :: VersionNumber -> Action ()
stackInstallHie versionNumber = do
  execStackWithGhc_ versionNumber ["install"]
  localBinDir <- getLocalBin
  let hie = "hie" <.> exe
  liftIO $ do
    copyFile (localBinDir </> hie)
             (localBinDir </> "hie-" ++ versionNumber <.> exe)
    copyFile (localBinDir </> hie)
             (localBinDir </> "hie-" ++ dropExtension versionNumber <.> exe)

buildCopyCompilerTool :: VersionNumber -> Action ()
buildCopyCompilerTool versionNumber =
  execStackWithGhc_ versionNumber ["build", "--copy-compiler-tool"]


-- | check `stack` has the required version
checkStack :: Action ()
checkStack = do
  stackVersion <- trimmedStdout <$> execStackShake ["--numeric-version"]
  unless (checkVersion requiredStackVersion stackVersion) $ do
    printInStars $ stackExeIsOldFailMsg stackVersion
    error $ stackExeIsOldFailMsg stackVersion

-- | Get the local binary path of stack.
-- Equal to the command `stack path --local-bin`
getLocalBin :: Action FilePath
getLocalBin = do
  Stdout stackLocalDir' <- execStackShake ["path", "--local-bin"]
  return $ trim stackLocalDir'

stackBuildData :: Action ()
stackBuildData = do
  execStackShake_ ["build", "hoogle"]
  execStackShake_ ["exec", "hoogle", "generate"]

-- | Execute a stack command for a specified ghc, discarding the output
execStackWithGhc_ :: VersionNumber -> [String] -> Action ()
execStackWithGhc_ versionNumber args = do
  let stackFile = "stack-" ++ versionNumber ++ ".yaml"
  command_ [] "stack" (("--stack-yaml=" ++ stackFile) : args)

-- | Execute a stack command for a specified ghc
execStackWithGhc :: CmdResult r => VersionNumber -> [String] -> Action r
execStackWithGhc versionNumber args = do
  let stackFile = "stack-" ++ versionNumber ++ ".yaml"
  command [] "stack" (("--stack-yaml=" ++ stackFile) : args)

-- | Execute a stack command with the same resolver as the build script
execStackShake :: CmdResult r => [String] -> Action r
execStackShake args = command [] "stack" ("--stack-yaml=install/shake.yaml" : args)

-- | Execute a stack command with the same resolver as the build script, discarding the output
execStackShake_ :: [String] -> Action ()
execStackShake_ args = command_ [] "stack" ("--stack-yaml=install/shake.yaml" : args)


-- | Error message when the `stack` binary is an older version
stackExeIsOldFailMsg :: String -> String
stackExeIsOldFailMsg stackVersion =
  "The `stack` executable is outdated.\n"
    ++ "found version is `"
    ++ stackVersion
    ++ "`.\n"
    ++ "required version is `"
    ++ versionToString requiredStackVersion
    ++ "`.\n"
    ++ "Please run `stack upgrade` to upgrade your stack installation"

requiredStackVersion :: RequiredVersion
requiredStackVersion = [1, 9, 3]

-- |Stack build fails message
stackBuildFailMsg :: String
stackBuildFailMsg =
  embedInStars
    $  "Building failed, "
    ++ "Try running `stack clean` and restart the build\n"
    ++ "If this does not work, open an issue at \n"
    ++ "\thttps://github.com/haskell/haskell-ide-engine"
