#Density Estimation
Density estimation is the process of estimating a probability density function[1].  It is used to determine the probability of a random variable occurring at a given point [2].

##Histogram
Histograms are among the oldest and most widely used density estimation methods [4].  To construct a histogram, the range of the data set is usually divided into consecutive, non-overlapping, fixed-width intervals called bins [3].  Each bin is then given a frequency based upon the number of points that fall in each interval.  While histograms are useful for the presentation and exploration of data, they are generally an efficient use of data if used for other purposes, such as cluster analysis and nonparametric discriminant analysis.

##Naïve estimator

##Kernel Estimator
Besides for the histogram, the kernel estimator is probably the most commonly used and studied density estimator [4].  It is a non-parametric way of estimating the probability density function of a random variable.  Kernel density estimation is a fundamental data smoothing problem where inferences about the population are made, based on a finite data sample [5].

##Nearest Neighbor
The nearest neighbor method is an attempt to adapt the amount of smoothing to the local density of data.  The degree of smoothing is controlled by an integer k, chosen to be considerable smaller than the sample size; typically k ≈ n1/2  [4].

##Variable Kernel

##Fixed-width Convolution vs Variable-width Convolution

#Windowing Function
A window function is a mathematical function that is zero-values outside of some chosen interval and manipulates the values inside that interval.  The simplest window is the rectangular window.  It simply takes a chunk the portion of the signal fitting inside in the window leaving discontinuities at the edges (unless the signal is entirely within the limits of the window) [6].  Filter shapes available in flam3 are the Guassian (default), Bell, Blackman, Box, Bspline, Hamming, Hanning, Hermite, Mitchell, Quadratic, and Triangle [8].

#Tone-Mapping

#Filtering Techniques

##Gaussian Convolution
Gaussian convolution filtering is a weighted average of the intensity of the adjacent positions with a weight decreasing with the spatial distance to the center position p.  The strength of the influence depends on the spatial distance between the pixels and not their values.  For instance, a bright pixel has a strong influence over an adjacent dark pixel although these two pixel values are quite different.  As a result, image edges are blurred because pixels across discontinuities are averaged together [7].

##Bilateral
The bilateral filter is also defined as a weighted average of nearby pixels, in a manner very similar to the Gaussian convolution filter described above.  The difference is that the bilateral filter takes into account the difference in value with the neighbors to preserve edges while smoothing.  The key idea of the bilateral filter is that for a pixel to influence another pixel, it should not only occupy a nearby location but also have a similar value.

The bilateral filter is controlled by two parameters: σs and σr.  Increasing the spatial parameter,  σs, smooths larger features.  Increasing the range parameter,  σr, makes the filter approximate the Gaussian convolution filter more closely.  An important characteristic of this filter is that the parameter weights are multiplied; no smoothing will occur with either of these parameters being near zero [7].

Iterations can be used to generate smoother images similar to increasing the range parameter, except for being able to preserve strong edges.  Iterating tends to remove the weaker details in a signal or image and is desirable for applications such as stylization that seek to abstract away the small details.  Computational photography techniques tend to use a single iteration to be closer to the original image content [7].

##KD-Trees

##Permutohedral Lattice

##Filtering Algorithms

###Denoising

###Texture and Illumination Seperation, Tone Mapping, Retinex, and Tone Management

###Data Fusion

###3D Fairing

#Structural Detection Techniques

##Morphological Anti-Aliasing

##Contourlet Transform

#Seperate Frame Buffers

#Log Scaling

References
[1] http://en.wikipedia.org/wiki/Density_estimation
[2] http://en.wikipedia.org/wiki/Probability_density_function
[3] http://en.wikipedia.org/wiki/Histogram
[4] Silverman Density Estimation
[5] http://en.wikipedia.org/wiki/Kernel_density_estimation
[6] http://en.wikipedia.org/wiki/Window_function
[7] Bilateral Filtering
[8] http://code.google.com/p/flam3/wiki/SpatialFilterExamples
