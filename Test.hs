module Test where

import Test.HUnit
import DataTypes

main = runTestTT tests

cardNum (CreditCard num _) = Just num
cardNum _                  = Nothing

-- THere isn't much functionality to test, since this is only datatypes
tests = TestList
   [ earthOrbitsSun  ~? "Earth should orbit the sun"
   , not earthIsFlat ~? "Earth is not flat"
   , cardNum myCreditCard ~=? Just 12345678
   , cardNum myPayPal     ~=? Nothing
   ]
