# Sample accumulation
\label{ch:accum}

After each iteration, the color value of a point within the bounds of the
accumulation buffer — a 2D region of memory slightly larger than the final
image, with gutters on all sides for proper filter behavior at edges — must be
added to its corresponding histogram bin. This process is simple, both
conceptually and in its basic implementations, yet it is, by nearly an order
of magnitude, the most time-consuming part of the fractal flame rendering
process on GPUs.

## Chaos, coalescing, and cache

The flame algorithm, and the chaos game in general, estimates the shape of an
attractor by accumulating point information across many iterations. While
visually interesting flames have well-defined attractors, the trajectory of a
point traversing an attractor is chaotic, jumping across the image in a manner
that varies greatly depending on the starting state of its thread. As a result,
there is little colocation of accumulator addresses in a thread's access
pattern over time. Spatial coherence is also unattainable, due to the need to
avoid warp convergence discussed in Chapter \ref{ch:funsel}.

Each accumulation, therefore, is to an effectively random address. While the
energy density across an image is not uniformly distributed, most flames spread
energy over a considerable portion of the output region [TODO: insert variance
statistics]. Since the accumulation buffer necessarily uses full-precision
floating-point values, it is not small; for a 1080p image, the framebuffer is
over 31MB[^fbsize]. Random access to a buffer of this size renders even CPU
caches useless, although CPUs are bottlenecked by iteration speed, so this is
not a concern. On GPU, however, the effects are amplified by simpler and
smaller caches, such that nearly every transaction may be expected to incur a
cache miss.

With each cache miss, a GPU reads in an entire cache line; each dirty cache
line is also flushed to RAM as a unit. In the Fermi architecture, cache lines
are 128 bytes, as compared to the accumulator cell size of 16 bytes. If nearly
every access to an accumulator results in a miss, then the actual amount of
bus traffic caused by one accumulation is effectively eight times higher than
the accumulator size suggests — and consequently, the peak rate of
accumulation is eight times lower.

To make matters worse, DRAM modules only perform at rated speeds when reading
or writing contiguously. There is a latency penalty for switching the active
row in DRAM, as must be done before most operations in a random access pattern.
This penalty is negligible for sustained transfers, but is a considerable
portion of the time required to complete a small transaction; when applied to
every transaction, attainable memory throughput drops as much as 50% [@elpida].

Improving performance requires addressing this step of the flame algorithm
carefully and thoroughly. In this chapter, we'll compare the three
implementations of the writeback stage currently avaiable in cuburn.

## Atomic writeback: perfectly slow

When running in multi-threaded mode, `flam3` uses atomic intrinsic functions
where available to perform histogram accumulations. These compiler-provided
intrinsics perform three operations — load a value from memory, add a second
value from a live register, store the updated value — in such a way as to
appear to all running threads like the operation happened instantaneously. On
x86 CPUs, this is typically accomplished using a compare-and-swap spinloop,
which is not exactly fast but far from the most egregious ineffeciency in
`flam3`. This technique allows for very simple multithreaded writeback code.

To establish a point of reference, we replicated this behavior in cuburn using
CUDA's atomic intrinsics. Global memory atomics on Fermi are implemented as a
single instruction, which is forwarded to the appropriate memory controller
along the packetized internal bus as an independent transaction^[Anecdotal
evidence suggests no coalescing is performed, but we have not confirmed this
with direct testing]. At the memory controller, the cache line containing the
address is loaded and then locked, so that it cannot be evicted or operated on
by another context.  One of a small set of local ALUs reads the relevant word,
performs an operation on it, and writes it back.  The line is then unlocked and
allowed to be flushed to DRAM when evicted.

This architecture makes individual atomic writes for which the issuing thread
does not require a return value execute faster than a read-modify-write cycle,
from the perspective of that thread: the SM dispatches a single memory
operation which gets appended to the memory controller queue, and is then
immediately free to move on with other tasks. However, the number of atomic
ALUs is limited, as is the queue depth for atomic operations, and the
cache-line-based locking mechanism stalls consecutive atomic transactions to
the same cache line. Under load, these quickly saturate the memory transaction
queue. This is handled by signaling each shader core to hold requests until the
queue has room, ensuring data integrity at the cost of performance.

The performance hit is substantial, as expected. Atomic writeback is at least
ten times slower than direct writeback on our hardware. [TODO: bench and add a
chart] It remains available in cuburn as a reference point and a debugging aid,
since this technique leads to deterministic output and has no precision loss,
but is impractical for production renders.

## Direct writeback

The direct writeback strategy performs a read-modify-write cycle against global
memory from the shader core, rather than at the atomic units. For the reasons
discussed at the start of this chapter, the random access pattern used by this
pattern performs poorly. Another important problem that needs to be considered
when using direct writeback arises from the incoherent nature of the caches
across the device.

A cache line loaded into an L1 cache to take part in a read-modify-write cycle
on a shader ALU is vulnerable to inconsistency from two sources. In a local
conflict, one thread can perform a read of a memory location after another
thread has read that location but before this other thread issues an
instruction to overwrite the location with an updated value. Both threads will
base their updates on the original value, causing one update to be silently
lost. This can happen either as a result of two warps interleaving instruction
issues in the normal process of latency hiding, or as a result of two threads
within the same warp reading the same location within the same instruction. The
latter case is particularly venomous, and results in siginficant image quality
degradations when point swapping between threads (as described in Chapter
\ref{ch:funsel}) is omitted.

A cross-core conflict occurs because L1 caches are not synchronized across the
device. If two separate shader cores request a cache line, that line will be
copied to both cores' L1 caches. A subsequent write from one core will not
invalidate the cache line in the other core. Depending on access patterns, this
allows invalid data to remain cached for substantial durations. It is possible
to effectively skip L1 via cache control operations, but in general the access
patterns cuburn exhibits makes this particular form of inconsistency far less
frequent, and so we do not take steps to avoid it. [TODO: measure impact]

These inconsistencies occur in a framebuffer, rather than in data that is used
for execution control, and therefore are closer in effect to a kind of sampling
noise than an outright bug. Fortunately, these collisions will tend to happen
in the image regions which have the highest density, where the relative error
for each lost sample will be considerably smaller and further reduced by log
filtering.

Characterizing the error at the pixel level is difficult, as out-of-order
execution makes exact reproduceability unlikely and inserting code to
atomically write to a separate buffer within one pass will increase time
between read-modify-write cycles and therefore underestimate the prevalence of
the problem. Indirect estimates suggest that the total error is small, and most
flames rendered using this mode were found to be indistinguishable from those
rendered using atomic writeback in a still-image, simultaneous presentation
subjective A/B test. However, this result is contingent on device timings and
flame characteristics. We have constructed pathological flames which exhibit
this flaw much more severely. As a result, we were interested in a strategy
which would not suffer these inconsistency problems — or at least suffer them
in a quasi-deterministic way that could be compensated for — and meet or
perhaps exceed the limited performance of direct writeback.

## Deferred writeback

A common strategy for avoiding the performance limits imposed by random memory
access patterns in graphics applications is tiling, where image elements are
rendered alongside others which are near it in screen-space. Implementations of
the Reyes algorithm for ray-tracing, such as Pixar's RenderMan, handle limited
cache sizes by splitting the global geometry in a scene along the boundaries of
the scene-space projection of small rectangular regions that tile the
destination framebuffer; the contents of each tile are then drawn separately
and discarded, allowing the information in a single image area to remain in the
cache [@Cook1987]. A similar technique is employed by graphics chips designed
for low-power applications, such as those in the PowerVR architecture
[@PowerVR2009].

Implementing tiling in cuburn's output stage would allow for the use of shared
memory to perform accumulation, as tile sizes could be chosen to fit within
available shared memory bounds. Shared memory supports atomic transactions with
much greater aggregate throughput than global memory, so this could allow for
reasonable performance without transaction loss. However, tiling requires that
we be able to subdivide data by region of interest, while the chaos game
requires that points cross the entire image area. It is not possible to perform
accurate chaos game sampling within a particular region of interest, save by
simply discarding all points outside of that region, which would be
tremendously ineffecient.

Since it is not possible to obtain chaos game samples by region of interest
directly, it is necessary to separate sample generation from sample handling.
The deferred writeback method does precisely this.

### Storing chaos game samples

Storing a point to the accumulator using atomic or direct writeback involves
adding three color values to a particular accumulator index, and incrementing
the corresponding density count. The color tristimulus value is obtained by
performing a palette lookup, using color coordinate and control point time
delta to perform a texture fetch with bilinear filtering enabled. This value
is then scaled by an opacity value, depending on xform, if the flame makes use
of the xform opacity feature. The accumulation index is determined by applying
the camera transform to the 2D $(x,y)$ coordinate pair, and multiplying $y$ by
the image row stride value.

For deferred writeback, we wish to store this information as efficiently as
possible in such a way that it can be reconstructed for accumulation at a
later time. A compact scheme is presented in Figure \ref{fig:logfmt}. 8 bits
are used to represent the color index, 2 bits represent the xform index when
opacity is used, and up to 22 bits (or 24, for flames which do not use xform
opacity) encode the accumulation buffer index after camera rotation and
clipping.


\begin{figure*}[t]
\raggedright
\begin{Verbatim}[fontsize=\footnotesize]
|                             | Sort key (9 bits)        |  | Shared key (12 bits)              |
| Color (8 bits)        |     | Accumulator address (22 bits)                                   |
 31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0

|                                         | Sort key (7 bits)  |                                |
|                                                           | Shared key (12 bits)              |
| Color (8 bits)        | XOI |           | Accumulator address (18 bits)                       |
 31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
\end{Verbatim}

\caption{Top: the log format used for a 2560x1600 image which does not use
xform opacity. Note that each memory cell in the sorted log is scanned twice in
this configuration, since bit 12 is not sorted; each pass ignores log entries
outside of its boundary. (Sorting will be described in Chapter \ref{ch:sort}.)
Bottom: The log format used for a 640x360 image.  To avoid entropy reduction,
bit 11 is included in the sort.}
\label{fig:logfmt}
\end{figure*}

\newcommand{\flo}[1]{\lfloor #1 \rfloor}
\newcommand{\ceil}[1]{\lceil #1 \rceil}

Faithful representation of the color index in 9 bits, instead of the 32 used
to represent that value as a floating-point coordinate, is possible by using
dithering. Consider a two-entry color palette, where the tristimulus value at
index $0$ is $C(0) = (0, 0, 0)$, and at index $1$ is $C(1) = (1, 1, 1)$.  With
linear blending, a lookup for an arbitrary value takes the form
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
bits, which we use.

The accumulator index is also in need of dithering under this scheme to
suppress the quantization error resulting from truncation of floating-point
values to linear memory addresses. Due to the 2D nature of this process, it is
often easier to use a signal-processing framework to analyze and correct these
errors, rather than a statistical one; we do so in Chapter \ref{ch:filt}.

A 22-bit upper bound on the image address size places an upper bound on
accumulator buffer size just larger than a 1080p region would occupy. Since
the fractal flame algorithm is statistically fractal, allowing for detail even
at very fine image scales, most flames can be scaled well past 1080p for
applications such as print material or art installations. However, consumer
hardware cannot decode video at these resolutions; in fact, H.264/AVC High
profile, as used in Blu-Ray, is insufficient to capture the image detail
available in even 1080p streams without visible blurring of fine structure. For
rendering animations, this limit is an acceptable compromise.

Even with dithering, two bits does not afford ample precision for storing xform
opacity. Rather than directly encode the floating-point opacity from the
interpolated control points, the value represents an index into a time-varying
array of those opacities, precomputed in a separate step. This array can
represent four opacity values exactly, which is often sufficient for most use
cases — although flames can have more than four xforms, typical uses of xform
opacity often involve the same value on multiple xforms. When more unique xform
opacities are in use, combining this lookup table with dithering enables a
DXTC-like encoding scheme which is capable of more accurately representing
opacity values, even at low sample counts, than a linear mapping.

Both color and xform opacity depend on knowing the time value at which the
source control point was interpolated to determine which look-up table to use.
Fortunately, no bits are needed to encode this value: the index position in the
output array is determined by the block index of the thread block which
generated the point, which also determines the control point used to create the
points. The time value can therefore be inferred from the index of the point in
the output buffer.

This information is packed and stored consecutively from the chaos game
iteration thread in efficient, coalesced transactions, which proceed
asynchronously and do not require confirmation of completion. As a result,
memory bottlenecks are absent from the iteration thread.

### Accumulating stored samples

The accumulation buffer is divided into tiles, with each tile's size based on
the interaction between accumulation buffer addressing patterns and shared
memory size.^[For simplicity, we use linear address segments as tiles, rather
than rectangular areas, but the principle, and thus the term, remains the
same.] After a certain number of iterations have been performed, the samples in
the iteration log are sorted into tile groups based on a key extracted from a
portion of the global address. Whenever possible, each tile group contains
exactly one tile, such that the tile group address is equal to the tile address
prefix, but this is not always the case, for reasons explained in Chapter
\ref{ch:sort}.

The accumulation kernel is launched with a thread block to service each tile.
A block looks up the start and end indices of the tile group in the sorted
array, clears its shared memory buffer, and begins loading log entries from the
tile group. If a log entry's tile address prefix does not match the current
block's tile address, it is discarded, and the next loaded. When a log entry is
in the current tile, the color, local address, and xform opacity index are
extracted from the entry, and the control point time value is inferred by the
entry's index within the tile group. Extracting the time from sorted data is
not necessarily as accurate as extracting it from the full array index, but the
error is subthreshold in every flame we have tested.

In traditional in-loop accumulation, the color value is determined by
performing a texture lookup into a palette texture with bilinear interpolation.
This enables compact, cache-efficient, and very accurate blending based on both
color coordinate and time value to retrieve an appropriate color four-vector
(of which one channel is currently unused) that can then be scaled if needed to
account for xform opacity. The use of clamped-integer values with dithering to
store the necessary coordinates offers an alternative possibility with
equivalent results: provide a pre-blended texture palette which does not use
texture unit interpolation. When using a four-vector of floats to store the
texture, this strategy would not result in a large performance improvement; its
usefulness is derived from the accumulation buffer format.

The process of shared-memory accumulation can be relatively expensive.
Shared-memory atomics are implemented on Fermi via load-lock and store-unlock
instructions, with the former setting a predicate indicating successful lock
acquisition; conflicts are handled by spinning until all threads in a warp have
successfully completed their transaction. Certain flames will encounter a high
number of collisions in certain tiles, and minimizing the number of collisions
improves performance. Storing accumulation buffers in planar format within
shared memory helps — with a stripe size of 4 bytes, interleaved float32
storage would quadruple the effect of any collisions — but reducing the size of
the buffers helps further.

The accumulation buffers therefore represent accumulation values as a packed
64-bit integer, storing density and the color tristimulus values in a clamped
format. The storage format assigns uneven bit ranges to the different values;
one configuration currently under test uses 11 bits to represent the density,
19 bits to represent the first color tristimulus value, and 17 bits each for
the remaining two values. At each accumulation, density is incrmented by one;
when the density reaches, in this case, 2047, the next accumulation will cause
this accumulation cell to wrap. Without recording the fact that the cell
wrapped, this is harmful, as it leads to loss of the accumulations and color
artifacts as the other counters also roll over. As a result, after each
accumulation, each cell examines the density counter it just updated. If it is
exactly equal to the largest representable density value less the number of
threads in this thread group — 1023, in this example — that thread triggers a
barrier, re-reads the value, and writes the cell to the global accumulation
buffer, zeroing it afterward. By checking for exact equality, we implicitly
ensure that only one thread handles the writeback, and by doing it well before
the value wraps, we can perform writeback and barrier syncing lazily,
increasing efficiency.

To ensure that the color cells don't wrap, the values added to those cells are
scaled such that the integer corresponding to the maximum tristimulus value,
$1.0$, times the maximum number of iterations before the density counter wraps,
is representable. In practice, that means each primary tristimulus value to be
added to the accumulator is represented in 8 bits, and the secondary ones with
6 bits. Dithering is once again required for accurate color representation in
low-intensity areas.

The uneven bit distribution between primary and secondary colors implies a
difference in importance, and indeed there is such a difference — as long as we
use YUV. Human vision is substantially more sensitive to luminance information
than to chrominance information, both in terms of spatial frequency and
intensity; video encoding schemes take advantage of this to encode much less
chrominance information than luminance information with little noticeable
impact on the final image quality. To do so, most coding schemes convert RGB
values via an invertible linear transform into a YUV color space,[^yuv] where
the Y channel contains luminance information and UV represent chrominance via
an opponent-color encoding. Both U and V are then spatially subsampled, often
by a factor of two in each dimension, and aggressively quantized. We avoid the
complexities of spatial subsampling in cuburn, since it is transaction count
and not buffer size that limits performance, but we can increase performance by
reducing the precision of the UV channels during accumulation, which allows us
to perform more iterations before forcing a flush to global memory. Naturally,
this requires conversion of RGB samples YUV.

[^yuv]: There are many YUV transformation matrices, and technically none of
these represent color spaces themselves, but are simply encoding schemes for
RGB values which may have an associated color space. Proper conversion to and
from YUV requires careful use and signaling of specified color matrices.
However, since cuburn is not a physically-based renderer and relies on
user-specified colorimetry information, its only responsibility is to be
consistent.

The long chain of conversions, from log entry to color and time values to
texture coordinates to bilerp texel four-vector to YUV-encoded four-vector to
dithered four-vector to scaled integers to single packed integer, is quite
costly, compounded by reliance by nearly all of these operations on the
lower-throughput special function units. It is this chain of conversions,
rather than the bilinear interpolation alone, which the preformatted texture
structure is designed to accelerate, as it simplifies this chain to a simple
lookup.

The actual process of adding the value from the look-up to the shared
accumulation buffer is performed using a call to `atomicAdd`, providing the
shared memory lock-and-load logic described previously. However, this requires
interleaving of the high and low bits of the 64-bit word, which doubles the
risk of bank collisions (although it does not strictly double their cost, as it
only requires one lock operation). We are currently prototyping a tool that
will allow us to perform post-compilation manipulation of opcodes within the
compiled binaray, or "monkey-patching", to efficiently planarize this lookup
and perform in-loop buffer zeroing to eliminate the need for a separate barrier
operation when performing early flushing. Monkey-patching is necessary because
the PTX ISA does not expose the underlying lock and unlock operations used to
implement shared memory atomics.

# Cuburn sort
\label{ch:sort}

Sorting is a common, intuitive operation, found as a core part of many
optimized algorithm implementations. It's also surprisingly difficult to do
quickly on GPU architectures. Because of the theoretical and practical
importance of sorting implementations, the peak sorting performance is often
used as a critical benchmark of an architecture's true performance and
flexibility: simple enough to be portable and reproduceable, while
cross-functional enough to be a holistic test. Sorting implementations for
GPGPU systems remain a vigorously active area of research for both professional
and academic individuals in the HPC community.

In cuburn, sorting is used in the deferred writeback mechanism to split the
iteration sample log into tile groups for efficient processing by an
accumulation kernel (Chapter \ref{ch:accum}). To be useful in cuburn, a sort
function must be easily callable within the complex asynchronous dispatch code
used to schedule operations on the GPU. It also must be fast; if the entire
deferred writeback sequence, including the sort, cannot be made to be as fast
as direct accumulation, development efforts would be better spent optimizing
that process and developing statistical workarounds for the possibility of
sample loss. The sort must also support operating on a partial bit range. While
every notable implementation does so internally as a consequence of using
multi-stage radix sorting to fully sort 32-bit keys, not every implementation
exposes this at the API level.

Of the most commonly used sorts available for Fermi GPUs, only MGPU sort meets
our performance requirements [CITE]. It also exposes options for sorting
partial bit ranges efficiently. Its C++ API is convenient to use from that
language, but less so from Python; still, a C wrapper that could be called from
Python code would not be overly difficult to create.

Instead of using MGPU sort, however, we elected to build our own. This was not
an instance of Not Invented Here syndrome, but simply a consequence of having
begun our implementation before MGPU sort was made public. Promising
theoretical results (and a fair amount of stubbornness) encouraged us to
produce a working implementation, which we have now done.

We stress here that cuburn sort is *not* a suitable replacement for MGPU sort,
or other general-purpose sorting implementations. It is a key-only sort, and
while it is usually a stable sort, it is absolutely not guaranteed to be
stable, which means that multi-pass sorts risk increasingly large misorderings
in lower bits with each pass. As a result, it's not useful for much outside of
a preprocessing pass for global memory reductions.

At that one thing, however, it's *great*. Cuburn sort is optimized to sort
between 7 and 9 bits, and does so faster than any other GPU sort implementation
with public performance figures (see Figure \ref{sorttimes}). Additionally, an
optional early-discard flag allows an additional workload reduction on top of
the figures seen here; for typical flames, this amounts to a further 40%
increase in performance.

We believe that the sort can be optimized further, and have concrete
optimizations in mind which we will begin implementing immediately after
finishing this documentation.

\begin{figure}[htp]
\begin{center}
\begin{tabular}{r r r r r}
        & Cuburn    & MGPU      & B40C      & CUDPP \\ \hline
7 bits  & 821       & 740       & 551       & 221   \\
8 bits  & 943       & 813       & 611       & 251   \\
9 bits  & 966       & 877       & 475       & 191   \\
10 bits & 862       & 910       & 528       & 211
\end{tabular}
\end{center}
\caption{Performance of different sort implementations, as measured on a GTX
560 Ti 900MHz. Values are in millions of keys per second, normalized to 32-bit
key length.}
\label{sorttimes}
\end{figure}

[TODO: can easily double pagecount here]

The sort is accomplished in four major steps. The first pass divides the buffer
to be sorted into blocks of 8,192 values, and performs an independent scan
operation on each. Unlike the other sorting techniques benchmarked here,
cuburn's scan uses shared memory atomics to perform this accumulation, by
performing an atomic increment on a shared memory index derived from the point
under analysis. This process is much slower than traditional prefix scans, but
because it is coordinated across all threads in a thread block, it allows the
derivation of a radix-specific offset for each entry in the current key block.
This offset is stored into an auxiliary buffer for every key processed, and the
final radix counts are stored to a separate buffer.

The second step loads the final radix counts and converts them to local
exclusive prefix sums, storing these in a separate buffer. This is performed
quickly and with perfect work efficiency by loading the radix counts into
shared memory using coalesced access patterns (see Figure
\ref{fig:sort_access}), rotating along the diagonal of the shared memory
buffer, and performing independent prefix sums in parallel horizontally across
the buffer, updating values in place.

[TODO: this figure]

\begin{figure}[htp]

\caption{Shared-memory patterns used in cuburn sort's work-efficient radix scan
reduction pass.}

\end{figure}

A third step operates on the final radix counts, transforming them in-place to
per-key-block, per-radix offsets into the output buffer. This is accomplished
by first reducing the buffers via addition in parallel to a very small set in a
*downsweep* operation, performing the prefix scan on this extremely limited set
in a manner that is not work-efficient but, due to the small number of buffers
involved, completes in microseconds, and then broadcasting the alterations back
out to the full set of buffers in an *upsweep* operation.

Sorting is accomplished by using the offsets and local prefixes to load each
key in the block to a shared memory buffer, then using the local and global
prefixes to write each key to the output buffer. Transaction lists are not
employed, but large block sizes help to minimize the impact of transaction
splitting.

One unusual characteristic of this architecture is that performance on data
that does not display a good deal of block-local entropy in radix distribution
is actually considerably slower than sorting truly random data. Sorting
already-sorted data is a worst case, with a penalty of more than an order of
magnitude arising from shared-memory atomic collisions during the initial scan.
We avoid this in cuburn by ensuring that the radix chosen to sort never
includes bits that are zero throughout the log. In some cases, this means that
some bits of the accumulation kernel's shadow window are also sorted, since
cuburn sort does not scale down to arbitrarily small radix sizes. This
oversorting is theoretically less efficient, but is actually faster than
including the zero bit in the sort.

A simple but powerful optimization enables discarding of any key equal to the
flag value `0xffffffff`. This value is used internally by cuburn to indicate
that a particular point log entry corresponded to an out-of-bounds point and
should be ignored. Discarding these during the sort stage improves performance
by around 40% on average for our test corpus of flames.


