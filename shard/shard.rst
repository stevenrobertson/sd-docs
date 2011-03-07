The Shard language
==================

:Author:    Steven Robertson
:Contact:   steven@strobe.cc
:Abstract:
    Shard is a simple embedded programming language for high-performance
    parallel computing. This document describes the design and function of
    the language.

.. note::
    Shard is still in the design stage. The language, and this
    manual, are subject to change.

Why was Shard created?
----------------------

GPGPUs, and other massively parallel architectures, offer extraordinary amounts
of computation power per watt, per dollar, and per cubic centimeter. This is
generally made possible by aggressively removing or sharing as many functional
units as possible within the hardware, and exposing the remaining hardware
behavior to the ISA at a relatively low level.

Removing features such as cache consistency and branch prediction makes this
level of performance possible, but it also demands additional care when
designing algorithms for such devices. Only a subset of computational tasks can
be performed efficiently; efficient programs must stick as tightly to this
subset as possible.

Unfortunately, the exact nature of this subset can vary from device to device.
OpenCL\ [#]_ was created to solve that problem. The framework forms an
approximately common subset of operations that can execute quickly (or be
easily transformed during optimization to do so) across supported
architectures, smoothing out the differences between each architecture and
allowing one implementation to work across many platforms.

.. [#]  The author knows DirectCompute exists, but can't be bothered to mention
        it in the same sentence as OpenCL each time.

Naturally, in the process of subsetting each architecture, some low-level
details of each architecture are hidden. In most cases, these details are
either not commonly used by OpenCL programs, or can be expected to be managed
effectively by the OpenCL compilers for each platform. However, this is not
always the case.

The project for which Shard was designed happened to be one such instance;
OpenCL turned out to be a bad fit. It wasn't that the idea of OpenCL was
fundamentally flawed, just that an endless stream of annoying little details
made it unsuitable for our purpose. So I made Shard instead.

Accordingly, Shard is OpenCL with most of the compromises and design decisions
turned around.  The language itself is lightweight, has a clean Python-inspired
syntax, and is tightly coupled to its parent language (Haskell). The
programming model exposes more of the underlying hardware than OpenCL, and
correspondingly provides fewer abstractions. Shard sacrifices portability in
favor of control and performance; there's almost nothing you can do in one of
the language's backends which you can't do natively in Shard, and for the
few exceptions, there's inline assembly.

Let's take a look.

The Shard language
------------------

Comments
~~~~~~~~

Shard comments are prefixed with a double-dash, ``--``, and extend to the end
of a line. You'll see them used in code examples throughout this document. This
was chosen so that, when you're editing Haskell sources with Shard blocks in
quasi-quotes, editors will properly color comments.

Types
~~~~~

Shard is a strongly-typed language, and tends to be rather strict about it.
Type inference, type variables, and compile-time polymorphism ease the
pain, and a very compact type annotation syntax makes resolving the
remaining ambiguities less obnoxious.

.. note:: TODO: not sure about type variables. May be overkill.

Syntax
``````

Like Haskell, all type names in Shard begin with a capital letter, to
distinguish them from other identifiers. *Un*\like Haskell, type
application is right-associative (as is all function application - but more
on this later). This works because all type constructors take exactly one
parameter, and it's worth the difference because it enables some very
concise type annotations.

Type annotations are provided simply by naming the type immediately before
the value it describes, either in an expression or a pattern-match.
Compound types are built in exactly the same manner. ::

    a = F4 1.0          -- Sets 'a' to the literal '1.0' as an F4
    F4 b = 1.0          -- Same effect, using annotation on the pattern

    n, p = inttoptr 1, inttoptr 2   -- Types inferred from later stmts
    m = load(Ptr Ptr F4 n)          -- m is a pointer of type (Ptr F4)
    Ptr F4 o = load(p)              -- p's type inferred as (Ptr Ptr F4)

    F8 k = F4 j         -- This is an error; these are type annotations,
                        -- not typecasts.

Basic types
```````````

Signed integer, unsigned integer, and floating-point values are supported
for math operations. These types are specified by an ``S``, ``U``, or
``F``, respectively, followed by the number of bytes in the type; the full
set of types is therefore ``S1 S2 S4 S8 U1 U2 U4 U8 F2 F4 F8``. The
half-precision type ``F2`` is limited to load, store, and convert
operations; on some architectures, ``S1`` and ``U1`` share the same
limits.

Boolean values have a separate type ``Bool``. Such values don't have a
defined in-memory representation, and can't be typecast to or from other
types. Use comparison operators to create a ``Bool`` from normal types, and
a select operator to go the other way.

.. note:: TODO: figure out what a select operator looks like.

Pointers
````````

Pointer types use the type constructor ``Ptr``, followed by the type of the
object they point to. Because of the right-associative, single-valued
nature of function application, pointer type annotations rarely need to
include parentheses.

.. note:: TODO: expand this section.

Haskell pointers
````````````````

.. note:: TODO: expand this section.

Tuples
``````

Tuples are Shard's equivalent of C structures. They can be created with the
comma operator — ``,`` — optionally surrounded by parentheses, and
decomposed by pattern-matching against the same syntax, as well as by an
indexing operation. ::

    v = (a, b, c, d)
    k, j, l = someFunc(m, n)
    ((q, r), s) = t, u

In normal code, Shard's tuples have no runtime overhead, or indeed any
runtime representation whatsoever; the compiler decomposes all operations
on tuples into operations on their components. To emphasize this — and
because I couldn't come up with a syntax that didn't suck — there's no type
annotation for tuple values. Instead, merely annotate each member of a
tuple separately in an expression or pattern binding. ::

    -- This example isn't the most readable, but it suffices.
    F8 x, y, U4 z = a, F4 b, U4 c

.. sidebar:: The trouble with tuple type annotation

    An explicit type annotation for tuple values yields many unpleasant
    corner cases and reduces the conceptual simplicity of the syntax.
    Here's a rundown of the reasons I omitted this obvious feature.

    In the case of a packed tuple, annotating it involves relatively low
    amounts of visual chicanery::

        (F4, F4, U8) tup

    About the only complaints with this syntax are that the basic type
    constructors, such as ``F4``, don't have an actual value immediately
    following them (unlike in expressions and pattern matches), and that
    the "parentheses are optional" rule for constructing tuple values
    doesn't extend here.

    Of course, tuples can be and often are pattern-matched, which is less
    concise::

        (F4, F8, U8) (a, b, c) = tup
        (F4, (F8, F8, (U4, U4)), U4) (x, y, z) = (a, b, c)

    In the first line, a set of type constructors is being composed into
    another type constructor, and applied to a set of values being composed
    into a tuple value for pattern matching, which is fine if a little
    burdensome to read. But in the second line, where some but not all
    tuples are being pulled apart in the LHS, the visual cadence of
    comparing type to value gets a bit smeared. And the error message about
    the type conflict from the assignment would be difficult to produce
    consistently.

    Without delving into type variables, polymorphic tuple types would
    require type annotations within a tuple, and a non-horrible function
    declaration syntax would require that anyway. Mixing internal and
    external type annotations leads to some weird and ugly type and style
    conflicts, and would be the only syntactically valid way to generate a
    type mismatch *within* a pattern match::

        (F4, F8, U8) (a, F4 b, c)   -- this is horrible, why god why, etc

    It also interferes with the "all functions take one argument" property
    that helps these inline type definitions stay conceptually simple.
    Granted, I ditch this property readily for the special case of tuple
    pointers, but it's still nice in the general case.

    There are more reasons why leaving this out, and I should probably come
    back and add them before publishing (TODO: this), but I'll finish
    describing the language first.

In code that accesses memory, Shard's tuples do have a run-time
representation; in particular, one identical to a C structure with the same
members (and subsequently the same alignment requirements). This means it's
possible to load and store tuple values to memory, pack and unpack them for
stack-based function calls, and so on.

Memory operations may be used on tuples directly, without an intervening
pattern match or composition. To avoid a superfluous pattern-match when the
contents of the values won't be used, pointers may directly declare a tuple
type without unpacking it. This feature only exists for pointers, where
most of the complexities noted in the sidebar don't apply.

The syntax for tuple pointers is pretty much as you would expect: a
parenthesized, comma-separated list of type constructors as an argument to
a ``Ptr`` constructor. This is the only instance where a type constructor
is not immediately followed by a value or another type constructor. ::

    a = load Ptr (F8, F4, F8) k[0]
    store (k[1], a)

There's no explicit syntax for a 1-tuple, nor is there any support for one.
Frankly I can't see an instance where it would be useful, although if
presented with such a situation I would warily consider adding a separate
type constructor and pattern match syntax for it.

It is occasionally necessary to reference the unit type, expressed as an
empty set of parentheses, ``()``.

Statements
~~~~~~~~~~

Statements consist of an expression on the RHS, optionally preceded by a
binding and equals character on the LHS. If the LHS is missing, the
statement is assumed to be bound to the unit pattern (that is, it's void);
this is useful for effectful computations.

Expressions
```````````

Expressions in Shard follow the usual C-like syntax and precedence used in most
programming languages. Not all of the operators are present in the language,
but the ones you'd expect are. ::

    1 + 2                           -- = 3
    4 * 5 + 6 / 3                   -- = (4*5) + (6/3) = 22
    1 - -2                          -- = 3 (unary negation supported)
    7 < 6                           -- = False
    a * -4 + 5 < (c + 1.2) / 2      -- means what you think it does

.. note:: TODO: Explicitly list the full set of supported operators.

The ``,`` tuple constructor has the weakest binding, but is otherwise just
a regular operator.

Function calls
``````````````

Many native operations, and most user-defined ones, are expressed through
function calls. In most cases, "function calls" are actually instances of
symbol replacement or in some cases branches to a local copy of the
function's body.

.. note::
    TODO: consider manual control mechanisms for inlining, inline
    threshold, loop unrolling, etc.

As with type constructors, all functions take exactly one argument, and
function application is right-associative.\ [#]_ Of course, that argument
could be a tuple constructed inline, in which case a function call looks
suspiciously like C. ::

    a = sin 0                   -- for single arguments, parens are optional
    b = cos (0)                 -- but they're allowed, of course
    c = sin cos sin cos 1       -- c = sin(cos(sin(cos(1))))

    store(p, c)                 -- opening parens can abut the identifier
    q = (p, c)
    store q                     -- calls can be made with pre-packed tuples
                                -- (but it might be ugly)

.. [#]  Thanks to CoffeeScript_ for the inspiration on this.
.. _CoffeeScript:   http://jashkenas.github.com/coffee-script/

Any function that is "stackless" (see the Flow Control section for the full
details) can return any type, including tuples. Since I haven't implemented
actual, C-convention function calls at all yet, I'm not sure whether
they'll automatically handle popping structure return values off the stack
yet.

Binding and pattern matching
````````````````````````````

Shard is a `single static assignment`_ (SSA) language, meaning each
variable can only be assigned exactly once in a given namespace. See the
Flow Control section for details on how this works.

Pretty much everything you need to know about binding has already been
covered in previous examples: the left-hand side of an equals sign may
contain a single value expression, consisting of either a lone variable
name or a (possibly nested) tuple of them, with optional type annotations
on each. Parentheses are only required for disambiguation. ::

    a, (b, c), (d, e, f), F4 g = yay       -- exciting stuff

That's pretty much it.

Calling this tuple expansion mechanism "pattern matching" is perhaps
overselling it. Eventually, more traditional functional language features
might be incorporated into Shard; a syntactic sugar for pattern matching
with numeric literals is under consideration. More than that, however, and
we're in danger of starting to make an incompatible dialect of Haskell. I'd
rather focus on a high-performance parallel backend for Disciple_ than try
to make Shard too featureful.

.. _single static assignment:
    http://en.wikipedia.org/wiki/Static_single_assignment_form

.. _disciple: http://disciple.ouroborus.net/

Function definitions
~~~~~~~~~~~~~~~~~~~~

Functions are defined with the ``def`` keyword, a function name, the
variable binding for the function argument, and a colon, followed by the
statement block which defines the function body. They are terminated by a
value or control statement, and optionally a ``where`` block. ::

    def funcA(U4 a, U8 b):
        return go extend a
      where:
        def go v:
            if v < b:
                branch go(v * -2)
            else:
                return v

Argument binding
````````````````

The variable binding pattern follows the same conventions as that for the
LHS of an ordinary statement. Here are some examples::

    def func1(U4 a, U4 b):      -- normal, C-like syntax here
        ...

    def func2(U4 a, b):         -- Type annotations can be omitted, in
        ...                     -- which case they will be inferred. See
                                -- the 'polymorphic functions' section.

    def func3(U4 a):            -- If there's a single argument, you can
        ...                     -- use parentheses for consistency,

    def func4 a:                -- or skip them if you prefer.
        ...


    -- CAUTION: I haven't decided if these two formats should be valid or
    -- not for consistency, but they are ugly and should be avoided.

    def func5 U4 a:             -- invalid and ugly
        ...

    def func6 U4 a, U4 b:       -- same
        ...

The variables bound in the pattern are visible throughout the entire
function definition, *including* the ``where`` block if present.

Statement block
```````````````

A line ending in a colon starts a block of statements. Each non-whitespace
line in the statement block must begin with an indent level that is
exactly four spaces greater than that of the line which began the block.
The statement block is terminated by a non-whitespace line which has a smaller
indent, or by end of input.

Each statement in a statement block which contains a binding exposes those
variables bound in a given line to each statement which follows it in that
statement block (or its children). It does not expose these variables to
the current or previous lines, so recursive binding's out. It also cannot
affect the parent block's lexical scope. In other words, closures can only
be formed from, and access, a parent function's arguments. Since this is an
SSA language without first-class functions but with subfunctions, it is no
great loss.

Statement blocks may have additional semantic termination requirements
apart from these syntactic ones. Function bodies are an example; the last
statement in a function body must be a value or control statement. See "Flow
Control" for details.

Where block
```````````

The ``where`` keyword begins a section wherein top-level definitions (for
now, just function definitions) can be expressed within the lexical scope
of the enclosing function. Each function defined in a ``where``
block is visible from the entire function, including its own body and every
other function in the block. The namespace of the parent function at its
head is also visible, including function arguments and any names exposed by
the parent function's parent.

The ``where`` keyword must be indended exactly two spaces greater than the
function body, and its contents must be indended exactly four spaces
greater than the function body, or two more than the keyword. This unusual
configuration was found to emphasize the keyword and its relation to both
its contents and the function body above it.

A function defined in a ``where`` block is free to include a nested
``where`` block of its own.

Polymorphic functions
`````````````````````

Shard doesn't currently support polymorphic functions in any capacity; each
function must fully specify the type of its argument using annotations. We
expect to implement this quickly.  When it is, this will be updated (and
probably moved to the Flow Control section too).

Flow control
~~~~~~~~~~~~

Flow control is expensive on a GPU, and will be for the forseeable future.
High-level languages can obscure the number of flow control instructions
generated, and assembly-language control constructs can be painful and
error-prone. Shard exposes each flow control choice to the programmer, but
uses compact, safe syntax to do so.

Currently, Shard primarily targets NVIDIA GPUs through a PTX backend, and
traditional CPUs via an LLVM backend. While Shard programs compiled for the
latter should run on par with C, the more powerful GPUs remain our primary
focus. The concepts and limitations of CUDA influence the design of Shard,
and are referenced frequently below. If you're not familiar with the
platform, it might be worth checking out NVIDIA's `CUDA developer site`_.

.. _CUDA developer site: http://developer.nvidia.com/object/gpucomputing.html

Host function calls
```````````````````










