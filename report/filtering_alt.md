# Filtering (alternate)

This chapter is an alternate organization of the filtering material Matt's
working on, providing a bit of context. Matt will merge this chapter and his
as he sees fit.

Filtering accomplishes two purposes: removal of aliasing and denoising.
The problems, and their solutions, are related, but they're not identical. We
address them both here.

## Aliasing

### Visual image information

- In the continouos domain, or at resolutions tending toward infinity, we can
  describe most flames perceptually as a collection of distinct (though often
  overlapping) objects with smoothly curved outlines.  Our brains perform
  object recognition all the time - it's hardwired into our visual system - so
  it's natural that the most visually interesting flames are those which
  stimulate traditional object recognition pathways in novel ways, rather
  than, say, white noise.

- 2D object recognition in our brains depends on recognition of sharp
  discontinuities in images (I have papers which you can cite to show this,
  you don't even have to read 'em if you don't have time). Since so much of
  our neural hardware depends on discontinuities at object boundaries, they
  become important.

- However, our algorithm runs in the discrete domain; ultimately the results
  get sent to monitors. As a result, the perfect curves in the continuous
  domain must be sampled along the 2D grid of pixels used in raster graphics.

### Spatial aliasing

- In the flame algorithm, as described, each generated (x, y) point is rounded
  to the nearest pixel, and then the color value is added to that pixel's
  accumulator. Effectively, each pixel represents the average value of the
  color function of the attractor across the area of that pixel. In other
  words, we sample the color values of the flame once per pixel.

- In 2D image space, this means any function with a higher spatial frequency
  than a single pixel will be aliased by the sampling process. Image
  discontinuities, such as object edges, are instantaneous, and therefore have
  an infinite frequency response (though with finite total energy). As a
  result, object edges are aliased in the spatial domain.

- The result is stair-step jaggies in images (demo). Since our brain depends
  so heavily on detecting object discontinuities for object recognition, these
  artifacts are extremely noticeable, especially in motion.

- The solution is to downfilter the highest spatial frequency components below
  the sampling threshold. Unfortunately, downfiltering any image component,
  but especially surface textures, results in a reduction of detail across the
  image. Our brains notice artifacts from aliasing at object borders, but also
  notice reduced detail apart from those regions.

### Approaches to antialiasing

- Hence, antialiasing. Multisample antialiasing uses the polygonal model of a
  scene to detect object boundaries, and perform sample blending at those
  points. In effect, AA acts like applying a low-pass filter only at object
  boundaries.  (Details?)

- Flam3 doesn't do that. Can't, actually; we don't have a polygonal model to
  do casting against, just a couple of not-necessarily-differentiable
  equations.  Since there's no coverage sampling, there's no native way to
  determine object boundaries. Instead, flam3 performs full scene
  antialiasing: the accumulation buffers have 2, 3, even 4 times the width and
  height of the final image, having a quadratic effect on memory consumption.
  After accumulating to these higher-resolution buffers, a low-pass filter is
  applied to the buffers; then they are subsampled to produce the final image.
  (In practice, these two steps are merged.)

- FSAA is effective, but it quite literally blurs the entire image; "Gaussian
  blur" and "Gaussian low-pass filter" are the same thing. However, this is
  not as noticeable for flames, because most flames tend to be composed of
  *smooth* image regions instead of the sharp textures present in natural
  images. In fact, sometimes flame designers intentionally turn up the blur
  radius well beyond what's necessary to subsample the image without aliasing
  for aesthetic purposes.

- Morphological antialiasing is a data-dependent strategy operating in the
  spatial domain. It's a post-processing solution which specifically looks for
  the kind of jaggies that cause aliasing problems in the final image, and
  blurs those regions; a lot like MSAA/CSAA in appearance, but requires no *a
  priori* knowledge of the scene to run. It can be fooled by some images, and
  misses discontinuities along axes very close to but not quite vertical or
  horizontal (due to a limited search window), but it's really, really fast.

- An entirely different strategy would be to perform filtering of each point
  on writeback. Right now, we clamp an (x, y) point to the nearest pixel; in
  other words, we apply a box filter windowing function to the
  nearly-continuous results of the IFS at each pixel. Instead of writing to
  the nearest pixel, we could identify the nearest four pixels, find the
  normalized Euclidean distance to the center of each, and deposit (1 - dist)
  of the sample's color into each of those pixels. This would effectively
  change the filter from a box to a triangle. Other arrangements are possible
  too. However, since this is done for every IFS sample, it's probably a lot
  more costly to do it this way than any other. Still, it's a useful way of
  understanding the effects of sampling.

## Denoising

- Antialiasing deals with the problems caused by approximating objects via
  sampling along a regular 2D grid. Denoising, by contrast, deals with the
  problems caused by approximating objects via random sampling.

- A "regular random grid"? Isn't that an oxymoron? No, they're really two
  separate things: first, we use random sampling to approximate the IFS with
  Monte Carlo methods, then we use grid sampling to approximate the histogram
  of those samples' positions.  Two separate sources of error, two separate
  strategies to deal with it.

### The origins of noise

- Sampling noise from Monte Carlo IFS estimation arises from two main sources:
  coverage limitations and accuracy errors.

  - Because we don't know the shape of the attractor analytically, we can't
    sample it directly; we must follow it along the IFS. This means that the
    IFS will jump around from location to location within the image in a
    generally unpredictable pattern. Because of this jumping, any errors in
    the image show up as point noise, rather than along contours as with
    aliasing.

  - Again, since we don't know the shape of the attractor, we choose random
    points to start with. After picking a new random point, a thread runs a
    few iterations without recording any data so that the point can join the
    main body of the attractor. However, this number may sometimes be
    insufficient, leading to random points placed "outside" the attractor.
    Floating-point precision errors can similarly reduce the accuracy of
    generated points.

### Visibility

- Both of these sources of error have something in common, though: they show
  up a lot more in darker image regions. The image is log-filtered, meaning
  the brightest image regions are covered by hundreds or even thousands of
  times more samples than the darkest. In many images,
  contrast-brightness-gamma settings cause extreme sensitivity in dark
  regions, so that a single sample in the middle of an otherwise-black image
  region causes a jump of, say, 5% of the total luminance scale of the final
  image. This is noticeable.

- When we say "dark", we mean pre-log-filtering. Since flam3 does color
  clamping, it's not uncommon to produce images where most of the energy lies
  outside of the final representable intensity scale. In those images, even
  mid-level tones have relatively few samples, and have visible point noise.

### Denoising a flame

- To combat this, flam3 does density estimation filtering. Within dark regions
  of the image, it applies a wider kernel, or a smaller blur. ...

- Problems: difficult to accelerate on GPU; usually requires hand tuning; it's
  "just another blur" which can reduce image details and textures.

- Bilateral filter may be a better fit. Because it preserves... etc

- [Other algorithms? Classical denoising using nonlinear estimation (in, e.g.,
  the wavelet domain) may not be appropriate, because our images aren't
  natural, but they may also be great. I suspect the addition of extra
  information from the iterations would allow us to make a very efficient
  wavelet (or related) filter for this purpose.]

