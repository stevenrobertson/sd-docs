# Random Numbers and Pseudo-Random Number Generators
Random numbers are used in this project because of their importance in calculating and rendering fractals using Iterated Function Systems. For example, in order to recreate Sierpinski’s triangle, one defines the three vertex points A, B and C. Starting at point A, one randomly picks the next point (B or C) and draws a point halfway between the points chosen. From there it is all about picking the next point randomly and doing the same thing all over again thousands of times until getting a fractal like that in Figure \ref{mandelbrot}.

Real random numbers are hard to calculate in a computer; in great part because they depend on time or because there isn’t an infinite number of bit sized chunks for computation. Pseudo-Random Number Generators (PRNGs) are algorithms that simulate randomness in a computer, usually by using prime numbers as seeds because when they are used in a division, the output is an irrational number.The greater the prime number, the better quality numbers are outputted. In order to find the right PRNG for this project we will consider advantages and disadvantages of different well known PRNGs.

In selecting the right PRNG, it is common to look at its period (or numbers it outputs until it starts repeating itself), its speed and its spectral properties, the latter which determine its true randomness. For this project, we are looking for a simple and fast PRNG that meets out minimum needs.

##  Pseudo Random Number Generators
There are various properties that a PRNG can have, but for this project, we are looking for maximized speed and spectrum properties, and a PRNG that can be implemented in a GPU.

## `rand()` and Linear Congruential Generators

The search for pseudo-random number generators begins with the most commonly
used, win32’s `rand()` function. The problem with this function is that its
randomness is biased.  If we say `x=rand()%RANGE;` the function returns any
number represented by $[0, \text{RANGE})$ instead of $[0,\text{RANGE}]$.
Assuming that `rand()` outputs a number $[0, \text{MAX}]$, RANGE should be able
to divide by $\text{MAX}+1$ entirely in an ideal PRNG, however it doesn’t in
the `rand()` function and therefore the probability of choosing a random number
X in $[(\text{MAX}\%\text{RANGE}), \text{RANGE}]$ is less than that of choosing
it in $[0, \text{MAX}\%\text{RANGE}]$. [CITE 1]

Another problem with `rand()` is that it is a Linear Congruential Generator
(LCG).  The way LCGs work is with the following basic formula:

\begin{displaymath}
    X_{n+1} = (a\cdot X_n +c) \mod m
\end{displaymath}

Where $X_{n+1}$ is the next output and a and m must be picked by the user of
the algorithm. Here, the problem is not only that to get decent randomness one
needs to pick $a$ and $m$ carefully (with $m$ closest to the computer’s largest
representable integer and prime) and $a$ equal to one of the following
values [CITE 2]:

\addfontfeatures{Numbers={Lining,Monospaced}}

           $m$     $a_1$        $a_2$      $a_3$
--------------  --------    ---------   --------
549755813881    10014146    530508823   25708129
2199023255531   5183781     1070739     6639568
4398046511093   1781978     2114307     1542852
8796093022151   2096259     2052163     2006881

Table: Acceptable values for LCG modulus $m$ and multiplier $a$.

\addfontfeatures{Numbers={OldStyle,Proportional}}

There are other choices for $m$, with their respective values for $a$, but those sets also have rules and may not apply to certain computers if they don’t have the required hardware.

## ISAAC
An alternative that sounds like a better choice is ISAAC, it stands for Indirection, Shift, Accumulate, Add, and Count [CITE 3]. The way it works is by using an array of 256 4-byte integers which it transforms by using the instructions that define its name and places the results in another array of the same size. As soon as it finishes the last number, it uses that array to do the same process again. The advantages of this PRNG are that it is fast since it only takes 19 for each 32-bit output word, and that the results are uniformly distributed and unbiased.[CITE 4] The disqualifying disadvantage is that even though the GPUs; which we will use for this project, have enough global memory, they don’t have the memory required to be able to have arrays of size 256.

## Mersenne Twister
“Mersenne” in its name because it uses Mersenne primes as seeds (Mersenne primes are prime numbers that can be represented as $2p -1$ where p is also a prime number). This PRNG uses a twisted linear feedback shift register (LFSR), which uses the XOR instruction to create the output, which then becomes part of the values that are being XORed. The “twist” in its name means that not only do values get XORed and shifted, but they also get tampered and there is state bit reflection.

It is a good choice for this project for several reasons; it is sufficiently fast for this project, it has a period of 2^19937 -1 (meaning the random numbers will not repeat for that many iterations), and it can be implemented on a GPU, however, it requires a large amount of static memory on the GPU, and it operates in batch mode, meaning that when the pool runs out of random bits, the entire pool must be regenerated at once. This can be handled with CUDA (NVIDIA’s parallel computing architecture)[CITE 5], but its not the fastest or simplest solution.

## Multiply With Carry This algorithm might seem similar to the typical one for
a LCG, but it differs when it comes to how the new iteration values are chosen.
To start, one chooses a numbers a, c, and m. A number b is also chosen such
that $b = 2^{\text{half the size of the register}}$. First, $x_1 = (a_0*x_0 +
c_0) \mod m$, then, the quotient of the past calculation becomes the quotient
for c and $x_n = (a_1*x_{n-1} + c_{n-1})$ where $x_{n-1} = x{n-2} \mod b$ and
$c_n-1 = \lfloor (x_{n-1}/b) \rfloor$. This process gives Multiply With Carry (MWC)
advantages over LCGs if the numbers are chosen carefully because by having c
vary in every iteration, the randomness of its output can pass tests of
randomness that LCGs can’t.

It is important to note that MWC implemented in this form has a period that
cannot be represented by a power of two, and depends on the size of the
register used. The best values to choose in order to have a large period are
when $ab - 1$ is a Safe Prime (a number that can be represented in the form
$2p-1$ where p is a prime number.) For a register of size 32, a can be chosen
to be a number represented by 15 or 16 bits, if it is 15 bits, then the maximum
number a can be is 32,718 and the period will be 1,072,103,423, if its 16 bits,
then the maximum number a can be is 65,184 and the period will be
2,135,949,311. For a register of size 64, a can be chosen to be a number
represented by 31 or 32 bits, if it is 31 bits, then the maximum number a can
be is 2,147,483,085 and the period will be 4,611,684,809,394,094,079, if it is
32 bits, then the maximum number a can be is 4,294,967,118 and the period will
be 9,223,371,654,602,686,463.

This algorithm can be used in the GPU for 4 main reasons; it is very elastic when it comes to limitations or requirements of register sizes, it is not over engineered or takes too many lines of code to implement, it passes the best known randomness tests, including the Diehard Tests[CITE 6], and its spectral properties meet the requirements for this project. The only thing that could be considered a disadvantage for this algorithm is that its most significant bits can be slightly biased, however, not enough as to make a difference in this project.

## Spectral Distribution
The spectral distribution test is devised to study the lattice structures of PRNGs and especially that of LCGs. It is also famous in great part because it fails LCGs that that have passed other tests.
It works by taking the outputs of PRNGs and finding where the numbers lie in s number of dimensions; it then takes that information and displays it as a lattice as seen in Figure R.2. Mathematically, overlapping vectors  $L_s = {x_n = (x_n, …, x_{n+s}-1)}$ where $n\ge 0$ are considered, since they exhibit the lattice structure.

![Example of lattice structure. [CITE 7] [TODO: Improve this caption] ](rng/latice.png)

However, without having to draw the dots, a conclusion about a PRNG can be made because of its mathematical properties; the spectral test determines a value $y_k$ which determines the minimum distance between points in the s hyper-planes on which it tests.
The formula is given by $y_k = \min(\sqrt(x_1^2 + x_2^2 + …+ x_k^2))$
Ideally, the minimum number from 0 to k will be a high value (in the thousands) and the PRNG will also have a high number of dimensions.

## Monte Carlo simulations
The Monte Carlo methods are algorithms that use statistics to determine probabilities in systems and their properties. They are used in finance, physics, communications and even game design. In the context of this project, they are necessary measures of randomness that can be held as a standard that filters out PRNGs that don’t meet the basic requirements. Using these methods, the spectral properties and periods of some PRNGs and their variations will be determined.

## Our approaches
There are several things to be attempted in order to obtain the desired results and the most efficient algorithm that contains most if not all the desired qualities of a necessary PRNG.
The initial ideas for finding the potential PRNG are the following:

Start with MWC. Only get more complicated if it looks necessary.

Use a PRNG that requires less state, like Marsaglia’s MWC, per-thread.

Pre-compute a large number of random values with ISAAC or similar, per-thread and swap the state out of registers when not using it.

Set up a warp to write the RNGs to shared memory for consumption by other warps. Use a very complicated manual implementation of semaphores and locks to trigger the generation of more RNGs as required.

REFERENCES

[1] http://www.azillionmonkeys.com/qed/random.html

[3] Robert J. Jenkins Jr., ISAAC. Fast Software Encryption 1996, pp41–49.

[2] Numerical Recipies,The Art of Scientific Computing, 3rd edition, William H.Press, Saul A. Teukolsky, William T. Vetterling, Brian P. Flannery, Cambridge University Press

[4] http://www.burtleburtle.net/bob/rand/isaacafa.html

[5] http://nvidia.com

[6] http://www.rlmueller.net/MWC32.htm

[7] Image generated and published within the pLab-random number generators project http://random.mat.sbg.ac.at/

[8] http://random.mat.sbg.ac.at/tests/theory/spectral/

[9] Michael Barnsley, "Fractals Everywhere", Academic Press, Inc., 1988.


