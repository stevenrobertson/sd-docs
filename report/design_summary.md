# Design summary

Cuburn is a Python library for rendering fractal flames on the GPU. This
chapter provides an overview of the operation of this library.

## Device software

After host-side initialization, a frame rendering begins with an invocation of
the interpolation function constructed for the current genome (Chapter
\ref{ch:accum}).  During interpolation, the splines representing an animation
are loaded from global memory, interpolated against at the current control
point time, and optionally used as the input of more complex functions to
produce control point parameters. Many control points are evaluated
simultaneously, and the results are stored in a global memory array.

An iteration kernel plays the chaos game, evaluating the trajectory of
individual points as they pass aroudn the attractor. The iteration kernel is
carefully tuned for high occupancy. When the kernel is generated to operate in
deferred mode, it is ALU-bound, and so care is taken to avoid warp divergence
without resulting in trajectory convergence (Chapter \ref{ch:funsel}). Each
iteration of the kernel produces an image sample, which is stored to a sample
log on the device in a condensed format (Chapter \ref{ch:accum}).

A sort engine built for this project (Chapter \ref{ch:sort}) efficiently
rearranges the sample log's contents for efficient histogram generation.  The
sort engine is a scan-based radix sort, although it makes extensive use of
low-level hardware features in a manner that differs from most other GPU radix
sorts to attain record-setting levels of performance.

After the functions comprising the sort engine have concluded, the log is
processed by an accumulation function (Chapter \ref{ch:accum}). This function
uses shared memory to generate a histogram of the logged trajectory data
quickly and accurately. Since memory is limited, the point log is finite, and
often too short to contain a full image's length of samples; therefore, the
process of iterate, log, sort, and accumulate usually repeats several times
before the next stage is reached.

Density estimation with antialiasing correction is applied to the generated
full-scale image (Chapter \ref{ch:filt}). This step, along with colorspace
conversion and out-of-bounds clamping, is used to convert the generated
histogram buffer into a low-dynamic-range image. The image is then sent via a
memory copy to the host, where it is compressed in the current output format.

## Host software

The cuburn library uses NumPy extensively and returns buffers as NumPy arrays,
meaning applications using cuburn as a library will also need to use NumPy for
numerical manipulation.  Internally, cuburn also depends on PyCUDA and Tempita.
When using XML genome files, cuburn additionally depends on fr0stlib and
libflam3 to perform conversion. A cuburn client application can be constructed
in under ten lines of Python code, and an example command-line application
which provides a rich set of options is available for non-programmers to use.

Despite a simple API, the control flow of the rendering process is complex. An
example internal flow is provided in Figure \ref{fig:host_design}.

\imfig{design_summary/host.pdf}{The host-side workflow of the example
application. This diagram describes the workflow of the most recent Windows
port.  The most recent development version differs slightly, and no longer
follows a fixed dispatch pattern.}{fig:host_design}

Cuburn relies heavily on runtime code generation to attain both speed and
flexibility (Chapter \ref{ch:dynamic}). Kernels are generated before rendering
starts in response to analysis of both the genome to be rendered and the
hardware it is to be rendered on. The code needed to render the genome is
computed in multiple passes, each pass adding additional auxiliary information
to prepare the next pass, and then sent to `nvcc` for compilation. A final pass
performs "monkey-patching" of opcodes in place to work around the absence of
certain hardware instructions from the PTX ISA. The module is then loaded in
the current CUDA context, allowing it to be used for host computation.

Resource allocation is performed at the call to the `render` function (Chapter
\ref{ch:usage}). This function masks complicated asynchronous dispatch behind
the Python generator API; in most cases, a Python `for` loop or `imap`
statement is all that is needed to read and process frames. When the function
exits, Python's reference management system cleans up outstanding references,
setting the CUDA context up for further rendering or a clean exit.


