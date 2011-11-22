# Benchmarking
Increasing the performance of Scott Drave's fractal flame algorithm is a main objective of this project. A secondary objective is for cuburn to accurately render the entire catalogue of variations available in flam3, our reference implementation. In order to verify that both the completeness and performance objectives have been reached it is necessary to benchmark and each flame variation. The benchmark's framework, setup, results, and analysis will be described in the following sections.

## Framework
NVIDIA has released a profiler with CUDA which aids developers in gathering information about a wide array of information such as kernel execution and memory transfer times.  The profile can be enabled and configured by the use of a handful of environment variables that need to be set on the user's operating system. 

By exporting the environment variable `CUDA_PROFILE` and setting it equal to `1`, the profiler exports the program's GPU statistics into a log file. By default, the profile will write the data to `./cuda_profile.log`. If a different location is desired, the user can set the `CUDA_PROFILE_LOG` environment variable accordingly.  Additionally by exporting the environment variable `CUDA_PROFILE_CSV` and setting it equal to `1`, the log file's format can be changed to a comma-seperated value (CSV) format. This format eases the processing of parsing this file for analysis because of it's more rigidly defined format specification.

Performance counters can be used in addition to the default timing information (timestamp, method, gputime, cputime, and occupancy) by creating a profiler configuration file specifying additional performance counters using the `CUDA_PROFILE_CONFIG` environment variable. The performance counters use on-chip hardware counters to gather statistics and hence their use change the algorithm's performance and should be used with caution. These performance counters were explored but in the end did not provide useful statistics or yield any insight that could make for an interesting discussion.

##  Benchmark Machine
In order to accurately talk about the benchmarking results as well as provide a frame of reference for the user, the benchmarking machine is described. The machine used for the benchmarking was an `Alienware M17xR3` laptop model with the following hardware and software specifics:

* Intel Core i7-2630QM CPU @ 2.00Ghz
* 6 GB Ram
* Windows 7 x64
* GeForce GTX 460M with:
     * 192 CUDA Cores
     * 675 Mhz Graphics Clock
     * 1350 Mhz Processor Clock
     * 1250 Mhz Memory Clock
     * 1.5 GB GDDR5 Memory

*Note:* All tests were performed with the AC/DC adapter plugged in and system performance set to the maximum allowable levels. This is an important note because GPU performance can be severely throttled, for power concerns, if the adapter is not plugged in or performance is being limited by the user.

## Benchmark Setup and Design

### Premise

After several empircal tests and observations it was noted that GPU time was one of the main performance statistics that we wanted to explore and discuss. With our goal of accurately comparing all of the catalogued variations, a design procedure was needed that attempted to isolate all other factors that could influence execution time and exclusively focus on how the variation code injected in the device. 

[TODO: Furthermore, after these performance statistics were to be attained we need to statistically prove they can be compared]

### Auto generation of flames

The procedure is as follows. First, all of the variations needed to be auto-generated into respective `flam3` files which could be used as input for cuburn. Cuburn can run these `flam3` files individually and the CUDA profiler can produce output statistics (using methods described above). Immediately, using this approach a complication arises. A valid iterated function system must be contractive or contractive on average. Using a single transform that is soley our selected variation is not a valid iterated function system and cuburn may prematurely abort rendering the frame. Because of this, we chose a baseline iterated function system that each variation would be applied to. This baseline iterated function consisted of two linear transforms.  The transform code is the following:

\begin{figure}
$<xform/ weight="0.33"/ coefs="-0.26/ 0.0/ 0.0/ -0.26/ 0.0/ 0.020"/ //>$
$<xform/ weight="1"/ linear="1"/ coefs="0.70/ 0.70/ -0.70/ 0.70 0.51 -1.18"/ //>$
\end{figure}

This produces a system which looks like the following:

[TODO: show what it looks like]


Because all of the same variation is applied to each



[TODO: note that everything else is fixed]

- each auto generated flame variation contains that flame variation with a low weighting $\approx 1E7$
- b/c of dynamic code generation  this xform variation would now have to be loaded onto the device (GPU) and executed (...)?
- only variable performance differences were noted in the iter kernel which is the main iteration kernel for the entire flame algorithm.
- run for only 1 frame

### Accumulating

The `iter` kernel is executed multiple times per frame.


CUDA Profiler reports all single instances
not useful for analysis between flames
all of the iter kernels GPU time was summed together to

- iter kernel is executed numerous times per frame rendering.
- all instances of iter kernel summed to give total iter kernel execution time.

Still missing a critical part

### Convincing ourselves, and you

Comparing iter kernel execution times between all catalogued variations is not enough. In order to account for the difference of execution times between runs, multiple runs were executed and the total execution times mentioned previously were averaged. Additionally, the standard deviation was computed in order to verify that it was not a statistically significant deviation which needed further analysis.


- 20 runs of all catalogued variations were run
- STD shown as error bars on chart

### GPU Execution Time Table
	 
[TODO: generate using online generator]	 
	
### GPU Execution Time Chart

[TODO: insert] 
	 
###  Discussion
The highest performing flame variations were the ones that used only a small number of basic arithmetic operations.  The number and complexy of these operations correlate directly with the variations performance.  Flames that use a large amount of mathematical functions such as modulus and the square root are the lowest performing variations.  The performance difference between the best and worst performing variations is on the order of about 20% which is significant but not extreme.

### High Performing Variation
The variations with the highest performance are those with a small number of basic arithmetic operations.  Examples of these include:

*linear:

	ox += tx * w;
	oy += ty * w;

*oscope:


    float tpf = 2.0f * M_PI * {{pv.frequency}};
    float amp = {{pv.amplitude}};
    float sep = {{pv.separation}};
    float dmp = {{pv.damping}};

    float t = amp * expf(-fabsf(tx)*dmp) * cosf(tpf*tx) + sep;

    ox += w*tx;
    if (fabsf(ty) <= t)
        oy -= w*ty;
    else
        oy += w*ty;

*sinusoidal:
    ox += w * sinf(tx);
    oy += w * sinf(ty);

*spherical:
    float r2 = w / (tx*tx + ty*ty);
    ox += tx * r2;
    oy += ty * r2;

*bent:
    float nx = 1.0f;
    if (tx < 0.0f) nx = 2.0f;
    float ny = 1.0f;
    if (ty < 0.0f) ny = 0.5f;
    ox += w * nx * tx;
    oy += w * ny * ty;

## Analysis

## Matt's notes
Making a list of which variations use which functions and at what frequency. TODO: Count frequency of mod and sqrt and do other functions

***mod
modulus 4
rings 1
bipolar 2
fan 1

***sqrt
horseshoe 1
poloar 1
handkerchief 1
heart 1
disc 1
spiral 1
hyperbolic 1
diamond 1
ex 1
julia 2
fisheye 1
power 1
rings 1
fan 1
blob 1
fan2 1
rings2 1
eyefish 1
gaussian blur 1
radial blur 2
blade 1
secant2 1
cross 1
super shape 1
flower 1
conic 1
parabola 1
butterfly 2
edisc 3
elliptic 4
lazysusan 1
loonie 1
scry 1
separation 4
wedge 1
whorl 1
flux 3

***sinf
sinusoidal 2
swirl 1
handkeychief 1
heart 1
disc 1
spiral 2
hyperbolic 1
diamond 2
ex 1
julia 1
waves 2
popcorn 2
exponential 1
power 1
cosine 1
rings 1
fan 1
blob 2
pdj 2
fan2 1
rings2 1
cylinder 1
noise 1
julian 1
juliascope 1
blur 1
guassian_blur 1
radial_blur 2
pie 1
arch 3
tangent 1
rays 1
blade 2
disc2 2
super_shape 1
parabola 1
cpow 1
edisc 1
escher 2
foci 1
lazysusan 1
preblur 1
popcorn2 2
wedge 1
whorl 1
waves2 2
exp 1
sin 1
cos 1
tan 1
sec 1
csc 1
cot 1
sinh 1
cosh 1
tanh 1
sech 1
csch 1
coth 1
flux 1

***cosf
swirl 1
handerchief 1
heart 1
disc 1
spiral 2
hyperbolic 1
diamond 2
ex 1
julia 1
exponential 1
power 1
cosine 1
rings 1
fan 1
blob 1
pdj 2
fan2 1
rings2 1
noise 1
julian 1
juliascope 1
blur 1
gaussian_blur 1
radial_blur 2
pie 1
ngon 1
arch 1
tangent 1
rays 1
blade 2
secant2 1
disc2 2
super_shape 1
flower 1
parabola 1
cpow 1
escher 2
foci 1
lazysusan 1
pre_blur 1
oscope 1
split 2
wege 2
whorl 1
exp 1
sin 1
cos 1
tan 1
sec 2
csc 2
cot 1
sinh 1
cosh 1
tanh 1
sech 2
csch 2
coth 1
flux 1

***acosf
edisc 1

***mwc_next
julia 1
juliascope 1

***mwc_next_01
noise 2
julian 1
juliascope 1
blur 2
gaussian_blur 2
radial_blur
pie 3
arch 1
square 2
rays 1
blade 1
super_shape 1
flower 1
conic 1
parabola 2
boarders 1
cpow 1
pre_blur 5

***expf
exponential 1
cpow 1
curve 2
escher 1
foci 1
oscope 1
exp 1
	
***logf
bipolar 1
cpow 1
edisc 1
elliptic 2
escher 1
polar2 1
log 1

***copysignf
splits 2

***floorf
ngon 1
rectangles 2
cell 2
cpow 1
stripes 1
wedge 1

***atan2f
polar 1
handkerchief 1
heart 1
disc 1
sprial 1
hyperbolic 1
diamond 1
ex 1
julia 1
power 1
rings 1
fan 1
blob 1
fan2 1
rings2 1
julian 1
juliascope 1
radial_blur 1
ngon 1
disc2 1
super_shape 1
flower 1
bipolar 1
cpow 1
elliptic 1
escher 1
lazysusan 1
polar2 1
wedge 1
whorl 1
log 1
flux 2


