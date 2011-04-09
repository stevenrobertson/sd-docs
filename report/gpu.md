# A brief tour of GPU computing

Graphics processing units began as simple, fixed-function add-in cards, but
they didn't stay there. Over many generations, demand for increasingly
sophisticated computer graphics required hardware that was not just faster,
but more flexible; device manufacturers responded by spending ever-larger
portions of the transistor budget on programmable functions. In 2007,
NVIDIA released the first version of the CUDA toolkit, unlocking GPUs for
straightforward use outside of the traditional graphics pipeline. Since
then, "general-purpose GPU computing" has become a viable, if still
nascent, market, with practical applications spanning the range from
comsumers to the enterprise.

Don't let the words *general purpose* fool you, however. While the major
manufacturers have shown interest in this market, it remains at present a
fraction of the size of these companies' core markets [@Voicu2010]. Every
transistor spent making GPGPU faster and easier to program may come at the
expense of doing the same for games, and that market is simply too small to bet
the farm on at present [CITE?]. This tension between compute and gaming has
real implications in the design of current hardware, as we'll see in this
chapter, and will be considered in depth when describing hardware decisions in
the next chapter.

Despite being "games first", GPUs still provide the highest performance per
dollar for most math-intensive applications. In general, porting algorithms
to such devices can be a challenge, but one worth the effort, and we feel
that the GPU is a good fit for an accelerated implementation of the fractal
flame algorithm.

This section is intended to give a grounding in the concepts and
implementations of GPU computing platforms. We start with a summary of the
OpenCL computing model, which subsets both NVIDIA's and AMD's hardware.
Then, we consider the implementations of the two manufacturers, covering at
first common approaches not covered by the OpenCL spec, followed by a deeper
look at a leading card from each manufacturer [@Overbeck2009].

## OpenCL

The OpenCL standard for heterogeneous computing is managed by the Khronos
Group, an industry consortium of media companies that also produces the
OpenGL specification [CITE]. OpenCL provides a cross-platform approach to
programming; while its execution model requires certain features of the
hardware it executes on, the language is kept general enough so that almost
all code can execute with reasonable efficiency on any supported
architecture (via driver-provided just-in-time compiling).

Because it forms a common, abstract subset of the GPUs under consideration
as platforms on which to implement this algorithm, OpenCL is a good
starting place for our discussion. As much as we might like to rely on an
open standard alone to inform our algorithm design, however, the
specification doesn't tell the whole story.

### An editorialized history of the standard

TODO: citations all through here

OpenCL was developed by Apple, Inc. to provide a generic interface to
high-performance devices like GPUs across their platform. At the time of
development, Apple had standardized on NVIDIA GPUs across its desktops and
laptops, and wished to expose the hardware's computational performance to
developers, but did not wish to lock itself into NVIDIA's proprietary CUDA
technology and in so doing weaken the threat of using AMD graphics products
at the negotiating table.

While cooperation on standards had clearly served the two graphics firms in
the past (with DirectX and OpenGL), NVIDIA's cards were far more flexible
for computing than AMD's; any standard which would work seamlessly across
cards would cripple NVIDIA's performance advantage. Naturally, Big Green
wasn't keen on signing on to a standard that would necessarily eliminate
its considerable head start in the compute market. But Apple provided
leverage — ruthlessly, if history is any judge — and months later AMD and
NVIDIA were showing off their new standard for compute together.

AMD was, at the time, shipping cards based on the much-derided R600
architecture, which did not meet even the limited requirements of OpenCL.
While the company was preparing to include the necessary components in
their next graphics architecture, full support did not emerge until two
hardware generations later, with the *Evergreen* family of GPUs.

On the heels of a very successful graphics architecture which was
compatible with OpenCL from day one, NVIDIA invested even more engineering
talent and die space into the *Tesla* architecture, which preceded AMD's
Evergreen. Tesla formed an even broader super-set of features available in
the base OpenCL spec, some which were simply inaccessable from the open
standard. Rather than let these features go to waste, however, NVIDIA put
them to work in their proprietary CUDA framework, which remains their
primary development and marketing focus.

As of now, OpenCL is still at version 1.1, which (along with an extension
or two) covers the functionality in AMD's *Northern Islands* family, their
latest. NVIDIA's *Fermi* architecture provides yet another increase in
compute features over OpenCL, and those features are again exposed through
CUDA. We'll take a look at this situation a bit later; for now, let's turn
to the OpenCL model for computation.

TODO: This section feels a little... off. When I sat down to write it, it
seemed necessary; now I'm not so sure, especially after putting the
Fermi+Larrabee discussion off for a later chapter.

### How to do math in OpenCL

OpenCL has something of a client/server model: a program running on an
OpenCL *host* communicates with one or more *devices* through the OpenCL
API. While the method of communication with the device is not fully
specified, both NVIDIA and ATI post requests to a command queue on the
device. The GPUs possess their own schedulers and DMA engines; after a
command is handed to a device, the host is left to do little but poll for
the task's completion.

By default, commands begin executing on the device as soon as the
appropriate execution resources are available. Stricter ordering is
possible; a *command-queue barrier* will stall until all previous commands
in the queue are complete. A *stream*[^stream] provides a strict ordering
for every task it contains, but multiple streams can execute concurrently.

[^stream]: We borrow the CUDA notation here. OpenCL allows any command to
wait on any other explicitly using *events*, which can be used to implement
a stream, but has no term (or API call) for the ordered tasks as a group.
It becomes a pain to talk about without a name.

There is no hardware mechanism for a strict interleaved ordering of both
host and device code. The OpenCL API exposes apparently-synchronous
execution of device commands in the host API, but this is implemented via a
spinloop which polls the device for task completion. This method is
ineffecient and should be avoided in performance-critical code.

Hosts and devices must be assumed to have independent memory spaces. To
provide data for execution, data must be explicitly copied to and from the
device via an OpenCL API call. Memory operations are contained within
commands, and are subject to the ordering constraints above; additionally,
since memory commands are executed by the GPU's DMA engine, the host-side
memory to be accessed may need to be page-locked to ensure that it is
resident when accessed and that its location in physical RAM does not
change. OpenCL devices may optionally support mapping a portion of device
memory into the host's address space or vice versa, although such access is
generally slower than bulk updates.

After the host has initialized the device's memory space, it may load a
*kernel* onto the device. The kernel is a fixed bundle of device code and
metadata, including at least one entry point for program execution.  From
the OpenCL API, the kernel's data is opaque on both host and device, so
device-side run-time code modification is prohibited. After uploading a
kernel, the host issues a command which sets up arguments for an entry
point and begins executing it in one or more *device threads*[^threads].

[^threads]: We revert again to CUDA's terminology; this time, though, merely
because "work-unit" is just a clumsy, unnecessary neologism.

As in a typical OS, a device thread is a set of data and state registers,
including a program counter indicating the thread's position within the
currently-loaded code segment. A thread can execute arithmetic instructions
and store the result to its registers, perform memory loads and stores, and
perform conditional direct branching to implement loops. However, OpenCL
does not support a stack; all function calls must be inlined, and recursion
is not allowed.

While a single thread executes instructions according to program flow, the
order of execution between any two threads is generally undefined. It's
possible to use global memory to do a limited amount of manual
synchronization, but this is impractical, as global memory accesses
typically carry high latencies, suffer from bandwidth constraints, have an
undefined ordering, and heavily penalize multiple writes to the same
location [CITE myself].

To facilitate inter-thread cooperation without mandating
globally-consistent local caches, threads are collected into *work-groups*.
A work-group is a 1-, 2-, or 3-dimensional grid of threads that share two
important consistency features: a fast, small chunk of *shared
memory*[^shared] accessible only to threads within that work-group, and
*barrier instructions*, which stall execution of any thread that executes
the instruction until every thread in the work-group has done so.

[^shared]: Another CUDA term. OpenCL calls this "local memory". Problem is,
CUDA uses the term "local memory" to refer to what OpenCL calls "private
memory". We choose the unambiguous name in both cases.

Work-groups themselves are arranged in a uniform grid of dimensionality ≤3.
Every thread in a grid must execute the same kernel entry point with the
same parameters. To obtain thread-specific parameters, each thread can
access its index within its work-group (its *local thread ID*), as well as
its work-group's index within its grid (the *global thread ID*); it may
then use those IDs to load thread-specific parameters such as a random seed
or an element of a matrix. This is the only means to differentiate between
threads at their invocation. Aside from providing a global ID, the only
feature provided by a grid of work-groups is the requirement that every
thread terminate before the grid is reported as complete to the host.

In addition to global and shared memory, OpenCL also provides *private
memory*, which is accessible only to a thread; *constant memory*, which has
a fast local cache but can only be modified by the host; and *image
memory*, which can only be accessed using texture samplers. The texturing
pathway, a clear holdover from OpenCL's GPU origins, is a high-bandwidth
but high-latency method of accessing memory which can only perform lookups
of 4-vectors but offers a read-only cache and essentially free address
generation and linear interpolation.

## Common implementation strategies

The OpenCL standard was constructed to subset GPU behavior at the time of
its ratification, but for portability reasons it omits implementation
details even when techniques were used in both NVIDIA and AMD GPUs. While
such details do not necessarily impact code correctness, they can have a
considerable impact on the ultimate performance of an application.

### Dropping the front-end

In modern x86 processors, only a small portion of the chip is used to
perform an operation; more die space and power is spent predicting,
decoding, and queueing an instruction than is spent actually executing it
[CITE].  This seems contradictory, but it is in fact well-suited to the
workloads an x86 processor is typically used for. It's also a consequence
of the instruction set; x86's long history and ever-growing set of
extensions has made translation from machine code to uops a challenging and
performance-critical part of a competent implementation.

Across the semiconductor industry, it has become clear that scaling clock
speed alone is not a realistic way to acheive generational performance
gains. To deliver the speed needed by graphics applications, both NVIDIA
and AMD simply pack hundreds of ALUs into each chip. If each ALU required
an x86-size front-end, the GPU would dim lights for a city block and cook
the gamer alive [CITE? oh, i hope so]. To avoid such an unpleasant
situation, the two hardware companies employ three important tricks.

The first of these tricks is runtime compilation. In OpenCL, device kernels
are stored in the C-like language which executes on the device, and are
only compiled to machine code via an API call made while the program is
running on the host; CUDA stores programs in an intermediate language, but
the principle is similar. In both cases, this pushes the responsibility for
retaining backward compatibility from the ALU frontend (where it would be
an issue billions of times per second) to the driver (where it matters only
once per program). Without needing to handle compatibility in hardware,
the actual instructions sent to the device can be tuned for each hardware
generation, reducing instruction decode from millions of gates to
thousands.

Another considerable saving comes from dropping the branch predictor. On an
x86 CPU, the branch predictor enables pipelining and prefetch, and a
mispredict is costly [CITE]. To axe the branch predictor without murdering
performance, GPU architectures include features which allow the compiler to
avoid branches. Chief among these is predication: nearly every operation
can be selectively enabled or disabled according to the results of a
per-thread status register, typically set using a prior comparison
instruction. For many expressions, using the results of a predicate to
disable writeback can be less costly than forcing a pipeline flush,
especially when hardware and power savings are taken into account. Drivers
also generally inline every function call; with thousands of active threads
and hundreds of ALUs all running the same code, a single large instruction
cache becomes less expensive than the hardware needed to make function
calls fast. Perhaps most intuitively, both companies go out of their way to
inform developers that branches are costly and should be avoided whenever
possible.

The final technique used to save resources on the front-ends is simply to
share them. A single GPU front-end will dispatch the same instruction to
many ALUs and register files simultaneously, effectively vectorizing
individual threads into an unit between a thread and a work-group. NVIDIA
calls these units *warps*[^warp], with a vectorization width of 32 threads;
AMD uses *wave-fronts* of 64 threads. Because each thread retains its own
register file, this kind of vectorization is not affected by serial
dependencies in a single thread. In fact, the only condition in which it is
not possible to vectorize code automatically in this fashion is when
threads in the same warp branch to different targets, whereupon they are
said to be *divergent*. Not coincidentally, the same approaches used to
avoid branches in general also help to avoid thread divergence.

[^warp]: We follow what is now a tradition and adopt NVIDIA's term, though
it does display a bit of whimsy on the part of Big Green.

While these techniques seem of only passing interest, the peculiarities of
the fractal flame algorithm are such that a naïve implementation which did
not heed these design parameters would suffer more than might be expected.
We will need to make careful use of runtime compilation, predicated
execution, and warp vectorization to write an efficient implementation.

### Memory coalescing

The execution units aren't the only part of a GPU trading granularity for
performance; memory accesses are also subject to a different kind of
vectorization, called *coalescing*, that has extremely visible consequences
for certain classes of tasks.

High-performance GPUs contain several front-ends. Because global memory is
accessible from all front-ends, there is effectively a single, shared
global memory controller which handles all global memory
transactions[^controllers].  Since each memory transaction must interact
with this memory controller, and multiple front-ends can issue transactions
simultaneously, this controller includes a transaction queue and
arbitration facilities, as well as simplified ALUs for performing atomic
operations.

[^controllers]: Actually, there are typically several memory controllers
connected by a crossbar switch, ring bus, or even internal packet bus, with
address interleaving on the lower bits and any cache distributed per-core.
But since each address block maps uniquely to one core, and typical access
patterns hit all cores evenly, we ignore this.

To simplify and accelerate the memory controller, memory transactions must
be aligned to certain bounds, and may only be 32, 64, 128, or 256 bytes
wide (depending on architecture). Because of unavoidable minimums on
address set-up time and burst width, GDDR5 devices can only attain rated
performance with transaction widths above a certain threshold, and these
minimums are reflected in the minimum transaction sizes on the other side
of the memory controller.

A single thread can issue at most a 16-byte transaction (while reading a
4-vector of 32-bit values), and will more often simply use 4-byte
transactions in typical code. On its own, this would result in most of each
transaction being discarded, consuming bandwidth and generating waste heat.
On traditional CPUs (and, to a limited extent, newer GPUs), caches are used
to mask this effect. However, with so many front-ends on a chip, placing a
large and coherent cache near each would be prohibitively expensive with
current manufacturing processes, and even centrally-located caches would
still require an enormously high bandwidth on-chip network to service a
request from every running thread.

Since GPUs must issue wide transactions to reduce chip traffic and
accomodate DDR latency, and temporal coherence is not enough to mitigate
the memory demands of thousands of threads, hardware makers have instead
turned to *spatial* coherence. As threads in a warp execute a memory
instruction, the local load/store units compare the addresses for each
thread. All transactions meeting certain criteria — falling within an
aligned 128-byte window, for example — are coalesced into a single
transaction before being dispatched to the memory controller.

On previous-generation architectures, use of coalescing was critical for
good memory performance, with uncoalesced transactions receiving a penalty
of an order of magnitude or more. Respecting coalescing is an easy task for
some problem domains, such as horizontal image filtering. Others required
the use of shared memory: segments of the data set would be read in a
coalesced fashion, operated on locally, and written back. Unfortunately,
the fractal flame algorithm supports neither of these modes of operation,
and there is no way to create a direct implementation with sufficient
performance on these devices.

Newer GPU architectures, such as NVIDIA's Fermi and AMD's Cayman, possess
some caching facilities for global memory. The cache on these devices
assists greatly in creating a high-performance implementation of the
fractal flame algorithm, but remain far smaller than the framebuffer size
at our target resolution. It is therefore clear that memory access patterns
will be an important focus of our design efforts.

TODO: citations of course, and also a more ominous ending?

### Latency masking

Memory transactions, even when coalesced, can take hundreds of cycles to
complete. Branching without prediction requires a full pipeline flush, as
do serially-dependent data operations without register forwarding (another
missing feature). Even register file access carries latency at GPU clock
speeds. Without the complicated front-ends of typical CPUs, how do GPUs
keep their ALUs in action?

The strategy employed by both AMD and NVIDIA is to interleave instructions
from different threads to each ALU. In doing so, nearly every other
resource can be pipelined or partitioned as needed to meet the chip's
desired clockspeed. This technique increases the runtime of a single thread
in proportion to the number of active threads, but results in a higher
overall throughput.

The mechanism for performing this interleaving differs between the two
chipmakers, and is one of the more significant ways these architectures
differ. Naturally, we'll take a closer look in our analysis throughout the
rest of the chapter.

TODO: need to expand this section?

## Closer look: NVIDIA Fermi

Fermi is NVIDIA's latest architecture, as implemented in the GeForce 400
and 500 series GPUs. The architecture represents a considerable retooling
of the company's successful Tesla GPUs with a focus on increasing the set
of programs that can be run efficiently rather than just on raw
performance. This was done by adding some decidedly CPU-like features to
the chip, including a globally-consistent L2D cache, 64KB of combined L1D
and shared memory per core, unified virtual addressing, stack-based
operations for recursive calls and unwinding, and double-precision support
at twice the ops-per-clock rate of other GPUs.

As might be imagined, the chip was months late, and only made it out the
door with reduced clocks and terrible yields. TSMC's problems at the 40nm
node was partly responsible for the troubled chip's delay, but the
impressive single-generation jump in the card's GPGPU feature set also had
a hand. NVIDIA architects were not ignorant of this risk, but judged it a
worthwhie one; an uncharacteristic move from a graphics company. What
pushed NVIDIA to focus so much on compute?

In a word, Intel. Larrabee, the larger company's skunkworks project to
develop stripped-down x86 CPUs with GPU-like vector extensions had the
potential to grind away NVIDIA's enterprise compute abilities, not because
of Larrabee's raw performance but because of its partial compatibility with
legacy x86 code. These chips would be far more power-hungry than any GPU,
but NVIDIA felt backward compatibility and a simplified learning curve
would woo developers away from CUDA, leaving them a niche vendor in the
enterprise compute market. Worse, Sandy Bridge, the new CPU architecture,
was to include a GPU on-die, potentially cutting out NVIDIA's
largest-volume market segments. NVIDIA's response was to invest in Tegra,
their mobile platform, and to make Fermi an enterprise-oriented,
feature-laden, unmanufacturable mess.

Well, Larrabee was all but cancelled, Sandy Bridge graphical performace is
decidedly lackluster, and TSMC got their 40nm process straightened out,
leaving NVIDIA room to prepare the GF110 and GF114 architectures powering
the GTX 500 series. These chips are almost identical to their respective
first-generation Fermi counterparts at the system design level; tuning at
the transistor level, however, greatly improved yield and power
consumption, making these devices graphically competitive at their price
level.

The GF104 and GF114 have slightly reworked shader cores as compared to
their GF1x0 counterparts. We discuss the conceptually simpler GF110 here,
and cover the superscalar GF114 [TODO: in a sidebar?] after introducing the
Cayman architecture.

### Shader multiprocessors

NVIDIA refers to the smallest unit of independent execution as a *shader
multiprocessor*, or SM. This is absolute marketing bollocks. We call it a
core.

[FERMI DIAGRAM] (either RWT, B3D, or home-grown)

Each core in GF110 contains a 128KB register file, two sets of 16 ALUs, one
set of 16 load/store units, and a single set of 4 special function units.
It also contains two warp schedulers, assigned to handle even- and
odd-numbered warps, respectively. This area is partitioned so that the
ALUs, SFUs, memory, and likely register file [TODO: check] run at twice the
rate of the warp schedulers and other frontend components. We refer to the
clock driving the ALUs as the "hot clock", and likewise the "cold clock"
for the rest of the chip.

Every thread in a warp executes together. At each cold clock, a warp's
instructions are loaded by the scheduler and issued to the appropriate
group of units for execution. Normal execution for all 32 of a warp's
threads takes a single cold clock, followed by result writeback. This
process is pipelined; it takes 11 cold cycles [TODO: verify this on Fermi]
for a register written in a previous instruction to become available.

As mentioned previously, there is no register forwarding during pipelined
instructions. In fact, every thread sees this delay between one instruction
and the next, regardless of data dependencies [TODO: verify on Fermi]. On
NVIDIA architectures, this is hidden by cycling through all warps which are
resident on the core and executing one instruction from each before
returning them to the queue. This is done independently for each warp
scheduler.

The SFUs, which handle transcendental functions (`sin`, `sqrt`) and
possibly interpolation, are limited in number. When dispatching an
instruction to that unit, it takes 8 hot clocks to cycle through all 32
threads of a warp. This stalls one warp scheduler for that duration, but
doesn't interfere with the other; if the current thread in the other
scheduler is waiting on access to that hardware, an NVIDIA-specific
hardware component called the "scoreboard" marks the thread as unready and
skips it until the required transactions complete.

This same scoreboarding approach handles the highly variable latency of
memory instructions. Each load/store operation appears to take a single
instruction to execute, wherein the resulting transaction is posted to a
queue; when the result is returned, another cold cycle is spent in the
load/store units to move the result from cache to the register pipeline.
Some memory transactions, including L1D cache hits and conflict-free shared
memory access, appear to complete in a single cold cycle.

Using thread-swapping is an elegant and simple way to hide latency, but it
has an important drawback: the only way to avoid a stall is to always have
a warp ready to run. Register file latency puts a hard lower bound on the
number of threads required to reach theoretical performance, but memory
access patterns can easily raise that number. Each of those threads,
however, must contend for a limited register file, shared memory space, and
bandwidth. Finding the right configuration to maximize occupancy without
losing performance from offloading registers to private memory will be a
theoretical and experimental challenge while developing our approach.

### Memory architecture

The GF110 has a flexible memory model. Its most distinguishing feature
among other GPUs is the large, globally-consistent L2D cache; at 128KB per
memory controller across the Fermi lineup, GF110 has 768KB of high-speed
SRAM to share across its cores. All global and texture memory transactions
pass through the L2D, which uses an LRU eviction policy for its 128B cache
lines, although an instruction can mark a cache line for discard
immediately or upon being fully covered by write operations. The latter
mode improves performance when threads perform sequential writes.

Each core has a 64KB pool of memory which can be split to provide 16KB of
shared memory and 48KB of L1D cache, or 48 and 16KB respectively. All
global reads must use this cache, although writes are handed straight to
L2D, invalidating the corresponding cache line in L1D in the process. While
the L2D is always globally consistent, L1D is only consistent across a
single core; writes to global memory from one core will *not* invalidate
the corresponding cache lines in a neighboring core. Volatile loads treat
all lines in L1D as invalid, but that flag only applies to memory
instructions, not to addresses.

Each work-group is assigned to a single core for the duration of its
execution. Each thread acquires its registers and local memory as the
work-group is assigned, and the work-group acquires shared memory; these
resources are not released until the work-group is complete. This also
indicates that

Shared memory is allocated to a work-group

Atomic operations in Fermi are available on both global and shared memory.
Shared-memory atomics are implemented using

A limited number of atomic operations on shared memory are supported. A
broader set is available

TODO: finish

### Instruction set

Brief description of how RISC-like PTX is very relevant? Or push this until
later?

## Closer look: AMD Cayman

General info.


### Cayman cores

Divided into cores, with 16 lanes of VLIW4 execution units. 64-wide
effective split. Each lane executes the same operation over 4 cycles;
VLIW4 handles parallelizable computations, but can be underscheduled in
case of register dependency (which happens frequently).

Wavefront method of latency hiding. Instead of scoreboard, clauses are
used, which always execute to completion on a given unit. Considerably
simpler design allows higher peak theoretical performance but requires a
much smarter compiler. Combination of explicit and external predication.

### Memory architecture

Incoherent global read and write caches, separate texture caches. Slow
atomics.

### Instruction set

Because of VLIW, and frequent architecture changes, should definitely use
OpenCL-level code instead of assembly.

## Vectorization and theoretical performance

  - GF100/GF110 dispatch has two single-issue schedulers for two ALUs, one
    transcendental, one LD/ST, and one interp. In pure-FMA code, such a
    part can be expected to attain its rated FLOPS consistently.

  - GF104/GF114 dispatch actually has two dual-issue schedulers with
    look-ahead.  To attain the peak rated SP FLOPS in pure-FMA code, at
    least one warp must have an instruction within the look-ahead window (4
    instrs) that does not have a serial dependency on the current thread or
    on any pending memory transactions. If this doesn't happen, the
    performance hit is 33% from the stated maximum. In practice,
    straight-ALU code (with no transcendentals, memory, etc) is rare, and a
    bit of assembly optimization (added by the driver at run-time) is
    enough to make full performance a realistic goal.

  - By constrast, AMD's static scheduler is free to extract any level of
    parallelism it can. However, since memory ops can't be interleaved and
    predication is limited, and since the thing has to schedule four lanes
    per thread independently to do FMA, practically all workloads will
    suffer a performance hit from insufficient vectorization. Worst-case,
    that performance hit is a whopping 75%.

  - In practice, the compiler manages to get about 50-60% of Cayman's
    theoretical workload performance in games, which (not coincidentally)
    makes parts at the same price level from both manufacturers similar in
    real-world performance. Hard to know in advance which will be faster
    for us.

Note: this section might well be axed.

## Bibliography

In the current mode, bibliographies get tacked on to the end of each chapter
without a heading so that you don't need to skip around as much while editing
the document. In the final version, they will be grouped together where-ever we
want to put them. This section is only here as an example, and will be removed.
TODO: remove this

