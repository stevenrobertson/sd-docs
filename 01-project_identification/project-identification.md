% GPU Implementation of the Fractal Flame Algorithm
% Steven Robertson; Nick Mejia; Michael Semeniuk; Matt Znoj
% January 31, 2011

# Project information

## Other contributors

[Erik Reckase](mailto:flam3dev@forethought.net) is the current maintainer of
the [flam3](http://flam3.com) library, and has expressed interest in providing
technical guidance for this project and incorporating it into flam3 when it is
complete.

[Vitor Bosshard](mailto:algorias@gmail.com) develops
[fr0st](http://fr0st.wordpress.com/), a front-end to flam3. Vitor has also
expressed interest in integrating our project into his software to enable
real-time manipulation.

# Narrative description

## Motivation

\begin{wrapfigure}{r}{0.35\textwidth}
    \begin{center}
        \includegraphics[width=0.32\textwidth]{electricsheep.244.22897.png}
    \end{center}
    \caption{An example fractal flame, from the Electric Sheep project.}
\end{wrapfigure}

The fractal flame algorithm produces images strikingly beautiful still and
moving images. Each flame is constructed from a limited number of parameters,
which enables flames to be manipulated procedurally; [Electric
Sheep](http://electricsheep.org), a distributed computing experiment which uses
machine learning and user feedback to drive the creation of its content, has
been successfully running for 12 years and boasts hundreds of thousands of
users. Human-designed flames are also popular; professional artists like [Cory
Ench](http://www.enchgallery.com/) use that same parameter space to create
stunning digital artwork.

The flame algorithm does suffer from a considerable limitation: it's slow. Or,
rather, its primary implementation is. The flame algorithm is based on
stochastic evaluation of an iterated function system, and computational
complexity grows quadratically with image size and exponentially with desired
quality. The core implementation is CPU-based, and although it has been
somewhat tuned for performance, it still takes a considerable amount of time to
render a single high-quality flame, much less an animated sequence of them.
This precludes many possible applications of the flame algorithm, as CPU-based
realtime rendering is firmly out of reach. As a result, the algorithm seems
ripe for a GPU implementation.

So ripe, in fact, that several GPU flame implementations already exist. Based
on either CUDA or OpenCL, these libraries vary in approach, performance, and
capability. The accelerated renderers do indeed work much faster than the
reference implementation. However, no GPU renderer to date is capable of
producing images that are similar enough to be used in an animation alongside
CPU-rendered flames, a requirement that prevents the flam3 project from
adopting any such implementation. Perhaps more tellingly, no implementation
exceeds (or even matches) the perceptual quality of flam3's output, which might
warrant outright replacement of the reference implementation.

Experience[^expr] suggests that this lack is not simple carelessness on the
part of implementers, but rather a result of both the general challenge of
writing algorithms optimized for the GPU, and particular aspects of the flame
algorithm which are hard to adapt to massively parallel devices. Some of these
hindrances are a result of current-generation GPU hardware architecture, but a
surprising number of them are actually imposed in software by the development
environment.

The goal of this project is to implement a fractal flame renderer on the GPU.
To do that, we need to overcome the problems which plagued previous attempts.
Rather than follow existing attempts by hacking around limitations in existing
GPU programming environments, we intend to construct a development environment
which avoids the software pitfalls in OpenCL and CUDA, and helps mitigate
hardware limitations. Development of the flame renderer and programming
environment will be done in parallel; experiences with each will inform the
other.

[^expr]: One team member created the first implementation of the flame
algorithm for GPUs in 2008.

## Goals and Objectives

- Independently implement a working version of the fractal flame algorithm.

- Develop a ruthlessly optimized, composable, typesafe dialect of CUDA.
  Implement portions of a standard library with it.

- Develop a concrete and functionally complete understanding of GPU performance
  (for the particular architecture we select through target microbenchmarking
  and statistical analysis.

- Using the knowledge gained through microbenchmarking, rewrite the fractal
  flame algorithm for GPUs using the aforementioned dialect.

- Document, develop, implement, and test new optimization strategies to
  improve the speed of the renderer.

- Use statistical, graphical, and psychovisual techniques to improve the
  perceived quality per clock ratio.

- Apply resulting renderers in real-world applications, including but not
  limited to:
    - Music visualization
    - Reactivity to environment
    - Real-time interactivity
    - Real-time evolution using genetic algorithms and user feedback

# Function

This project is entirely software-based. Nevertheless, it is tightly coupled
with a particular GPU architecture, and a successful outcome will depend on a
deep understanding of the internals of this "supercomputer-on-a-card". Thus,
the GPU should be considered the first layer of the project's function.

Programming for the GPU is unusual and challenging, made more so by the degree
of abstraction imposed by sticking to C/C++ as the template language. A
complete implementation of the fractal flame algorithm in these languages would
require either unmanageably large numbers of branches (which are very expensive
operations on GPUs) or a series of stack-based function calls from within the
inner loops (which are *even more* expensive). In light of this and other
problems, we need to develop a new approach to programming GPUs. This approach
will form the second layer of the project.

On top of the new programming method, we will also need to construct a few
system routines on the GPU, including an asynchronous memory allocator,
asynchronous 'printf' facilities, thread dispatch, interchip synchronization,
and a testing framework. These facilities will be used by all GPU kernels.

The 'iterate' kernel produces data through stochastic sampling of an iterated
function system. This kernel will initially contain the most code, yet will
likely remain the simplest component, as it is essentially a straight
translation of the math involved. The output is a stream of unfiltered data
points.

The 'accumulate' kernel accepts input from the iterate kernel and accumulates
it in the unfiltered buffer. Initially, this kernel is expected to be quite
simple, and can be directly coupled to the iterate thread. However, a naïve
implementation is expected to perform two orders of magnitude worse than an
optimized one, and will easily bottleneck the iterate kernel. It is expected to
be the subject of careful and thorough optimization.

The 'filter' kernel will initially perform log-density filtering and density
estimation for variable-width convolution subsampling. This part of the fractal
flame algorithm is psychovisual in nature, and takes a considerable amount of
time to complete; while it functions acceptably well, modern techniques from
the real-time rendering community may be able to significantly enhance it.

The 'sync' kernel will manage intra- and inter-chip communication, memory
allocation, and adaptive rate control in real-time situations.

On the CPU side, a server process will manage the dispatch and coordination of
frames to one or more cards. The process will support a simple socket-based
control mechanism for both local and network rendering, and on-the-fly
compression for streaming the resulting images. The process will also be able
to display the result (including previews for extremely large / slow renders)
on the rendering system using an embeddable OpenGL window.

Additional components can connect to the server process using the socket API.
The nature and scope of these external components will be determined by
available time, but will at a minimum include a backend for the fr0st flame
design software.

# Specifications and Requirements

Only two classes of processors currently exist which are capable of delivering
a suitable cost/performance ratio: GPUs by AMD and NVIDIA.  AMD GPUs, while
capable of sustaining a larger rate of raw computation, lack the cache and
synchronization primitives necessary to implement the flame algorithm
efficiently. Older NVIDIA GPUs are also unsuitable. The only products capable
of supporting this algorithm are based around NVIDIA's Fermi microarchitecture.

Fermi parts conform to CUDA Compute Level 2.1, which imposes the following
limitations:

    - 32-wide vector operation ("warp") width
    - 1536 threads per multiprocessor
    - 32768 registers per multiprocessor
    - 48KB shared memory per multiprocessor
    - 16KB L1 cache per multiprocessor

These limitations do more than impose an upper bound on the performance of this
device; together, they also set lower bounds for certain parameters. For
example: due to deep pipelining, each 32-thread warp may only execute once
every 22 cycles. If every warp performs pure computation, a minimum of 704
threads per SM is necessary to fully utilize the device. Accessing memory can
stall a warp temporarily, so that minimum figure must be increased by the
proportion of time a warp may spend waiting for memory. Main memory accesses
take several hundred cycles, so it is advantageous to have as many threads as
possible — but then the number of registers per thread is reduced. This
multidimensional give-and-take is an integral part of designing
high-performance algorithms for GPUs.

A goal of this project is to render a flame animation in real-time. To do
quality factor 10 at a resolution of 800x600 and a framerate of 20 frames per
second, 9.6 million iterations of the algorithm would need to occur, producing
at least 9.1 GB/sec of data across five radix sort passes and two filter
passes. On a single, top-of-the-line GPU, capable of executing 1.5 TFLOPS, each
operation must complete in no more than 225 cycles, including amortized filter
cost. This ceiling is unrealistically low; it is quite likely that multiple
GPUs will need to work in parallel to produce such an image.

Another goal of this project is to render flames in higher quality than the CPU
implementation. This goal is independent of the previously-listed one. Desktop
hardware performs single-precision computation between 4 and 16 times faster
than double-precision computation, and the additional bandwidth required for
intermediate data values would further constrain performance. As a result,
"performance" and "quality" modes will operate differently. Performance mode
will be limited to a resolution of 4096×4096 at 8 bits per pixel, and use a
64-bit point log structure, while quality mode can generate images up to
65535×65535 at 16bpp, using a 96-bit point log structure.

Amazon Web Services offers EC2 instances which feature NVIDIA's professional
line of graphics cards; these devices perform double precision computation at
half the speed of single precision. These instances can be used to perform
quality-oriented renders, and to ensure that our software scales well across up
to eight GPUs.

# Project Block Diagrams

See the attached document for project block diagrams.

# Project Budget and Financing

Description                                                  Quantity     Cost
------------------------------------------------------------ --------- -------
NVIDIA GTX 460 GPU                                                   1     N/A
NVIDIA GTX 560 Ti GPU (or equivalent)                                1 $270.00
Amazon EC2 GPU Compute instance hours                               50   $2.10
Total                                                                  $375.00

# Project Milestones

## First semester
- March 1
     - Unoptimized implementation of flam3 algorithm running on GPU, written in
       CUDA's C dialect.
     - `hsptx` capable of code generation and execution on GPU.
     - First reports from team members on potential avenues for optimization
       and alternate renderiing strategies
- April 1
     - Flame implementation ported to hsptx
     - flam3 library used to implement flame interpolation
     - First benchmarks of optimization techniques complete
     - Documentation on potential optimizations complete

## Second semester
- Fully functional, optimized flame algorithm working on GPU(s)
- Implementation of API finished
- Final benchmarks complete

# License

This document is under a
[CC-BY](http://creativecommons.org/licenses/by/3.0/us/) license. Images from
the [Electric Sheep project](http://electricsheep.org/), under the same license.
