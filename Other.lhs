## Showing the query

In order to send the query to the Graql shell, we need to convert it into Graql
syntax. This means we have to make our types instances of  `Show`. `Show` is a
typeclass (like an interface) to represent things that can be converted to
strings. To make something an instance of `Show`, we just have to define a
method `show` that will turn it into a string:

```haskell
instance Show MatchQuery where
    show (Match patterns) = "match " ++ spaces patterns
    show (Select mq vars) = show mq ++ " select " ++ commas vars ++ ";"
```

We've taken advantage of pattern-matching so we can write definitions for
`Match` and `Select` separately. We use `++` to concatenate our strings
together, as well as helper methods `spaces` and `commas`, which will change a
list of things into strings, separated using spaces and commas respectively:

```haskell
spaces :: Show a => [a] -> String
spaces = intercalate " " . map show

commas :: Show a => [a] -> String
commas = intercalate ", " . map show
```

Patterns may start with a variable, with their properties separated by spaces
and ending in a semicolon:

```haskell
instance Show Pattern where
   show (Pattern var props) = var ++ " " ++ spaces props ++ ";"
```

Our other `Show` definitions are fairly straightforward:

```haskell
instance Show Property where
   show (Isa name)       = "isa " ++ show name
   show (Rel castings)   = "(" ++ commas castings ++ ")"
   show (Has name value) = "has " ++ show name ++ " " ++ showEither value

instance Show RolePlayer where
   show (RolePlayer roletype player) = roletype ++ ": " ++ show player

instance Show Var where
   show (Var str) = '$' : str

instance Show Name where
   show (Name str) = str

-- a dumb method that will print either the left- or right- side of an either
showEither = either show show
```


## Sending it to the shell

This was the bit I was dreading. We need to invoke an external command, so all
the "pure" guarantees of Haskell are gone. This means using `IO`. `IO` is a
datatype in Haskell that represents the idea of a computation that may have
side-effects.  For example, the `getLine` method that reads a line of user
input has this type signature:

```haskell.ignore
getLine :: IO String
```

Notice that `getLine` doesn't return a `String`, instead `IO String` represents
something that will yield a `String` eventually when it is "evaluated". This is
a weird trick to keep the language _technically_ "pure" while still letting you
do impure things, like read user input or write to files. We can join these
`IO` objects together using the `do` notation:

```haskell
printUppercase2 :: IO ()
printUppercase2 = do
   line <- getLine
   putStrLn (map toUpper line)
```

The above will get a line of user input, then convert it to uppercase and print
it.

So, we can use this `IO` datatype with `do` notation to describe actions that
have side-effects, such as contacting the shell:

```haskell
runGraql :: MatchQuery -> IO String
runGraql query = do
   (_, stdout, stderr) <- readProcessWithExitCode "graql.sh" args ""
   if null (lines stderr)
      then return stdout
      else fail stderr
   where args = ["-e", show query, "-o", "json"]
```

We use the `show` method we defined earlier to get the string representation of
the query to send to the shell.

This style of programming is starting to look a lot less functional and much
more imperative! It is structured in a "do this, then do that" way, including
conditional statements to check for errors.
