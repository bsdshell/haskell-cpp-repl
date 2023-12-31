{-# LANGUAGE MultiWayIf        #-}
{-# LANGUAGE QuasiQuotes       #-} -- support raw string [r|<p>dog</p> |]
import Text.RawString.QQ       -- Need QuasiQuotes too 


-- import Data.Set   -- collide with Data.List 
import Control.Monad
import Data.Char
import Data.Typeable (typeOf) -- runtime type checker, typeOf "k"
import qualified Data.List as L
import Data.List.Split
import Data.Time
import Data.Time.Clock.POSIX
import System.Directory
import System.Environment
import System.Exit
import System.FilePath.Posix
import System.IO
import System.Posix.Files
import System.Posix.Unistd
import System.Process
import Text.Read
import Text.Regex
import Text.Regex.Base
import Text.Regex.Base.RegexLike
import Text.Regex.Posix
import Data.IORef 
import Control.Monad (unless, when)
import Control.Concurrent
import Control.Arrow
import qualified Data.Text                 as TS  -- Strict Text
import qualified System.Console.Pretty as SCP

import qualified Text.Regex.TDFA as TD
import Control.Monad.Trans
import System.Console.Haskeline

import System.Console.Haskeline
import qualified System.Console.ANSI as AN
import AronModule
import AronToken
  

p1 = "/Users/cat/myfile/bitbucket/testfile/test.tex"

-- zo - open
-- za - close


{-|
main :: IO ()
main = runInputT defaultSettings loop
   where
       loop :: InputT IO ()
       loop = do
           minput <- getInputLine "% "
           case minput of
               Nothing -> return ()
               Just "quit" -> return ()
               Just input -> do outputStrLn $ "Input was: " ++ input
                                return $ writeFileListAppend "/tmp/xx2.x" [input]
                                outputStrLn $ "my input => " ++ input
                                loop
-}

mycmd = [
      ":h        => Help",
      ":q        => Quit",
      ":mod sh   => Shell mode",
      ":mod code => Cpp mode",
      ":keep m n => Keep mth to nth lines in Code",
      ":lib s    => Simple library",
      ":lib a    => All libraries",
      ":next n   => Append code to next nth line",
      ":pre n    => Prepend code to previous nth line",
      ":dl n     => Delete nth line",
      ":df 2 4   => Delete from 2nd to 4th lines",
      ":dr n     => Delete nth line and Replace with current code",
      "---",
      ":pb       => print fileBlock",
      ":mv 1 2   => move lines 1-2 to fileBlock",
      ":dfb n    => Delete nth block from fileBLock",
      ":get n    => Get nth block from fileBlock",
      "---",
      ":ls       => List source file",
      ":run      => Run source file",
      ":rep      => Insert snippet to cpp.cpp",
      ":app      => Append to the end of cpp.cpp with { }",
      ":sw 2 3   => Swap line 2 and 3",
      ":heada    => Show libAronLib",
      ":heads    => Show libSimple",
      ":hsc      => Search AronLib.h",
      ":cr       => Clear screen"
    ]


headStr = [r|
#include<iostream>
#include "AronLib.h"
// #include "catch.hpp"

#include <string>
#include <fstream>
#include <sstream>
#include <iostream>
#include <vector>


using namespace std;
// using namespace AronPrint;  // pp()
// using namespace Algorithm;
// using namespace Utility;

int main() {
    // std::cout<<"cool"<<std::endl;
       |]

libSimple = [r|
#include<iostream>
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>
#include <vector>
#include <stdio.h>

              |]
  
libAronLib = [r|
#include<iostream>
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>
#include <vector>
#include "AronLib.h"
#include <stdio.h>


// KEY: cpp array language, cpp apl
#include <blitz/array.h>  

using namespace blitz;

using namespace std;
using namespace AronPrint;  // pp()
using namespace Algorithm;
using namespace Utility;
using namespace MatrixVector;
using namespace AronLambda; // take(2, v)

              |]

mainStr = [r|
int main() {

           |]
  
  
tailStr = [r|
}
         |]
  
getTemplate::String -> String -> IO ([String], [String])
getTemplate cx cy = do
                    let ls = trimList $ lines cx
                    let lt = trimList $ lines cy
                    return (ls, lt)
  
-- cppFile = "./cpp.cpp"
-- cppEditedFile = "./block.cpp"

repelPath :: IO String
repelPath = do
            s <- readFileList "./config.txt" >>= \x -> return $ trimList x
            let path = splitStr "=" $ head s
            -- pre path
            if head path == "rootpath" then do
              -- putStrLn $ last path
              return $ last path </> "src" </> "code"
            else do
              putStrLn "ERROR: Can not find rootpath"
              return ""
            
            -- getCurrentDirectory >>= \x -> return $ x </> "src" </> "code"
  
getCppFile :: IO String
getCppFile = do
             fn <- (</> "cpp.cpp") <$> repelPath
             b <- fileExistA fn
             when (not b) $ do
               createFile fn
             return fn
             
  
getEditedFile :: IO String
getEditedFile = do
                fn <- (</> "block.cpp") <$> repelPath
                b <- fileExistA fn
                when (not b) $ do
                 createFile fn
                return fn
  
lsHeadAll :: String
lsHeadAll = libAronLib
  
lsHeadSimple :: String
lsHeadSimple = libSimple
  
conStr = containStr
  
execCode :: IO()
execCode = do
      -- clear
      (cmdExit, cmdOut, cmdErr) <- runSh $ toSText "./src/code/bin/cpp"
      if cmdExit == ExitSuccess then do
        putStrLn $ toStr cmdOut
      else do
        pp "ERROR: Run ./src/code/bin/cpp"
        putStrLn $ toStr cmdErr

buildNinja :: IO()
buildNinja = do
  let cmd = "cmake -G Ninja"
  let delCache = "rm CMakeCache.txt"
  rootDir <- getpwd
  
  -- Change to rootDir/src/code
  cd $ rootDir </> "src" </> "code"
  (ex, _, err) <- runShStr delCache
  when (ex /= ExitSuccess) $ do
    pp $ "ERROR:" ++ err

  
  (ext, stout, sterr) <- runShStr cmd
  if ext == ExitSuccess then do 
    -- logFileG ["cmake --build build -- -j3 => ExitSuccess"]
    logFileG [cmd]
    pp "OK: Build"
    putStrLn cmd
    -- clear
  else do
    let err = "ERROR: Run " ++ cmd
    pp err
    logFileG [err]
    putStrLn err

  -- Go back to root dir
  cd rootDir

runCode :: [String ] -> [String]-> IO()
runCode cx cy = do
      -- clear
      rootDir <- getpwd
      old <- timeNowSecond
      -- repelPath >>= putStrLn
      cppEditedFile <- getEditedFile
      cppFile <- getCppFile
      ls <- readFileStrict cppEditedFile >>= return . lines
      writeFileList cppFile $ cx ++ ls ++ cy
      cd "src/code"
      -- (ext, stout, sterr) <- runShStr "cmake --build build -- -j12"
      -- SEE: https://ilyas-hamadouche.medium.com/build-your-c-projects-faster-using-ninja-3d7af9b418fc
      (ext, stout, sterr) <- runShStr "ninja"
      cd rootDir
      if ext == ExitSuccess then do 
        -- logFileG ["cmake --build build -- -j3 => ExitSuccess"]
        logFileG ["ninja"]
        -- clear
        (cmdExit, cmdOut, cmdErr) <- runShStr "./src/code/bin/cpp"
        if cmdExit == ExitSuccess then do
          putStrLn cmdOut
          tmpPath <- getEnv "t"
          writeFileStr tmpPath cmdOut
        else do
          let err = "ERROR: Run ./src/code/bin/cpp"
          pp err
          logFileG [err]
          putStrLn cmdErr
  
        -- clear
      else do
        pp "ERROR:"
        let tmpf = "/tmp/xxabc.x"
        writeFileStr tmpf stout
        writeFileListAppend tmpf $ lines sterr
        ls <- run $ "grep -A 5 error " ++ tmpf
        -- let lt = map (concat . colorToken) $ map (tokenize) ls
        putStrLn $ unlines $ colorx ls
      new <- timeNowSecond
      putStrLn ""
      let diff = new - old
      putStrLn $ "Run seconds =" ++ show diff

repFile::[String] -> [String] -> [String] -> IO()
repFile left cx right = do
      cppFile <- getCppFile
      cppEditedFile <- getEditedFile
      let ls = left ++ cx ++ right
      -- replaceFileWithStr "// replaceStr00" ((unlines . reverse) cx) cppFile
      writeFileList cppFile ls
      writeFileList cppEditedFile cx
  
delCode::IO ()
delCode = do
      cppFile <- getCppFile
      ls <- readFileStrict cppFile >>= return . lines
      let lss = splitListWhen (\x -> (conStr "BEG_" x) || (conStr "END_" x)) ls
      let h = head lss
      let t = last lss
      writeFileList cppFile $ h ++ ["// BEG_rep", "// replaceStr00", "// END_rep"] ++ t
      str <- readFileStrict cppFile 
      let zls = zipWith(\n s -> (show n) ++ " " ++ s) [1..] $ lines str
      clear
      mapM_ (\x -> putStrLn $ "\t" ++ x) zls 

clearCode::IO ()
clearCode = do
      clear

cmdRun:: String -> IO ()
cmdRun s = do
    clear
    let cmd = drop 5 s
    out <- run $ cmd 
    setCursorPos 10  4 
    mapM_ putStrLn out

cppSnippet:: String -> IO ()
cppSnippet s = do
       clear
       let cmd = trim $ drop 4 s
       stdout <- run $ "hsc " ++ cmd
       mapM_ (\x -> putStrLn $ "\t" ++ x) stdout 

{-|
 @
 if first char is '{' or '}' then color the '{' '}' else do nothing
 @
 -}
isCurlyChar:: String -> (Bool, String)
isCurlyChar s = if len s' == 0 
              then (False, s) 
              else let c = head s' 
                       x = colorStr s
                   in if c == '{' || c == '}' then (True, x) else (False, x)  
        where
          s' = trim s

{-|
   === KEY: Use astyle to format it.
-}
showCode :: FilePath -> IO()
showCode fn = do
              _ <- runCmd $ "astyle " ++ fn
              str <- readFileStrict fn
              let lt = lines str
              let lr = colorx lt
              let lu = map isCurlyChar lt
              -- let zls = zipWith(\n s -> (show n) ++ " " ++ s) [0..] $ ls
              let zls = zipWith(\n (b, s) -> b ? (colorfgStr 83 $ show n ++ " " ++ s) $ show n ++ " " ++ s) [0..] lu 
              -- clear
              mapM_ (\x -> putStrLn $ "\t" ++ x) zls
    
showHead :: String -> IO()
showHead s = do
             let fn = "/tmp/abc123.cpp"
             writeFileStr "/tmp/abc123.cpp" s
             _ <- runCmd $ "astyle " ++ fn
             let lt = lines s
             let ls = map (\(n, s) -> even n ? s $ s) $ zip [0..] $ colorx lt
             -- let zls = zipWith(\n s -> (show n) ++ " " ++ s) [0..] $ ls
             let zls = zipWith(\n s -> (show n) ++ " " ++ s) [0..] $ ls
             clear
             mapM_ (\x -> putStrLn $ "\t" ++ x) zls
  
lsCode:: IO ()
lsCode = do
       cppEditedFile <- getEditedFile
       showCode cppEditedFile
  
lsTmp:: IO ()
lsTmp = do
       let cppTmp = "/tmp/tmpfile.cpp"
       _ <- runCmd $ "cp /tmp/tmpfile.txt " ++ cppTmp
       showCode cppTmp
  
lsAllCode:: IO ()
lsAllCode = do
       cppFile <- getCppFile
       showCode cppFile

helpMe::IO ()
helpMe = do
    clear        
    setCursorPos 20  4 
    printBox 2 mycmd


data EffectIORef = EffectIORef {
                                 lib_ :: String,
                                 mod_ :: RunMode,
                                 prompt_ :: String
                               } deriving (Show)

getLibIO :: IORef EffectIORef -> IO String
getLibIO ioRef = do
  s <- readIORef ioRef
  return $ lib_ s
  
modifyLibIO :: IORef EffectIORef -> String -> IO()
modifyLibIO ioRef s = do
  eff <- readIORef ioRef
  let r = (\x -> eff{lib_ = x}) s
  writeIORef ioRef r
  
modifyModeIO :: IORef EffectIORef -> RunMode -> IO()
modifyModeIO ioRef m = do
  eff <- readIORef ioRef
  let r = (\x -> eff{mod_ = x}) m
  writeIORef ioRef r
  
modifyPromptIO :: IORef EffectIORef -> String -> IO()
modifyPromptIO ioRef s = do
  eff <- readIORef ioRef
  let r = (\x -> eff{prompt_ = x}) s
  writeIORef ioRef r
  
data RunMode = ShellX | CodeX deriving (Show, Eq)
  
colorx ls = map (concat . colorToken) $ map (tokenize) ls
colorStr s = (concat . colorToken) $ tokenize s
  

fbFile = "/tmp/kk.x"
delimiter = "-"
  
type Repl a = InputT IO a

process :: [String] -> IO ()
process cx = mapM_ putStrLn cx

repl :: [String] -> Int -> IORef EffectIORef -> Repl ()
repl acc n ioRef = do
  prompt <- liftIO $ readIORef ioRef >>= return . prompt_
  
  minput <- getInputLine prompt

  (left, right) <- liftIO $ getTemplate headStr tailStr
  let qr = [r|fileBlock '/tmp/kk.x' '-' |]  
  case minput of
    Nothing -> outputStrLn "Goodbye."
    Just s -> do
                  -- case let lv = splitSPC $ trim s in null lv ? [] $ head lv of
               case let lv = break (== ' ') $ trim s in join (***) trim lv of
                (v, w) | strEq ":mod" v -> do
                         case w of
                           var | var == "sh" -> do
                                   liftIO $ modifyPromptIO ioRef ">> "
                                   liftIO $ modifyModeIO ioRef ShellX
                               | var == "code" -> do
                                   liftIO $ modifyPromptIO ioRef ">"
                                   liftIO $ modifyModeIO ioRef CodeX
                               | otherwise -> do
                                   liftIO $ print "ERROR: Invalid mode => :mod sh || :mod code"
                         repl [] n ioRef
                       | strEq ":q" v -> outputStrLn "Quit"
                       | strEq ":h" v -> do
                         liftIO helpMe
                         repl [] n ioRef
  
                       | otherwise -> do
                         runMode <- liftIO $ readIORef ioRef >>= return . mod_
                         case runMode of
                              ShellX -> do
                                 let cmd = trim s
                                 (exCode, stdout, stderr) <- liftIO $ runShStr cmd
                                 if exCode == ExitSuccess then do
                                   liftIO $ mapM_ putStrLn $ lines stdout
                                   else do
                                   liftIO $ print $ "ERROR: " ++ stderr
                                 repl [] n ioRef

                              CodeX -> do
                                 case v of
                                      v | strEq ":test" v -> (liftIO $ process $ reverse acc) >> repl [] n ioRef
                                        | strEq ":cmdls" v -> do
                                                        ls <- liftIO $ run "ls"
                                                        mapM_ put ls
                                                        repl [] n ioRef

                                        | strEq ":cr" v -> do
                                          liftIO clearCode
                                          repl [] n ioRef

                                        | strEq ":ls" v -> do
                                                     liftIO lsCode
                                                     repl [] n ioRef
                                        | strEq ":run" v -> do
                                          liftIO $ runCode left right
                                          repl [] n ioRef
  
                                        | strEq ":build" v -> do
                                          liftIO buildNinja
                                          repl [] n ioRef

                                        | strEq ":exe" v -> do
                                          liftIO execCode
                                          repl [] n ioRef

                                        | strEq ":mod" v -> do
                                          let ns = dropPrefix ":mod" s
                                          case ns of
                                            var | var == "sh" -> do
                                                    liftIO $ modifyPromptIO ioRef " "
                                                    liftIO $ modifyModeIO ioRef ShellX
                                                | var == "code" -> do
                                                    liftIO $ modifyPromptIO ioRef "> "
                                                    liftIO $ modifyModeIO ioRef CodeX
                                                | otherwise -> do
                                                    liftIO $ print "ERROR: Invalid mode"
                                          repl [] n ioRef  


                                        | strEq ":pre" $v -> do
                                            cppEditedFile <- liftIO getEditedFile
                                            ls <- liftIO $ readFileStrict cppEditedFile >>= \x -> return $ lines x
                                            let n = read w :: Int
                                            let left = take n ls 
                                            let right = drop n ls
                                            let lt = left ++ reverse acc ++ right
                                            liftIO $ pre lt
                                            liftIO $ writeFileList cppEditedFile lt
                                            liftIO lsCode
                                            repl [] n ioRef

                                        | strEq ":next" v || strEq ":n" v -> do
                                            cppEditedFile <- liftIO getEditedFile
                                            ls <- liftIO $ readFileStrict cppEditedFile >>= \x -> return $ lines x
                                            let n = read w :: Int
                                            let left = take (n + 1) ls 
                                            let right = drop (n + 1) ls
                                            let lt = left ++ reverse acc ++ right
                                            -- liftIO $ pre lt
                                            liftIO $ writeFileList cppEditedFile lt
                                            liftIO lsCode
                                            repl [] n ioRef

                                        | strEq ":df" v -> do
                                            cppEditedFile <- liftIO getEditedFile
                                            ls <- liftIO $ readFileStrict cppEditedFile >>= \x -> return $ lines x
                                            let lr = map (\x -> read x :: Int) $ trimList $ splitSPC w
                                            let (n1, n2) = (head lr, last lr)
                                            let left = take n1 ls 
                                            let right = drop (n2 + 1) ls
                                            let lt = left ++ right
                                            liftIO $ writeFileList cppEditedFile lt
                                            liftIO lsCode
                                            repl [] n ioRef

                                        -- keep m n => Keep m to n lines only
                                        | strEq ":keep" v -> do
                                          cppEditedFile <- liftIO getEditedFile
                                          ls <- liftIO $ readFileStrict cppEditedFile >>= \x -> return $ lines x
                                          let lr = map (\x -> read x :: Int) $ trimList $ splitSPC w
                                          let n1 = head lr
                                          let n2 = last lr
                                          let lv = take (n2 - n1 + 1) $ drop n1 ls
                                          liftIO $ writeFileList cppEditedFile lv
                                          liftIO lsCode
                                          repl [] n ioRef

                                        -- Get code from fileBlock
                                        | strEq ":get" v -> do
                                            let p = qr <> [r| -printindex|]
                                            cx <- liftIO $ run $ p ++ " " ++ w

                                            cppFile <- liftIO getCppFile
                                            cppEditedFile <- liftIO getEditedFile
                                            ls <- liftIO $ readFileStrict cppEditedFile >>= \s -> return $ trimList $ lines s
                                            let lt = ls ++ ["{"] ++ cx ++ ["}"]
                                            liftIO $ writeFileList cppEditedFile lt
                                            liftIO lsCode

                                            liftIO $ pre cx
                                            repl [] n ioRef

                                        | strEq ":db" v -> do
                                            let p = qr <> [r| -dropindex|]
                                            cx <- liftIO $ run $ p ++ " " ++ w
                                            liftIO $ print cx
                                            liftIO lsCode

                                            liftIO $ pre cx
                                            repl [] n ioRef
                                        -- Print fileBlock
                                        | strEq ":pb" v -> do
                                            let s = qr <> [r|-size|]
                                            let p = qr <> [r|-printindex|]
                                            k <- liftIO $ run s >>= \x -> return (read $ head x :: Int)
                                            liftIO $ mapM_ (\x -> (run $ p ++ " " ++ x) >>= \s -> let n = read x :: Int in putStrLn (colorfgStr 200 $ show [n]) >> (return . colorx) s >>= (mapM_ putStrLn) >> putStrLn (replicate 10 '-')) $ map show [0..(k - 1)]
                                            liftIO $ print k
                                            repl [] n ioRef

                                        -- Move code to fileBlock
                                        | strEq ":mv" v -> do
                                            cppEditedFile <- liftIO getEditedFile
                                            ls <- liftIO $ readFileStrict cppEditedFile >>= \x -> return $ lines x
                                            let lr = map (\x -> read x :: Int) $ trimList $ splitSPC w
                                            let (n1, n2) = (head lr, last lr)
                                            let rest = drop n1 ls
                                            let lt = take (n2 - n1 + 1) rest
                                            let s = qr <> [r|'-appendlist' |] <> [r|'|] <> show lt <> [r|'|]
                                            liftIO $ run s
                                            -- liftIO $ writeFileList cppEditedFile lt
                                            liftIO lsCode
                                            repl [] n ioRef
                                                  
                                        | strEq ":dfb" v -> do
                                            cppEditedFile <- liftIO getEditedFile
                                            ls <- liftIO $ readFileStrict cppEditedFile >>= \x -> return $ lines x
                                            let inx = read w :: Int
                                            liftIO $ fileBlock fbFile delimiter $ DropIndex inx
                                            -- liftIO $ writeFileList cppEditedFile lt
                                            liftIO lsCode
                                            repl [] n ioRef

                                        -- Delete and Replace             
                                        | strEq ":dr" v -> do
                                          cppEditedFile <- liftIO getEditedFile
                                          liftIO $ fw "w"
                                          liftIO $ pp w 
                                          let nx = read w :: Int
                                          liftIO $ fw "nx"
                                          -- liftIO $ pp nx
                                          -- liftIO $ threadDelay $ 1000 * 1000 * 3 
                                          str <- liftIO $ readFileStrict cppEditedFile
                                          let ls = lines str
                                          let left = take nx ls
                                          let right = drop (nx + 1) ls
                                          let lt = left ++ acc ++ right
                                          liftIO $ writeFileList cppEditedFile lt
                                          liftIO lsCode
                                          repl [] n ioRef

                                        | strEq ":dl" v -> do
                                            cppEditedFile <- liftIO getEditedFile
                                            ls <- liftIO $ readFileStrict cppEditedFile >>= \x -> return $ lines x
                                            let lv = splitSPC w
                                            let ln = map (\x -> read x :: Int) lv
                                            liftIO $ print ln
                                            let tu = zip [0..] ls
                                            let lt = map snd $ filter (\(m, _) -> m >= 0) $ map (\(n, x) -> elem n ln ? (-1, x) $ (n, x))  tu
                                            liftIO $ writeFileList cppEditedFile lt
                                            liftIO lsCode
                                            repl [] n ioRef

                                        | strEq ":top" v -> do
                                          cppFile <- liftIO getCppFile
                                          cppEditedFile <- liftIO getEditedFile
                                          ls <- liftIO $ readFileStrict cppEditedFile >>= \x -> return $ trimList $ lines x
                                          let lt = ["{"] ++ reverse acc ++ ["}"] ++ ls
                                          liftIO $ writeFileList cppEditedFile lt
                                          liftIO lsCode
                                          repl [] n ioRef

                                        | strEq ":app" v || strEq ":a" v -> do
                                            cppFile <- liftIO getCppFile
                                            cppEditedFile <- liftIO getEditedFile
                                            ls <- liftIO $ readFileStrict cppEditedFile >>= \s -> return $ trimList $ lines s
                                            let lt = ls ++ ["{"] ++ (reverse acc) ++ ["}"]
                                            liftIO $ writeFileList cppEditedFile lt
                                            liftIO lsCode
                                            repl [] n ioRef

                                        | strEq ":lib" v -> do
                                                         let ls = splitSPC s
                                                         when (len ls == 2) $ liftIO $ do
                                                           let opt = last ls
                                                           eff <- readIORef ioRef
                                                           case opt of
                                                               x | x == "a" -> do
                                                                     let eff' = (\x -> eff{lib_ = x}) libAronLib
                                                                     liftIO $ pre eff'
                                                                 | x == "s" -> do
                                                                     let eff' = (\x -> eff{lib_ = x}) libSimple
                                                                     liftIO $ pre eff'
                                                                 | otherwise -> do
                                                                     liftIO $ print $ "ERROR: Unknown Option = " ++ x

                                                           liftIO $ print ":lib"
                                                         repl [] (n + 1) ioRef
                                        | strEq ":fi" v -> do
                                                        ls <- liftIO $ readFileList "/tmp/a.x"
                                                        mapM_ put ls
                                                        repl [] (n + 1) ioRef
                                        | strEq ":hsc" v -> do
                                                        cx <- liftIO $ run $ "hsc " ++ w
                                                        mapM_ put cx
                                                        repl [] (n + 1) ioRef

                                        | otherwise -> repl (s:acc) (n + 1) ioRef
  where
    put = outputStrLn
    dropPrefix ds s = trim $ drop (len ds) s
    strEq :: String -> String -> Bool
    strEq = (==)
    -- colorx ls = map (concat . colorToken) $ map (tokenize) ls


-- SEE: https://stackoverflow.com/questions/29390884/ambiguous-type-variable-with-haskeline-auto-completion
mySettings :: Settings IO
mySettings = (defaultSettings :: Settings IO)
          {
           historyFile = Just "myhist"
          , complete = completeWord Nothing " \t" $ return . search
          }
  
keywords :: [String]
keywords = [
           ":h"        
           ,":q"        
           ,":mod" 
           ,":mod" 
           ,":get"    
           ,":keep" 
           ,":lib"    
           ,":lib"    
           ,":next"   
           ,":pre"    
           ,":dl"     
           ,":df"   
           ,":dr"
           ,":dfb"
           ,":ls"       
           ,":run"      
           ,":rep"      
           ,":app"      
           ,":sw"   
           ,":heada"    
           ,":heads"    
           ,":hsc"      
           ,":cr"       
           ]

keyCode::[String]
keyCode = [
           "vector<float> v = {1, 2, 3};"
           ,"vector<vector<float>> vv = {{1, 2, 3}, {4, 5, 6}};"
          ,"mat m(3, 3);"
          ]

  
search :: String -> [Completion]
search s = map simpleCompletion $ filter (s `L.isPrefixOf`) $ keywords ++ keyCode

{--
main :: IO ()
main = do
       pp "ok"
       let fp = "/tmp/a.cpp"
       showCode fp 
       s <- readFileList fp
       let ss = map (\x -> isCurlyChar x) s
       pre ss
--}

main :: IO ()
main = do
       ioRef <- newIORef EffectIORef { lib_ = libAronLib, mod_ = CodeX, prompt_ = "> " }
       -- runInputT defaultSettings $ repl [] 0 ioRef
       runInputT mySettings $ repl [] 0 ioRef
