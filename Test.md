We're going to use HUnit to run our tests.

```haskell
module Test where

import Test.HUnit
import DataTypes

main = runTestTT tests
```

This is a helper method that extracts the credit card number from some payment
info, if it has one.

```haskell
cardNum (CreditCard num _) = Just num
cardNum _                  = Nothing
```

There isn't much functionality to test, since we have only defined datatypes.

```haskell
tests = TestList
   [ earthOrbitsSun  ~? "Earth should orbit the sun"
   , not earthIsFlat ~? "Earth is not flat"
   , cardNum myCreditCard ~=? Just 12345678
   , cardNum myPayPal     ~=? Nothing
   ]
```
