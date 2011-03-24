Okay, so here are a few pointers.

MT19937 - that is, the Mersenne Twister - is a great PRNG. It's even suitable
for implementation on GPUs (see the CUDA SDK for an example). However, it
requires a large amount of state, and it operates in batch mode, meaning that
when the pool[^1] runs out of random bits, the entire pool must be regenerated
at once. This *can* be handled with CUDA, but it's not the fastest or simplest
solution.

ISAAC is in a similar boat. Relatively fast, but not explicitly parallelizable;
can be made to run on the GPU, but requires batch refreshes.

win32's rand(), unlike the above two, is a comically bad PRNG. It's an example
of a lagged congruential generator (see Wikipedia), and the LCG multiplier
chosen is known to be a terrible choice, making a bad algorithm worse.
(Microsoft knows this, and warns people away from using it, but - at least up
to XP - didn't change the behavior to avoid breaking old code.)

The problem with LCGs in general, *especially* for simulations like ours, is
that these PRNGs have atrocious spectral properties (google "LCG spectral").
This *absolutely* shows up when rendering flames (Erik has a good story about
it). To find more research into the reasons why bad RNGs screw up this type of
simulation, you should know what it's called in the literature: the algorithm's
an "IFS", or "iterated function system", which is a kind of "Markov chain" (or
"Markov process"), and we estimate it using a "Monte Carlo" simulation.
Searching any of the quoted terms along with "random", "RNG", or "PRNG" on
Google Scholar (or just Google) should bring up plenty of information.

Now, the MWC. The (plain or lag-0) MWC's generating function, to get from state
x_n-1_ to state x_n_, is:

    x_n_ = (M * x_n-1_ + C_n-1_) mod 2^32^
    C_n_ = (M * x_n-1_ + C_n-1_) div 2^32^

In fact, the 'mod' and 'div' operators can be represented much, much faster, as
they are mod-2^32^: in fact, x_n_ and c_n_ are the lower and upper 32 bits of a
64-bit multiply-add operation, respectively. In CUDA's PTX, here's the entire
process:

    .reg.u32 x0, c0, x1, c1, mwcMul;
    .reg.u64 tmpC, tmpOut;

    // assume x0, c0, mwcMul are set externally

    // sign-extend c0 to a 64-bit unsigned int (this step may be optimized out
    // by the assembler on Fermi): "tmpC = sext(c0)"
    cvt.u64.u32     tmpC,       c0;

    // do a multiply-add, computing the full 64-bit product and adding the
    // sign-extended carry afterward: "tmpOut = x0 * mwcMul + tmpC"
    mad.wide.u32    tmpOut,     x0,     mwcMul,     tmpC;

    // move the upper and lower halves of tmpOut to x1 and c1 (this step is
    // always optimized out by the assembler on Fermi)
    mov.u64         {c1, x1},   tmpOut;

    // result now in 'x1'; carry (for next value) now in 'c1'

It's important to note that the optimizer can, in some cases, reduce this
entire process to one or two instructions, and that's it. Meaning that this
algorithm is blazingly fast. Note that although it uses several different
variable *names*, the only variables that actually need space in the register
file after this operation completes are the current state, carry, and
multiplier.

A lagged MWC extends this algorithm by storing a history of carry values, and
choosing a new one each time. This, of course, extends the resident size of the
algorithm by 4 bytes (or one register) for each carry value, plus an extra
register for tracking which register to use next (except for lag-1, where an
XOR swap is sufficient). This increases the period size, which is good if you
need to generate enormous numbers of values, or for cryptographic purposes.

Which brings up a very important point: *we don't care about cryptographic
purposes*, or about extraordinarily long periods. "PRNG quality" matters for
two big purposes: simulation and crypto. The PRNG needs of simulation are
different, and usually less stringent, than that of crypto. While it's
important that the RNG state not loop too often during the rendering of a
single flame, a lag-0 MWC's "modest" period of four quintilion is orders of
magnitude larger than even a single-threaded, Q=2000 flame would ever require.

In general, when reading about RNG quality for this paper, be sure to
distinguish between what's important for crypto and what's important for
simulation. It might help to know what to look for: the flame algorithm solves
an "IFS", or "iterated function system", which is an example of a "Markov
chain" or "Markov process", and to approximate a solution we use a "Monte
Carlo" simulation. Punching the quoted terms into Google Scholar, along with
PRNG or just random, should yield interesting results.

Questions / topics that you may wish to write about (google first, but don't
hesitate to ask for clarification or help with the answers!):

- What statistical properties of PRNGs do we care about? (The spectral
  distribution is enormously important; for more statistical properties of
  randomness, look up the DIEHARD battery of tests.)

- What properties are important to crypto that are commonly cited, but that we
  don't care about?  (I've never done crypto, so I can't be much help here.
  Skip this if you want to.)

- How much state does MT19937 require, in bits, per thread? How about ISAAC?

- Give a brief overview of MT19937's principle of operation. (Not an easy task;
  only do this if you need to boost the page count.)

- Do the same for ISAAC. (This is easier and probably worth the time per page.
  Also, look at TEA; it's conceptually similar to ISAAC, and is better
  documented. A paper in the Mendeley group covers it, and describes how it can
  be ported to GPUs.)

- And again for MWC.

- Do each of the above generators meet our statistical needs? (Hint: yes. But
  see if you can find DIEHARD test results to show this, and compare between
  them.)

- Which one best meets our performance needs? (MWC, of course.)

- Why is the period of a lag-0 MWC, even though small compared to others, still
  entirely sufficient for our purposes?

- The GPU requires thousands of threads to perform well. Explain how linear
  dependence between threads can cause problems if multiple threads happen to
  be near each other on the same period. (In other words, why we must seed each
  thread with random data taken from a different kind of random generator.)

- Note that since the multiplier is only 32 bits, handing different multipliers
  to each thread can put them on entirely different sequences of random
  numbers, with less concern about linear correlation across threads.

- How to choose a good MWC multiplier? (Large safeprimes.)


