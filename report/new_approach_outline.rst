

- Conventional pipeline performance estimates

  - How many operations does it take to generate a sample?

  - How many operations can we do a second?

  - How does memory support come into play?

  - This is ridiculous.

- Approximate results

  - Reasons that reference-quality is desirable are all related to offline
    rendering; no compelling reason to aim for exact reference quality

  - In fact, nonphotorealistic rendering; our target is really "whatever
    looks good" (although appearing similar to ``flam3``, or at the minimum
    providing a CPU-based implementation, is an important courtesy to
    designers)

  - Let's explore what we can do with approximations to the existing
    algorithm!

- Restricting design space

  - Rather than solve the entire algorithm, we'll solve this "simplified
    flame system", or SFS:

    - IFS over xforms

    - Xforms consist of affine, sum-of-variations, and optionally another
      affine

    - Variations are C^2^-differentiable across the image region

    - Desired result is time series of 2D grids approximating log-scaled
      energy density of attractor formed by IFSes

    - No IFS in grid is degenerate

    - Interpolation is "slow"

  - This explicitly eliminates several features of flam3 which are "built
    in" to the system, but which make it very difficult to accelerate:

    - Variations with low visibility, symmetry transforms

    - Color (surprisingly important)

- Solving the SFS with Monte Carlo sampling

  - It's quite possible to solve this using straight-up MC sampling

  - Reduced data overhead, removing memory bottleneck

  - Still have to generate 3 bajillion samples

- Exploiting temporal redundancy

  - The next image is going to look an awful lot like the current one for
    an animation to be smooth. Why not use that?

  - Technique is critical for the next sections, so let's spend a moment
    establishing it in the continuous domain

  - Energy map from one state to the next is given by:

  - Energy of set is calculated by iteration

  - Rate of convergence is expected to be high (in truth this is assumed;
    can be calculated w/ some accuracy for arbitrary xforms)

  - Next frame given by integral of time over IFS functions

- Discrete approximation to function application

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

- Aliasing

  - The first problem is aliasing. Gamers know this as the jaggies that
    appear on lines (examples).

  - Consequence of Nyquist theorem in 2D. Pixels are boxes, but we're
    lighting them up with samples.

  - Gaming solution: supersampling. During rasterization, casts extra
    reverse samples around each point to more accurately determine
    coverage, and blends. Requires extra space for depth buffer to
    determine which triangle intersects at each point. (More
    intricacies...)

  - flam3 solution: increase the buffer size, and downfilter. Larger the
    buffer, better the approximation.

  - Would this help here? Yes, at quadratic cost. Is this sufficient? Well,
    no.

- Self-similarity and (fractal dimension? local derivative?)

  - IFS as a whole should be contractive, but not infinitely so (quantify
    this)

  - Relate function application to frequency modification in Fourier domain
    via local derivative

  - Detail from local derivative

Finish later...

