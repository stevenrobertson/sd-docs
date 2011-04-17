# Other implementation challenges

This chapter has some miscellaneous stuff which probably needs to make it
into the report, but may or may not need its own chapter.


## Function selection

The GPU relies on vectorization to attain high performance. As a result,
divergent warps carry a heavy performance penalty; even one divergent thread in
a warp can double the amount of time evaluating the results of an operation
that includes branching. Avoiding unnecessary branches within a warp is
therefore an important performance optimization.

For each iteration of the IFS, one function of the flame is randomly selected
to transform the current point. This poses a problem: if the algorithm relies
on the random selection of transforms for each point, threads may select
different transforms and therefore become divergent.  With a maximum of
12 variations per flame, this leads to a worst-case branch divergence penalty
of an order of magnitude on the most computationally complex component of an
iteration.

### Divergence is bad, so convergence is... worse?

The trivial solution to this problem is to eliminate divergence on a per-warp
basis. The typical design pattern for accomplishing this is to evaluate the
branch condition in only one lane of the warp, and broadcast it to the other
threads using shared memory; in this case, have the thread in lane 0 broadcast
the `xform_sel` value generated from the RNG. Each thread in a warp will then
proceed to run its own point through the same transform.

This neatly resolves the problem of warp divergence, bringing the
samples-per-second performance of flames with large numbers of transforms
closer to that of simpler transforms. However, inspect the output of this
modified engine and it becomes clear that visual quality suffers; in fact,
subjective measurement shows that this change actually *decreases* overall
quality-per-second[^nopic]. The illustrated change has no effect on the
transform functions themselves, or on any other part of an individual thread —
from the perspective of a sample passing through the attractor, both variants
are identical. Where, then, is this drop in quality coming from?

[^nopic]: This information was gathered by one of the authors using the
earliest GPU implementation, which no longer runs on current hardware, so
example images are not available until our renderer is complete.

Recall that a necessary condition for stability in a traditional iterated
function system is that each transform function is *contractive*, and that this
is at least approximately true for the flame algorithm as well. Each successive
application of a contractive function to a point reduces the distance between
the point and the function's fixed point. In the system modified to iterate
without divergence, each thread continues to select a new transform each time
it is chosen, and this behavior prevents the system as a whole from converging
on a fixed point.

However, since each thread in a warp applies the same transform, each
application brings every point in the warp closer to the same fixed point, and
therefore to the other points in the warp. It doesn't matter that the next
transform will have a different fixed point; the same effect will happen. While
the points won't converge to a single fixed point across the image, they will
quickly converge on one another. The precision of the accumulation grid is
relatively low, even with FSAA active, so that after only a few rounds each of
the 32 threads in the warp is effectively running the same point. Despite
computing each instruction across all threads, the vectorized hardware produces
no more image information than a single thread.

While a sequence of contractive functions applied to any two disparate points
will cause those points to converge, the amount of convergence depends both on
the length of the sequence and the contractiveness of those functions. Because
the images have limited resolution, any sequence which reduced variability
between disparate points below the sampling resolution[^resolv] of the image
grid would effectively "reset" the point system each time it was encountered,
resulting in an image with substantially reduced variation. Since short-length
subsequences of transforms are likely to be encountered in a high-quality
render, we can reason that flame designers typically reject genomes whose
transform sequences are overly contractive.

[^resolv]: It is possible to construct generally contractive functions with
exceedingly large local derivatives, which would allow the extraction of
visible structure from points ordinarily too close to be seen; in this case,
the lower bound is actually determined by the precision of the floating point
format in use. However, these systems tend to be highly unstable under
interpolation and are not often found in practice.

[TODO: expand the IFS chapter to include an explanation that the nonlinear
functions used in flames are often not technically contractive, because they
can have multiple fixed points, and that for practical purposes we can
characterize whether or not they are contractive on the bounds of the image by
computing the first moment of the distance from the center of the camera over
the domain of the image and call it "contractiveness" or come up with a better
name for it.]

It is therefore not necessary to ensure that every instance of the system under
simulation receive an entirely independent sequence of transforms; rather, it
is sufficient to limit the expected frequency of identical transform
subsequences across threads. Fortunately, there's a simple and computationally
efficient way to do this while retaining non-divergent transform application
across warps — simply swap points between different warps after each iteration.

### Doing the twist (in hardware)

There is no efficient way to implement a global swap, where any thread on the
chip can exchange with any other; architectural limits make global
synchronization impossible, and an asynchronous path would further burden an
already overworked cache (see below). Instead, data can be exchanged between
threads in a work-group by placing it in shared memory, using barriers to
prevent overwriting data.

To conduct such a swap on a Fermi core, each warp of a work-group issues a
barrier instruction after writing the results of an iteration to the global
framebuffer. The barrier instruction adds a value to an architectural register,
then adds a dependency on that register to the scoreboard, preventing further
instructions from that warp from being issued until the barrier register
reaches a certain value, after which it is reset. Multiple registers (up to 8)
are available for implementing complex, multi-stage synchronization, but as
with all addressable resources in a Fermi core, they are locked at warp
startup, so overallocation will reduce occupancy.

After reaching this barrier, all threads write one value in the state to a
particular location in shared memory, then issue another barrier instruction.
Once the next barrier is reached, indicating that values have been written
across all threads, each thread reads one of the values from another location.
If further data must be exchanged, another barrier is issued and the process
repeats; otherwise, each warp proceeds as usual.

The choice of location for each read and write is, of course, not arbitrary,
and depends on implementation factors as well as software parameters. One
important constraint on location arises from the arrangement of shared memory
into 32 banks, with a 4-byte stripe. Fermi devices have 64KB of local SRAM
which can act as L1D or shared memory, indicating a 16-bit address size for
accessing this memory. Bits `[1:0]` of each address identify position within a
4-byte dword, and are handled entirely by the ALU datapaths. The next five
bits, `[6:2]`, identify which of the 32 bank controllers to send a read or
write request to, and the remaining nine upper bits `[15:7]` form the address
used by an individual bank's memory controller[^guess].  Each memory controller
can service one read or write per cold clock. A crossbar allows 1-to-N
broadcast from every bank port on read operations and 1-to-1 access to any bank
port for write operations, all handled automatically.

[^guess]: Some details in this subsection are conjecture. The described
implementation is consistent with publicly disclosed information from NVIDIA
and benchmarks run by the authors and third parties, but has not been confirmed
by the company.

This memory architecture is flexible and fast, and most shared memory
operations can be designed to run in a single cold clock across all 32 threads.
However, there are some addressing modes which trigger a *bank conflict*,
requiring thread serialization and a corresponding stall. These conditions
arise whenever two or more operations access the same bank at different
addresses — that is, when bits `[6:2]` are the same but `[15:7]` are not.
Because barriers are required for synchronization and code in this section is
essentially homogeneous across warps, warp schedulers cannot hide latency as
efficiently while waiting for these transactions to complete, so stalls while
swapping may be compounded in other warps and should be avoided.

A simple way to prevent bank conflicts is to constrain each thread to access
the bank corresponding to its lane ID, such that bits `[6:2]` of every shared
memory address are equal to bits `[4:0]` of its thread ID. We follow this
pattern — with an inner loop this complex, simplicity is something we're pretty
desperate for — and thereby keep the problem of determining read and write
locations in a single dimension of length equal to the number of warps in a
work-group.

Within that dimension, we must still find a permutation of bank addresses for
both read and write operations. Shuffling both read and write order provides no
"extra randomness" over shuffling just one, so we allow one permutation to be
in natural thread order; since registers cannot be traced on the GPU, reads are
more challenging to debug, and so we choose to only shuffle the write orders.

To further simplify matters, we fix the write offset against the bank address
as a modular addition to the warp number. The resulting write-sync-read,
therefore, turns each memory bank into a very wide barrel register. This scheme
can be accomodated with, at most, a single broadcast byte per bank, one
instruction per thread and no extra barriers. A more complex permutation would
require considerable amounts of extra memory, a multi-stage coordination pass,
and a lot of extra debugging; it is the latter which most condemns a full
permutation. We'll examine the impact of this simulation a bit later in this
section.

In the end, the entire process resembles twisting the dials on a combination
lock: a point can move in a ring around a column, but can't jump to another row
or over other points in a column.

### Shift amounts and sequence lengths

Under this simplified model for swap, there is one free parameter for each lane
of a warp, shared across all warps. Methods for choosing these parameters
include providing a random number per vector lane and using the lane ID. We
wish to determine how effective each method is at minimizing the length of
repeated sequences in comparison with best- and worst-case arrangements.

For a flame with $N$ transforms of equal density, the probability of selecting
a given transform $n$ is $P(n) = \frac{1}{N}$. For two independent sequences of
samples, the probability that one stream would have the same transform at the
same index as the other stream is therefore $P(S) = P(n) = \frac{1}{N}$; the
probability of having a sequence of identical selections of length $l$ is

\begin{equation}\label{prob-ind}
    P(S_l) = P(n)^l = \frac{1}{N^l}
\end{equation}

In any work-group using independent selection of transforms, any two pixel
state threads $t_1, t_2 \in T,\; t_1 \neq t_2$ will also be independent, and
therefore the probabilities do not depend on the work-group size $T$. This is
the optimal case which corresponds to an efficient approximation of the
attractor.

For a work-group using warp-based branching without a swap, any two threads in
different warps are essentially independent, and so $P(S_l|\bar{W}) = P(n)^l$.
Threads in the same warp will always have the same transform, giving
$P(S_l|W)=1$. For a warp size $W$, the chance that any thread $t_2$ shares a
warp with a particular thread $t_1$ is $P(W)=\frac{W-1}{T-1}$, yielding a
combined probability

\begin{equation}\label{prob-noswap}
  P(S_l)=\frac{W-1}{T-1}+(1-\frac{W-1}{T-1})\cdot\frac{1}{N^l}
\end{equation}

The shuffle mechanism modifies $P(W)$, introducing dependencies on vector
lanes.  Since two threads in the same vector lane can never appear in the same
warp, they are independent. Vector lanes are shared with
$P(V)=\frac{T/W-1}{T-1}$; as a result, $P(S_l|V)=P(n)^l$. The probability of
any $t_2$ being in the same warp as $t_1$ is $P(W)=P(\bar{V})\cdot\frac{1}{V}$.
Threads sharing a warp will always have the same state at a given sequence
index, but because threads in other vector lanes may now be swapped, each stage
is independent. $P(S_1|\bar{V}) = P(W)\cdot 1 + P(\bar{W})\cdot P(n)$, and so

\begin{align}
  P(S_l) &= P(V)\cdot P(S_l|V) + P(\bar{V})\cdot P(S_l|\bar{V}) \nonumber \\
  &= \frac{T/W-1}{T-1}\cdot \frac{1}{N^l}
    + \frac{T-T/W}{T-1}\cdot (\frac{W-1}{T-T/W}\cdot 1
        + \frac{T-W-W/T+1}{T-T/W}\cdot \frac{1}{N})^l
    \label{prob-randswap}
\end{align}

In one sense, this model also extends to the case of fixed modular offsets;
however, for cases where $W < T/W$ — that is, where the warp size is larger
than the number of warps per work-unit — each lane equal under the modulus of
the number of warps will never swap with respect to each other, which violates
the assumptions of independent events and increases the expected length of
identical sequences. We solve this by applying a different columnar rotation of
each repeated section in the read pattern, which respects banking and thus adds
little overhead.

For reference, we also find the expected probability of a common sequence for a
full shuffle, which whe have not implemented on the device. In this case,
$P(W)=\frac{W-1}{T-1}$, and there are no independent values, so

\begin{equation}\label{prob-allswap}
  P(S_l) = (\frac{W-1}{T-1}\cdot 1 + (1 - \frac{W-1}{T-1}) \cdot \frac{1}{N})^l
\end{equation}

To compare the efficacy of each shuffle method to the independent case, we show
the results of calculating these probabilities for a few configurations and
lengths in Table \ref{probtable}. Fixed values of $N=8$ and $W=32$ are used.

\begin{table}
  \begin{tabular}{ r l r r r r }
    & & $l=2$ & $l=4$ & $l=8$ & $l=32$ \\
    \cline{3-6}
        & Independent (\ref{prob-ind})
        & $0.0156$ & $2.441\cdot 10^{-4}$ & $5.960\cdot 10^{-8}$
        & $1.262\cdot 10^{-29}$ \\
    \\[-4pt]
    \multicolumn{1}{r|}{}
        & No shuffle (\ref{prob-noswap})
        & $0.2314$ & $0.1352$ & $0.1218$ & $0.1216$ \\
    \multicolumn{1}{r|}{$T=256$}
        & Ring shuffle (\ref{prob-randswap})
        & $0.0556$ & $3.145\cdot 10^{-3}$
        & $1.013\cdot 10^{-5}$ & $1.144\cdot 10^{-20}$ \\
    \multicolumn{1}{r|}{}
        & Full shuffle (\ref{prob-allswap})
        & $0.0535$ & $2.8658\cdot 10^{-3}$
        & $8.213\cdot 10^{-6}$ & $4.550\cdot 10^{-21}$ \\
    \\[-4pt]
    \multicolumn{1}{r|}{}
        & No shuffle (\ref{prob-noswap})
        & $0.0753$ & $0.0608$ & $0.0607$ & $0.0607$ \\
    \multicolumn{1}{r|}{$T=512$}
        & Ring shuffle (\ref{prob-randswap})
        & $0.0332$ & $1.1113\cdot 10^{-3}$
        & $1.261\cdot 10^{-6}$ & $2.748\cdot 10^{-24}$ \\
    \multicolumn{1}{r|}{}
        & Full shuffle (\ref{prob-allswap})
        & $0.0317$ & $1.006\cdot 10^{-3}$
        & $1.011\cdot 10^{-6}$ & $1.048\cdot 10^{-24}$ \\
  \end{tabular}
  \caption{Probability of encountering identical transform sequences of
    length $l$ with different shuffle types.}
  \label{probtable}
\end{table}

[TODO: center tabular inside table?]

The results display a strong preference towards higher efficiency at larger
work-group sizes; this is an important and challenging constraint on launch
parameters, as more effort is required to avoid stalls and inadequate occupancy
of shader cores when using large work-groups. It's also clear that the simple
and efficient ring shuffle methods work nearly as well as a full shuffle. Less
clear, however, is how well the ring shuffle works as compared to completely
independent threads. While the probability of a chain decays asymptotically to
zero, as it does in the independent case, the ring shuffle algorithm does not
do so as quickly. So, does it do so quickly *enough*?

Alas, the answer is image-dependent, and not amenable to easy statistical
manipulation. The probabilities derived are a good way to gain insight about
different strategies for swapping points without an implementation — we
discarded several mechanisms that proved too slow or complex for the relative
gain in statistical performance in this manner — but there is no way to apply
this information. We will simply have to implement and compare.

If a ring-shuffled implementation loses little or no perceptual quality per
sample due to point convergence on test images, we will be satisfied.  However,
in the unexpected event that it is not, the best solution may simply be to
allow threads to diverge. This will cause extra computation to be done, but in
the end may not significantly impact rendering speed; as it turns out, the
bottleneck on current-generation GPUs is likely to lie in the memory subsystem.

## Accumulating results (another try)

At each iteration, the current sample must be added to the accumulation buffer.
In a typical implementation, each accumulator is 16 bytes in size, holding four
4-byte single-precision floating point values. Adding a sample to an
accumulator requires a read, to find the original value, followed by a write of
the updated value. Because many different threads will be accumulating points
simultaneously, this process may cause updates to be lost if threads write to
the same location, so global atomic instructions, which execute on dedicated
ALUs located near the memory controllers, are called for.

If an accumulator is in cache, the local ALUs allow the update operation to
complete very quickly. However, accumulation buffers can be hundreds of
megabytes in size, and write locations do not typically display spatial
cohesiveness across threads; in fact, as above, warps that are consistently in
the same neighborhood are ineffecient. Additionally, due to locally chaotic
behavior among transform functions, sample locations do not display any general
pattern in typical flames, making temporal re-use of a particular cache line
unlikely. As a consequence, most accumulations will result in an L2 cache miss.

Fermi devices use 128-byte lines in L2. Consequently, each L2 miss triggers a
128-byte load, irrespective of the amount of data to be accessed. For a 16 byte
read, this indicates an 8× bandwidth penalty on reads. Similarly, cache lines
are marked as dirty in their entirety [TODO: verify with microbenchmark],
placing an equal bandwidth penalty on writes.

The average number of operations required to complete an iteration will vary
considerably depending on the variations in use and the precision requirements
of the render, but a trace of the execution of one iteration in the abstract
[TODO: reference previous] demonstrates that the simplest cases generally
require very few operations. While this may not be useful to determine final
running time without benchmarks, it is sufficient to determine whether
alternative accumulation strategies bear investigating: if the difference
between theoretical iteration rate and accumulation rate is large, accumulation
is likely to be a bottleneck in actual implementations.  A A mid-level Fermi
GPU attains 750 GFLOPs for single precision operations (and twice that if an
FMA is counted as two operations). With an arbitrary, but reasonable, estimate
of 50 operations required to complete an iteration, this yields an upper bound
of $15\cdot 10^9$ points per second. If points were written linearly, such
cards' peak pixel fill-rate — in the neighborhood of $25\cdot 10^9$ pixels per
second — would be more than enough to capture all points efficiently. However,
with an eightfold penalty on writes, a doubling of that cost for the reads, and
limited numbers of L2-local ALUs to perform atomic operations, that peak figure
drops by more than an order of magnitude to become the clear bottleneck.

Not all flames will encounter this bottleneck. Renders to small framebuffers
that fit inside L2 are expected to have more cache hits, and consequently the
steep bandwidth penalty on reads and writes to DRAM will be lessened in the
average case. Iterations can also take longer; complex transform functions with
many parameters that use double precision will take considerably more
computation to complete, relieving the memory bottleneck. However, such
situations are rare. Given the severity of the bottleneck for a trivial flame,
it seems likely that memory bandwidth may be a limiting factor in the average
case.

To ensure optimal performance, then, a GPU implementation of the fractal flame
algorithm may employ alternate strategies for accumulation. In this section, we
discuss several possible individual techniques which reduce memory traffic or
increase efficiency, and describe how they can be combined to raise the limit
on the number of accumulations per second.

### Color strategies

As discussed in previous sections [TODO: backref or drop], human vision has
considerably less sensitivity and spatial resolution for color than for
luminance. In existing implementations of the flame algorithm, however, color
is given three times the storage space and bandwidth of density information in
the accumulator. Reducing the amount of color traffic during accumulation may
result in bandwidth savings without visible quality loss.

After rendering, individual flames are typically compressed with the JPEG image
codec, and animations with H.264 or MPEG-4 ASP video codecs. These compression
formats, and many others, store color information at a fraction of the spatial
resolution

In lossy still-image formats such as JPEG [CITE], and nearly every common video
format [CITE],

- Treat color differently, because our eyes are less sensitive

- Chroma subsampling: separate color components from alpha, and sample the
  color grid at a much lower resolution; cuts framebuffer size by ≥75%.
  However, on its own, causes misses to increase; definitely causes
  ineffeciency to increase.

- Chroma undersampling: only calculate chroma for a limited number of points.
  Possibility to leave some points unmapped, must use other methods (mipmapped
  chroma? post-hoc search?) to handle

- Data-dependent probabilistic chroma writeback: reduce number of times chroma
  written in logarithmic proportion to intensity of point. Requires that atomic
  intensity be written first. Doesn't do much good without chroma subsampling.

### Manipulating the cache

- Explicit L2 manipulation using cache instructions and read. By hitting the
  cache with a read over a particular intensity, data can be kept local.

  - Run the math, but I'm doubtful. Depends on image variance.

  - Probably won't have too strong an effect on core image performance.

  - L2 is a latency reducer, not a bandwidth amplifier. Reductions should
    bypass the L1 and may amplify bandwidth, but need to benchmark.

  - Result => may actually reduce bandwidth.

- There was another one?

### Attaining spatial coherence

- Log and sort

  - Log the points linearly. 32 bits for an alpha sample, 64 for color; size
    decreases as addresses get more finely resolved

  - Radix/bucket sort can dispatch efficiently to local lines in shared memory,
    which can be written to global buffers only when fully covered, improving
    efficiency of transactions and bringing them in line with atomics

  - Final accumulation can be done in shared memory, taking advantage of much
    faster atomics therein (bank penalties much smaller than overall crippling)

- A further method will be covered in a later chapter

### Final thoughts

- Best theoretical combination from: (my guess is, chroma subsampling, chroma
  undersampling, log and sort)

- Depends on number of scatter buckets. Probable best bet: heterogeneous
  workloads, using small, continuous, memory-intensive kernel in parallel with
  giant ones

- Done right, this can use shared memory and mostly skip L1, leaving it and the
  texture caches ready to handle the enormous genome structures.

## Motion blur

- Motion blur is used in static flames to give a sense of implied motion.
  Also important for dynamic flames, as few systems can handle H.264
  1080p60 at great bitrates, and 1080p24 is unsatisfying without at least
  some motion blur

- Critically important to the illusion of depth

- flam3 implements motion blur by performing 1,000 interpolations in a
  narrow range around a single time value, and distributing samples across
  this time range in a serial fashion

- For the GPU, this would result in too much memory bandwidth; would lose
  out on the benefit of the constant cache (or L1).

- Solution 1: use fewer motion blur steps; might it give acceptable visual
  approximation?

- Solution 2: use piecewise linear interpolation via the texture hardware.
  If data loads can be vectorized, it's almost free.

- Solution 3: cooperation across SMs to avoid needing to reload too many
  points.

<!-- vim: syntax=pdcf: -->
