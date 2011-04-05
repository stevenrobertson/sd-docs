Real-time flames: a new approach
================================

Author's note: I'm hoping to implement these ideas, and if they work well
and can be generalized, to write a conference paper regarding their use and
applications. While the Creative Commons license governs this document,
nothing prevents you from stealing these ideas. However, I ask that you let
me know if you use these techniques before I get a chance to implement
them, and that you contact me if you plan to publish academic works about
them. ~~ Steven Robertson, steven@strobe.cc

So far, we've discussed the tools we'll be using (and building) to
implement the fractal flame algorithm on the GPU, and our approach to the
algorithm itself. For each major step in the algorithm, we've looked at
potential challenges and bottlenecks to a GPU implementation, and
identified ways to make fast implementations of each component possible. We
expect that this approach will result in a renderer that will produce
images of reference quality in a fraction of the time of ``flam3``.

But is this enough to get to real-time?

Conventional pipeline performance estimates
-------------------------------------------

TODO: this

Even with aggressively fast theoretical estimates of single-round
performance and implausibly optimistic assumptions about caching, it simply
doesn't seem possible to acheive the desired number of samples per second
needed to produce a reference-quality image on the GPU in real time.

Visually satisfying approximations
----------------------------------

To this point, we've considered ``flam3`` as the reference standard, and by
"quality", we mean "similarity to high ``quality`` parameter ``flam3``
output". As established elsewhere, this definition is appropriate for the
offline renderer, but as we've seen, it doesn't seem possible to attain
real-time performance with the same approach we use to produce compatible
images.

Fortunately, the unique applications of such an implementation —
environmentally-responsive rendering, interactive evolution of parameters,
part of a live performance — don't seem to require us to render images
exactly like a different, arbitrary reference. In fact, there's no explicit
reason why a real-time approach need resemble ``flam3`` in any way.

Of course, there are good reasons why we should try to at least approximate
the output of the canonical reference renderer, not least among these being
the incredible library of fascinating templates already out there. However,
fractal flames have no visual analogue in our world; we are free to explore
the entire space of visual phenomena to choose whatever is most pleasing.

With that in mind, we choose a revised definition of "quality" in the
context of real-time fractal flames:

    Quality refers to the extent to which generated images are visually
    satisfying.

Over the next few sections, we will see how treating ``flam3`` as merely
one way to visualize a function system, rather than the ultimate goal,
allows us to render animations with the saliency of offline-rendered images
at interactive rates.

The Simplified Fractal Flame
----------------------------

For the purposes of discussion, the full specification of a fractal flame
is unnecessarily broad, so we define a simplified fractal flame system, or
SFF

TODO: beef this section up with more math

    Like a fractal flame animation, an SFF consists of a set of control
    points interspersed throughout time; each parameter of a control point
    is smoothly interpolated from one system to the next so as to generate
    an image with apparent features that seem to have continuous local and
    global motion.  This interpolation is additionally constrained in an
    SFS to avoid "fast" changes in global features and degenerate control
    points which excessively concentrate image energy. [#]_

    A control point describes an iterated function system, and a camera
    translating IFS coordinates to image coordinates. Each function in the IFS
    takes a two-dimensional point in IFS space and returns another such point.
    These functions are C^2^-differentiable whereever they are defined within
    the domain of the IFS space sampled by the camera.

    The camera has a well-defined rectangular domain in the IFS space. The
    final image is the result of sampling the energy density of the IFS
    space across its domain, where the energy is given by [TODO: FORMULA].

.. [#]  This definition is ambiguous, but existing work in the ``flam3``
        and ``fr0st`` projects has produced an interpolator that
        subjectively satisfies these properties.

The simplified flame ignores or explicitly disallows many of the
components which characterize fractal flame systems, including xform
visibility, xform density, and (most importantly) color. In later sections,
we will re-extend the SFF to include most of these features.

Solving the SFS with Monte Carlo sampling
`````````````````````````````````````````

Apart from a few notational differences, a simplified flame is defined to
be a subset of a traditional flame, so it's not surprising that the
traditional pipeline is capable of rendering this flame with little
modification. When converting a traditional flame to an SFF by simply
dropping incompatible features, the basic structure remains visible, and
intensity levels are more or less proportional to those found in the
original image.

It is instructive to consider the performance characteristics of a pipeline
tuned to the simplified definition of a flame as a starting point for our
comparisons. In the proposed traditional renderer,


- Reduced data size, meaning less bandwidth but more importantly less cache
  misses

- Still have to generate an impractical number of samples, though

Temporal redundancy
```````````````````

- The next image is going to look an awful lot like the current one for
an animation to be smooth. Why not use that?

- This is something we can't do with the regular algorithm

- Technique is critical for the next sections, so let's spend a moment
establishing it in the continuous domain

- Energy map from one state to the next is given by:

- Energy of set is calculated by iteration

- Rate of convergence is expected to be high (in truth this is assumed;
can be calculated w/ some accuracy for arbitrary xforms)

- Next frame given by integral of time over IFS functions

Discrete approximation to function application
``````````````````````````````````````````````

- Implementation: for every point in the previous generation, apply the
  translation function, and write the results to an output buffer.

- Smoothness acheived by being very very fast (which this will do).
  Motion blur acheived by merging several samples. (Maybe discuss linear
  blending between the buffers, multiple buffers, having a single "last"
  buffer, or something)

- Contractive, visually pleasing xforms tend to have relatively smooth
  derivatives (esp. given constraints on xforms) => local spatial
  grouping => cache operators are quite happy

- So this seems like a magnificent approach. Can take the energy of a
  thousand samples and place it with a single evaluation of the xform.

- Except the output looks *terrible*. (examples) Why?

The frequency domain
--------------------

- We need to look at this problem through the lens of signals

Aliasing in 2D sampling
```````````````````````

  - The first problem is aliasing. Gamers know this as the jaggies that
    appear on lines (examples).

  - Consequence of Nyquist theorem in 2D. Pixels are boxes, but we're
    lighting them up with samples.

  - Gaming solution: supersampling. During rasterization, casts extra
    reverse samples around each point to more accurately determine
    coverage, and blends. Requires extra space for depth buffer to
    determine which triangle intersects at each point. (More
    intricacies...)

  - Technically this is like a selective lowpass. Kind of a
    balancing operation because loss of detail in areas like textures is
    also noticeable (our eyes have higher sampling rates than current
    monitors, so

  - flam3 solution: increase the buffer size, and downfilter. Larger the
    buffer, better the approximation. Same idea.

  - Would this help here? Yes, at quadratic cost. Is this sufficient? Well,
    no.

Self-similarity
```````````````

- Intuitively, think of an xform application as a frequency shift
  operation. Nyquist says we need to have this resolution or we get
  aliasing; xforms can violate that locally and globally on a cast.

- Of course, that's so *mathy*. An intuitive understanding: Really
  expansive transform regions will skip over pixels, leaving individual
  points of light...

- Will finish this after taking a closer look at less theoretical sections,
  I think I might be duplicating too much stuff here

