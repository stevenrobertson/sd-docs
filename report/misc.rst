Other implementation challenges
===============================

This chapter has some miscellaneous stuff which probably needs to make it
into the report, but may or may not need its own chapter.



Xform selection
---------------

Why it's important
``````````````````

Xform selection by density a necessary component of the random transform.
Correlations have a way of becoming perceptible. When intentional, can add
expressive depth (see xaos), but unintended correlations or insufficient
randomization can cause large deviations from expected image appearance.

(Math to show this? probably unnecessary)

Challenge
`````````

On CPU, it's pretty thoughtless: just use a decent RNG to select an xform
according to density. However, this doesn't work on GPUs due to
vectorization. This can result in a pretty hefty performance hit due to
thread divergence.

However, can't carry around points in the same thread. In general, IFSes
must be contractive; run wildly different points through the same xforms in
the same order, and they will quickly converge. That's the whole point.
Simply keeping the points in the registers will be an effective 32x
performance hit.

Solutions
`````````

Use shared memory to swap the points. This doesn't provide optimal
feedback, but it's reasonable: (see benchmarks, previously generated file).

Or just accept the performance hit. Might be preferable, might not be,
depending on a great many factors.

Writeback
---------

Okay, so as we've established, flam3 generates an enormous number of points
to render a high-quality image. We've looked at how to reduce the effects
of noise due to undersampling the IFS, which may allow us to reduce the
number of samples required for satisfactory images, but half of a ton of
points is still a lot of points. For the classical approach, most of our
time will be spent performing iterations.

As has been discussed, GPUs have a much higher ratio of computation to
memory bandwidth and cache size than CPUs do, and have a strong
architectural preference for coalesced memory operations. Unfortunately, as
we've also mentioned, the IFS follows the attractor around the image space,
jumping from region to region, so there is little temporal coherence in
memory access patterns.  Also, since we need each point to pass through a
different sequence of transforms, there's no spatial locality to our
accesses either.

All of this adds up to an unavoidable worst-case scenario for the
traditional flame algorithm. For chips with no coherent cache — basically
everything other than Fermi — the memory subsystem would be an almost
certain bottleneck.  [show math] Even for newer chips, the only way the
memory bottleneck can be avoided is if L2 happens to cover most of the
image regions being written to, which [math] is just not gonna happen. Then
turn on supersampling — which on CPU is essentially free — and watch all
hope disappear.

Reducing color traffic
``````````````````````

There's a stopgap approach, which is this: subsample the color buffers.
Humans have much more limited spatial resolution for color than for
luminosity, so we don't notice color bleed like that. In fact, almost all
compressed video uses that technique. This cuts down on the total
framebuffer size considerably. But, [math], not enough. Also, it requires
splitting the color buffers apart, which can actually reduce performance by
requiring extra cache lines to be loaded.

Another approach is to use probabilistic writeback of color. We again
exploit the human visual system's color weaknesses, and the knowledge that
the effect of any given sample upon the final color decreases in proportion
to the number of samples in that pixel's area. Write the pixel's alpha
value first; then, calculate a probability like $2^{-k\alpha}$ for writing
back that color. This doesn't reduce the size of the color buffer, but in
concert with the above, it greatly reduces the memory traffic and number of
cache lines occupied by the colors rather than alpha.

Cutting the alpha buffer down to a half-precision float wouldn't be too bad
either, although it would remove the ability to use fast atomics in L2.

Point logging
`````````````

Another approach would be to restore cache coherency, which would allow the
memory and caches to function much closer to their theoretical throughput
and remove the bottleneck. The way to do it? Sort the points first.

GPU friendly sorts, such as radix-based bucket sort and bitonic sort, can
churn through the point log relatively quickly. With large bucket sizes and
clever timing, the sort could be done in two or three passes, and writeback
could be accelerated by doing all atomic compaction on shared memory
instead of global.

[Insert teaser for big new approach]

Motion blur
-----------

- Motion blur is used in static flames to give a sense of implied motion.
  Also important for dynamic flames, as few systems can handle H.264
  1080p60 at great bitrates, and 1080p24 is unsatisfying without at least
  some motion blur

- Critically important to the illusion of depth

- flam3 implements motion blur by performing 1,000 interpolations in a
  narrow range around a single time value, and distributing samples across
  this time range in a serial fashion

- For the GPU, this would result in too much memory bandwidth; would lose
  out on the benefit of the constant cache (or L1).

- Solution 1: use fewer motion blur steps; might it give acceptable visual
  approximation?

- Solution 2: use piecewise linear interpolation via the texture hardware.
  If data loads can be vectorized, it's almost free.

- Solution 3: cooperation across SMs to avoid needing to reload too many
  points.



