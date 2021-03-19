{-|
Module      : HsLua.PackagingTests
Copyright   : © 2020-2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <tarleb+hslua@zeitkraut.de>

Test packaging
-}
module HsLua.PackagingTests (tests) where

import Test.Tasty (TestTree, testGroup)
import qualified HsLua.Packaging.FunctionTests
import qualified HsLua.Packaging.ModuleTests

-- | Tests for package creation.
tests :: TestTree
tests = testGroup "Packaging"
  [ HsLua.Packaging.FunctionTests.tests
  , HsLua.Packaging.ModuleTests.tests
  ]
