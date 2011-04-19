# Other implementation challenges

This chapter has some miscellaneous stuff which probably needs to make it
into the report, but may or may not need its own chapter.

## Variations

- More than 100 variations in `flam3`

- Indirect branching still not implemented in Fermi; enormous and very slow
  fall-through

- Data structure is more than 8K in size... for each xform. With 1000 control
  poins per frame, this is very hard to keep in cache

- Can we optimize this?

### Feature detection

- Xforms only use a few variations

- Set of variations in use across a single edge or loop in an animation do not
  change from one control point to the next

- Many other parts of the flame algorithm are only used on rare occasions

- Without branch predictors and large caches, a streamlined implementation of
  the flame algorihm implementing only the features used in a particular flame
would have quite an edge over a generic, full-featured version

### Just-in-time compilation

- Do feature detection on example of genome to determine the features required

- Run the feature set through a process which turns out three things:

    - A pile of code, ready to be compiled for the target

    - A definition of the data structure which will be read by the target, that
      will be used to pack this data

    - Resource allocations and other sizing info required by the code

- Easy enough, right?

### Template OpenCL

- The only way we've seen this done is to spit out C code that's handled by
  OpenCL

- This doesn't scale to an implementation as complex and data-dependent as this
  one

    - Can't even verify that different bits of code which are intended to do a
      particular thing will compile when swapped for another such block of code

    - Side effects, loops, etc become exceedingly difficult to track

    - Easy to fuzz variables (e.g. incorrectly cast void-typed pointers)

    - Info on how to pack the data for the target kept separate from the code,
      and many potential screwups there too

### Haskell EDSL

- Haskell offers a better way: use an EDSL

- Code for device is expressed as statements that "feel" native; i.e. 1+1

- Underneath, x+y actually composes a representation of the operation rather
  than computing the result; the native Haskell value is something like ...

- Side effects such as memory loads and stores must be explicitly demarcated
  and propagate up, so that they are never hidden

- Newtype wrappers distinguish between values that have the same run-time
  representation but different meanings, without any run-time overhead

- Dynamic code packer: simply provide the accessor used to read the data value
  against a suspended representation of the runtime data, and it gets replaced
on the host with a function to pack the data and on the device with aligned
load instructions

- All of this is enforced at the type level. The corner cases that could plague
  an all-ifdef system will be caught by the compiler with an error, not in the
field with a crash

### Testing and benchmarking

- GPU testing is generally awful. Multithreadedness means that debugging
  statements will often make problems disappear, getting into or out of a
particular state is difficult, test harnesses can be as complicated as entire
programs

- Haskell's type system is so good, "if it compiles, it's almost certainly
  correct" [CITE]

- Our testing plan is, whenever possible, avoid needing to test. Use the type
  system to prevent bugs.

- Where that fails, use optimization to test

    - Throughout this document, we offer alternative implementation strategies
      for performance reasons

    - Many of these should behave identically

    - Simply keep even older, suboptimal code in the system, and compare
      results when swapping out different segments of code

- More subtle bugs, and those affecting all implementations, can be caught by
  comparing against `flam3` reference images

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

[FIG: could get some nice diagrams of the shuffle process]

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

## Accumulating results

The simplest transform functions can be expressed in a handful of instructions;
with careful design of fixed loop components, many common flames may require an
average considerably less than 50 instructions per iteration. Single-GPU cards
in the current hardware generation can retire more than $750\cdot 10^{9}$
instructions per second[^FMA] [CITE] [TODO: I'm thinking about the GTX 560 Ti
OC'd to 1GHz here; should that be specified here and below?]; it's not
unreasonable to expect normal consumer hardware to be able to calculate more
than 15 billion IFS samples in a single second.  Each of these samples needs to
make it from a core to the accumulation buffer.  Can the memory subsystem keep
up?

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

### Chaos and coalescing

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

[^fbsize]: $(1920 \cdot 1080) \text{accumulators} \cdot 2^2
\text{accumulators}/\text{sample} \cdot 16 \text{bytes}/\text{accumulator} =
132710400 bytes$

[TODO: verify eqn renders properly]

With each cache miss, a GPU reads in an entire cache line; each dirty cache
line is also flushed to RAM as a unit [TODO: verify on Fermi]. In the Fermi
[TODO: and Cayman?] architecture, cache lines are 128 bytes. If nearly every
access to an accumulator results in a miss, then the actual amount of bus
traffic caused by one accumulation is effectively eight times higher than the
accumulator size suggests — and consequently, the peak rate of accumulation is
eight times lower.

To make matters worse, DRAM modules only perform at rated speeds when reading
or writing contiguously. There is a latency penalty for switching the active
row in DRAM, as must be done before most operations in a random access pattern.
This penalty is negligible for sustained transfers, but is a considerable
portion of the time required to complete a small transaction; when applied to
every transaction, attainable memory throughput drops by more than 20% [CITE
GDDR5 spec] [CHECK I pulled this number out of thin air].

A 3× penalty may be acceptable, but one of more than 30× cannot be overlooked.
Meeting this project's performance goals will require finding
higher-performance alternatives to the traditional accumulation method.

### Taking advantage of L2

In many situations, the level-2 cache on Fermi GPUs is large and fast enough to
accelerate random access patterns, with no specific development effort required
to attain reasonable performance. This is not the case for the flame algorithm;
the buffers involved are simply too large relative to the cache to make it
likely that the next accumulator will already be in L2.

If accesses to L2 did result in a cache hit in the majority of cases, it would
improve accumulation speed, reducing the bottleneck or eliminating it entirely.
To that end, techniques which can increase the chance of this are presented
below. In general, any algorithm depending on the availability of cached data
will not scale, even with these tricks; increasing the framebuffer size beyond
a certain threshold will cause significant loss of performance.

#### Color subsampling

As discussed in previous sections [REF or drop], human vision has considerably
less sensitivity and spatial resolution for color than for luminance. In
existing implementations of the flame algorithm, however, color is given three
times the storage space of density information in the accumulator. Since still
images are typically compressed with JPEG, and animations with H.264 or MPEG-4
ASP, most of this information never makes it to the viewer; each of these
codecs downsamples color information before transforming and applies more
aggressive quantization to increase compression efficiency. Applying similar
techniques during rendering could reduce the size of the accumulation buffer,
allowing a larger proportion of it to remain cached.

In most video transmission systems, RGB tristimulus values are encoded to
YUV[^yuv] via an invertible transform. The Y channel encodes the luminance
value of the image sample, while the remaining two channels store the
information needed to distinguish between multiple colors. YUV encodings are
linear and time-invariant, and so behave like RGB under addition;
pre-converting color values in the palette to YUV and post-converting back to
RGB would provide the same data (apart from rounding error) as unconverted
accumulation.

- In flame algorithm, "density" and "color"; color != chrominance

- In YUV, Y contains most visual and nonredundant information

- In DYUV, D contains more information than averaged Y, much more than averaged
  UV in most images

- Schemes that subsample YUV and just UV should be considered

- Place subsampled channels in separate planes. On its own, not a great
  solution

- Interleave channels in larger units. Pros and cons

#### Color discard

- On principle that color is averaged, and subsequent color samples are less
  important, make recording the color probabilistic

- Based on color density; points with a lot of color samples don't need more

- Or simply based on an overall scale; will leave some points undercovered but
  that's what filtering is for

- In this case, makes sense to separate planes into density-only and a second
  color-only DRGB / DYUV

- Density can fit as 4 bytes per accumulator, to efficiently fill the space

- We can do better

#### Compact fixed-point representation

- Limited by what atomics can support

- Range much smaller than full range given by single-precision floating point.
  32-bit fixed-point is more than capable of handling it

- Most of the 32-bit number is never touched; waste of cache

- Two accumulation buffers. One holds full 32-bit values, either float or
  fixed-point; the other holds small fixed-point values, tightly packed

- Add to a fixed-point value. When it overflows, add its contents to the real
  accumulation buffer. (Plus a final pass through at the end to collect any
  remaining values)

- Problem: GPU atomics only work on 32-bit integers or floats

- Use atomic adds with the addend shifted to the appropriate place within a
  32-bit field, and test for overflow manually

- When it happens, issue a sub to clear the current state of that individual
  slice (and the overflow from the one above), then add to the full buffer

- This works even if intermediate instructions write to the same pixel; only
  one thread will detect the overflow, and the subtract won't affect any data
  written while preparing to fix overflow

- Only special case is when a value and the one above it in the same dword
  are about to overflow, the overflow catches both locations, *and* an
  instruction writes to the higher value before the lower one can be adjusted

- Will implement a trap for this in debugging mode to see if it happens often
  enough to require handling in normal code

- What vword size to use? Must fit into 32-bit dword. Useful choices seem to be
  16-bit x 2, 10 bit x 3 (also useful as it has overflow bits which eliminate
  the weird special case above), 8 bit x 4, 6 bit x 5, 5 bit x 6, 4 bit x 8

- Asymmetrical packing an option too, although that may be too complex

- Tradeoff: more compact code requires more oveflow spills. Overflow spills are
  reductions, and typically won't stall a warp, so no special divergence
  protection needed, but still, savings/bandwidth ratio must be considered.

#### Dithering

- Most flames use visibility values of 1.0 or 0.0 for all xforms, letting us
  use 0 bits after decimal in density

- Rounding an intermediate visibility would result in a substantial bias. Just
  as true for color.

- When quantizing these components, use dithering. At each write, round up if a
  random number is smaller than the bits being chopped off.

- Over many rounds, same result as floating accumulation

#### Combining techniques

Color subsampling reduces the size of the color buffer. Color discard ensures
that the color buffer doesn't need to be kept in the cache. Fixed-point storage
shrinks both density and color buffers, and dithering makes sure it doesn't
trash image quality.

With these combined, the most frequently-accessed information can be stored in
as little as 4 bits per pixel. At 4BPP, the entire density information of an
unsupersampled 1280x720 image fits in L2, and a good deal of a 1080P one too.

A lot of parameters in this one; no substitute for experimentation.

Also, it doesn't scale. We'd like an approach that does, for turning on SS and
rendering very large images. The big images need it most.

### Acheiving spatial locality

- The only truly scalable techniques can't depend on the cache; must use
  bandwidth more efficiently

- Can't attain spatial or temporal locality in access pattern to accumulators.
  There is a way, though: don't write straight to accumulators, sort first.

- Seems unlikely, no? Indeed, a comparison sort would almost certainly be too
  slow. But we don't need a generalized sort; we can optimize in certain ways.

#### Logging a point

- What exactly are we sorting?

- Info required: accumulator address and color to log. In floating values,
  that's 24 bytes; ick.

- How are color values determined? Palette index and temporal position.

    - Palette changes very slowly across time; only need a few bits to fully
      specify temporal position, and dithering should be fine

    - Palette uses linear blending between elements, but not across whole
      palette; 8 bits minimum with dithering

    - Visibility also affects palette values when present. Absolute dithering
      works, but only with very large numbers of samples; better to dither a
visibility value

- In the best case, where all visibilities are binary and the palette is nearly
  stationary across time, can represent color with 8-bit dithered address with
  deferred tex lookup.

- If temporal palette address and/or visibility are required, bump that up to a
  16-bit color address. (Less is probably OK, but non-power-of-two sizes add
  too much complexity here)

- Accumulator address. 2D coordinate, but address calculations turn it into a
  1D index.

- Number of bits required is simply log-2 number of accumulators. Round up to
  nearest 8-bit number for simplicity. Worth noting that 720P with up to 4X
  supersampling and 2560P with up to 2X supersampling fit in 24 bits.

- Thus, for most flames, we can fit in 32 bits: a 24-bit accumulator index and
  an 8-bit color value. We assume that this is the case for now.

#### Quick review of radix sorting

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

#### Efficient sort of point log

- To write efficiently, want to avoid read-modify-write and not waste any
  bytes; therefore, work to only write complete cache lines.

- For each bucket, set up a single cache-line's worth of shared memory, and an
  index in main memory  [FIG a nice flowchart for this loop]

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

#### Iterating and sorting

- This algorithm requires frequent synchronization across all participating
  threads, and storage space in proportion to the number of threads.  It works
best in a single warp.

- There is no explicit cross-work-group synchronization primitive, so
  producer-consumer queues are incredibly challenging.

- Therefore, we want to attach one warp of this to a work-group of iterating
  threads, and use work-group barriers to ensure things stay synchronized.

- Here's how it goes: [FIG another flowchart]

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

[TODO: the description of the bucket mechanism, and how to move them down each
level, is so complicated and hardware-dependent that it would take dozens of
pages to explain the alternatives before we run the benchmarks to determine
what works best. I'm going to simply avoid mentioning the implementation of
buckets at all and hope nobody notices.]

#### Accumulating values in shared memory

- After accumulations fill a bucket, it is sent back through the sorting thread
  for an additional round of splitting.

- After the second pass, each point is in a bucket where the upper 14 bits of
  each index are the same, leaving only the lower 10 bits.

- Each bucket thus spans a range of 1024 index positions.

- Accumulators are 16 bytes wide, and the shared memory sort buffer is 16KB in
  size.

- The sort buffer is zeroed, then each point in the bucket is read in turn. The
  index is peeled from the value, the color is used to do a palette lookup, and
the shared-memory copy of the accumulator is updated just as if it were in main
memory.

- Once the entire bucket has been read, the shared-memory accumulators are
  added to their global memory counterparts.

- The whole process is considerably more complex than other writeback
  mechanisms, and there are in fact hardware-dependent details which have been
elided in this description. However, it ends up being considerably faster
overall. [TODO: make this point better.]

<!-- vim: syntax=pdcf: -->
