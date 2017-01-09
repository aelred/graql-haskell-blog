Ever since I read [Learn You A Haskell](http://learnyouahaskell.com/) I've been
looking for a chance to try out functional programming "for real".

At [Grakn Labs](http://grakn.ai/) we're building a knowledge graph using Java.
Although Java 8 has introduced some support for a functional style, there's
only so many lambdas I can put in my code before my colleagues will try to kill
me.

I work on building a SPARQL-inspired query language, "Graql" for our knowledge
graph "Grakn". A few weeks back I was finally given the opportunity I'd been
waiting for - we needed to interface Graql with other languages. We already had
a Python and R driver, but we needed more! So I give you:
[haskell-graql](http://github.com/aelred/haskell-graql/). This library lets you
interface with the Grakn knowledge graph using Haskell. You can build Graql
queries, send them to the database and receive results.

This is ideal for applications like data science - with Grakn as the database,
Haskell for data processing and Graql as the intermediary between the two.

In this blog post you'll get a quick introduction to the Graql query language
and to Haskell, no prior knowledge required! If you want to try running the
examples, the blog post itself is also valid Haskell code and can be found
[here](http://github.com/aelred/haskell-graql-blog) in the file `README.md`.
You'll need to install [Stack](https://www.haskellstack.org/) and then run
`stack ghci` to load the example.

For `haskell-graql` a lot of the work was already done for me - we have a REPL,
`graql.sh` (the Graql shell) that can be passed a query string and will output
results in JSON format. So my Haskell driver needed to do the following:

1. Provide methods to construct a query
2. Convert this query to a string
3. A method to pass the query to the Graql shell and parse the result

I'm going to focus on just this first point, because it's the most fun!

## What is Haskell?

Haskell is a pure functional programming language. "Functional programing"
means a lot of things and nothing. To me, it means that functions are usually
"pure" and are first-class objects - they can be passed to other functions.

"Pure" means that functions have no side effects - they do not "change"
anything in the machine, such as the value of a variable or a file on the
hard drive.

## The Haskell Type System

Before we look at the Graql language properly, we're going to have a quick look
at the Haskell type system.

So what is a "type"?. A "type" is the equivalent to a struct or a class in an
object-oriented language. They're used to structure your data.

These are probably best explained by example, so let's open a new Haskell file:

```haskell
module DataTypes where
```

Here's how boolean is defined in Haskell:

```haskell.ignore
data Bool = True | False
```

The `data` keyword states we're defining a new type with the name `Bool`. We
read `|` as "or", so an instance of `Bool` can be either `True` or `False`:

```haskell
earthOrbitsSun = True
earthIsFlat = False
```

Let's say we wanted to record payment information for a website. Someone can
pay with credit card or PayPal. If they pay with credit card, they have to
provide an (integer) card number and (string) name. If they use PayPal, they
just have to provide their PayPal username (a string):

```haskell
data PaymentInfo = CreditCard Int String | PayPal String
```

We can make instances of `PaymentInfo` like so:

```haskell
myCreditCard = CreditCard 12345678 "Felix"
myPayPal = PayPal "felix@me.co.uk"
```

We use the `CreditCard` constructor to create a `PaymentInfo` instance,
providing an `Int` and a `String` as arguments. We can also use the `PayPal`
constructor to make a `PaymentInfo` instance, providing only a `String`.

This is basically the same as the Java:

```java
PaymentInfo myCreditCard = new CreditCard(12345678, "Felix");
PaymentInfo myPayPal = new PayPal("felix@me.co.uk");
```

## Graql Queries

So what does a Graql query look like? Here's an example:

```
match
$x isa person, has first-name "Alice";
$m (wife: $x, husband: $y) isa marriage;
select $y;
```

The above query will find people Alice is married to.
A quick summary of Graql's structure:

A *match query* is comprised of *patterns*.  In this example our *patterns* are
`$x isa person, has first-name "Alice"` and `($x, $y) isa marriage`.  Each
*pattern* starts with a *variable* such as `$x` and several *properties*. For
example, `$x isa person, has first-name "Alice"` is comprised of two
*properties*: `isa person` and `has first-name "Alice"`.

*variables* and *names* are just strings. Variables are displayed with a
prefixed `$`.

You can add a *select* statement after a *match query* and the result is also a
*match query*. The select statement is followed by *variables*.

## Graql In Haskell

This all maps pretty neatly to the Haskell type system:

> *variables* and *names* are just strings.

These can be modelled with types containing a single `String` field:

```haskell
data Var = Var String
data Name = Name String
```

> A *match query* is comprised of *patterns*.

To indicate a list, we wrap it in square brackets, e.g. `[Pattern]` represents
"a list of `Pattern`":

```haskell.ignore
data MatchQuery = Match [Pattern]
```

> Each *pattern* starts with a *variable*, such as `$x` and is followed by
> several *properties*.

So our `Pattern` type needs two fields: a `Var` and a list of `Property`:

```haskell
data Pattern = Pattern Var [Property]
```

> For example, `$x isa person, has first-name "Alice"` is comprised of two
> *properties*: `isa person` and `has first-name "Alice"`.

There are lots of different kinds of properties, so our `Property` type needs
to be a list of alternatives, separated by `|`:

```haskell
data Property = Isa Name         -- e.g. $x isa person
              | Rel [RolePlayer] -- e.g. (wife: $x, husband: $y)
              | Has Name String  -- e.g. $x has username 'felix'

data RolePlayer = RolePlayer Name Var -- e.g. wife: $x
```

If we added a new property to the Graql language, all we would have to do is
add it as another option here!

> You can add a *select* statement after a *match query* and the result is also
> a *match query*. The select statement is followed by *variables*.

We could make a new type, called `SelectQuery` comprised of a `MatchQuery` and
a list of `Var`s:

```haskell.ignore
data SelectQuery = Select MatchQuery [Var]
```

However, there's a catch! Our definition states that "the result is also a
*match query*", so instead we need to add another alternative to `MatchQuery`
like so:

```haskell
data MatchQuery = Match [Pattern] | Select MatchQuery [Var]
```

## Building Queries

Let's look at how you write some of the different parts of a query:

```haskell

-- $x, $y and $m
x = Var "x"
y = Var "y"
m = Var "m"

-- person, marriage, wife, husband, firstname
person = Name "person"
marriage = Name "marriage"
wife = Name "wife"
husband = Name "husband"
firstName = Name "firstName"

-- isa person
isaPerson = Isa person

-- has first-name "Alice"
namedAlice = Has firstName "Alice"
```

We can define lists of things by putting them in square brackets like so:

```haskell
propertyList = [Isa person, Has firstName "Alice"]
```

So here's how to make a pattern:

```haskell
-- $x isa person, has first-name "Alice";
myPattern = Pattern x [Isa person, Has firstName "Alice"]
```

Simple, right? Here's that example query again:

```
match
$x isa person, has first-name "Alice";
$m (wife: $x, husband: $y) isa marriage;
select $y;
```

And here it is in Haskell:

```haskell
uglyQuery = Select (Match
   [ Pattern x [Isa person, Has firstName "Alice"]
   , Pattern m [Rel [RolePlayer wife x, RolePlayer husband y], Isa marriage]
   ]) [y]
```

...OK, that's not so pretty. So our next step is to introduce functions to help
build these structures. Defining these is really boring so I'm skipping some
definitions:

```haskell
isa = undefined
has = undefined
rel = undefined
(.:) = RolePlayer;
```

The whacky `(.:)` is an "infix" function, meaning we can put it between two
arguments (just like `+` and `&&`). I'm using it to define relationships:

```haskell
--               (wife: $x, husband: $y)
myRelation = Rel [wife .: x, husband .: y]
```

You can make any function infix by putting it in `` `backticks` ``. This can
make some things read more clearly:

```haskell
boringPrefix = isa x person
awesomeInfix = x `isa` person
```

These tricks let us write the query like this:

```haskell
query = Match
  [ x `isa` person `has` firstName $ "Alice"
  , m `rel` [wife .: x, husband .: y] `isa` marriage
  ] `Select` [y]
```

Here's the Java equivalent:

```java
MatchQuery query = graph.graql().match(
    var("x").isa("person").has("first-name", "Alice"),
    var("m").rel("wife", "x").rel("husband", "y").isa("marriage")
).select("y");
```

I'd say they're fairly comparable!

This is only scratching the surface of the power of both Haskell and Graql.
If you'd like to know more, here are some links:

- [Grakn Labs](http://grakn.ai/), where Grakn and Graql are developed.
- [Moogi](http://moogi.co/), a movie search engine, built using Grakn.
- [haskell-graql](http://github.com/aelred/haskell-graql/), the repo for
  `haskell-graql` which is much more fully-featured than this example.
- [Learn You A Haskell](http://learnyouahaskell.com/), a great book that
  teaches you the basics of Haskell. If you could follow this blog post, you'll
  have no trouble with this!
