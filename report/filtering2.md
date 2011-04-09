# Filtering

Image filtering is the process of enhancing an image so that inaccuracies in the
image can be corrected.  Sources of inaccuracies can be from bad sensor
measurements, extremely low or high data ranges, digital misrepresentations, and
many other sources.  These artifacts can be corrected by  Since image quality is subjective due to human judgement, it may be difficult to determine a "best" filter.  However, by identifying the type of inaccuracies and choosing filters
suited to chosen criteria, the subjective nature of image enhancement can be
decreased such that the resulting images will be a clear improvement over the
original.

When rendering flames, there are two kinds of artifacts that need to be
minimized in order to create more visually attactive flames: aliasing and noise.
While these two problems and their solutions are related, we will need to
approach them with different techniques.  We will address both of these problems
and their solutions in more detail in the following sections.

## Aliasing

Aliasing is the effect of high frequency signals, in high resolution graphics,
being mapped and interpolated onto a lower resolution graphic such that the
smooth edges and gradients in the original image can not be represented
properly.  It is observable as distortion or artifacts on lines and smooth
curves.

Aliasing occurs when high resolution graphics are mapped to a lower resolution
that cannot support the smooth gradients in the original graphic.  Interpolation
is performed  resulting in
jagged edges on lines and curves.

![Left: aliased image, right: antialiased image](filtering/Aliasing_a.png) 

### Visual image information

In the continouos domain, or at resolutions tending toward infinity, we can
describe most flames perceptually as a collection of distinct (though often
overlapping) objects with smoothly curved outlines.  Our brains perform
object recognition all the time - it's hardwired into our visual system - so
it's natural that the most visually interesting flames are those which
stimulate traditional object recognition pathways in novel ways, rather
than, say, white noise.

2D object recognition in our brains depends on recognition of sharp
discontinuities in images (I have papers which you can cite to show this,
you don't even have to read 'em if you don't have time). Since so much of
our neural hardware depends on discontinuities at object boundaries, they
become important.

However, our algorithm runs in the discrete domain; ultimately the results
get sent to monitors. As a result, the perfect curves in the continuous
domain must be sampled along the 2D grid of pixels used in raster graphics.

### Spatial aliasing

### Approaches to antialiasing

- Supersample antialiasing

- Multisample antialiasing

- Coverage antialiasing

- Morphological antialiasing

- Window function

## Denoising

### The origins of noise

### Visibility

### Denoising a flame

- Gaussian Convolution
  Gaussian convolution filtering is a weighted average of the intensity of the 
  adjacent positions with a weight decreasing with the spatial distance to the 
  center position   p.  The strength of the influence depends on the spatial 
  distance between the pixels and not their values.  For instance, a bright 
  pixel has a strong influence over an adjacent dark pixel although these two 
  pixel values are quite different.  As a result, image edges are blurred 
  because pixels across discontinuities are averaged together [7].

- Bilateral filter
  The bilateral filter is also defined as a weighted average of nearby pixels, 
  in a manner very similar to the Gaussian convolution filter described above.  
  The difference i s that the bilateral filter takes into account the difference
  in value with the neighbors to preserve edges while smoothing.  The key idea 
  of the bilateral filter is that for a pixel to influence another pixel, it 
  should not only occupy a nearby location but also have a similar value.

  The bilateral filter is controlled by two parameters: σs and σr.  Increasing 
  the spatial parameter,  σs, smooths larger features.  Increasing the range 
  parameter,  σr, makes the filter approximate the Gaussian convolution filter 
  more closely.  An important characteristic of this filter is that the 
  parameter weights are multiplied; no smoothing will occur with either of these 
  parameters being near zero [7].

  Iterations can be used to generate smoother images similar to increasing the 
  range parameter, except for being able to preserve strong edges.  Iterating 
  tends to remove the weaker details in a signal or image and is desirable for 
  applications such as stylization that seek to abstract away the small details.
  Computational photography techniques tend to use a single iteration to be 
  closer to the original image content [7].

- KD-Trees

- Permutohedral Lattice
