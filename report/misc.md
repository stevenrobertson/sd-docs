# Runtime code generation
\label{ch:dynamic}

The diversity of variations available in the flam3 and Apophysis
implementations of the flame algorithm are a boon to fractal flame artists, but
a curse upon implementors. While the selection of variation functions is
somewhat standardized — by the simple expedient of declaring that whatever the
latest version of flam3 supports is the standard — the functions themselves
vary widely, from simple polynomial expressions to those that require thousands
of CPU instructions and as many as ten parameters from the host.

In flam3, this is implemented by use of a cascade of `if`/`else` conditions,
which check whether or not a variation is used and, if so, apply it. Even on
CPU, this is not a terribly efficient way to handle the more than 100
variations; the branch structure requires tens of thousands of unused
instructions from inlined variation functions to be brought into the
instruction cache only to be dumped again thereafter. (A `switch` statement is
more easily recognized by optimizing compilers, and more likely to be turned
into a jump table or other efficient structure.) Nevertheless, the overhead
for this dispatch technique is relatively small compared to the overall
runtime of an iteration on CPU.

On GPU, however, the performance of such a structure is not so much suboptimal
as farcical. This is in some part due to the hardware restrictions inherent in
massively parallel devices; GPUs lack branch predictors, for instance, and the
per-core instruction caches of Fermi GPUs are estimated to be on the order of
64 bytes. [CITE] It is also partly due to a focus on floating-point hardware
in current devices. Instructions in both the load and comparison classes
execute at less than full throughput per clock — comparison being half of full
throughput, load being at most a quarter, and typically much less — meaning
that this conditional cascade, which must be executed billions of times per
frame, would itself require more GPU cycles than all other components of the
iteration kernel combined.

Even without the performance problems that arise from the conditional cascade
itself, a branch-based solution to variation selection will *still* have a
considerable negative impact on performance. GPUs do not perform on-the-fly
instruction reordering, but can dual-issue instructions to shared functional
units in some cases. The compiler performs instruction reordering to allow
dual-issue to occur more often, and will also reorder instructions to reduce
pipeline delays on dependent operations when there are insufficient active
warps to hide pipeline latency. Instruction reordering can't cross basic block
boundaries, however, limiting the impact these techniques could have on the
computationally expensive variation functions. Common subexpression
elimination, where multiple identical idempotent statements are replaced with
a single invocation, similarly cannot cross basic blocks; this can be
particularly costly since many variations use expensive trigonometric routines
like `atan2`.

Additionally, no matter how it is scheduled to run, the mere presence of
variation code within a kernel function is enough to reduce performance. This
is due to CUDA's approach to register allocation. Each Fermi shader core can
allocate a configurable number of registers from the 128KB register file to a
thread. However, the number of registers used must be selected at
compile-time, and must be the same for every thread. With a pipeline depth of
22 cycles, Fermi requires at least that many warps to be ready to run in as
many cycles in order to avoid a stall, and since thread swapping (discussed in
Chapter \ref{ch:funsel}) requires power-of-two block sizes and will regularly
stall blocks for synchronization, avoiding stalls altogether requires 32 warps
of 32 threads per shader core. With this many threads, an even division of the
register file leaves just 32 registers per thread.

Without runtime register count changing, a kernel will use as many registers as
that used in its most heavily-occupied point. Variation invocation occurs in
the center of the inner loop, when the largest number of variables are in
scope. As a result, total register use with the conditional cascade approach to
variation selection is constrained by the register use of the most complex
variation, and this number cannot be reduced by instruction reordering for the
reasons noted above. After porting the full set of variations from `flam3`,
register usage was so high that only half of the needed occupancy was
obtainable.

The problems surrounding the variation functions were of such magnitude that we
elected to pursue an approach which would be otherwise discouraged due to its
complexity: we constructed a system to perform runtime code generation. Rather
than distributing a compiled code object containing the kernels intended for
GPU execeution, we distribute an annotated repository of CUDA code snippets
embedded into our Python library. When a flame is loaded for rendering, its
genome is analyzed to determine which segments of device code are needed. These
segments are gathered and joined into a consistent CUDA `.cu` file, which is
then passed to PyCUDA's caching `nvcc` frontend to obtain a GPU code object in
ELF format that can be loaded by the CUDA driver and copied to the device.

By selecting source code segments at runtime, we can eliminate the conditional
cascade by building separate inlined functions for each xform that include the
exact set of variation functions. We can also remove the conditional guards
around those variations, allowing them to be merged into a single basic block
and optimized more effectively. While this technique adds a considerable amount
of complexity to the host side, the improved performance and flexibility in
device code cannot be obtained otherwise.

While initially considered primarily to solve the variation problem described
above, the runtime code generation system has found use in simplifying or
improving many parts of cuburn's device code. In some cases, these
improvements are small, yielding execution time changes of one or two
percentage points; in others, the flexibility it offers has proved critical to
reaching our performance targets. One such case is the method for
interpolating and accessing control point parameters.

[TODO: review and expand?]

# Function selection
\label{ch:funsel}

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

[TODO: update]

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
  \centering
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
This issue is discussed further in Chapter \ref{ch:accum}.

