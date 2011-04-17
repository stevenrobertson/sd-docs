<!-- Use this command only once, in the first appendix of the document -->
\appendix

# Glossary

Between GPU computing, the fractal flame algorithm, signal processing, and
multiresolution analysis, describing this project requires a considerable
amount of often conflicting terminology. This reference may help resolve and
disambiguate unfamiliar terminology.

In cases where terminology is nonstandard or conflicting across the fields of
study involved by this project, the source of a term is provided. Only the
terms used in our project have entries; some terms may have alternate meanings
in other fields of study, but these are not listed here.

Accumulation buffer

~   The grid of accumulators used to store the results of a simulation.  The
    accumulation buffer may be of a higher resolution than the output buffer to
    accomodate FSAA.

Accumulator

~   An element of the accumulation buffer, storing density and color
    information. In `flam3`, these are called "buckets". In some IFS
    literature, these are called "histogram bins".

Accumulated sample

~   The value of an accumulator after all iterations have been performed.

Barrier

~   (CUDA) An instruction which will stall the warp which issues it until a
    condition is met, used for synchronization. OpenCL term is "work-group
    barrier", where OpenCL's "command-queue barriers" are used to build
    streams.

Command

~   (OpenCL) A task which a device must complete.

Core

~   The smallest unit of a device capable of completely executing a single
    instruction. Our usage explicitly conflicts with marketing material from
    both AMD and NVIDIA, which refer to each vector lane as a core, but is in
    line with industry parlance. (In some architectures, a core may be able to
    dispatch more than one instruction at a time to shared hardware resources;
    under this definition, it is still a single core, as the functional unit
    cannot be divided further.)

Decimation

~   (Multiresolution analysis) A reduction in the number of samples in a
    signal.  In our algorithm, as elsewhere, the term is assumed to refer to
    octave-band decimation, where a signal is downsampled by a factor of 2 in
    all dimensions.

Device

~   (OpenCL) A hardware unit which may execute commands, and which appears to
    run asynchronously to the CPU. In our case, one of the GPUs available in a
    system.

Flame

~	TODO: Talk about when somebody mentions a 'flame' in context to refering to the
	output of the algorithm
	
IFS iteration

~   An application of one transform function from an iterated function system
    to an IFS point to produce a new point.

IFS point

~   The vector resulting from a number of applications of transform functions
    to a starting vector.

IFS sample

~   The information about the shape of the attractor gained by performing an
    iteration.

Stream

~   (CUDA) A strictly ordered series of device commands. Ordinarily, devices
    may dispatch commands as soon as execution resources become available to do
    so; a command in a stream, on the other hand, is not started until the
    previous command in the stream completes.

Transform function

~   A member of an iterated function system, as described by an xform.

Warp

~   (CUDA) A group of threads that must execute the same instruction at the
    hardware level. Hardware and compiler tools allow a programmer to overlook
    warps without compromising code correctness, but optimal performance
    requires careful consideration of warps. This term technically applies only
    to NVIDIA devices, where AMD uses notionally similar but technically
    different "wave-fronts", and its use in this document is a compromise
    between correctness and clarity.

Work-group

~   (OpenCL) A collection of threads which share a global ID.  Work-groups are
    the largest structure that can access a common slice of shared memory or
    enter a barrier. CUDA equivalent term is "block".

Vector lane

~   An element of a vector.

Xform

~   (`flam3`) The data structure associated with each function of an iterated
    function system.

