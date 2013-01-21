{-# LANGUAGE DeriveDataTypeable, RecordWildCards, PatternGuards #-}

-- | Types exposed to the user
module Development.Shake.Types(
    Progress(..), Verbosity(..), Assume(..),
    ShakeOptions(..), shakeOptions
    ) where

import Data.Data
import Data.List
import Development.Shake.Progress


-- | The current assumptions made by the build system, used by 'shakeAssume'. These options
--   allow the end user to specify that any rules run are either to be treated as clean, or as
--   dirty, regardless of what the build system thinks.
--
--   These assumptions only operate on files reached by the current 'Development.Shake.action' commands. Any
--   other files in the database are left unchanged.
data Assume
    = AssumeDirty
        -- ^ Assume that all rules reached are dirty and require rebuilding, equivalent to 'Development.Shake.storedValue' always
        --   returning 'Nothing'. Useful to undo the results of 'AssumeClean', for benchmarking rebuild speed and
        --   for rebuilding if untracked dependencies have changed. This assumption is safe, but may cause
        --   more rebuilding than necessary.
    | AssumeClean
        -- ^ /This assumption is unsafe, and may lead to incorrect build results/.
        --   Assume that all rules reached are clean and do not require rebuilding, provided the rule
        --   has a 'Development.Shake.storedValue' and has been built before. Useful if you have modified a file in some
        --   inconsequential way, such as only the comments or whitespace, and wish to avoid a rebuild.
    deriving (Eq,Ord,Show,Data,Typeable,Bounded,Enum)


-- | Options to control the execution of Shake, usually specified by overriding fields in
--   'shakeOptions':
--
--   @ 'shakeOptions'{'shakeThreads'=4, 'shakeReport'=Just \"report.html\"} @
--
--   The 'Data' instance for this type reports the 'shakeProgress' field as having the abstract type 'ShakeProgress',
--   because 'Data' cannot be defined for functions.
data ShakeOptions = ShakeOptions
    {shakeFiles :: FilePath
        -- ^ Defaults to @.shake@. The prefix of the filename used for storing Shake metadata files.
        --   All metadata files will be named @'shakeFiles'./extension/@, for some @/extension/@.
    ,shakeThreads :: Int
        -- ^ Defaults to @1@. Maximum number of rules to run in parallel, similar to @make --jobs=/N/@.
        --   To enable parallelism you may need to compile with @-threaded@.
        --   For many build systems, a number equal to or slightly less than the number of physical processors
        --   works well.
    ,shakeVersion :: Int
        -- ^ Defaults to @1@. The version number of your build rules.
        --   Increment the version number to force a complete rebuild, such as when making
        --   significant changes to the rules that require a wipe. The version number should be
        --   set in the source code, and not passed on the command line.
    ,shakeVerbosity :: Verbosity
        -- ^ Defaults to 'Normal'. What level of messages should be printed out.
    ,shakeStaunch :: Bool
        -- ^ Defaults to 'False'. Operate in staunch mode, where building continues even after errors,
        --   similar to @make --keep-going@.
    ,shakeReport :: Maybe FilePath
        -- ^ Defaults to 'Nothing'. Write an HTML profiling report to a file, showing which
        --   rules rebuilt, why, and how much time they took. Useful for improving the speed of your build systems.
    ,shakeLint :: Bool
        -- ^ Defaults to 'False'. Perform basic sanity checks after building, checking files have not been modified
        --   several times during the build. These sanity checks fail to catch most interesting errors.
    ,shakeDeterministic :: Bool
        -- ^ Defaults to 'False'. Run rules in a deterministic order, as far as possible. Typically used in conjunction
        --   with @'shakeThreads'=1@ for reproducing a build. If this field is set to 'False', Shake will run rules
        --   in a random order, which typically decreases contention for resources and speeds up the build.
    ,shakeFlush :: Maybe Double
        -- ^ Defaults to @'Just' 10@. How often to flush Shake metadata files in seconds, or 'Nothing' to never flush explicitly.
        --   It is possible that on abnormal termination (not Haskell exceptions) any rules that completed in the last
        --   'shakeFlush' seconds will be lost.
    ,shakeAssume :: Maybe Assume
        -- ^ Defaults to 'Nothing'. Assume all build objects are clean/dirty, see 'Assume' for details.
        --   Can be used to implement @make --touch@.
    ,shakeProgress :: IO Progress -> IO ()
        -- ^ Defaults to no action. A function called when the build starts, allowing progress to be reported,
        --   see 'Progress' for details. This function will be called on its own thread.
    }
    deriving Typeable

-- | The default set of 'ShakeOptions'.
shakeOptions :: ShakeOptions
shakeOptions = ShakeOptions ".shake" 1 1 Normal False Nothing False False (Just 10) Nothing (const $ return ())

fieldsShakeOptions =
    ["shakeFiles", "shakeThreads", "shakeVersion", "shakeVerbosity", "shakeStaunch", "shakeReport"
    ,"shakeLint", "shakeDeterministic", "shakeFlush", "shakeAssume", "shakeProgress"]
tyShakeOptions = mkDataType "Development.Shake.Types.ShakeOptions" [conShakeOptions]
conShakeOptions = mkConstr tyShakeOptions "ShakeOptions" fieldsShakeOptions Prefix
unhide x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 = ShakeOptions x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 (fromProgress x11)

instance Data ShakeOptions where
    gfoldl k z (ShakeOptions x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11) =
        z unhide `k` x1 `k` x2 `k` x3 `k` x4 `k` x5 `k` x6 `k` x7 `k` x8 `k` x9 `k` x10 `k` ShakeProgress x11
    gunfold k z c = k $ k $ k $ k $ k $ k $ k $ k $ k $ k $ k $ z unhide
    toConstr ShakeOptions{} = conShakeOptions
    dataTypeOf _ = tyShakeOptions

instance Show ShakeOptions where
    show x = "ShakeOptions {" ++ intercalate ", " inner ++ "}"
        where
            inner = zipWith (\x y -> x ++ " = " ++ y) fieldsShakeOptions $ gmapQ f x

            f x | Just x <- cast x = show (x :: Int)
                | Just x <- cast x = show (x :: FilePath)
                | Just x <- cast x = show (x :: Verbosity)
                | Just x <- cast x = show (x :: Bool)
                | Just x <- cast x = show (x :: Maybe FilePath)
                | Just x <- cast x = show (x :: Maybe Assume)
                | Just x <- cast x = show (x :: Maybe Double)
                | Just x <- cast x = show (x :: ShakeProgress)
                | otherwise = error $ "Error while showing ShakeOptions, missing alternative for " ++ show (typeOf x)


-- | Internal type, copied from Hide in Uniplate
newtype ShakeProgress = ShakeProgress {fromProgress :: IO Progress -> IO ()}
    deriving Typeable

instance Show ShakeProgress where show _ = "<function>"

instance Data ShakeProgress where
    gfoldl k z x = z x
    gunfold k z c = error "Development.Shake.Types.ShakeProgress: gunfold not implemented - data type has no constructors"
    toConstr _ = error "Development.Shake.Types.ShakeProgress: toConstr not implemented - data type has no constructors"
    dataTypeOf _ = tyShakeProgress

tyShakeProgress = mkDataType "Development.Shake.Types.ShakeProgress" []


-- | The verbosity data type, used by 'shakeVerbosity'.
data Verbosity
    = Silent -- ^ Don't print any messages.
    | Quiet  -- ^ Only print essential messages (typically errors).
    | Normal -- ^ Print normal messages (typically errors and warnings).
    | Loud   -- ^ Print lots of messages (typically errors, warnings and status updates).
    | Diagnostic -- ^ Print messages for virtually everything (for debugging a build system).
      deriving (Eq,Ord,Bounded,Enum,Show,Read,Typeable,Data)

