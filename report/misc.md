# Dynamic kernel generation
\label{ch:dynamic}

The current version of `flam3` has nearly 100 variations. A transform function
is composed of an initial affine transform, followed by application of each of
the variation functions to the result of the initial affine transform. A
weighted sum is then performed on the results of the variation applications to
get the transformed point.

In `flam3`, a list of those variations with non-zero weights is generated
before iteration begins, and only those variations are computed. This is
implemented in-loop by a very large `if-else` block. Some compilers will
optimize this `if-else` block by turning it into an indirect branch situation,
and most modern CPUs will perform branch prediction to accelerate the
fall-through of this structure.

The current version of NVIDIA's CUDA platform, however, does not fully
implement indirect branching, so a switch statement cannot be used. Direct
branching, even in non-divergent situations, is still expensive; it takes time
to perform instruction fetches and update the scoreboard for each warp after a
branch. With the entire set of variations in place, the single most
computationally expensive component of an iteration for most flames would
actually be this `if-else` cascade.

The transforms aren't the only feature guarded by conditionals. In fact, the
data structure which controls which features are enabled and disabled for a
particular flame can grow to over 64KB in size. Motion blur in `flam3` is
handled by interpolating a default of 1000 control points in a tight temporal
neighborhood around the current frame's timestamp in an animation; these
control structures can easily occupy 64MB of memory on the GPU. At that size,
keeping the relevant parts of a control structure in local cache is unlikely.

The `flam3` iteration loop just has too many options to operate quickly on GPU.
Previous efforts to port the flame algorithm to GPU have all encountered this
problem, although solutions vary: `flam4CUDA` and Fractron 9000 simply omit
parts of the algorithm which are required for full compatibility, whereas
`flam4OCL` attempts to construct the source of a kernel which is tuned for the
flame at hand.

This project requires full `flam3` compatibility and high performance; the
often-disabled parts of the algorithm cannot be omitted, but the performance
hit from having dead code in a kernel cannot be ignored. Dynamic creation of a
rendering kernel seems the most promising option.

## Just-in-time compilation

A profusion of rarely-enabled legacy code, experimental hacks, compatibility
tweaks, and alternate approaches — a result of more than a decade of
enthusiastic participation by the fractal flame community — complicates and
slows rendering. Fortunately, between environment configuration and the genomes
themselves, it is possible to detect these features' presence before rendering
begins.

Animations in `flam3` are composed from sequences of *loops* and *edges*. A
loop is a frame sequence where a subset of the parameters are rotated over
time, returning to their original values at the end of the rotation. Edges are
rendered by interpolating every parameter between two visually distinct flames.
The desired effect of an edge is a slow morphing from one shape to another.

The interpolation functions exported by the `flam3` library provide several
guarantees about which features will be enabled in one of these kinds of
animations. While some parameters, such as image size and filter support width,
require special handling, the general rule is that every frame of an animiation
will use exactly the union of the sets of features used by both end-points. If
instead of providing a rendering kernel with the host code, a template for
producing a kernel is provided, an example control point taken from near the
center of an interpolated sequence can be used to to tune the templated code
and produce a kernel optimized for every frame in the animation.

The task of compiling such a kernel is not as complex as it may sound. To make
it possible for new GPU designers to enter a market with devices capable of
running existing software, and for established manufacturers to produce new
hardware without needing to support their own legacy instruction set
architectures, OpenGL requires that shaders be shipped in the same C-like
syntax in which they are typically written and compiled on the host system.
OpenCL preserves this requirement for its more general kernels. This has led to
the inclusion of extremely fast, high-quality compilers within major GPU
manufacturers' drivers.

CUDA's model is somewhat different. Because CUDA kernels can take advantage of
certain C++ features, a small and fast compiler is much harder to obtain. As a
result, CUDA kernels are stored in PTX, a RISC-like intermediate language, and
assembled for the target architecture on the host. This has the advantages of
being faster than OpenCL's subset of C to compile, and offering additional
hardware control; however, because it is very low-level, it is difficult to
write large amounts of code directly in PTX.

In either case, the compiler and assembler is located on the client system with
a simple, standard API; there is no need to include a development environment
with the resulting binary or write our own assembler.

## Dynamic code, static types

Both OpenCL and CUDA provide mechanisms for loading dynamically-generated code,
which is used to exclude unused features from the final kernel. On its own,
however, this does not exclude unused data from the control point structure;
this information will still be sparsely distributed throughout the control
point, spread over many additional cache lines, and is thus more likely both to
evict needed data and be evicted itself.

To use cache lines more efficiently and avoid costly misses, the data may be
packed according to the pattern of its use. For dynamically generated code, a
simple means of doing this is to use a stack-like structure, where a pointer
advances or rewinds in a memory region with code flow, and each block of code
carries the total size of its data so that it may properly reset the pointer at
entrance and exit points.

This mechanism works well for small dynamically-generated systems, but is
challenging for larger ones: The host logic which packs the stack must be kept
precisely in line with the control flow of the device code, and since the
contents of the stack can affect program flow, any bugs on the device which
result in mis-positioning of the stack pointer can be exceptionally hard to
isolate. Therefore, fixed address offsets into the stack are preferred. This
simplifies debugging on the device and adds reliability, but still requires
that the front-end follow the flow of device code.

Instead of attempting to replicate the control flow of the templated code
following feature analysis, it would be more efficient to combine both stages;
have the information needed to perform memory packing on the host in the same
location within the program source as the description of the device-side
operations to load it. Shard was written to provide this ability.

Shard is an embedded domain-specific language for the dynamic creation of GPGPU
programs, written in Haskell. As an EDSL, Shard uses native language syntax to
record operations rather than perform them. Consider the statement `y = 4
* x + 1`. If `x` is a number, this statement  would instruct the Haskell
compiler to emit code that stores the value of $4\cdot x + 1$ in the memory
reserved for variable `y`. As a Shard variable, however, this statement
instructs the compiler to store a data structure representing the calculation
in `y`, which can itself then be used as another Shard variable. In this way,
each new expression adds to a tree of operations that can later be evaluated to
produce device code.

Shard includes expressions that assist with dynamic memory management. A
`loadHost` statement in Shard takes a base pointer and a host-side expression
which returns a value. When the Shard data structure is evaluated, all such
statements are analyzed to determine the offsets of each value in the stack, so
that the actual code emitted on the device contains the appropriate offset. To
pack the stack for use on the GPU, each host-side expression is applied to the
corresponding data structure automatically. Because the host and device
commands are contained in the same expression, Shard eliminates the risk of
code drift between memory packing and loading.

Haskell's strong static typing provides additional guarantees on the
correctness of this approach. In many languages, the two arguments of the
`loadHost` function would be indistinguishable from one another and from any
invocation. Shard uses phantom types to avoid this; the base pointer, closure,
and function result must all be consistent. Despite representing a primitive on
the device, the result of this expression preserves its type from the host
code, so that a program will refuse to compile even if two values with
different meanings but the same OpenCL or CUDA type are used together. This
checking happens entirely at compile-time, and carries no run-time overhead.

## Testing — or lack thereof

Haskell's type system is not limited to ensuring variables are not erroneously
switched; it can provide deeper guarantees of code correctness and
interchangeability.

Because the number of independent selectively-enabled code segments required
for a full implementation of `flam3` is so large, it is effectively impossible
to test even a fraction of every permutation of features. This enormous
parameter space compounds the similarly massive parameter space of the genomes
themselves.

When it is not possible to fully cover code with holistic tests, unit testing
is often used, wherein each component is exercised separately, and to use
strict modularity to ensure that side effects from function calls are
contained. However, this modularity is expensive, particularly on GPUs, and
would preclude certain optimizations that are not localized to particular
regions of code. Without guarantees of modularity, unit testing cannot discover
the insidious bugs arising from interactions between different combinations of
parameters.

For this reason, Shard requires explicit and granular denotation of impure code
in function type signatures. Certain operations which have side effects — that
is, have the potential to modify the operating environment of the device — have
their return types wrapped in such a way that the results can only be accessed
inside of functions that are themselves similarly wrapped. Because this is
embedded in the type system, these checks are evaluated at compile-time,
meaning that it is enforced in all code that has the potential to be enabled on
the device. This prevents hidden interactions against shared state for all
permutations of the rendering kernel without having to test them discretely.

This renderer is designed to hew closely to `flam3`'s visual output. To provide
a holistic test, a selection of flames are rendered on CPU and GPU and
compared; if no significant deviations are encountered, the code is working as
expected. It is reasonable to attain complete code coverage in this way,
wherein every segment of device code is exercised at least once. Such testing
cannot provide assurances on hidden interaction errors, however, and is no
subsitute for strong type safety.

[TODO: shore this up, could use a bit stronger of a conclusion]


# Function selection

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

## Divergence is bad, so convergence is... worse?

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

It is therefore not necessary to ensure that every instance of the system under
simulation receive an entirely independent sequence of transforms; rather, it
is sufficient to limit the expected frequency of identical transform
subsequences across threads. Fortunately, there's a simple and computationally
efficient way to do this while retaining non-divergent transform application
across warps — simply swap points between different warps after each iteration.

## Doing the twist (in hardware)

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

[FIG: could get some nice diagrams of the shuffle process]

## Shift amounts and sequence lengths

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

# Accumulating results

The simplest transform functions can be expressed in a handful of instructions;
with careful design of fixed loop components, many common flames may require an
average considerably less than 50 instructions per iteration. Single-GPU cards
in the current hardware generation can retire more than $750\cdot 10^{9}$
instructions per second[^FMA] [@Voicu2010]; it's not unreasonable to expect
normal consumer hardware to be able to calculate more than 15 billion IFS
samples in a single second.  Each of these samples needs to make it from a core
to the accumulation buffer.  Can the memory subsystem keep up?

[^FMA]: The FLOPs figures commonly cited by graphics manufacturers are twice
this value, as they count multiplies and adds as separate operations in an FMA.

Each element in a typical CPU implementation's accumulation buffer is 16 bytes
wide, holding one single-precision floating point value representing density
and three representing the unscaled sums of the red, green, and blue color
values for the points within that accumulator's sampling region. With full
utilization of the 150 GB/s or so of global memory bandwidth in current-gen
hardware, one device may be expected to perform about 5 billion of the 16-byte
read-modify-write cycles required to accumulate a sample.

A three-fold drop in performance due to memory limitations is easy to accept
for an offline renderer. In fact, such a limitation might simplify the entire
project; an externally-imposed performance cap would limit the need for more
complex optimizations and provide a concrete stopping place for ongoing
optimization efforts. Unfortunately, the iteration rate limit imposed by
accumulation speed is far more severe than the 3× penalty implied by the raw
bandwidth.

## Chaos, coalescing, and cache

The flame algorithm, and the chaos game in general, estimates the shape of an
attractor by accumulating point information across many iterations. While
visually interesting flames have well-defined attractors, the trajectory of a
point traversing an attractor is chaotic, jumping across the image in a manner
that varies greatly depending on the starting state of its thread. As a result,
there is little colocation of accumulator addresses in a thread's access
pattern over time. Spatial coherence is also unattainable, due to the need to
avoid warp convergence discussed in the previous section.

Each accumulation, therefore, is to an effectively random address. While the
energy density across an image is not uniformly distributed, most flames spread
energy over a considerable portion of the output region [TODO: insert variance
statistics]. Accumulation buffers can be quite large; for a 1080p image
rendered using 2× supersampling, the framebuffer is over 100MB[^fbsize]. This
access pattern would challenge even traditional CPU caches, which tend to be
spacious and include advanced prefetching components; it renders the small,
simple caches found in GPUs useless.

[^fbsize]: $(1920 \cdot 1080) \, \text{accumulators} \cdot 2^2 \,
\text{accumulators}/\text{sample} \cdot 16 \, \text{bytes}/\text{accumulator} =
132710400 \, \text{bytes}$

With each cache miss, a GPU reads in an entire cache line; each dirty cache
line is also flushed to RAM as a unit. In the Fermi architecture, cache lines
are 128 bytes. If nearly every access to an accumulator results in a miss, then
the actual amount of bus traffic caused by one accumulation is effectively
eight times higher than the accumulator size suggests — and consequently, the
peak rate of accumulation is eight times lower.

To make matters worse, DRAM modules only perform at rated speeds when reading
or writing contiguously. There is a latency penalty for switching the active
row in DRAM, as must be done before most operations in a random access pattern.
This penalty is negligible for sustained transfers, but is a considerable
portion of the time required to complete a small transaction; when applied to
every transaction, attainable memory throughput drops as much as 50% [@elpida].

A 3× performance penalty may be accepted; a 30× penalty *must* be addressed to
meet this project's stated performance goals. An improvement of more than an
order of magnitude, however, is rarely trivial, and no single solution will
remove this bottleneck entirely. Over the course of this chapter, several
improvements will be introduced, each providing incrementally higher memory
performance at the cost of increasing complexity. In concert, these techniques
form an accumulation stage that, while arcane, is fast enough to keep up with
iteration.

## Tiled accumulation

The most immediate problem in the writeback stage is that of a cache miss,
which will happen often due to the random distribution of write locations and
the poor fit of the accumulation buffer into the L2 cache. Little can be done
about the write patterns without fundamentally restructuring the flame
algorithm[^newappr], suggesting that it is the cache fit which should be
optimized.

[^newappr]: The authors intend to explore such a restructuring after the
initial rendering is built.

This is not a novel problem. Implementations of the Reyes algorithm for
ray-tracing, such as Pixar's RenderMan, handle limited cache sizes by splitting
the global geometry in a scene along the boundaries of small rectangular
regions that tile the destination framebuffer; the contents of each tile are
then drawn separately and discarded, allowing the information in a single image
area to remain in the cache [@Cook1987]. A similar technique is employed by
graphics chips designed for low-power applications, such as those in the
PowerVR architecture [@PowerVR2009].

As accumulations cannot be bounded *a priori* in the flame algorithm, any
tile-based approach must be implemented after the iteration step, splitting
accumulation information across the entire image domain into discrete queues
for each tile. The mechanics of the queue system depend on several
implementation choices; to avoid ambiguity, it will be described after the
techniques on which it depends.

### Representing an iteration

An accumulation requires adding a density and three color values to an
accumulator located on a two-dimensional grid. Representing this information as
a six-dimensional tuple using floating point values requires 24 bytes. Queueing
the image information for rendering requires reading and writing it multiple
times. If each value consumes 24 bytes of memory, the implementation will
encounter space and bandwidth limitations; encoding this information more
efficiently is desirable.

The accumulator is identified along a rectangularly-sampled 2D grid. In this
arrangement, there is an isomorphic map between image regions and accumulator
indices, so representing the location in intermediate stages by accumulator
index loses no information as compared to normal accumulation. Use of an
integer format for representing location is also useful. Typically, flames are
rendered using resolution and supersampling settings which require a number of
accumulators less than $2^{24}$, indicating that the index can be fully
represented as a 24-bit integer.

The color values in an IFS accumulation are calculated from the IFS color
coordinate by performing a linear blending between the two closest samples of
the active control point's color palette, followed by a multiplication against
the transform visibility. Storing this information, rather than the results of
this calculation, can lead to additional savings. A typical flame uses 1000
control points to produce motion blur, so a palette index can fit in a 10-bit
integer. Both the color coordinate and the visibility transform are bounded on
$[0, 1]$, so a fixed-point representation can achieve a full-precision
representation with 22 bits per coordinate.

Together, this results in a total of 78 bits of information. On an architecture
designed entirely around 32-bit word sizes, this size is awkward and
ineffecient. Fortunately, this algorithm is a Monte Carlo simulation with a
very high sample count; since all samples in a given image region are averaged,
sample contributes relatively small amounts of information to the final image.
Thus, considerably smaller intermediate representations are possible without
loss of detail — but only if dithering is used to avoid quantization bias.

### Dithering

\newcommand{\flo}[1]{\lfloor #1 \rfloor}
\newcommand{\ceil}[1]{\lceil #1 \rceil}

Consider a two-entry color palette, where the tristimulus value at index $0$ is
$C(0) = (0, 0, 0)$, and at index $1$ is $C(1) = (1, 1, 1)$. With linear
blending, a lookup for an arbitrary value takes the form
$C_l(i)=P(\flo{i})\cdot (\ceil{i}-i)+C(\ceil{i})\cdot (i-\flo{i})$, such that
$C_l(0.4)=C(0)\cdot 0.6 + C(1) \cdot 0.4$. The average value of a number of
linearly-blended lookups with $i=0.4$ would then be $(0.4,0.4,0.4)$.  On the
other hand, if the index was first truncated to integer coordinates, the
average value of any number of samples would be $C_l(\flo{0.4})=C_l(0)$, or
$(0,0,0)$. Many flames use automatically-generated palettes which feature
violent color changes between coordinates, so such truncation can result in a
substantial amount of error.

Dithering applies noise to signal components before quantization to distribute
quantization error across samples, enabling more accurate recovery of average
values [@Furht2008]. For the fixed quantization of the IFS color coordinate,
dithering is accomplished by adding a value sampled from a uniform distribution
covering the range of input values which are quantized to $0$ — for integer
truncation, this is $[0, 1)$, whereas round-to-nearest-integer would use
$[-0.5,0.5)$ — to the floating-point color sample before quantization.

To continue the example, dithering the index value $i=0.4$ before integer
truncation would provide an expected value uniformly distributed in the range
$[0.4, 1.4)$. Over many samples, this value would be expected to be quantized
to a value of $0$ as $P(i_q\le 1)=0.6$, and $1$ as $P(i_q>1)=0.4$. Applying
those values to the palette lookup functions, we have $C(i_q)=C(0)\cdot
P(i_q\le 1) + C(1)\cdot P(i_q > 1)=C_l(i)$, so that over many samples the added
noise has actually eliminated the quantization error in the average.

A flame's palette contains 256 color samples. Linear blending occurs between
palette samples, but no such guarantee exists from sample to sample; as a
result, subsampling the palette would result in aliasing, even when dithering
is applied. The minimum size of the color index component, therefore, is 8
bits. This offers a potent optimization: if the information in the other
coordinates can be transmitted without adding additional bits to a logged
point, the log of each point can fit in a single 32-bit word. As it turns out,
side channels exist for both control point time and visibility.

Each work-group conducts all iterations required to complete a time step before
moving on to the next in order to keep control point data in cache.  Because
most work-groups will proceed at approximately the same pace, a single global
counter indicating the current control point can be shared across all
work-groups. Across the narrow time range of a single animation frame, the
variation of a palette is typically imperceptible, so this approximation is
acceptable.

As for visibility information, there is another channel from which an
additional bit can be extracted: whether or not the point is written to a
queue. Discarding half of the points that were computed to provide an accurate
long-run density intuitively seems much more severe than discarding half of the
bits to recover an accurate density value, yet the principles are the same;
dithering works just as well with one bit as with eight. There are pathological
cases in which this technique could result in additional shot noise in dark
image regions, but this can be solved by simply increasing the number of
iterations on such images, and is in any case unlikely to appear in practice.

### Reducing accumulator size

Even at a mere 32 bits per sample, queueing every sample of a high resolution
flame would exhaust a GPU's memory[^queuesize]. Periodically, the queue for
each tile must be flushed to the accumulators, involving at least one write for
every sample in the tile. Reducing the size of an accumulator increases the
number of samples that can fit inside a single tile, thus requiring fewer
tiles. This leaves more space for each tile queue, allowing more points to be
processed per flush.

[^queuesize]: $(1920 \cdot 1080) \, \text{pixels} \cdot 2000 \,
\text{samples}/\text{pixel} \cdot 4 \, \text{bytes}/\text{sample} = 16588800000
\, \text{bytes}$

#### Color subsampling

Most rendered flames are compressed with the JPEG image codec or
the H.264 video codec. These codecs, and many others, reduce the
size of transmitted frames by sampling image channels containing color
information at a lower spatial resolution than the luminosity channel, and by
quantizing the subsampled result more severely [@JPEGSpec]. That these codecs
do so without objectionable degradation of the image is evidence of the human
visual system's reduced sensitivity to perception of color, as compared to
brightness. Since most of the color information in the accumulation buffer is
discarded before ever reaching the user, subsampling color during the
accumulation stage reduces the size of the accumulator with little or no loss
in visual quality.

In video and image applications, RGB tristimulus values are first transformed
to the YUV colorspace[^yuv] via a simple matrix multiplication. The resulting
value separates luminosity information, in the Y component, from the
chromaticity information in the other two components. It is the latter two
components which are subsampled in the resulting image. However, due to
transform color selection and the behavior of the density-based log scaler, the
luminance component of the resulting image will display very strong correlation
with density values. As a result, this implementation will subsample all three
components in the accumulation process, exploiting redundant information in the
density buffer to perform accurate reconstruction.

[^yuv]: YUV is more accurately described as a "hodgepodge of ideas" than a
colorspace. We refer here to linear, invertible, continuous, full-range
encodings such as $YC_BC_R$.

Sampling image components at different spatial frequencies breaks the
isomorphism between the image-space coordinate grid and buffer element
coordinates, requiring more complicated addressing schemes. In most systems
which use channel subsampling, the components are interleaved so that the
values for any image-space coordinate are contained within the same cache line
(regardless of system). On the other hand, interleaving complicates addressing,
requiring rearrangement in two dimensions according to a predetermined pattern.
This restricts the set of subsampling ratios which are valid, and makes certain
filtering operations less efficient.

Because we are explicitly targeting a system which will keep all data being
accessed for accumulation in cache, there is no significant benefit to having
all image components share a cache line, and we are free to choose a simpler
solution. One such solution is to simply store each image component, or set of
image components, with a unique sampling rate in a separate plane. Assuming an
efficient data alignment exists, this scheme uses no more memory than an
interleaved format, and retains the benefits of linear addressing.

#### Efficient representation

The log-scaling process performed to compress the high-dynamic-range flame into
the display image's dynamic range is explicitly designed to remove the
information in the lower bits of each image sample. In nearly every case, the
final display format of fractal flames is an image format using 8 bits for each
of its three channels for 24 bits total; in most cases, the intermediate
subsampled encoding represents flames with 12 bits per pixel before
compression. At 128 bits per sample, traditional accumulators store more than
ten times as much information as the final image.

A problem confounding the selection of intermediate encodings is the need to
store a large dynamic range. Images with high sample counts, aggressive gamma
curves, and very small image features can require accumulators to store
thousands or millions of points, requiring excessively large fixed-point and
integer representations. The solution to such a problem is often to use
floating-point numbers, which is what has been done previously.

Modern GPUs are optimized to work quickly with standard single-precision
floating-point numbers, and they serve as an excellent compromise between speed
and precision during calculation. When storing accumulators, however, the
exceptionally high cost of a cache miss makes footprint reduction worth using
slower, more complicated instructions. For such purposes, GPUs include support
for converting to and from IEEE 754 half-precision floating-point formats.
Unfortunately, support for these 16-bit values is missing from the atomic
instruction set; flushing a tile would require performing read-modify-write
over the inter-chip bus, which would cause it to flood [^icbw].

[^icbw]: Fermi's L2 provides low-latency acceleration of instructions, but does
not provide significant bandwidth amplification over global memory;
microbenchmarks pin it at less than twice the bandwidth of the memory it
covers. On-core RMW cycles to global memory require an immediate transfer and
invalidation of lines in L1, making the transactional efficiency even lower
than for an L2 miss, so we hit the ceiling at about the same rate.

Due to extreme cache pressure and a limited number of atomic instructions, the
most efficient solution which accomodates the large dynamic range of
intermediate image formats in the minimum number of bits is the implementation
of a software floating-point format. Density information is used differently
from color information, and is expected to be sampled differently as well. As a
result, we use different representations for these two values.

The 32-bit datapath of a GPU makes using values which fit evenly into that
width. Since the density value scales all channels in the output image, at
least 8 bits of precision are required. Only widths of 10 and 16 bits possess
enough space for an 8 bit mantissa while dividing evenly into a word. Typical
flame images will easily exhaust the upper bound of a two-bit mantissa[^man10],
so we consider a width of 16 bits as the minimum choice for independent storage
of density information. Within these 16 bits, a five bit mantissa is the
smallest value providing comfortable headroom.

[^man10]: $2^8\cdot2^{2^2}=4096$. Adding another bit to the mantissa provides a
heartier range of $2^7\cdot2^{2^3}=32768$, but this is not enough to be
generally applicable.

\addfontfeatures{Numbers=Lining}

\newcommand{\hex}[1]{\text{#1}_{\text{h}}}

Apart from the missing sign bit, this floating point format differs from
standard IEEE 754.2008 half-precision floats in one important respect: the
exponent bias is set at $\hex{-01}$, rather than $\hex{0F}$. Subnormal numbers
are therefore represented by the exponent $\hex{1F}$, where the exponent is
treated as if it is also represented in two's complement. This notational
difference implies that a string of zero bits does not represent a value of
zero, which is inconvenient. The extra effort is justified by an extremely
simple addition algorithm.

To add a value to a memory location, first read the exponent value as $E$.
Multiply the addend by $2^{-(E+1)}$, and round to the nearest integer using
dithering. Finally, perform an atomic addition to the value in global memory.
[FIG of the addition algorithm, maybe?]

\addfontfeatures{Numbers=OldStyle}

This algorithm can be implemented in as few as ten operations, including the
generation of a random number for the purposes of dithering. Two of those
operations may require access to memory — the initial exponent read,
followed by the actual addition — and both of these would require access to
atomic units.

[TODO: finish the rest of this]

<!--

Everything below is commented for page count reasons, in case I have
to drop the rest of this section in the middle to finish the required sections.

### Quick review of radix sorting

- Brief review of MSB first radix sort:

  - Radix of size R. For binary numbers, want power of two; use N bits, so
    $R=2^N$.

  - Create R empty buckets, indexed from 0 to R-1.

  - For each value, examine the largest radix (mask and shift to look at the
    top N bits); call this I. Choose the bucket with index I, and append the
    value to that bucket.

  - After all values accumulated, repeat process on each bucket by itself with
    the next radix.

- Radix sort is not comparison sort; we can beat the number of comparisons
  required.

### Efficient sort of point log

- To write efficiently, want to avoid read-modify-write and not waste any
  bytes; therefore, work to only write complete cache lines.

- For each bucket, set up a single cache-line's worth of shared memory, and an
  index in main memory

  - Each thread loads a sample, pulls the radix, and identifies the
    corresponding bucket index

  - Atomically add to the index

  - If the modified index is less than the line length, write the point. If
    it's greater, don't. If it's equal, flag overflow.

  - Overflow detect loop

    - Perform a hack warp vote. Clear a shared memory location, then have every
      thread which flagged overflow write its index to it.

    - If it's empty, exit this loop.

    - If not, every thread in the warp picks up the cache line and writes it
      together. Presto, serial write.

    - If offset >= line length, overflow index == index, and line length >= 0,
      write out point to appropriate line. Clear offset.

    - Loop.

- We choose a radix size of 7. As discussed later, the shared-memory
  accumulation process N+3 bits of address.  With a radix of 6, an extra pass
is required to finish sorting; a radix size of 8 uses too much shared memory
and won't fit on the GPU. For N=7, 16KB are required for the radix sort buffer.

### Iterating and sorting

- This algorithm requires frequent synchronization across all participating
  threads, and storage space in proportion to the number of threads.  It works
best in a single warp.

- There is no explicit cross-work-group synchronization primitive, so
  producer-consumer queues are incredibly challenging.

- Therefore, we want to attach one warp of this to a work-group of iterating
  threads, and use work-group barriers to ensure things stay synchronized.

- Here's how it goes:

  - On start, the sort warp immediately goes to the sort barrier, and the
    iterating threads move through an iteration.

  - After completing the iteration and swap, the iterands compact the point
    into the 32-bit sortable index and store it in the swap buffer.

  - Iterands hit sort barrier, which is now full; all threads now free to run

  - Sort warp reads a line of samples to sort from the swap buffer, and
    executes Algorithm N.1

  - After sort warp is finished with swap buffer, it hits swap barrier, and
    waits for iterands

  - Meanwhile, iterands are performing an iteration. When they finish, they hit
    the swap buffer, and wait for sort warp

  - After both arrive, swapping starts, and process repeats

- This interleaved producer/consumer model prevents starvation with very little
  overhead on synchronization.

- It also provides firm bounds on work-group sizes. Radix of N=7 means 16KB
  radix sort buffer. We desire the largest size work-group attainable. The swap
buffer is proportional to the number of iterands. On Fermi, with 48KB
available, we can fit two radix buffers, but not three - there's overhead, plus
the swap buffers. Fermi only supports 1536 threads per core; across two, that's
768 per. Since we want a power-of-two size for the number of iterands, it's
512. Add in the sort warp and it's 544 threads per work-group.

-->

<!-- vim: syntax=pdcf: -->
