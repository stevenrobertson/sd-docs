# Benchmarking
Increased performance of an existing algorithm is a main objective of this project.  To properly show that the performance objectives have been reached, it is necessary to benchmark and analyze each variation.  The benchmark framework, performance, and analysis will be described.

## Framework
NVIDIA has released a simple profiler with CUDA that will gather kernel execution and memory transfer times.  The profile can be enabled and configured by the use of a handful of environment variables.  The profiler can be enabled so that it dumps the default timing information to a log by simply setting the environment variable "CUDA_PROFILE" to 1.  The profile will write the data to ./cuda_profile.log by default; if a different location is desired, the user can set the "CUDA_PROFILE_LOG" environment variable accordingly.  Performance counters can be used in addition to the default timing information (timestamp, method, gputime, cputime, and occupancy) by creating a profiler configuration file specifying additional performance counters (using the CUDA_PROFILE_CONFIG environment variable).  The performance counters use on-chip hardware counters to gather statistics and hence their use change the algorithm's performance and should be used with caution. 

## Performance

## Analysis

## Matt's notes
Making a list of which variations use which functions and at what frequency. TODO: Count frequency of mod and sqrt and do other functions

***mod
modulus
rings
bipolar
fan

***sqrt
flux
horseshoe
poloar
handkerchief
heart
disc
spiral
hyperbolic
diamond
ex
julia
fisheye
power
rings
fan
blob
fan2
rings2
eyefish
gaussian blur
radial blur
blade
secant2
cross
super shape
flower
conic
parabola
butterfly
edisc
elliptic
lazysusan
loonie
scry
separation
wedge
whorl
flux

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

