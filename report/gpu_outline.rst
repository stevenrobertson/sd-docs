A brief tour of the modern GPU

- GPUs are the most inexpensive way to get a teraflop in the same memory
  space; best overall performance characteristics for many algorithms

- To accelerate the fractal flame algorithm, GPUs are the obvious choice

- Necessary background information will be referenced throughout the
  document

- In this section, we'll discuss the OpenCL compute pipeline, which subsets
  the various alternatives; then we'll take a look at implementation
  details which affect all major architectures. We'll also discuss parts of
  OpenGL that are relevant.  Finally, we'll look into the architecture of
  the latest parts from NVIDIA and AMD.

- OpenCL overview

  - OpenCL 1.1, Khronos group

  - "Embarrassingly parallel"

  - Host and device. Separate memory space, asynchronous execution;
    synchronous events emulated by polling.

  - Kernel, or instruction stream. Kernel is fixed; no JITing on device.

  - Constant memory.

  - Thread (work-unit) executes the kernel. Has limited number of registers
    available for storing state, including PC. May branch; may do memory
    scatters and gathers at any time. Has private memory.

  - Writes to main memory have no guaranteed ordering. Further, main memory
    is very slow. Atomics exist but should be avoided whenever possible.

  - Threads are collected into work-groups. Work-groups all execute the
    same program; have access to shared memory and some limited barriers to
    establish ordering. Each thread can access its local ID (within the
    workgroup) and global ID (within the set of all work-groups), which
    becomes important for control purposes.

- OpenCL implementation: shared approaches

  - Vectorization width, predication and divergence.

  - Memory coalescing, and how much of a bitch it can be. Avoid random.

  - Register and memory latency, and thread over-provisioning. The state
    size trade-off.

- OpenGL: influence, shared features

  - Rendering graphics first. Shading language origins.

  - Texture units.

  - Copy to texture. Opaque tex / surf instructions.

- NVIDIA's implementation

  - CUDA, which predated OpenCL. Terminology upheaval.

  - Divided into SMs. 32-wide effective split. Actually implemented as 3
    ALU / 1 LS / 1 SFU per block, etc. This is hidden; each lane executes
    the same operation.

  - 16/48 or 48/16 shared/L1D split.  Compiler-automated register spilling.
    Seems to move entire cache lines to/from L1. L2 bandwidth not
    astounding, but no random-access penalty. Rich atomics, barriers.

  - (N) warps per SM. 22-cycle regfetch latency and dual-issue scheduling
    set minimum bounds. Scoreboard handles memory stalls by rescheduling.
    Net effect is that, while algorithms must be parallelized, individual
    operations don't need to be, which is kind of a big deal.

  - Single program stream; all ops can be predicated per-lane; divergence
    per-lane is allowed at linear cost.

  - Quadratic approximation for transcendentals.

  - RISC-like instruction set; intermediate assembly format allows
    compatibility of compiler architecture between hardware generations.

- AMD's implementation

  - Standardized on OpenCL

  - Divided into cores, with 16 lanes of VLIW4 execution units. 64-wide
    effective split. Each lane executes the same operation over 4 cycles;
    VLIW4 handles parallelizable computations, but can be underscheduled in
    case of register dependency (which happens frequently).

  - Tex and constant cache, inconsistent read and write cache. (Atomics?
    Barriers?)

  - No scoreboard, instruction dispatch. Instead, clauses are used, which
    always execute to completion on a given unit. Considerably simpler
    design allows higher peak theoretical performance but requires a much
    smarter compiler.

  - Two active wavefronts per core that trade off to hide register latency.

  - Combination of explicitly and externally predicated

  - 3-term Lagrange polynomial interpolation for transcendentals.

  - VLIW instruction set; frequent and deep changes to the hardware. Better
    off using their backends.

- Sidebar: Vectorization and theoretical performance

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


