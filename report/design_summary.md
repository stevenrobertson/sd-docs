# Design summary

This implementation of the fractal flame library is split into several Haskell
libraries, with a small front-end application for demonstration purposes.
Together, these programs build, run, and retrieve the results of a CUDA kernel.
The actual rendering is done entirely on the CUDA device.

## Host software

This project will produce a platform-independent console application that will
accept one or more flames in the standard `flam3` XML genome format and save a
fractal flame image for each input flame. More elaborate applications, such as
a long-running process with socket communication for use in quasi-real-time
applications such as the `fr0st` fractal flame editor, are expected to be
produced, but these applications fall outside the scope of this document. The
high-level flow of the rendering application is depicted in Figure [FIG].

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

[TODO: go into excruciating detail]

<!--
- flam3-types: various interpolation strategies. Somewhat heavyweight library.
  Eventually, may want to move away from binding flam3 to allow for more
  flexibility in interpolation, and exploration of genome manipulation without
  the full set of Haskell dependencies.

- flam3-hs: A standard Haskell FFI binding. Wraps only a small subset of the
  functions in that library, but that's all we need. To preserve
  forward-compatibility against data structures that are added to from release
  to release, the library only allows transforms to be read in binary format,
  another reason why it's good we split types off.

- While not mentioned above, Shard forms the underpinning of the `cuburn`
  library; the device code contained in `cuburn` is actually written entirely
  in the Shard language. Shard is still in the prototype stage.

- cuburn: contains the Shard code. Also contains a number of helper functions.

## Host-device interaction

After the kernel is uploaded to the device, certain execution resources — those
that will remain resident across the lifetime of the kernel — are prepared by
the software. These resources include the initial states for the per-thread
multiply-with-carry random number generators (described further in Chapter
\ref{ch:rng}), the global accumulation buffers, and the global fast-allocation
pool.

To begin rendering, the host invokes the rendering kernel across the device
according to the execution pattern determined during the compilation process.

-->

## Device software

[REF: the rendering, accumulation, and filtering kernels are really separate]

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

### Rendering kernel

Upon invocation, a rendering thread uses its global thread ID to load a unique
random state.  This state is kept resident for the duration of the thread's
execution, and is updated in global memory by the thread as it exits. This
action is also performed by the accumulation and filtering kernels upon a
distinct set of states. Other rendering-specific actions include setting the
consecutive bad value flag to trigger point regeneration and initial point
fusing [REF previous discussion of fuse] and clearing the buffers in shared
memory.

Threads in a work-group operate on a single control point at a time. This
control point is selected through atomic access to a global counter, which acts
as an index into a global array of control points; once the index reaches a
maximum value, all control points have been processed, and the rendering thread
exits. The control point select index is a fixed multiple of the number of
control points in an image, allowing multiple work-groups to operate on the
same control point simultaneously. This increases the efficiency of the global
cache and balances workload across cores.

