# Design summary

This implementation of the fractal flame algorithm is split into several
Haskell libraries, with a small front-end application for demonstration
purposes. Together, these programs build, run, and retrieve the results of a
CUDA kernel. The actual rendering is done entirely on the CUDA device.

This chapter provides an overview of the method of operation of the software
produced as part of this project. It also includes background information and
rationale on those portions of the project which have not been covered
elsewhere in the document.

## Host software

This project will produce a platform-independent console application that will
accept one or more flames in the standard `flam3` XML genome format and save a
fractal flame image for each input flame. More elaborate applications, such as
a long-running process with socket communication for use in quasi-real-time
applications such as the `fr0st` fractal flame editor, are expected to be
produced, but these applications fall outside the scope of this document. The
high-level flow of the rendering application is depicted in Figure
\ref{fig:host_design}.

\imfig{design_summary/host.pdf}{The host-side workflow of the example
application.}{fig:host_design}

The host application parses command-line arguments to determine operating mode,
and then loads a `flam3`-compatible XML stream, either through a specified
filename or through standard input. This information is then passed to the
`flam3` library via the `flam3-hs` bindings for parsing and validation. The
resulting flames are returned in a binary format that can be unpacked to a
genome type from `flam3-types`.

A control point near the center of the requested animation range is selected as
the prototype control point. This information, in addition to information about
the device gathered from the CUDA driver and from the running environment, is
passed to the `cuburn` library, where it is used to generate the CUDA kernel
and context for uploading to the device, as well as the functions needed to
pack control points for use by this algorithm.

A CUDA context is initialized in a bound thread, and the generated kernel is
loaded, where kernel-specific initialization is performed as needed by the
`cuburn` library. For each control point to be rendered, the program creates a
final image framebuffer, performs data-stream compaction on the interpolated
family of control points needed to render with motion blur, and schedules a
rendering with another `cuburn` command.

This rendering thread continues performing these steps until all images have
been scheduled. Once any render is complete, its final framebuffer is copied
from the device, and an output thread is spawned to save the contents of this
image to disk.

### `flam3-hs` and `flam3-types`

The `flam3` library is written in C, and is designed to be used as a dynamic
library. It uses POSIX facilities, and some features are only enabled when
compiling and linking with GCC. Cross-platform support is partially
implemented, allowing the library to be built on Windows with MSVC++, but the
process is not trivial. Additions of new features, such as variations,
filtering modes, and empirical algorithm tunings, require modifications to the
extremely large data structures used to store genome information. These
binary-incompatible changes require foreign function interfaces to be tightly
coupled to particular versions of `flam3`.

To ensure that code produced by this project is cross-platform and not strictly
dependent on particular `flam3` versions, the bindings to the flame library are
split across two libraries. `flam3-types` defines Haskell datatypes which are
capable of expressing a genome, as well as a basic parser for flames. The
genome datatypes are specifically crafted to allow maximum compatibility
without breaking type safety, so that later feature additions do not require
changes to existing code where-ever possible. `flam3-types` does not depend on
the `flam3` library, so that it is maximally portable.

For the purposes of interpolation and compatibility, `flam3-hs` provides
Haskell bindings to `flam3`. This requires linking to the `flam3` library,
which presents a number of practical problems on Windows; as a result, it is
possible to use the `cuburn` library without `flam3-hs`, although some features
will be disabled. This FFI library maintains forward compatibility with data
structures by preventing them from being serialized from their `flam3-types`
counterparts; while the raw data can be maintained for fast consecutive
function calls, the only means of turning a native Haskell genome into one
compatible with `flam3` is to use XML as an intermediate format.

### Shard and `cuburn`

The `cuburn` library contains the actual code used to render fractal flames.
The code is written in the Shard language for GPU programming, which is being
developed as part of this project. As an embedded domain-specific language,
Shard allows developers to build code at runtime for the GPU using ordinary,
pure Haskell expressions. This allows for complex analysis and optimization
efforts to take place without sacrificing functional purity or type safety.

`cuburn` also includes ancillary functions to help with generating and running
device code. It intentionally omits "all-in-one" rendering functions which
encapsulate the rendering process from start to finish, so that focus can be
placed on ensuring the interface for full control is straightforward enough for
common use. Management of CUDA state is also omitted; operations on CUDA
contexts are effectful, and a developer making use of this library must that
`cuburn` does not interfere with other CUDA activity in the same process.

The full API is not difficult to use; while the full flow presented in Figure
\ref{fig:host_design} may appear to be intimidating, it lends itself to concise
expression under idiomatic Haskell.

## Device software

Code on the device is split into either two or three kernels. Together, these
kernels form an implementation of the algorithm outlined in Chapter
\ref{ch:flame}. Each of these kernels is dynamically generated, for reasons
outlined in Chapter \ref{ch:dynamic}, so the workflow may differ from that
presented below.

Threads running the rendering kernel — henceforth simply a rendering thread —
run for the duration of a render. After loading initial data, the thread will
begin the iteration phase of the flame algorithm, computing an IFS sample for
the indicated control point. The generated points are efficiently recorded to
global memory buffers, and after a short intra-work-group communication, the
threads continue with another iteration. Once all iterations are complete, the
thread exits, allowing the device to begin computing subsequent commands.

Accumulation threads run alongside rendering threads, using memory hardware
while rendering threads remain mostly arithmetic in their operations. An
accumulation thread loads point record produced by rendering threads and
performs a sorting pass to group point records by address. When a group becomes
full, the accumulation threads then process it and add the accumulated results
to the global buffer.

After all rendering and accumulation threads complete on the device, the
hardware thread scheduler dispatches the filtering threads on the device. Each
filtering work-group cooperates to apply the steps necessary to convert the
accumulated color and density information into a final image. When these
threads exit, the device signals to the host that the image is complete, copies
the final framebuffer to the device, and begins rendering the next image.

### Rendering

Upon invocation, a rendering thread uses its global thread ID to load a unique
random state.  This state is kept resident for the duration of the thread's
execution, and is updated in global memory by the thread as it exits. This
action is also performed by the accumulation and filtering kernels upon a
distinct set of states. Other rendering-specific actions include setting the
consecutive bad value flag to trigger point regeneration and initial point
fusing [REF previous discussion of fuse], acquiring output queues, and clearing
the buffers in shared memory.

Threads in a work-group operate on a single control point at a time. This
control point is selected through atomic access to a global counter, which acts
as an index into a global array of control points; once the index reaches a
maximum value, all control points have been processed, and the rendering thread
exits. The control point select index is a fixed multiple of the number of
control points in an image, allowing multiple work-groups to operate on the
same control point simultaneously. This increases the efficiency of the global
cache and balances workload across cores.

The iteration loop begins with a test of the bad value flag to determine
whether a new random point needs to be generated, and a divergent branch to do
so if needed. The first thread in a warp then generates the transform select
value and broadcasts it to the rest of the warp. Threads then apply the
selected transform function to the current position and color values to obtain
a new IFS state [REF].

If the bad value flag is not less than zero — indicating that the point is
currently joining the attractor, and should not be written — and the point is
within image boundaries, the point is quantized by its thread into the record
format described in [REF].  The top six bits are used to select an output
queue, and the record is appended to the corresponding consolidation queue,
using the resolution algorithm described in [REF] to handle consolidation
flushes. The bad value flag is reset to zero.

If the point is outside of the image domain or joining the attractor, the bad
value flag is incremented. If the flag is originally less than zero, this may
cause it to move to zero, indicating that the point's trajectory has joined the
attractor and is ready to be written in subsequent threads. If it is larger
than a determined amount, indicating several consecutive invalid values, it may
have entered an expansive region of the function system, and will be rest at
the next iteration.

Once a sufficient number of valid points have been generated, the iteration
loop exits. The control point select index is tested to see if additional work
is queued; if more is available, the thread restarts, otherwise it exits.

### Accumulation

The process of moving samples from first-stage output queues to final
accumulators is handled by accumulation threads. A portion of the first warp in
an accumulation work-group performs an infrequent poll of a corresponding
portion of the global queue tree to determine when new work is available; when
it is, the entire work-unit wakes, takes ownership of the corresponding queue
buffers, and begins processing the first queue.

The accumulation threads perform two functions, depending on the queue being
processed. First-stage output queues contain point records over an address
range of as many as 17 bits. The output stage requires a range no larger than
10 bits, so there may be as many as 128 second-stage output queues per
first-stage queue. The accumulation thread is responsible for reading points
from the first-stage queue and writing them to the second-stage queue. This
sorting pass is almost identical to that performed by the first-stage output,
save for using a larger number of consolidation queues and obtaining points by
reading output queues instead of iterating directly.

Once a first-stage output queue is read, its buffers is returned to the main
buffer pool. After reading the contents of all first-stage output queues, the
second-stage queues within an accumulation work-group are examined to determine
if any are approaching a sufficient length for writeback to begin. If any are,
the accumulation work-group enters its second mode.

Processing a second-stage queue begins by taking ownership of all flushed
output buffers in the output queue, and clearing the internal accumulation
values in shared memory. Each value in the queue is then read and added to the
appropriate shared accumulator. As each buffer in the queue is read, it is
freed and returned to the global pool. After a queue has been fully processed,
the work-group once again waits for data by polling global memory.

[REF in here to writeback sections if/when they're done]

### Filtering

The filtering kernels perform the log scaling process described in Chapter
\ref{ch:coloring}, and one of the filtering mechanisms described in Chapter
\ref{filteringsection}. The log scaling information is applied per-pixel, and
maps cleanly to the traditional threading dispatch model employed in GPU
shading; while the particular method has considerable impact on the appearance
of the final image, the implementation is straightforward. On the other hand,
efficient implementation of filtering algorithms on GPU architectures can be
challenging, and almost always involves optimizations particular to the kind of
algorithm chosen, so there is little opportunity for a general description. In
both cases, full explanations of the processes involved are available in the
appropriate chapters.

