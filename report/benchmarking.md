# Benchmarking
Increasing the performance of Scott Drave's fractal flame algorithm is a main objective of this project.  To properly show that the performance objectives have been reached, it is necessary to benchmark and analyze each flame variation.  The benchmark's framework, implementation's performance, and analysis will be described in the following sections.

## Framework
NVIDIA has released a simple profiler with CUDA that will gather kernel execution and memory transfer times.  The profile can be enabled and configured by the use of a handful of environment variables.  The profiler can be enabled so that it dumps the default timing information to a log by simply setting the environment variable "CUDA_PROFILE" to 1.  The profile will write the data to ./cuda_profile.log by default; if a different location is desired, the user can set the "CUDA_PROFILE_LOG" environment variable accordingly.  Performance counters can be used in addition to the default timing information (timestamp, method, gputime, cputime, and occupancy) by creating a profiler configuration file specifying additional performance counters (using the CUDA_PROFILE_CONFIG environment variable).  The performance counters use on-chip hardware counters to gather statistics and hence their use change the algorithm's performance and should be used with caution. 

## Performance
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


