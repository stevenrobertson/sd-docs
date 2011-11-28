[TODO: Proof]

# Benchmarking
Increasing the performance of Scott Drave's fractal flame algorithm is a main objective of this project. A secondary objective is for cuburn to accurately render the entire catalogue of variations available in flam3, our reference implementation. In order to verify that both the completeness and performance objectives have been reached it is necessary to benchmark and each flame variation. The benchmark's framework, setup, results, and analysis will be described in the following sections.

## Framework
NVIDIA has released a profiler with CUDA which aids developers in gathering information about a wide array of information such as kernel execution and memory transfer times.  The profile can be enabled and configured by the use of a handful of environment variables that need to be set on the user's operating system. 

By exporting the environment variable `CUDA_PROFILE` and setting it equal to `1`, the profiler exports the program's GPU statistics into a log file. By default, the profile will write the data to `./cuda_profile.log`. If a different location is desired, the user can set the `CUDA_PROFILE_LOG` environment variable accordingly.  Additionally by exporting the environment variable `CUDA_PROFILE_CSV` and setting it equal to `1`, the log file's format can be changed to a comma-seperated value (CSV) format. This format eases the processing of parsing this file for analysis because of it's more rigidly defined format specification.

Performance counters can be used in addition to the default timing information (timestamp, method, gputime, cputime, and occupancy) by creating a profiler configuration file specifying additional performance counters using the `CUDA_PROFILE_CONFIG` environment variable. The performance counters use on-chip hardware counters to gather statistics and hence their use change the algorithm's performance and should be used with caution. These performance counters were explored but in the end did not provide useful statistics or yield any insight that could make for an interesting discussion.

##  Benchmark Machine
In order to accurately talk about the benchmarking results as well as provide a frame of reference for the user, the benchmarking machine is described. The machine used for the benchmarking was an `Alienware M17xR3` laptop model with the following hardware and software specifics:
\newpage

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

The procedure is as follows. First, all of the variations needed to be auto-generated into respective `flam3` files which could be used as input for cuburn. Cuburn can run these `flam3` files individually and the CUDA profiler can produce output statistics (using methods described above). Immediately, using this approach a complication arises. A valid iterated function system must be contractive or contractive on average. Using a single transform that is soley our selected variation is not a valid iterated function system and cuburn may prematurely abort rendering the frame. Because of this, we chose a baseline iterated function system that each variation would be added to. This baseline iterated function consisted of two linear transforms.  The transform code is seen in Figure \ref{baseline_ifs_for_perf}:

\begin{figure}[!ht]
	$<flame>$
	\newline	$<xform\;weight="0.33"\;...\;linear="1"\;coefs="-0.26\;0.0\;0.0\;-0.26\;0.0\;0.020"\;/>$
	\newline
	$<xform weight="1.00"\;...\;linear="1"\;coefs="0.70\;0.70\;-0.70\;0.70\;0.51\;-1.18"\;/>$
	\newline
	$...$
	\newline
	$</flame>$
	\caption{Baseline Iterated Function System that each variation was applied to.}
	\label{baseline_ifs_for_perf}
\end{figure}

When rendering a single frame with standard coloring parameters, a size of 640 $\times$ 480, quality of 50, and the predefined autumn-themed color palette `10` the resulting flame looks like that of Figure \ref{baseline_ifs_image_for_perf}:

\begin{figure}[!ht]
	\centering
	\includegraphics{./benchmarking/baseline_ifs.png}
	\caption{Visual of Baseline Iterated Function System}
	\label{baseline_ifs_image_for_perf}
\end{figure}

Now that an acceptable iterated function has been chosen we can append the appropriate variation to one of the xforms. We have chosen to append it to the second xform but have to note that this decision was does not have any significant effects besides that the chance of the variation being applied is $Second\;Xform_{Weight} \times  Variation_{Weight}$ versus $First\;Xform_{Weight} \times Variation_{Weight}$ if it were applied to the first variation.

The new transform code for the second xform would look like Figure \ref{julia_variation_perf} if the `julia` were applied:

\begin{figure}[!ht]
	$<xform weight="1.00"\;...\;linear="1"\;coefs="0.70\;0.70\;-0.70\;0.70\;0.51\;-1.18"\;julia="1e-07"\;/>$
	\caption{Julia variation being applied to Baseline Iterated Function System.}
	\label{julia_variation_perf}
\end{figure}

By keeping the baseline IFS fixed and just appending an additional variation for each flame we can effectively isolate the runtime differences caused by having to load the additional code onto our device and compute the additional variation. This will only hold if our initial assumptions that the runtime is consistent that for each generation of a flame with minimal deviation.

The extremely low weighting value (chance of variation being applied) of $1e-7$ was chosen because it will still be applied given the tremendous amount of points being computed however it will only influence it in a minor fashion. This small influence is what we hope to capture. The weight could have been dramatically increased but the entire benchmarking process would have taken an greatly increased amount of time and the graphs would more than likely need additional transformations such as log filtering in order to be useful.

### Accumulating Kernel Execution Times

After using CUDA's `Compute Visual Profiler` developer tool to compare several pairs of the numerous variation profile results it was found that the only interesting kernel which changed was the main `iter` kernel. We have decided to focus on comparisons between this kernel when presenting our results. A drawback of the `Compute Visual Profiler` is that it is limited to comparing 2 profile results and lacks more sophisticated tools such as averaging multiple runs, computing standard deviations, and comparing numerous profile results. A hand crafted solution was in order if the data was needed to be properly visualized and analyzed.

The CUDA profile log file we are using displays each instance of the kernel running regardless if it is a kernel that has run previously. This results in numerous `iter` kernel entries for our log file. In order of this information to be of any use the individual `iter` GPU times needed to be accumulated to produce a Total GPU time. Once this was done all of the variations were compared using a bar chart sorted ascendingly. The graph confirmed our predictions that variations that applied more expensive operations such as modulus performed worse than variations that applied simple arithmetic such as linear. However, this was not enough to convince ourselves and conclude that this was the way the system operated.

### Multiple Runs and Standard Deviation Analysis: Convincing ourselves, and you

Comparing `iter` kernel execution times between all catalogued variations is not enough. In order to account for the difference of execution times between runs, multiple runs were executed and the total execution time was averaged. Additionally, the standard deviation was computed in order to verify that it was not a statistically significant deviation which needed further analysis. The standard deviation proved to be of minimal concern and the conclusive results are presented in the next section and then visualized afterwards.

### GPU Execution Time Table

Below in Table \ref{iter_execution_table} are the average GPU execution times of 20 runs and their respective standard deviations of the `iter` kernel ordered ascendingly.

\begin{center}
	\begin{longtable}{|c|c|c|} 
		\hline
		\textbf{Variation Applied:} & \textbf{GPU Execution Time ($\mu$sec): }& \textbf{Standard Deviation ($\mu$sec):}\\ \hline
		linear & 41215.01 & 30.41\\ \hline
		oscope & 41220.54 & 25.60\\ \hline
		sinusoidal & 41482.11 & 33.98\\ \hline
		spherical & 41541.97 & 36.79\\ \hline
		bent & 41591.70 & 36.05\\ \hline
		exp & 41603.94 & 34.31\\ \hline
		bubble & 41609.78 & 37.94\\ \hline
		exponential & 41670.39 & 36.64\\ \hline
		horseshoe & 41684.67 & 33.05\\ \hline
		square & 41687.31 & 30.63\\ \hline
		waves & 41688.71 & 29.72\\ \hline
		swirl & 41714.31 & 23.33\\ \hline
		cross & 41726.91 & 34.17\\ \hline
		cylinder & 41768.29 & 42.57\\ \hline
		loonie & 41779.30 & 40.05\\ \hline
		arch & 41815.04 & 37.59\\ \hline
		tangent & 41832.91 & 34.37\\ \hline
		rays & 41870.36 & 41.76\\ \hline
		blur & 41871.57 & 28.48\\ \hline
		bent2 & 41871.63 & 35.45\\ \hline
		scry & 41875.42 & 36.75\\ \hline
		foci & 41893.15 & 36.83\\ \hline
		stripes & 41911.58 & 39.83\\ \hline
		blade & 41921.20 & 30.32\\ \hline
		pre\_blur & 41930.98 & 33.02\\ \hline
		noise & 41941.71 & 40.02\\ \hline
		fisheye & 41968.95 & 36.98\\ \hline
		eyefish & 41977.16 & 30.31\\ \hline
		split & 42008.76 & 33.99\\ \hline
		butterfly & 42018.22 & 36.21\\ \hline
		secant2 & 42030.67 & 33.96\\ \hline
		rectangles & 42035.00 & 29.72\\ \hline
		curl & 42051.49 & 24.40\\ \hline
		splits & 42069.96 & 34.11\\ \hline
		perspective & 42181.27 & 31.24\\ \hline
		waves2 & 42257.88 & 25.12\\ \hline
		popcorn & 42259.05 & 33.54\\ \hline
		pdj & 42292.23 & 26.90\\ \hline
		parabola & 42333.18 & 31.25\\ \hline
		popcorn2 & 42401.33 & 37.46\\ \hline
		gaussian\_blur & 42409.56 & 28.35\\ \hline
		cell & 42562.43 & 44.09\\ \hline
		curve & 42617.94 & 26.56\\ \hline
		conic & 42636.51 & 43.74\\ \hline
		lazysusan & 42642.68 & 31.45\\ \hline
		separation & 42698.13 & 25.62\\ \hline
		log & 42725.48 & 54.63\\ \hline
		cosine & 42809.25 & 44.79\\ \hline
		cos & 42823.28 & 38.41\\ \hline
		sin & 42835.36 & 42.60\\ \hline
		polar2 & 42845.89 & 43.50\\ \hline
		polar & 42853.39 & 51.13\\ \hline
		cosh & 42861.36 & 44.98\\ \hline
		pie & 42868.96 & 23.46\\ \hline
		hyperbolic & 42884.68 & 52.65\\\hline 
		handkerchief & 42909.86 & 62.95\\ \hline
		heart & 42965.43 & 66.75\\ \hline
		cot & 42966.10 & 47.70\\ \hline
		tan & 42975.99 & 40.86\\ \hline
		diamond & 42993.51 & 55.80\\ \hline
		julia & 43026.11 & 79.77\\ \hline
		power & 43058.50 & 60.50\\ \hline
		disc & 43075.76 & 76.50\\ \hline
		sinh & 43148.75 & 54.12\\ \hline
		ex & 43213.52 & 46.36\\ \hline
		tanh & 43221.40 & 47.42\\ \hline
		coth & 43268.99 & 38.96\\ \hline
		sec & 43316.82 & 46.80\\ \hline
		spiral & 43317.85 & 59.94\\ \hline
		csc & 43318.06 & 48.53\\ \hline
		sech & 43451.97 & 50.67\\ \hline
		fan2 & 43466.66 & 62.67\\ \hline
		flower & 43516.26 & 42.37\\ \hline
		rings2 & 43519.23 & 50.51\\ \hline
		mobius & 43537.89 & 25.99\\ \hline
		julian & 43575.00 & 51.50\\ \hline
		juliascope & 43640.76 & 48.41\\ \hline
		blob & 43698.43 & 56.94\\ \hline
		boarders & 43741.34 & 110.07\\ \hline
		escher & 43763.02 & 55.41\\ \hline
		disc2 & 43845.57 & 62.24\\ \hline
		bipolar & 43847.78 & 77.48\\ \hline
		csch & 43994.95 & 51.53\\ \hline
		wedge & 44104.10 & 55.02\\ \hline
		radial\_blur & 44131.67 & 76.65\\ \hline
		cpow & 44185.85 & 61.63\\ \hline
		ngon & 44333.52 & 74.90\\ \hline
		elliptic & 44484.01 & 76.08\\ \hline
		super\_shape & 44871.59 & 77.20\\ \hline
		edisc & 45076.11 & 134.23\\ \hline
		flux & 45527.62 & 217.42\\ \hline
		rings & 47397.50 & 355.91\\ \hline
		fan & 47726.17 & 393.94\\ \hline
		modulus & 49125.81 & 225.78\\ \hline
		\caption[execution table]{`Iter` kernel performance results on each variation.} \label{iter_execution_table}
	\end{longtable}
\end{center}
	
### GPU Execution Time Bar Graph

This data can easily be visualized on a bar graph and as an additional feature error bars can be added to represent the standard deviations of each variations. This is shown in Figure \ref{iter_execution_graph}:

\newpage

\begin{figure}[!ht]
	\centering
	\includegraphics{benchmarking/kernel_execution_times.pdf}}
	\caption{Bar graph of `iter` kernel performance results on each variation.}
	\label{iter_execution_graph}
\end{figure}

[TODO: Matt]

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


