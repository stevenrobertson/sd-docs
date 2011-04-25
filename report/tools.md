# Tools and components

GPUs attain extraordinary peak performance by sacrificing generalizability.
Devices from NVIDIA and AMD present the same high-level model of massively
parallel computing, but — as shown in the previous chapter — these
architectures have significant differences at the implementation level.
Standards-compliant OpenCL code which does not rely on vendor-specific
extensions should run correctly on every compatible device without
modification, including the newest GPUs from both manufacturers; the standard,
however, offers no indication that the same code will achieve similar
*performance* across multiple architectures [@OpenCLSpec].

The flame algorithm is, in one sense, an embarrassingly parallel problem, and
thus fits well into the abstract model of computation offered by OpenCL. Yet,
as the rest of the document makes clear, the actual implementation of this
algorithm tests the limits of current-generation GPGPU hardware. Writing a
fractal flame renderer for the GPU is straightforward; writing one with
excellent performance is far more challenging, and requires a much deeper
knowledge of each architecture.

The scope of this project is considerable, and the performance goals are near
the theoretical upper bounds of current GPU architectures. Given the need to
take advantage of architecture-specific features, this project's software is
not likely to be portable between graphics architectures or compute platforms,
making a late-stage change in those decisions expensive. Meeting the
performance goals of this project without exceeding time or budget constraints
will require carefully selecting the tools with which it is built.

This chapter is an overview of that selection process and its result. Because
the optimizations required to implement the flame algorithm require support at
every level of the toolchain, those optimizations are an important part of the
selection process. However, the exact nature of those optimizations depends on
the results of the selection process. Consequently, tool selection is an
ongoing, iterative effort that may be subject to further change during initial
implementation. For this document, we break the dependency cycle by presenting
tool selection first and extensively referencing future chapters.

## GPU architecture

The fastest compute devices available to consumers, at time of writing, feature
AMD's Cayman or NVIDIA's Fermi architectures. Cayman devices have dramatically
higher peak theoretical performance values, but as discussed in Section
\ref{sect:cayman}, it can be difficult to reach peak throughput due to the
nature of the VLIW4 architecture used. In low-level optimization projects, it
may be tempting to believe that hand-tuned code can beat even the best
optimizing compilers; the pragmatic view, however, is that even if such an
extraordinary hand-tuning effort were to produce faster code, architecture
variations in the next GPU cycle would likely erase that performance gain. In
other words, there is a practical limit to how low a project of this scope can
delve for optimizations and still be successful. With that in mind, we accept
the general consensus on raw computing power — that Cayman and Fermi are
generally well-matched, and the winner is workload-dependent [@gtx590] — and
focus on other factors to choose an architecture.

AMD's architecture implements flow control using clauses [REF if this will be
covered earlier] which execute to completion; each clause specifies the next
clause to execute in its terminating condition.  Apart from indirectly enabling
higher throughput by simplifying scheduling, clauses provide the advantage of
temporary registers. NVIDIA cores allocate all local resources statically,
requiring each thread to consume its worst case number of registers at all
times, whereas Cayman and other AMD architectures allow non-persistent
resources to be shared. This could significantly increase occupancy of AMD
cores when the most complex variations are active, helping to hide latency. On
the other hand, NVIDIA's solution — provde an enormous 128KB register file per
core — tends to be sufficient to avoid this circumstance.

AMD executes clauses in wave-fronts [REF again if covered earlier] of 64
threads, whereas NVIDIA uses a 32-lane warp. Both methods accomodate the
producer-consumer relationships across vectorized execution units through
work-group barriers, but Fermi takes advantage of its particular vector width
by providing a number of instructions and virtual registers that enable
intra-warp communication without using shared memory. Warp voting is not a
common activity in graphics operations, but it is a required part of some of
the optimizations described herein, and in such cases Fermi holds a 32× lead.

\label{sect:globalshare}

Another key differentiator between the two compute platforms is the use of
cache in main memory access. Cayman devices have 512KB of read cache, and a
separate 64KB of write cache; the latter is used primarily to extract spatial
coherency from temporally-coherent data. The separation of concerns makes the
cache a less costly addition to Cayman devices than Fermi's full-featured L2,
but does little to accelerate random-access updates to values in global memory,
and can increase the complexity required to ensure consistency of global
values.

AMD's solution is the global data store, another 64KB chunk of memory shared
across all cores. This structure is intended only for inter-work-group
communication, providing fast and atomic access via a separate address space.
This anomaly is a useful tool for coordinating access to complex data
structures, but may simply be a stepping stone on the way to a full cache in
future architectures [@Kanter2010].  For the complex addressing patterns needed
to support full-rate accumulation, Fermi's L2 seems the more capable solution
for inter-thread communication.

The company behind Cayman has a history of being more open than its competitors
with technical information, a trend continued with its latest GPU offerings;
technical documentation on the Cayman ISA and other architectural features is
publically available. In principle, this is a big advantage over NVIDIA, who
hides most instruction-level details behind PTX, their cross-platform
intermediate language for GPU kernels. Unfortunately, for this project, the
practical advantages of PTX make it the better option. The intermediate
language provides access to nearly every feature of interest in NVIDIA's
hardware while preserving forward compatibility, and is optimized at runtime by
the driver to best fit each platform; writing a backend that emits PTX is
therefore a relatively straightforward task. Generating assembly for AMD
devices is more challenging, and a backend must target a set of primitives that
changes with each hardware generation while performing device-specific
optimization itself.  A more realistic solution to take advantage of low-level
instructions on AMD hardware is to precompile code for AMD hardware and
monkey-patch in memory [@whitepixel], but this task becomes much more
challenging with dynamically-assembled code.

There is no substitute for profiling live code; conjecture on the performance
of optimized code across multiple architectures is speculative at best. Given
the need to standardize on a single architecture, the information available
suggests that NVIDIA's Fermi is more likely to yield the highest performance
without overwhelming optimization efforts.

## GPGPU framework

OpenCL is, well, open. Its broad industry support, including stalwart backers
Apple and AMD, and adoption in the mobile computing space make it likely to be
the standard of choice for cross-platform development of high-performance
compute software [@Kanter2010a]. It also offers an extension mechanism, similar
to the one used in OpenGL, to offer a clean path for a vendor-specific hardware
or driver feature to become a part of the standard without breaking old code.
OpenGL's history presents evidence that vendor support of these extensions is
important in determining whether the standard will stay current and relevant.

Once again, however, NVIDIA's technological head-start in the GPGPU market is
large enough to warrant ignoring ideological preferences. Kanter notes that
OpenCL is "about two years behind CUDA [@Kanter2010]," a sentiment echoed by
many industry observers and supported both by a simple comparison of the
feature sets of both frameworks and by the authors' first-hand experience.

Due to the need to optimize the rendering engine to hardware constraints,
particularly with regard to components such as the accumulation process
(Chapter \ref{ch:accum}), porting this implementation across GPUs is expected
to be difficult. As a result, compatibility and standards compliance is not a
priority for this implementation. This implementation will therefore be based
on the CUDA toolkit, rather than OpenCL[^future].

[^future]: The authors are also planning an entirely new implementation which
should not be quite so *fussy* about the hardware parameters. This
implementation operates quite differently from the traditional flame algorithm,
and we're still working out the necessary mathematics, so it is not documented
here — but when it is ready to be implemented, we do intend to use OpenCL.

## Host language

The recommended host language for CUDA development is C++. The CUDA toolchain
includes compiler extensions and syntactic sugar to make many tasks simple, and
the device code compiler supports a subset of C++ features, including classes
and templates. Despite its name, however, the runtime API used for native C++
development with CUDA does not support run-time code generation, and is thus
unsuitable for this project. No host code lies in a performance-critical path;
without the tight integration offered by the CUDA toolchain, there is little
incentive to use systems programming languages like C or C++.

Python was strongly considered as a host language. Python is a dynamic,
interpreted programming language with high-quality bindings to CUDA and flam3.
Its rich object model, duck-typing of numerics, and monad-like ContextManager
allows for the extraction of instruction streams from "pure" mathematical code.
This approach was in fact followed by one of the authors before this project
began, resulting in the PyPTX library for dynamic GPU kernel generation
[@pyptx] and a modest but functioning prototype implementation of the fractal
flame algorithm on top of PyPTX [@cuburn].

Experimentation with PyPTX revealed shortcomings inherent in the expression of
EDSLs in Python. Inside a code generation context, operations on PTX variables
would trigger code generation, whereas normal operations would not; the
inclusion of a block of code in the output was contingent on whether that code
was evaluated on the host. It became extremely difficult to separate both host
and device flow, and complicated bugs would arise in edge cases along code
generation paths which could not be detected in advance.  For similar reasons,
the backtracking context needed to provide type and data inference in the EDSL
was complex and error-prone, and loops could not be tracked across host
function call boundaries. In short, Python's flexibility in host code provided
too many opportunities for improper code generation.

In place of Python, Haskell was considered. Haskell is a lazy, pure, functional
language with a remarkably expressive static type system and excellent support
for both traditional domain-specific languages (with excellent native parsers
such as Parsec and compile-time evaluation of native expressions using Template
Haskell) and embedded DSLs (via infix operators, rebindable syntax, and other
language features [@haskell2010]). The Haskell and Python communities are
intermixed, with both programmers and language features frequently crossing the
gap between the two [CITE], but at its core, Haskell's purity and type safety
make it an ideal host language to build run-time code generation facilities
that feature compile-time analysis [CITE].

Other languages were also considered. Ruby is considered to be EDSL-friendly
due to its rich, rebindable syntax [CITE], but as a dynamic language, it would
require reimplementing the same roundabout strictness measures as Python, with
no expected improvement. Despite also having rebindable syntax, Scala's
reliance on the JVM would complicate the memory model and FFI tasks, and would
require additional bindings to be written. Microsoft's F# is an interesting
effort from the company, but its type system inherits much from its
object-oriented underpinnings and is less suitable for expressing the desired
strong constraints.

<!--

## Interface language

- Dynamic compilation required.

- C-style templates? Oh, heck no. What a nightmare.

- Really, choice comes down to DSL versus EDSL. Explain more...

- Reference PyPTX, Shard somehow

- Final decision: SSA-based EDSL, with stackless recursive notation for
  loops. Easy to port to LLVM if we need to.

-->
