# Cuburn
Cuburn is the intended independent implementation of the fractal flame algorithm, therefore a flame fractal renderer. The difference between this renderer and the ones available is that this will take advantage of the computational power of GPUs, will have better quality fractals and will take less time to render images of good quality and be able to produce images real-time for animations by exploiting the optics of motion detection.

##Project Motivation
Fractals are not only appealing to the eyes, but they can also be useful in many fields such as biology, genetics, chemistry, physics, etc. For example, fractals are useful to measure geographical borders, have better reception of electromagnetic signals and they are even present in semiconductors[2].
The fractal flame algorithm produces images strikingly beautiful still and moving images. Each flame is constructed from a limited number of parameters, which enables flames to be manipulated procedurally; Electric Sheep, a distributed computing experiment which uses machine learning and user feedback to drive the creation of its content, has been successfully running for 12 years and boasts hundreds of thousands of users. Human-designed flames are also popular and can be designed using freeware available online. Professional artists like Cory Ench use that same parameter space to create digital artwork[1].

The flame algorithm does suffer from a considerable limitation: its primary implementation is slow. The flame algorithm is based on stochastic evaluation of an iterated function system, and computational complexity grows quadratically with image size and exponentially with desired quality. The core implementation is CPU-based, and although it has been somewhat tuned for performance, it still takes a considerable amount of time to render a single high-quality flame, much less an animated sequence of them. This precludes many possible applications of the flame algorithm, as CPU-based real-time rendering is firmly out of reach. As a result, the algorithm seems mature enough for a GPU implementation.

In fact, several GPU flame implementations already exist. Based on either CUDA or OpenCL, but these libraries vary in approach, performance, and capability. The accelerated renderers do indeed work much faster than the reference implementation; however, no GPU renderer to date is capable of producing images that are of enough quality to be used in an animation alongside CPU-rendered flames, a requirement that prevents the flam3 project from adopting any such implementation. Perhaps more tellingly, no implementation exceeds (or even matches) the perceptual quality of flam3's output, which might warrant outright replacement of the reference implementation.
Experience [^expr] suggests that this lack is not simple carelessness on the part of implementers, but rather a result of both the general challenge of writing algorithms optimized for the GPU, and particular aspects of the flame algorithm which are hard to adapt to massively parallel devices. Some of these hindrances are a result of current-generation GPU hardware architecture, but a surprising number of them are actually imposed in software by the development environment.
 [^expr]: One team member created the first implementation of the flame algorithm for GPUs in 2008.

## Challenges:
There are three main challenges in this project are adapting the flam3 such that it successfully runs on a GPU, maximize performance of the algorithm in order to have more quality over a smaller amount of time compared to other implementations, and to increase the quality overall of the fractals that are outputted, whether if it is on the resolution of the images or in other optical properties of the images as to make them more pleasing to the user.

## Objectives:
The main objective of this project is to develop a fractal flame renderer that implements the flam3 algorithm, and that is used on GPU. This software should not only work, but it must output fractals with better quality than other GPU implementations. This breaks into different objectives, since the quality, real-time output and implementation itself depend on different aspects such as hardware and software.
For the hardware, the right GPU is to be obtained as the main tool of work and its architecture must be understood.
A dialect interface between the creators and the GPU must be created using CUDA.
Increase the speed of the renderer significantly compared to those already available.
Find a pseudo-random number generator that passes randomness tests and can be implemented on a GPU
Find any possible ways to maximize the efficiency of color filtering, log scaling, aliasing and super-sampling fractal images.

## Project Requirements
Because Cuburn is an implementation of the flame fractal for GPU, the main requirements are that it is compatible with the GPU to be selected. Therefore the limitations of such GPU are great part of the requirements. They are the following:
 32-wide vector operation ("warp") width
 1536 threads per multiprocessor
 32768 registers per multiprocessor
 48KB shared memory per multiprocessor
 16KB L1 cache per multiprocessor

These limitations do more than impose an upper bound on the performance of this device; together, they also set lower bounds for certain parameters. For example: due to deep pipelining, each 32-thread warp may only execute once every 22 cycles. If every warp performs pure computation, a minimum of 704 threads per SM is necessary to fully utilize the device. Accessing memory can stall a warp temporarily, so that minimum figure must be increased by the proportion of time a warp may spend waiting for memory. Main memory accesses take several hundred cycles, so it is advantageous to have as many threads as possible, but then the number of registers per thread is reduced. This multidimensional give-and-take is an integral part of designing high-performance algorithms for GPUs.

Other requirements of the project include a PRNG that works well with GPUs and that has good spectral qualities. Also, the filtering and scaling techniques must offer outputs of greater or equal qualities than those of other implementations of the flame algorithm, especially better than those existing that are to be used with GPU.

References:
[1] http://www.enchgallery.com
[2]http://www.sciencenews.org/view/generic/id/62006/title/Superconductors_go_fractal
