# Benchmarking
A major objective of this project is to benchmark the performance of cuburn while it is executing on the GPU. A secondary objective is for cuburn to accurately render the entire catalogue of variations available in flam3, our reference implementation. In order to verify that both the completeness and performance objectives have been reached it is necessary to benchmark and each flame variation. The benchmark's framework, setup, results, and analysis will be described in the following sections.

A very important note is on the matter of comparing the flam3, the reference implementation, and cuburn is that it is a complicated matter which could be done many ways that do not lend any meaningful insight. Because performance can vary so greatly depending on the flam3 used we instead present an alternative, meaningful discussion on benchmarking the interesting performance statistics of cuburn.

## Framework
NVIDIA has released a profiler with CUDA which aids developers in gathering information about a wide array of information such as kernel execution and memory transfer times.  The profile can be enabled and configured by the use of a handful of environment variables that need to be set on the user's operating system. 

By exporting the environment variable `CUDA_PROFILE` and setting it equal to `1`, the profiler exports the program's GPU statistics into a log file. By default, the profile will write the data to `./cuda_profile.log`. If a different location is desired, the user can set the `CUDA_PROFILE_LOG` environment variable accordingly.  Additionally by exporting the environment variable `CUDA_PROFILE_CSV` and setting it equal to `1`, the log file's format can be changed to a comma-separated value (CSV) format. This format eases the processing of parsing this file for analysis because of it's more rigidly defined format specification.

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

After several empirical tests and observations it was noted that GPU time was one of the main performance statistics that we wanted to explore and discuss. With our goal of accurately comparing all of the catalogued variations, a design procedure was needed that attempted to isolate all other factors that could influence execution time and exclusively focus on how the variation code injected in the device. 

[TODO: Furthermore, after these performance statistics were to be attained we need to statistically prove they can be compared]

### Auto generation of flames

The procedure is as follows. First, all of the variations needed to be auto-generated into respective `flam3` files which could be used as input for cuburn. Cuburn can run these `flam3` files individually and the CUDA profiler can produce output statistics (using methods described above). Immediately, using this approach a complication arises. A valid iterated function system must be contractive or contractive on average. Using a single transform that is solely our selected variation is not a valid iterated function system and cuburn may prematurely abort rendering the frame. Because of this, we chose a baseline iterated function system that each variation would be added to. This baseline iterated function consisted of two linear transforms.  The transform code is seen in Figure \ref{baseline_ifs_for_perf}:

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

Now that an acceptable iterated function has been chosen we can append the appropriate variation to one of the xforms. We have chosen to append it to the second xform but have to note that this decision was does not have any significant effects besides that the chance of the variation being applied is $Second\;Xform_{Weight}$ $\times  Variation_{Weight}$ versus $First\;Xform_{Weight} \times Variation_{Weight}$ if it were applied to the first variation.

The new transform code for the second xform would look like Figure \ref{julia_variation_perf} if the `julia` variation was applied:

\begin{figure}[!ht]
	$<xform weight="1.00"\;...\;linear="1"\;coefs="0.70\;0.70\;-0.70\;0.70\;0.51\;-1.18"\;julia="1e-07"\;/>$
	\caption{Julia variation being applied to Baseline Iterated Function System.}
	\label{julia_variation_perf}
\end{figure}

By keeping the baseline IFS fixed and just appending an additional variation for each flame we can effectively isolate the runtime differences caused by having to load the additional code onto our device and compute the additional variation. This will only hold if our initial assumptions that the runtime is consistent that for each generation of a flame with minimal deviation.

The extremely low weighting value (chance of variation being applied) of $1e-7$ was chosen because it will still be applied given the tremendous amount of points being computed however it will only influence it in a minor fashion. This small influence is what we hope to capture. The weight could have been dramatically increased but the entire benchmarking process would have taken an greatly increased amount of time and the graphs would more than likely need data transformations such as a log transformation in order to be useful.

### Accumulating Kernel Execution Times

After using CUDA's `Compute Visual Profiler` developer tool to compare several pairs of the numerous variation profile results it was found that the only interesting kernel which changed was the main `iter` kernel. We have decided to focus on comparisons between this kernel when presenting our results. A drawback of the `Compute Visual Profiler` is that it is limited to comparing 2 profile results and lacks more sophisticated tools such as averaging multiple runs, computing standard deviations, and comparing numerous profile results. A hand crafted solution was in order if the data was needed to be properly visualized and analyzed.

The CUDA profile log file we are using displays each instance of the kernel running regardless if it is a kernel that has run previously. This results in numerous `iter` kernel entries for our log file. In order of this information to be of any use the individual `iter` GPU times needed to be accumulated to produce a Total GPU time. Once this was done all of the variations were compared using a bar chart sorted in ascending order. The graph confirmed our predictions that variations that applied more expensive operations such as modulus performed worse than variations that applied simple arithmetic such as linear. However, this was not enough to convince ourselves and conclude that this was the way the system operated.

### Multiple Runs and Standard Deviation Analysis: Convincing ourselves, and you

Comparing `iter` kernel execution times between all catalogued variations is not merely enough. In order to account for the difference of execution times between runs, multiple runs were executed and the total execution time was averaged. Additionally, the standard deviation was computed in order to verify that it was not a statistically significant deviation which needed further analysis. The standard deviation proved to be of minimal concern and the conclusive results are presented in the next section and then visualized afterwards.

### GPU Execution Time Table

Below in Table \ref{iter_execution_table} are the average GPU execution times of 20 runs and their respective standard deviations of the `iter` kernel sorted in ascending order.

\begin{center}
	\begin{longtable}{|c|c|c|} 
		\hline
		\textbf{Variation Applied:} & \textbf{GPU Execution Time ($\mu$sec): }& \textbf{Standard Deviation ($\mu$sec):}\\ \hline
		linear & 41,215.01 & 30.41\\ \hline
		oscope & 41,220.54 & 25.60\\ \hline
		sinusoidal & 41,482.11 & 33.98\\ \hline
		spherical & 41,541.97 & 36.79\\ \hline
		bent & 41,591.70 & 36.05\\ \hline
		exp & 41,603.94 & 34.31\\ \hline
		bubble & 41,609.78 & 37.94\\ \hline
		exponential & 41,670.39 & 36.64\\ \hline
		horseshoe & 41,684.67 & 33.05\\ \hline
		square & 41,687.31 & 30.63\\ \hline
		waves & 41,688.71 & 29.72\\ \hline
		swirl & 41,714.31 & 23.33\\ \hline
		cross & 41,726.91 & 34.17\\ \hline
		cylinder & 41,768.29 & 42.57\\ \hline
		loonie & 41,779.30 & 40.05\\ \hline
		arch & 41,815.04 & 37.59\\ \hline
		tangent & 41,832.91 & 34.37\\ \hline
		rays & 41,870.36 & 41.76\\ \hline
		blur & 41,871.57 & 28.48\\ \hline
		bent2 & 41,871.63 & 35.45\\ \hline
		scry & 41,875.42 & 36.75\\ \hline
		foci & 41,893.15 & 36.83\\ \hline
		stripes & 41,911.58 & 39.83\\ \hline
		blade & 41,921.20 & 30.32\\ \hline
		pre\_blur & 41,930.98 & 33.02\\ \hline
		noise & 41,941.71 & 40.02\\ \hline
		fisheye & 41,968.95 & 36.98\\ \hline
		eyefish & 41,977.16 & 30.31\\ \hline
		split & 42,008.76 & 33.99\\ \hline
		butterfly & 42,018.22 & 36.21\\ \hline
		secant2 & 42,030.67 & 33.96\\ \hline
		rectangles & 42,035.00 & 29.72\\ \hline
		curl & 42,051.49 & 24.40\\ \hline
		splits & 42,069.96 & 34.11\\ \hline
		perspective & 42,181.27 & 31.24\\ \hline
		waves2 & 42,257.88 & 25.12\\ \hline
		popcorn & 42,259.05 & 33.54\\ \hline
		pdj & 42,292.23 & 26.90\\ \hline
		parabola & 42,333.18 & 31.25\\ \hline
		popcorn2 & 42,401.33 & 37.46\\ \hline
		gaussian\_blur & 42,409.56 & 28.35\\ \hline
		cell & 42,562.43 & 44.09\\ \hline
		curve & 42,617.94 & 26.56\\ \hline
		conic & 42,636.51 & 43.74\\ \hline
		lazysusan & 42,642.68 & 31.45\\ \hline
		separation & 42,698.13 & 25.62\\ \hline
		log & 42,725.48 & 54.63\\ \hline
		cosine & 42,809.25 & 44.79\\ \hline
		cos & 42,823.28 & 38.41\\ \hline
		sin & 42,835.36 & 42.60\\ \hline
		polar2 & 42,845.89 & 43.50\\ \hline
		polar & 42,853.39 & 51.13\\ \hline
		cosh & 42,861.36 & 44.98\\ \hline
		pie & 42,868.96 & 23.46\\ \hline
		hyperbolic & 42,884.68 & 52.65\\\hline 
		handkerchief & 42,909.86 & 62.95\\ \hline
		heart & 42,965.43 & 66.75\\ \hline
		cot & 42,966.10 & 47.70\\ \hline
		tan & 42,975.99 & 40.86\\ \hline
		diamond & 42,993.51 & 55.80\\ \hline
		julia & 43,026.11 & 79.77\\ \hline
		power & 43,058.50 & 60.50\\ \hline
		disc & 43,075.76 & 76.50\\ \hline
		sinh & 43,148.75 & 54.12\\ \hline
		ex & 43,213.52 & 46.36\\ \hline
		tanh & 43,221.40 & 47.42\\ \hline
		coth & 43,268.99 & 38.96\\ \hline
		sec & 43,316.82 & 46.80\\ \hline
		spiral & 43,317.85 & 59.94\\ \hline
		csc & 43,318.06 & 48.53\\ \hline
		sech & 43,451.97 & 50.67\\ \hline
		fan2 & 43,466.66 & 62.67\\ \hline
		flower & 43,516.26 & 42.37\\ \hline
		rings2 & 43,519.23 & 50.51\\ \hline
		mobius & 43,537.89 & 25.99\\ \hline
		julian & 43,575.00 & 51.50\\ \hline
		juliascope & 43,640.76 & 48.41\\ \hline
		blob & 43,698.43 & 56.94\\ \hline
		boarders & 43,741.34 & 110.07\\ \hline
		escher & 43,763.02 & 55.41\\ \hline
		disc2 & 43,845.57 & 62.24\\ \hline
		bipolar & 43,847.78 & 77.48\\ \hline
		csch & 43,994.95 & 51.53\\ \hline
		wedge & 44,104.10 & 55.02\\ \hline
		radial\_blur & 44,131.67 & 76.65\\ \hline
		cpow & 44,185.85 & 61.63\\ \hline
		ngon & 44,333.52 & 74.90\\ \hline
		elliptic & 44,484.01 & 76.08\\ \hline
		super\_shape & 44,871.59 & 77.20\\ \hline
		edisc & 45,076.11 & 134.23\\ \hline
		flux & 45,527.62 & 217.42\\ \hline
		rings & 47,397.50 & 355.91\\ \hline
		fan & 47,726.17 & 393.94\\ \hline
		modulus & 49,125.81 & 225.78\\ \hline
		\caption[execution table]{`Iter` kernel performance results on each variation.} \label{iter_execution_table}
	\end{longtable}
\end{center}
	
### GPU Execution Time Bar Graph

This data can easily be visualized on a bar graph and as an additional feature error bars representing the standard deviation have been added. This is shown in Figure \ref{iter_execution_graph}:

\newpage

\begin{figure}[!ht]
	\centering
	\includegraphics{benchmarking/kernel_execution_times.pdf}}
	\caption{Bar graph of `iter` kernel performance results on each variation.}
	\label{iter_execution_graph}
\end{figure}

##  Discussion and Analysis
Visualizing the execution times easily makes for an interesting discussion concerning why certain variations performed the way they did as well as the explanations that explain the differences in execution times. The first observation is that it is rather difficult to cluster variations into performance groups as the execution times increase linearly (with a few outliers such as the `rings`, `modulus`, and the `fan` variation). The performance difference between the best and worst performing variations is on the order of 20% which is shows significance but for single frame renders is negligible to casual human observation. Of course if this was reframed with our goals being real time rendering then that casual 20% is now whopping difference which would prompt further optimizations. Furthermore, the standard deviations of lower performing variations were dramatically higher than more well behaved higher performing variations such as linear.

By observational sampling of high, mid-grade, and low performing variations, a conjecture that operations such as addition, subtraction, multiplication, division, generating a MWC random number, and basic trigonometric functions such as sine and cosine are less expensive in terms of GPU time than the operations that follows. These more expensive operations were found to be modulus, exponential math, square root values, and logarithms. By observing the actual code that will be dynamically generated on the device we can verify the conjecture above. Some of the highest performing variations in terms of performance are seen in Figure \ref{high_perf_1}, Figure \ref{high_perf_2}, and Figure \ref{high_perf_3}. Lower performing variations are seen in Figure \ref{low_perf_1}, Figure \ref{low_perf_2}, and \ref{low_perf_3}.


### High Performing Variation
Three high performing variations are presented below:

\begin{figure}[!ht]
\begin{verbatimtab}
		ox += tx * w;
		oy += ty * w;
\end{verbatimtab}
\caption{High Performing Variation 1: Code for `linear` variation}
\label{high_perf_1}
\end{figure}

\begin{figure}[!ht]
\begin{verbatimtab}
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
\end{verbatimtab}
\caption{High Performing Variation 2: Code for `oscope` variation}
\label{high_perf_2}
\end{figure}

\begin{figure}[!ht]
\begin{verbatimtab}
		ox += w * sinf(tx);
		oy += w * sinf(ty);
\end{verbatimtab}
\caption{High Performing Variation 3: Code for `sinusoidal` variation}
\label{high_perf_3}
\end{figure}

\newpage

### Low Performing Variation
Three low performing variations are presented below:

\begin{figure}[!ht]
\begin{verbatimtab}
		float mx = {{pv.x}}, my = {{pv.y}};
		float xr = 2.0f*mx;
		float yr = 2.0f*my;

		if (tx > mx)
			ox += w * (-mx + fmodf(tx + mx, xr));
		else if (tx < -mx)
			ox += w * ( mx - fmodf(mx - tx, xr));
		else
			ox += w * tx;

		if (ty > my)
			oy += w * (-my + fmodf(ty + my, yr));
		else if (ty < -my)
			oy += w * ( my - fmodf(my - ty, yr));
		else
			oy += w * ty;
\end{verbatimtab}
\caption{Low Performing Variation 1: Code for `modulus` variation}
\label{low_perf_1}
\end{figure}

\begin{figure}[!ht]
\begin{verbatimtab}
		float dx = M_PI * ({{px.affine.xo}} * {{px.affine.xo}});
		float dx2 = 0.5f * dx;
		float dy = {{px.affine.yo}};
		float a = atan2f(tx, ty);
		a += (fmodf(a+dy, dx) > dx2) ? -dx2 : dx2;
		float r = w * sqrtf(tx*tx + ty*ty);
		ox += r * cosf(a);
		oy += r * sinf(a);
\end{verbatimtab}
\caption{Low Performing Variation 2: Code for `fan` variation}
\label{low_perf_2}
\end{figure}


\begin{figure}[!ht]
\begin{verbatimtab}
		float dx = {{px.affine.xo}} * {{px.affine.xo}};
		float r = sqrtf(tx*tx + ty*ty);
		float a = atan2f(tx, ty);
		r = w * (fmodf(r+dx, 2.0f*dx) - dx + r * (1.0f - dx));
		ox += r * cosf(a);
		oy += r * sinf(a);
\end{verbatimtab}
\caption{Low Performing Variation 3: Code for `rings` variation}\label{low_perf_3}
\end{figure}


In closing, these performance benchmarks allow us to observe how the device code runs reliably without having to crawl over ten thousand lines of assembler to find out which operations they use. These benchmarks show that we don't have to count opcodes in order to understand performance. It is evident from the charts that the performance estimates from assembly are reliable without things such as memory accesses getting in the way.



