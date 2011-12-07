# Animating fractal flames
\label{ch:anim}

Fractal flames are uniquely interesting as animations. Well-designed fractal
flames typically contain overwhelming amounts of what the human visual system
perceives as objects in motion. Under proper viewing conditions, overloading
the visual system in this way provides an almost hypnotic effect, and the word
"mesmerizing" is often used to describe extended-length flame sequences. The
coloration scheme in use by fractal flames also provides sub-pixel detail
missing from other fractal rendering algorithms, allowing the human visual
system to perform temporal interpolation to recover image detail at scales
much finer than single-frame rendering or display.

Despite the distinctive visual qualities of fractal flame animations,
animation has heretofore been a hands-off process. Interpolation for fractal
flames is, in almost every case, handled by `flam3`'s genome tools, which
leave extremely limited room for either artistic or programmatic exploration
of the aesthetics and physiological impact of fractal flame animations. Since
rendering was so expensive, this made sense; `flam3`, and the Electric Sheep
project, were first written in an era where ordinary computers would take
*hours* to render frames, instead of the minutes used by today's CPUs or the
seconds it takes cuburn. However, with cuburn's ability to provide
near-real-time feedback for animators and huge volumes of video for machine
learning, the time has come to engineer more flexible animation tools.

## Flocks

Flame animations are most commonly found as a flock. Flocks are generated from
a set of still flames provided by users (and, in some cases, generated
programmatically by blending two or more user-provided flames). Each still
flame is animated to create a *loop* by rotating the primary affine
transformation of each xform about that affine transformation's offset point.
This rotation is performed at constant angular velocity over the duration of
the loop. While this sometimes causes the resulting animation to give the
perception of global frame motion, as if the "camera" or the "world" were
spinning, it often results instead in a movement pattern which suggests that
some of the "objects" in the frame are rotating across a fixed image grid.
The motion of these "objects", when passed through variation functions, is key
to providing an illusion of depth, and time-integration performed by our
brains allows us to recover a sense of the "shape" of these variation
functions.[^hvs]

[^hvs]: The notions of objects passing through shapes in a world is entirely
an artifact of the human visual system attempting to make sense of an
astonishing amount of foreign information, and in a certain sense even the
artists who design these flames are just poking at some numbers in a very
peculiar spreadsheet. Nevertheless, humans' common heritage and neural
structures allow an artist's intent to be received by the viewer intact,
despite passing through an austere 4KB text file on the way. We can assure the
reader that even years of careful study of fractal flame renders doesn't do a
thing to shake the perception that a hundred thousand tiny snowflakes are
dancing through crystal, or that a bolt of lightning just gave a glimpse into
an alien landscape.

[TODO: example figures. This is a great place for them, really.]

When creating a flame for a loop animation using XML tools, the artist may
specify that certain xforms are not to be rotated, the number of frames to be
rendered, and the width of the temporal multisampling as a ratio of a single
frame's duration. When submitting to the Electric Sheep project, as most flame
artists have done historically to get a loop, the duration and framerate are
set by the server, so even that control is removed. Compared to the unbounded
set of possibilities, this is a bit stifling.

After creating loops, `flam3` will add *edges* to a flock. An edge creates an
animation that joins two loops "seamlessly" by interpolating every value in a
flame (apart from those related to video playback, such as frame resolution
and rate) smoothly between two loops. This typically results in a morphing
effect, where the shapes of the source loop slowly distort into
unrecognizability and then resolve into the destination loop. Occasionally,
singularities, zero-crossings, or other irregularities will result in more
unusual phenomena, such as vibrant bursts of color or simply black
frames.^[The Electric Sheep project relies on users to identify which edges
are good and which are not. We're interested in accomplishing the same task
algorithmically, and hope to do so given time.]

The result is a directed graph with cycles. Each graph node is a point in time
when two animations have identical values for all parameters. These points are
made to occur either at the presentation time of the first frame in a
pre-rendered video file containing an animation, or at the "end" of the last
frame in such a file (presentation time plus display time). If two such
animation files are properly concatenated,^[Few media containers can be
concatenated at the bitstream level without remuxing. We have chosen one that
can (MPEG-2 Transport Stream without Blu-Ray timecode extensions).] they will
appear to form a single, smooth animation. In this way, a playback engine can
engage in a random walk of a flock, creating a continuous animation that uses
variety in playback order to maintain novelty and user interest for far longer
than sequential playback of all videos in the flock would suggest.

## XML genome sequences

The format used by `flam3` to describe animations is a simple extension of the
XML format used to describe still images. An animation genome contains a
separate XML `<flame>` element for every frame in the animation, each bearing
a `time` property describing the center of the display time for that frame
($\mathrm{PTS} + 0.5 \cdot \mathrm{DTS}$, essentially, although DTS is always
equal to $1$ and the first frame's PTS is always $0$).

This presents a problem for smooth playback. Since the frame's center time is
specified by the `time` parameter, the first frame of the sequence has an
effective unscaled PTS of $-0.5$. Encoding this animation will shift this PTS
to 0, since negative presentation times are not allowed. As a result, the edge
parameter set used in the directed graph is never explicitly specified. Edges
are generated against the last frame in the file, instead of this phantom
parameter set, and therefore there is a small but noticeable discontinuity in
position when transitioning between two sets.

Even if this discontinuity is corrected for, so that the position is
continuous in time, the use of linear interpolation between nodes in a flock
by `flam3` means that the velocity of objects will change abruptly when
transitioning between a loop and an edge. With motion blur enabled, this does
more than simply break the illusion of physicality lent to objects by
continuous velocity curves during animation; the abrupt change causes visible
distortions in motion-blurred shapes.

The interpolated parameter sets^[These are called "control points" in `flam3`
parlance, which is patently incorrect; the specified frames are the control
points, not the result of interpolation. The authors have been sticking to
`flam3` terminology when possible, including using "control point" in previous
documents, but this is just too dang wrong to continue doing.] are generated
for a frame by performing linear or Catmull-Rom interpolation, depending on
the number of surrounding frames available. Since the frames themselves are
generated using linear interpolation, the use of Catmull-Rom interpolation to
generate parameter sets between frames is questionable, and may result in
additional velocity discontinuities.

Regardless of the technical limitations, the XML format is simply cumbersome
to use. The genome file for an animation of reasonable length can be hundreds
of megabytes in size, and the mix of implicit and explicit ordering within the
file resists hand-editing, splitting, and merging of files. Animation files
are almost never themselves edited, due to their size and that the output
doesn't identify keyframes or transmit them intact. It is possible to design a
tool which uses different interpolation strategies or exposes additional
artistic options to the user, but the limits of the `flam3` tools mean that
this format would either have to be interpreted and converted to `flam3`'s
format on the rendering host, or exported beforehand, suffering all the
indignations inflicted by the XML genome format.

[TODO: figure of XML genome, in readable format, showing length]

## Cuburn genome format

Instead of building a layer on top of `flam3`-style XML files, we have decided
to create a new format for representing genomes. This format uses a
JSON-compatible object model, and so may be embedded in any suitable
container.

In cuburn's genomes, all parameters are represented by Catmull-Rom cubic
splines. Animations are always represented as occurring from $t=0$ to $t=1$,
with the start time corresponding to the start of the presentation of the
first frame, and likewise for the end of the last frame. Spline knots may be
inserted at any temporal value; cubic interpolation ensures that the value of
any parameter at the time of a knot is exactly that of the knot. This enables
graph nodes in a flock, or any other animation constraint, to be hit
precisely.

Spline knots can also be inserted outside of the rendered time values. Our
interpolator uses this to match velocity in addition to value at transition
points between animations, creating seamless transitions. This system accounts
for variable duration when matching velocity, lifting `flam3`'s implicit
restriction that all loops and edges must be the same length to get smooth
results.

Because the splines are encoded independently in a simple JSON list, they can
be easily hand-edited. More importantly, those edits are not transformed. When
using a frame-based format, edits would require resampling the entire curve
and storing the samples; applying additional edits at a later time would
either require having stored the unquantized curve separately or running
error-prone inference to approximate the significant knot positions. With this
format, users and editing software no longer have to keep two versions of the
same file in sync.

The format is not yet finalized; we are considering extending the spline
description to include specification of a domain in which to scale a parameter
for interpolation, such as reciprocal or logarithmic. This will present more
flexibility in transitions between very different values or values which
behave non-linearly as they drop to zero.

This new flame format supports import of still images in XML format, and can
support export of still images or animations to the legacy format.

[TODO: figure of this format]

## Implementing interpolation on device

The new format allows us to store an entire genome on the device and
interpolate parameter sets for rendering as needed, which is simpler and more
efficient than relying on host-based interpolation driven by foreign function
calls to `flam3`. This process is efficient and fast, but getting there was
not trivial.

CUDA GPUs have a provision for loading parameter sets from memory, known as
constant memory. This is device memory which is shadowed by a small read-only
cache at each GPU core with its own narrow address space configured to map to
global memory by the host. Accesses to constant memory can be inlined into
dependent operations with no overhead, not requiring a separate load
instruction or temporary register, but only if that access follows certain
restrictions, chief among these that the access must use a fixed offset from
the start of the memory space. If a non-fixed index is used, the code makes use
of the normal memory data path, which is considerably slower.

In order to run chaos game iterations on thousands of temporal samples, we need
to be able to load data from a particular parameter set. Doing so with constant
memory requires either performing a separate kernel launch, with corresponding
constant address space configuration, for each temporal sample, or using
indexing to select a temporal sample at runtime. The former method leads to
ineffecient load balancing, and the latter forces constant memory accesses to
take the slow path.

The most common alternative to constant memory is shared memory, which can be
described as an L1 cache under programmer control. Static-offset lookups from
shared memory are not quite as fast as inline constant memory lookups, but are
faster than indexed lookups. However, another problem presents itself: when
represented as a complete data structure, the full parameter set exceeds the
maximum available 48KB of memory and far outstrips the 2KB maximum size
required to obtain sufficient occupancy to hide pipeline latency on
current-generation hardware.

To retain the benefits of static-offset lookups without requiring a static data
structure, we augmented the runtime code generator with a data packer. This
tool allows you to write familiar property accessors in code templates, such as
`cp.xform[0].variations.linear.weight`. The code generator identifies such
accessors, and replaces them with a fixed-offset access to shared memory. Each
access and offset are tracked, and after all code necessary to render the
genome has been processed, they are used to create a device function which will
perform the requisite interpolation for each value and store it into a global
array. Upon invocation, each iteration kernel may then cooperatively load that
data into shared memory and use it directly.

Each direct property access as described above triggers the device-memory
allocation and copying of the original Catmull-Rom spline knots from the genome
file for that property. In some cases, it can also be useful to store something
other than a directly interpolated value. To this end, the data packer also
allows the insertion of precalculated values, including arbitrary device code
to perform the calculation during interpolation. The device code can access one
or more interpolated parameters, which are themselves tracked and copied from
the genome in the same manner as direct parameter accesses. This feature is
used both for precalculating variation parameters (where storing the
precalculated version as a genome parameter directly would be either redundant
or unstable under interpolation), as well as for calculating the camera
transform with jittered-grid antialiasing enabled (described in Chapter
\ref{ch:filt}).

The generated function which prepares an interpolated parameter set on the
device performs Catmull-Rom interpolation many times. To control code size, it
is important to implement this operation in as few lines as possible. One step
in variable-period Catmull-Rom interpolation involves finding the largest knot
index whose time is strictly smaller than the time of interpolation. To
implement this, we wrote a binary search (given in Figure \ref{bsearch}) that
requires exactly $3 \log N + 1$ instructions. We suspect this is not a novel
algorithm, but we have not seen it elsewhere.

\begin{figure}[htp]
\begin{verbatim}
    ld.global.u32   rv,     [rt+0x100];
    setp.le.u32     p,      rv,     rn;
@p  add.u32         rt,     rt,     0x100;
\end{verbatim}

\caption{One round of cuburn's unrolled binary search. In this particular set
of instructions, a load instruction brings a value from global memory into a
register. The address of this value by adding an offset representing 64 array
positions to the current index value, `rt`. The addition is performed in-line
by the memory units. The next instruction tests to determine if the value `rv`
is less than or equal to the reference value `rn`, storing the result in
predicate `p`. If `p` is set, the last instruction simply advances the index
by the offset. Each round repeats the same instructions, halving the offset
size each time.}

\label{bsearch}
\end{figure}


