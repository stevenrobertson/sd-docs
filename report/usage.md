# Usage and host-side API
\label{ch:usage}

Despite cuburn's internal complexity, its API is straightforward. Only two
user-facing modules are required to render a flame: `cuburn.genome` and
`cuburn.render`.

To load a JSON genome file, call `cuburn.genome.load_info` with the file's
contents as a string argument. This loads all genomes in the file, as well as
information about rendering parameters, if present. Pass this information to
`cuburn.render.Renderer` to create a new instance of that object. Use the
`compile` method to perform code generation, infer and store runtime
parameters, and attach the compiled module to the current CUDA context. Call
the `render` object with a list of `(name, start_time, end_time)` tuples,
producing a generator, and read the resulting `RenderedImage` objects from
that generator. [TODO: code example?]

## Behind the scenes

That one call to `render` does quite a bit.

Because it is a generator function, the `render` method is not necessarily
blocking. After the initial call to create the generator loads two frames into
the GPU's asynchronous task dispatch queue, each frame that gets read triggers
the dispatch of another frame for later reading. In blocking mode, if a frame
is requested when none is available, the thread will repeatedly sleep until a
frame is ready to return, allowing other tasks to execute in different
threads. When blocking is disabled, even this behavior is gone: the generator
simply returns `None` immediately if no frames are available. This allows
rendering to be used from, say, a GUI-driven application without the
inconvenience of threading *or* the performance loss that comes from
infrequent polling; since multiple frames are queued, polling only needs to
happen once per frame to keep the GPU at full load.

In order for this method to work, care must be taken to avoid conflicting use
of shared resources by asynchronously-scheduled kernels. On the other hand,
strict serialization of kernels reduces performance, as it does not allow
proper load-balancing — important in cuburn due to the use of unusually
long-running kernel invocations. Asynchronous dispatch therefore requires the
use of multiple, cross-synchronized CUDA streams, ensuring that asynchronous
work which does not result in buffer conflicts is free to proceed until shared
resources need once again be handled individually.

There are three contested resources which must be synchronized: the point log,
used as the destination of iteration samples and the source for sorting; the
accumulation buffer, used as the destination for the entire iteration process
and the source for density estimation; and the final output buffer,
destination of color filtering and source for the host-to-device copy. Each
source has its own stream, and events are injected into the destination
streams to act as barriers to prevent one stream from outpacing another in a
manner that could cause inconsistent access.

To allow for asynchronous processing by the host, there are two independent
device buffers that are preallocated for asynchronous copies. The generator's
control logic only yields a buffer when it has been copied, and queues
everything up to the next overwrite of that buffer on the device before
yielding it again. When the next iteration begins, the previous buffer is
reclaimed. This ensures that the current buffer is never overwritten by
asynchronous DMA while in use by the application.

An instance of this asynchronous dispatch architecture is depicted in an
abbreviated form in Figure \ref{fig:task_model}.

\begin{figure}
\centering
\Oldincludegraphics[height=8.5in]{task_model}
\caption{One example of the task dispatch pattern for a particular
flame animation rendered using deferred writeback. Solid arrows indicate host
dispatch order; dashed arrows indicate buffer contention and event barriers;
vertical order within a stream indicates mandatory execution order; vertical
order between streams indicates expected execution order. Tasks that may block
are represented by boxes with rounded corners.}
\label{fig:task_model}
\end{figure}

A curiosity of this architecture is that the `render` method is a single
monolithic function. This is not an example of poor programming practice or
lazy design, but rather a cautious and proactive choice intended to make
development easier and program operation more reliable. Inside the rendering
function, dozens of resources on both the host and the device must be
obtained, many of which depend on values calculated during the allocation of
previous resources. Using a single, local namespace for these values ensures
that the complex, interrelated calculations are all present in a single file
for easy inspection, modification, and documentation. These parameters are
never accessed outside of the render loop, so a more modular, object-oriented
approach would have added overhead and almost certainly introduced additional
bugs resulting from repeated calculations drifting out of sync with revisions
to different files. This also enables more accurate tracking of resource
lifetime, as Python's reference tracking occasionally frees device resources
too aggressively as they pass out of scope, resulting in stalls due to
synchronization barriers imposed by CUDA on deallocation functions.

## Command-line use

Cuburn also comes with a command-line client. This client includes several
options to make convertingn and rendering an animation from an XML genome
easier, as well as a simple OpenGL interface which displays frames as they are
rendered. The documentation for the command-line interface is repoduced in
Figure \ref{fig:usage}.

\begin{figure}[htb]
\begin{Verbatim}
usage: main.py [-h] [-g] [-j [QUALITY]] [-n NAME] [-o DIR] [--resume] [--raw]
               [--nopause] [-s TIME] [-e TIME] [-k TIME] [--renumber [TIME]]
               [--qs SCALE] [--scale SCALE] [--tempscale SCALE]
               [--width PIXELS] [--height PIXELS] [--test] [--keep] [--debug]
               [--sync] [--sleep [MSEC]]
               FILE

Render fractal flames.

positional arguments:
  FILE               Path to genome file ('-' for stdin)

optional arguments:
  -h, --help         show this help message and exit
  -g                 Show output in OpenGL window
  -j [QUALITY]       Write .jpg in addition to .png (default quality 90)
  -n NAME            Prefix to use when saving files (default is basename of
                     input)
  -o DIR             Output directory
  --resume           Do not render any frame for which a .png already exists.
  --raw              Do not write files; instead, send raw RGBA data to
                     stdout.
  --nopause          Don't pause after rendering when preview is up

Sequence options:
  Control which frames are rendered from a genome sequence. If '-k' is not
  given, '-s' and '-e' act as limits, and any control point with a time in
  bounds is rendered at its central time. If '-k' is given, a list of times
  to render is given according to the semantics of Python's range operator,
  as in range(start, end, skip). If no options are given, all control points
  except the first and last are rendered. If only one or two control points
  are passed, everything gets rendered.

  -s TIME            Start time of image sequence (inclusive)
  -e TIME            End time of image sequence (exclusive)
  -k TIME            Skip time between frames in image sequence. Auto-sets
                     --tempscale, use '--tempscale 1' to override.
  --renumber [TIME]  Renumber frame times, counting up from the supplied start
                     time (default is 0).

\end{Verbatim}
\caption{Usage information for the command-line cuburn application.}
\label{fig:usage}
\end{figure}

\begin{figure}[htb]
\ContinuedFloat
\begin{Verbatim}
Genome options:
  --qs SCALE         Scale quality and number of temporal samples
  --scale SCALE      Scale pixels per unit (camera zoom)
  --tempscale SCALE  Scale temporal filter width
  --width PIXELS     Use this width. Auto-sets scale, use '--scale 1' to
                     override.
  --height PIXELS    Use this height (does *not* auto-set scale)

Debug options:
  --test             Run some internal tests
  --keep             Keep compilation directory (disables kernel caching)
  --debug            Compile kernel with debugging enabled (implies --keep)
  --sync             Use synchronous launches whenever possible
  --sleep [MSEC]     Sleep between invocations. Keeps a single-card system
                     usable. Implies --sync.
\end{Verbatim}
\caption{Usage information for the command-line cuburn application
(continued).}
\end{figure}

