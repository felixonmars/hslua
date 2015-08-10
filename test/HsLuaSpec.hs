module HsLuaSpec where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as B
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import System.Mem (performMajorGC)

import Test.Hspec
import Test.Hspec.Contrib.HUnit
import Test.HUnit

import Test.QuickCheck
import qualified Test.QuickCheck.Monadic as QM
import Test.QuickCheck.Instances ()

import Data.Maybe (fromJust)

import Scripting.Lua

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
    describe "StackValue" $ mapM_ fromHUnitTest
      [bytestring, bsShouldLive, listInstance, nulString]
    describe "Random StackValues" $ do
      it "can push/pop booleans" $ property prop_bool
      it "can push/pop ints" $ property prop_int
      it "can push/pop bytestrings" $ property prop_bytestring
      it "can push/pop lists of booleans" $ property prop_lists_bool
      it "can push/pop lists of ints" $ property prop_lists_int
      it "can push/pop lists of bytestrings" $ property prop_lists_bytestring

bytestring :: Test
bytestring = TestLabel "ByteString -- unicode stuff" $ TestCase $ do
    l <- newstate
    let val = T.pack "öçşiğüİĞı"
    pushstring l (T.encodeUtf8 val)
    val' <- T.decodeUtf8 `fmap` tostring l 1
    close l
    assertEqual "Popped a different value or pop failed" val val'

bsShouldLive :: Test
bsShouldLive = TestLabel "ByteString should survive after GC/Lua destroyed" $ TestCase $ do
    (val, val') <- do
      l <- newstate
      let val = B.pack "ByteString should survive"
      pushstring l val
      val' <- tostring l 1
      pop l 1
      close l
      return (val, val')
    performMajorGC
    assertEqual "Popped a different value or pop failed" val val'

listInstance :: Test
listInstance = TestLabel "Push/pop StackValue lists" $ TestCase $ do
    let lst = [B.pack "first", B.pack "second"]
    l <- newstate
    pushlist l lst
    setglobal l "mylist"
    size0 <- gettop l
    assertEqual
      "After pushing the list and assigning to a variable, stack is not empty"
      0 size0
    getglobal l "mylist"
    size1 <- gettop l
    assertEqual "`getglobal` pushed more than one value to the stack" 1 size1
    lst' <- tolist l 1
    size2 <- gettop l
    assertEqual "`tolist` left stuff on the stack" size1 size2
    close l
    assertEqual "Popped a different list or pop failed" (Just lst) lst'

nulString :: Test
nulString =
  TestLabel "String with NUL byte should be pushed/popped correctly" $ TestCase $ do
    l <- newstate
    let str = "A\NULB"
    pushstring l (B.pack str)
    str' <- tostring l 1
    close l
    assertEqual "Popped string is different than what's pushed" str (B.unpack str')


-----
-- Random Quickcheck testing for StackValue instances
-----

-- Bools
prop_bool :: Bool -> Property
prop_bool = testAllStackValueInstance
-- Ints
prop_int :: Int -> Property
prop_int = testAllStackValueInstance
-- Bytestrings
prop_bytestring :: ByteString -> Property
prop_bytestring = testAllStackValueInstance
-- Lists of bools
prop_lists_bool :: [Bool] -> Property
prop_lists_bool = testAllStackValueInstance
-- Lists of ints
prop_lists_int :: [Int] -> Property
prop_lists_int = testAllStackValueInstance
-- Lists of bytestrings
prop_lists_bytestring :: [ByteString] -> Property
prop_lists_bytestring = testAllStackValueInstance

-- Check that the StackValue instance for a datatype works
testStackValueInstance :: (Eq t, StackValue t) => t -> Property
testStackValueInstance xs = QM.monadicIO $ do
  x <- QM.run $ do
         l <- newstate
         push l xs
         peek l (-1)
  QM.assert $ xs == (fromJust x)

-- Check that pushing/popping multiple times works
testMultiStackValueInstance :: (Eq t, StackValue t) => t -> Property
testMultiStackValueInstance xs = QM.monadicIO $ do
  (x1,x2) <- QM.run $ do
             l <- newstate
             push l xs
             push l ()
             push l ()
             push l xs
             x1 <- peek l (-1)
             x2 <- peek l (-4)
             return (x1, x2)
  QM.assert $ xs == (fromJust x1)
  QM.assert $ xs == (fromJust x2)

-- Test both regular and multi instances
testAllStackValueInstance :: (Eq t, StackValue t) => t -> Property
testAllStackValueInstance xs = testStackValueInstance xs .&&. testMultiStackValueInstance xs
