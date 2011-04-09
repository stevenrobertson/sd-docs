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
application brings every point in the warp closer to the *same* fixed point,
and therefore to the other points in the warp. It doesn't matter that the next
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

TODO: expand the IFS chapter to include an explanation that the nonlinear
functions used in flames are often not technically contractive, because they
can have multiple fixed points, and that for practical purposes we can
characterize whether or not they are contractive on the bounds of the image by
computing the first moment of the distance from the center of the camera over
the domain of the image and call it "contractiveness" or come up with a better
name for it.

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
used by an individual bank's memory controller.  Each memory controller can
service one read or write per cold clock. A crossbar allows 1-to-N broadcast
from every bank port on read operations and 1-to-1 access to any bank port for
write operations, all handled automatically.

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
pattern — simplicity is something we're pretty desperate for at this point —
and thereby keep the problem of determining read and write locations in a
single dimension.


TODO: finish


## Writeback

Okay, so as we've established, flam3 generates an enormous number of points
to render a high-quality image. We've looked at how to reduce the effects
of noise due to undersampling the IFS, which may allow us to reduce the
number of samples required for satisfactory images, but half of a ton of
points is still a lot of points. For the classical approach, most of our
time will be spent performing iterations.

As has been discussed, GPUs have a much higher ratio of computation to
memory bandwidth and cache size than CPUs do, and have a strong
architectural preference for coalesced memory operations. Unfortunately, as
we've also mentioned, the IFS follows the attractor around the image space,
jumping from region to region, so there is little temporal coherence in
memory access patterns.  Also, since we need each point to pass through a
different sequence of transforms, there's no spatial locality to our
accesses either.

All of this adds up to an unavoidable worst-case scenario for the
traditional flame algorithm. For chips with no coherent cache — basically
everything other than Fermi — the memory subsystem would be an almost
certain bottleneck.  [show math] Even for newer chips, the only way the
memory bottleneck can be avoided is if L2 happens to cover most of the
image regions being written to, which [math] is just not gonna happen. Then
turn on supersampling — which on CPU is essentially free — and watch all
hope disappear.

### Reducing color traffic

There's a stopgap approach, which is this: subsample the color buffers.
Humans have much more limited spatial resolution for color than for
luminosity, so we don't notice color bleed like that. In fact, almost all
compressed video uses that technique. This cuts down on the total
framebuffer size considerably. But, [math], not enough. Also, it requires
splitting the color buffers apart, which can actually reduce performance by
requiring extra cache lines to be loaded.

Another approach is to use probabilistic writeback of color. We again
exploit the human visual system's color weaknesses, and the knowledge that
the effect of any given sample upon the final color decreases in proportion
to the number of samples in that pixel's area. Write the pixel's alpha
value first; then, calculate a probability like $2^{-k\alpha}$ for writing
back that color. This doesn't reduce the size of the color buffer, but in
concert with the above, it greatly reduces the memory traffic and number of
cache lines occupied by the colors rather than alpha.

Cutting the alpha buffer down to a half-precision float wouldn't be too bad
either, although it would remove the ability to use fast atomics in L2.

### Point logging

Another approach would be to restore cache coherency, which would allow the
memory and caches to function much closer to their theoretical throughput
and remove the bottleneck. The way to do it? Sort the points first.

GPU friendly sorts, such as radix-based bucket sort and bitonic sort, can
churn through the point log relatively quickly. With large bucket sizes and
clever timing, the sort could be done in two or three passes, and writeback
could be accelerated by doing all atomic compaction on shared memory
instead of global.

[Insert teaser for big new approach]

### Motion blur

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



