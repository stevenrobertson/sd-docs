#Fractal Background
##Purpose of Section

The fractal flame algorithm draws upon concepts across many fields including: statistics, mathematics, fractal geometry, the philosophy of art and aesthetics, computer graphics, computer science, and others. One may become short of breathe just trying to read that entire sentence on one breathe of air.  The point that is trying to made is that the fractal flame algorithm is arguably the most complex fractal process to date. The road ahead of us for not only optimizing but fundamentally changing the process for how fractal flames are rendered is not so clear and will require a solid knowledge as well as innovation.

The innovation is what the majority of this paper is about and as a guiding rule the words of Sir Francis Bacon are very true to the author's research process: *"When you wish to achieve results that have not been achieved before, it is an unwise fancy to think that they can be achieved by using methods that have been used before."*

As unwise as it would be to assume a solution to the current design challenge has already been solved, it would also be unwise not to draw from previous knowledge from the aforementioned fields. Therefore knowledge from mathematics, statistics, and graphics will be supplemented as needed when design decisions are presented later in the paper. However, before the paper transitions into the innovation aspect of this project, the need to present ample background information on two fields of which warrant attention is felt. These fields are fractal geometry and the aesthetic nature of fractal geometry.


The justification of presenting fractal geometry lies in the reasoning that the mathematics and properties behind it is not blatantly intuitive and key concepts cannot be hand waved later in this paper. Had the famous equation $z_{n+1} = z^2_n + C$ been intuitive then humans would be able to visualize it, without the aid of computer graphics, as the Mandelbrot Set (Figure \ref{mandelbrot}) and understand its ability to scale infinitely without degradation.

\begin{figure}[h!]
	\centering
	\includegraphics{./fractal/mandelbrot.png}
	\caption{The Mandelbrot Set}
	\label{mandelbrot}
\end{figure}

This section will touch on these intriguing and sometimes counterintuitive fractal properties and also address their relevance in the project and what limitations they pose upon us for a GPU implementation or new approach. The different types of fractals and how fractal flames, a variant of the iterated function system, vary from the Mandelbrot set, shown above, will be explained. Unlike classical geometry, fractal geometry is a rather new field of geometry and the authors believe presenting a comprehensive knowledge of the field in context of the project is absolutely feasible.

The next area that will be articulated is an atypical one: the aesthetical nature of fractal geometry. The concept of beauty is something that has not been universally defined and one may often allude to the idiom: *"Beauty is in the eye of the beholder."* Besides perhaps art therapy and for visual appeal, flame fractals do not have an immediate real life application and therefore much of the justification for developing a GPU Fractal Flame Render lies upon their aesthetics, the idea of creating a process which allows artistic formation, and the wonder they bring. Excruciating detail is spared but major milestones are shown in history dating back to African civilizations who built their culture and art around self-similar repeating geometric figures. The point trying to be made is that there is a widely accepted attraction towards these shapes that penetrates different societies and cultures.

After understanding the background behind fractal aesthetics this will be furthered with additional visual concepts such as gamma correction, filtering, motion blur, and symmetry.

##Origins: Euclidean Geometry vs. Fractal Geometry

Geometry has formalized the way humans talk about and perceive points, shapes of figures, and the properties of space. Up until the $19^{th}$ century geometry need not be prefixed with the specific type of geometry that it was referring to- it was assumed it was Euclidean, named after *Euclid* the Greek mathematician of Alexandria, Egypt.  While teaching at the Alexandria Library, Euclid had transcribed a comprehensive set of 13 books in which he titled *Elements*. These books described Euclidean Geometry (and other topics) and included his own work along with other mathematicians including Thales, Pythagoras, Plato, Eudoxus, Aristotle, Menaechmus, and other predecessors.

*Element*'s impact was dramatic. So much so that *Euclid* is often referred to as the "Father of Geometry". By the $20^{th}$ century Euclidean geometry was being taught globally in schools. Shapes such as: circles, triangles, and polygons are taught at an early age.

However as influential as the idea of Euclidean Geometry is its ideal shapes failed to describe the shapes that appear in nature. As stated in the opening paragraph of Benoît Mandelbrot's book, The Fractal Geometry of Nature: *"Clouds are not spheres, mountains are not cones, and lightning does not travel in a straight line. The complexity of nature's shapes differs in kind, not merely degree, from that of the shapes of ordinary geometry."*[1]

##Fractal Geometry and Its Properties

This new geometry Benoît Mandelbrot writes about in his book, he calls fractals which come from the Latin work fractus meaning *"fractured"*.  These new shapes exhibited different properties than classical Euclidean shapes. These shapes were rough and did not belong to an integer valued dimension. Fractals also exhibited self-similarity in which parts of the figure repeat themselves. Ideal fractals also did not degrade with scale either like other classical shapes or like a photograph. These new shapes had been investigated in the Western World previous to Mandelbrot and were already an accepted part of African art and culture before Mandelbrot had been observed and published his findings which lead to their widespread use and acceptance.

The properties in which Mandelbrot and his predecessors have found are summarized. They later will be freely referenced from this point forward when they are needed to explain additional concepts.

[TODO Allude to glossary]

###Self Similarity

Fractals contain the property of self-similarity. This self-similarity is classified into different types ranging from the strongest form which is called exact self-similarity to the weakest form called statistical or approximate self-similarity. The three classifications are below:

**Exact Self-Similarity:** This type of self-similarity contains, as its name implies, exact copies of itself repeating at infinitely smaller scales. Classical examples include Sierpinski's gasket or the Koch Curve (Figure \ref{kochcurve}).

\begin{figure}[h]
	\centering
	\includegraphics{./fractal/koch_curve.png}
	\caption{The Koch Curve}
	\label{kochcurve}
\end{figure}


**Quasi Self-Similarity:** This type of self-similarity does not contain exact copies but rather distorted or degenerate forms of itself at infinitely smaller scales. Classical examples include the Mandelbrot set (Figure \ref{mandelbrot}).

**Statistical Self-Similarity:** This type of self-similarity is the weakest and is the type often encountered in the real world. Statistical self-similarity refers to the fact that the object has numerical or statistical measurements that are maintained at different scales. When classifying shapes in nature as fractal-like this definition is being implied. For example, the self-similar aspects of how a tree branches (See Figure \ref{treebranching}) are never found to be exact and sometimes deviate from their expected pattern but still exhibit self similarity in a sense. The definition of statistical self-similarity  account for this and is important because the luxury is not always given to observe concepts in their ideal sense.
Another classical example is measuring a coastline such as Britain. When scaling the coastline it appears similar to at magnified scales. Additionally, what follows from this is the more accurately one measures the coastline (with a smaller base measurement) the more the length increases. This length increases without limit and contrary to intuition shows that the coastline of a country is infinite.

\begin{figure}[h!]
	\centering
	\includegraphics{./fractal/tree_branching.png}
	\caption{Statistical self-similarity found in the branching of trees.}
	\label{treebranching}
\end{figure}


###Fractal Dimensionality

Classical dimensionality is often expressed in whole number integer values. Lines have a dimensionality of 1, squares have a dimensionality of 2, and cubes have a dimensionality of 3. This however does not explain how completely a fractal fills a space. Does the Sierpinski's Triangle (Figure \ref{sierpinskitriangle}) cover 1 dimension like a line or 2 dimensions like a triangle? The answer is actually that it contains a dimension that is between the two!

\begin{figure}[h!]
	\centering
	\includegraphics{./fractal/sierpinski.png}
	\caption{A visual of Sierpinski's Triangle which has a fractal dimensionality.}
	\label{sierpinskitriangle}
\end{figure}

This can be shown using a variety of ways that formally define fractal
dimensionality including: Hausdorff dimension, Rènyi dimension, and packing
dimension. These theoretical definitions differ in their approach however all
three attempts to explain the same phenomenon: real numbered dimensionality.

Fractal dimensionality will be explained in this section in an intuitive way
rather than providing the reader with a heavy mathematical explanation. This
will be done using the concept of a box-counting dimension which lends itself
to ideas from the Rènyi dimension.

To calculate the dimensionality of an object, an equidistant grid is imposed upon the object and the number of boxes that are necessary to cover the object are counted. The process continues and the equidistant grid is refined by decreasing the size of the grid. Again, the number of boxes that are necessary to cover the object are counted and the process repeats. The formula used is:

\begin{displaymath}
    \text{Dimensionality}_{box}(S) =
    \lim_{\varepsilon \to 0}
        \frac{\log N(\varepsilon)}{\log \frac{1}{\varepsilon}}
\end{displaymath}

where $N(\varepsilon)$ is the number of boxes needed to cover the set, $\varepsilon$ is the side length of each box, and $S$ is the set to be covered.

For a line with a known dimensionality of 1 the box counting procedure is performed. The procedure will start with a side length of length 1 and continually half the side length until a recognizable pattern emerges (See Figure \ref{bcline}).

\begin{figure}[h]
	\centering
	\includegraphics{./fractal/bc_line.png}
	\caption{Box Counting Dimension Process For a Line}
	\label{bcline}
\end{figure}

The box counting equation can be solved by completing the pattern that shows the rate at which the number of boxes in the grid grow compared to the number of boxes needed to cover the shape as the side length approaches 0. This is shown in Table \ref{bclinetable}.

\begin{table}[h]
	\begin{tabular}{|l|l|}
		\hline
		\ \textbf{Box Length: }	$\varepsilon$	& \textbf{Number of Boxes:} $N(\varepsilon)$  	\\
		\hline
		$1$										& $1$											\\
		\hline
		$\frac{1}{2}$							& $2$											\\
		\hline
		$\frac{1}{4}$							& $4$											\\
		\hline
		$\frac{1}{8}$							& $8$											\\
		\hline
		...										& ...											\\
		\hline
		$\varepsilon$							& $\frac{1}{\varepsilon}$						\\
		\hline
	\end{tabular}
	\caption{ Box length ($\varepsilon$) and the number of boxes ($N(\varepsilon)$)  as $\varepsilon$ approaches 0. }
		\label{bclinetable}
\end{table}

From this table the following formula can be deduced by solving the pattern.

\begin{displaymath}
    \text{Dimensionality}_{Line}(S) =
    \lim_{\varepsilon \to 0}
        \frac{\log \frac{1}{\varepsilon}}{\log \frac{1}{\varepsilon}} = 1
\end{displaymath}

Our box counting procedure coincides with the view that a line has a dimensionality of one. We now use this same box counting procedure to calculate a shape of non integer value dimensionality. Sierpinski's gasket will be used as the example. The procedure will again start with side length of 1 and continually half it until a recognizable pattern emerges (See Figure \ref{bcsierpinski}).

\begin{figure}[h]
	\centering
	\includegraphics{./fractal/bc_sierpinski.png}
	\caption{Box Counting Dimension Process For Sierpinski's Gasket}
	\label{bcsierpinski}
\end{figure}

The results are rewritten in the form of powers to expose the pattern.  This is shown in Table \ref{bcsierpinskitable}.


\begin{table}[h]
	\begin{tabular}{|l|l|}
		\hline
		\ \textbf{Box Length: }	$\varepsilon$	& \textbf{Number of Boxes:} $N(\varepsilon)$  	\\
		\hline
		$1$										& $3^{0} = 1$											\\
		\hline
		$\frac{1}{2^{1}} = \frac{1}{2} $							& $3^{1} = 3$											\\
		\hline
		$\frac{1}{2^{2}} = \frac{1}{4} $							& $3^{2} = 9$											\\
		\hline
		$\frac{1}{2^{3}} = \frac{1}{8} $							& $3^{3} = 27$											\\
		\hline
		...										& ...											\\
		\hline
		$\frac{1}{2^{N}} = \varepsilon $							& $3^{N}$						\\
		\hline
	\end{tabular}
	\caption{ Box length ($\varepsilon$) and the number of boxes ($N(\varepsilon)$)  as $\varepsilon$ approaches 0. }
		\label{bcsierpinskitable}
\end{table}


From this table the following formula can be deduced by solving the pattern.

\begin{displaymath}
    \text{Dimensionality}_{Sierpinski}(S) =
    \lim_{\varepsilon \to 0}
        \frac{\log 3^{N} }{\log 2^{N} } \approx  1.58
\end{displaymath}



The concept of dimensionality is often referred to as **roughness** which is a measure of a shape's irregularity.

###Formation by Iteration

The method for constructing a fractal relies on an iterative process. Regardless if  the fractal is a naturally occurring statistically self-similar fractal, a computer generated fractal, or even a mathematical calculation of a set that exhibits fractal-like properties they all rely on a process which involves multiple iterations of a specific process. This process could be for example in geometric fractals scaling shapes or in the case of algebraic computer generated fractals adjusting parameter values.



##Fractal Types
When one gets their first taste of fractal geometry they notice the diversity of shapes and figures that encompass it. For the paper's purposes, fractals will not be classified by how they visually look but rather the process for creating them. This is done because given the nature of this project the focus is on the data structures and algorithms used to create the fractal. The shape and patterns that are merely the byproduct of the process. It is not always apparent which creation method was used to create a certain pattern. By classifying fractals by their creation method, the following information is gained:

1. Explain what this project is not
2. Draw similarities from closely related fractal systems
3. Compare the bottlenecks and difficulties between systems.

The major classifications of fractals by their generation methods are the 4 types presented in the following subsections.

###Escape Time Fractals

This type of fractal relies on recursively applying an equation upon an initial point. The transformed point can either diverge past a certain bounds, set by the programmer, or can never reach the escape circumstance.T his bounds is called the escape circumstance. Different points reach the escape circumstance at different rates.

Output images of these images can be black and white denoting which points did not escape and which points did escape. This however is too simplistic and does not produce visually appealing image. A simple fix that greatly enhances the appearance is coloring the points depending on how fast each point escaped.

Classical examples of fractals include:

-	Julia Set
-	Mandelbrot Set
-	Orbital Flowers

and many others.


###Strange Attractors
Strange attractors (See Figure \ref{strangeattractor}) are attractors whose final attractor set are that of a fractal dimension. An attractor is a set that a dynamical system approaches as it evolves. Dynamical systems are systems which describe the state of the system at any instant and contain a rule that specifies the future state of system. A difference of the strange attractor versus a traditional attractor is that strange attractors have a sensitive dependence on their initial conditions and often exhibit properties of chaos[^propchaos] which makes their behavior hard to predict.

[^propchaos]: When the properties of chaos are referred to what is meant by them is the notation that a point which is close to the attractor will become separated at an exponential rate.

\begin{figure}[h]
	\centering
	\includegraphics{./fractal/strange_attractor.jpg}
	\caption{Image of a Strange Attractor}
	\label{strangeattractor}
\end{figure}

###Random Fractals
Random fractal's iterative process relies on a non-deterministic process for creation (See Figure \ref{randomfractal}). By applying some process the resulting set or image exhibits fractal-like properties. Many landscapes and plants in nature exhibit this property. For example, mountains are not formed by a deterministic process yet exhibit statistical self-similarity. Fractal landscape generation is a stochastic process which tries to mimic this stochastic process in nature.

\begin{figure}[h]
	\centering
	\includegraphics{./fractal/random_fractal.png}
	\caption{Image of a computer generated fractal landscape compared with a mountain landscape}
	\label{randomfractal}
\end{figure}


###Iterated Function Systems
This is the fractal system that the project will focus upon. Iterated function systems rely on performing a series of transformations stochastically (which are generally contractive on average[2]) to produce the output image. This stochastic process is called the **chaos game**. The **chaos game** starts with randomly choosing an initial point and then consecutively applying a randomly chosen transformation from the set of transformations that make up the iterated function system.

The entire iterated function system process and its intricacies will be articulated upon in Section \ref{ifsprimer}.

##Visual Appeal
The visual appeal of fractal geometry is far reaching and includes groups of people such as certain African societies, individuals who appreciate the fractal aspects of nature, and online fractal art communities such as [Electric Sheep](http://electricsheep.org/). Its universal appeal is of course subjective like any other art societies.

First and foremost, nature has is the most apparent in creating fractal-like features which can readily be observed. Examples are plentiful and include:

- The leaves of ferns and other plants
- Tree branching
- Mountain landscapes
- Certain intricate rivers
- River erosion patterns
- Coastlines
- Electrical discharge patterns
- Romanesco (a broccoli-like plant)
- Hydrothermal springs
- Cloud-spiral Formations
- Virus and bacterial colonies
- Coastlines
- and numerous others [3]

The wonder that nature brings individuals can partly be attributed to the idea of self-similarity and the complex shapes it produces.

Fractal Geometry has been a part of the African culture, social hierarchy, and art predating any formal western knowledge on fractals. Village architecture, jewelry, and even religious rituals all exhibit the concepts of self-similarity. [4] Recently with the advancement of computer aided image generation, the appreciation of fractals has spread to a wider community. For example, the application [Electric Sheep](http://electricsheep.org/) uses distributed computing in order to evolve fractal flames which are displayed as screensavers to users. The community has membership of roughly 500,000 unique members [5] who appreciate viewing fractal flame images.

Hopefully this background information shows the general interest in fractal-like patterns and with that the project focuses on this last group of individuals who appreciate computer generated fractal images. The proposed GPU rendered fractal algorithm hopes to deliver the existing community with the opportunity to continue viewing these fractal flame images without the need for distributed computing to render them in real time- a major improvement.

##Limitations of Classical Fractal Algorithms
Escape Time Fractals, Strange Attractors, and Random Fractals all have distinct methods of fractal generation however they lack several characteristics which limit the resulting images and videos that can be generated with them. Some of the limitations include:

-	A generic process for combining multiple effects (whether they be matrix transformations, series of equations, or process steps) to create an increasingly complex fractal.
-	The ability to structurally color each defined effects instead of coloring the entire result of all of the combined effects.
-	Inherently, take on the task of image correction and color theory as part of the problem in order to provide higher quality and more accurate output.
-	The ability to seamlessly interpolate between effects.

All of these bulletpoints above are accomplished using the fractal flame algorithm, a variant of the Iterated Function System fractal type. These additionally features allow beautiful interpolation between transformations, a heightened focus on color and image correction techniques, as well as more intricate shapes. Because of these additional features the flame algorithm has many advantages over classical fractal flame algorithms which is one of the governing reasons why this system was chosen for the project.

[TODO Revise citations in correct format and put in Acknowledgements section]


## References

[1] Brickmann, J. (1985), B. Mandelbrot: The Fractal Geometry of Nature, Freeman and Co., San Francisco 1982. 460 Seiten, Preis

[2] Draves, Scott; Erik Reckase (July 2007). "The Fractal Flame Algorithm" (pdf). Retrieved 2008-07-17.

[3] http://www.miqel.com/fractals_math_patterns/visual-math-natural-fractals.html

[4] http://www.ted.com/talks/ron_eglash_on_african_fractals.html

[5] http://www.triangulationblog.com/2011/01/scott-draves.html
