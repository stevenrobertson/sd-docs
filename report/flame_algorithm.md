#Fractal Flame Algorithm Demystified

##Section Outline
This section provides an in-depth description of the flame algorithm along with a primer on the Iterated Function System (IFS) in which the Flame Algorithm is a variant of. We provide this primer to the reader in order to solidify the concept of the chaos game which is essential to understanding the flame algorithm because it builds heavily on upon the concepts used in the classical IFS. 

Also included in this section is a comprehensive history of the Flame algorithm from its birth in 1992 into the present day. This includes any new theoretical as well as empirical research (such as software implementations). Given our goals of implementing a heavily optimized version of the Fractal Flame Algorithm for the GPU we felt it was prudent to dissect a handful of previous implementations to examine design decisions, inner-algorithmic choices (e.g. filtering, tone-mapping, etc.), and possible bottlenecks that occur because of design decisions. These findings are presented below and are pivotal in providing a basis for comparison and understanding of what areas of optimization of the Fractal Flame Algorithm remain unexplored.

Finally, we end with a concluding section summarizing our current knowledge on the topic and describe how it influenced our proposed implementation for rendering fractal flames using the flame algorithm which is described in the following section.

##Iterated Function System Primer
\label{ifsprimer}
This primer aims to present the fundamental concepts of iterated function systems along with several classic examples that will visually and mathematically convey two important concepts:

1. The importance of random application of defined affine transformations on a random starting point in the plane
2. How affine transformations are used to transform (rotation, scaling, or shear) and transform points to produce self-similar images such as the Sierpinski Triangle and Baransley Fern.

These concepts are the building blocks of the flame algorithm. If the reader is already familiar with the concept of iterated function systems feel free to skip over this section and start reading how fractal flames differ from the classical iterated function system that is described below. 

###Definition
An **Iterated Function System** is defined as a finite set of **affine contraction transformations** $F_{i}$ where i= 1, 2, ..., N(1, 3) that map a **metric space** onto itself. Mathematically this is [1]:

$\left \{  f_{i} : X \mapsto X  \right \}, N \text{ } \epsilon \text{ } \mathbb{N}$


A **metric space** is any space whose elements are points, and between any two of which a non-negative real number can be defined as the distance between the points - an example is Euclidean space.[2]

An **affine transformation** from one vector space to another comprises a linear transformed (rotation, scaling, or shear) following by a translation. Mathematically this is [3]:

$x \mapsto Ax +b$

These transforms can be represented in one of two ways:

1.	By applying matrix multiplication (which is the linear transform) and then performing vector addition (which represents the translations).


2.	By using a transformation matrix. To do this we must use homogeneous coordinates. Homogenous coordinates have the property that preserves the coordinates in which the point refers even if the point is scaled. By using the transformation matrix we can represent the coefficients as matrix elements and combine multiple transformation steps by multiplying the matrices. This has the same effect as multiplying each point by each transform in the sequence. This effectively cuts down the number of multiplications needed- this is worth noting as it will be utilized in our implementation.

\begin{figure}[h]
	\centering
	\includegraphics{./flame/sheer_trans_rot_scale.png}
	\caption{Visual representation of Sheer, Translation, Rotation, and Scaling.}
	\label{affineoperations}
\end{figure}


**Rotation Matrix** \newline
To perform rotation using the transformation matrix the matrix positions $A_{0,0}$, $A_{0,1}$, $A_{1,0}$, and $A_{1,1}$ should be modified (where $A$ is the matrix). By using the transformation matrix below and setting $\theta$ you effectively rotate your points by $\theta$ degrees.

\newline

$\begin{vmatrix}
\cos{\theta}     & -\sin{\theta}  & 0  \\
\sin{\theta}     &  \cos{\theta}  & 0  \\
0                &  0             & 1  \\
\end{vmatrix}$

$\text{ }$

**Shear Matrix**\newline
To perform sheer using the transformation matrix the matrix position $A_{0,1}$ should be modified (where $A$ is the matrix). By using the transformation matrix below and setting $Amount$ you effectively perform sheer of value $Amount$ on your points. 

\newline

$\begin{vmatrix}
1         &  Amount        & 0 \\
0         &  1             & 0 \\
0         &  0             & 1 \\
\end{vmatrix}$

$\text{ }$

**Scaling Matrix**\newline
To perform scaling using the transformation matrix the matrix positions $A_{0,0}$ and $A_{1,1}$ should be modified (where $A$ is the matrix). By using the transformation matrix below and setting $Scale\text{ }Factor_{x}$ to the magnification you would like your x-axis and $Scale\text{ }Factor_{y}$ to the magnification you would like your y-axis you effectively scale your points by that amount.

\newline

$\begin{vmatrix}
Scale\text{ }Factor_{x} & 0                       & 0 \\
0                       & Scale\text{ }Factor_{y} & 0 \\
0                       & 0                       & 1 \\
\end{vmatrix}$

$\text{ }$

**Translation Matrix**
To perform translation using the transformation matrix the matrix positions $A_{0,2}$ and $A_{1,2}$ should be modified (where $A$ is the matrix). By using the transformation matrix below and  setting $Translation_{x}$ to the offset from your current x-point and $Translation_{y}$ to the offset from your current y-point you effectively translate your points by that amount.

\newline

$\begin{vmatrix}
1 & 0 & Translation_{x} \\
0 & 1 & Translation_{y} \\
0 & 0 & 1 \\
\end{vmatrix}$

$\text{ }$

3. The term **contraction mapping** in plain English refers to a mapping which maps two points closer together. The distance between these points is uniformly shrunk. This contraction will be seen when performing the classic Sierpinski Triangle problem.[4] The properties above can be proved by the Contraction Mapping Theorem and because of this proves the convergence of the linear iterated function systems we present in this section.

###Chaos Game
The most common way of constructing an Iterated Function System is referred to as the *chaos game* as coined by Michael Barnsley. Our initial fractal flame algorithm will also use this approach. In the *chaos game* a random point on the plane (in our case between -1 and 1) is selected. Next, one of the affine transformations to describe the system is then applied to this point and the new resulting point is then plotted and the procedure repeats. Selection of the affine transformation to apply is either random (in the case of Sierpinski's triangle) or probabilistic (in the case of Barnsley's Fern). The procedure is repeated for N iterations where N is left up to the user. The more iterations you allow the chaos game to run for the more closely your resulting image resembles the iterated function system. A flow chart of this procedure is found in Figure \ref{ifs_flowchart}

\begin{figure}[h]
	\centering
	\includegraphics{./flame/ifs_flowchart.png}
	\caption{Flow chart of IFS Procedure}
	\label{ifs_flowchart}
\end{figure}

###Classical Iterated Function System : Sierpinski's Triangle 
We will start with the illustrative example of Sierpinski's Triangle. This example is suitable to show how the fractal will begin to show itself with a certain number of iterations. We will also observe the contractive nature of the affine transformations.

To construct the Sierpinski Triangle using the Chaos Game we need to describe the affine transformations that will be used. Using the most basic version of an affine transformation described in variation 1, we can describe the system with the following 3 transformations:

$A_{0}=
\begin{vmatrix}
\frac{1}{2} & 0             \\ 
0           & \frac{1}{2}   \\
\end{vmatrix}
\text{ }b_{0}=
\begin{vmatrix}
0 \\
0 \\
 \end{vmatrix}
\text{ selected with a probability of }
\frac{1}{3}
\text{. (Pulls point towards Vertex A)}$

$A_{1}=
\begin{vmatrix}
\frac{1}{2} & 0             \\ 
0           & \frac{1}{2}   \\
\end{vmatrix}
\text{ }b_{1}=
\begin{vmatrix}
\frac{1}{2} \\
0           \\
 \end{vmatrix}
\text{ selected with a probability of }
\frac{1}{3}
\text{. (Pulls point towards Vertex B)}$

$A_{2}=
\begin{vmatrix}
\frac{1}{2} & 0             \\ 
0           & \frac{1}{2}   \\
\end{vmatrix}
\text{ }b_{2}=
\begin{vmatrix}
0           \\
\frac{1}{2} \\
 \end{vmatrix}
\text{ selected with a probability of }
\frac{1}{3}
\text{. (Pulls point towards Vertex C)}$

Using the affine transformation matrix described previously we can equivalently write the transformations more succinctly as:

$F_{0}=
\begin{vmatrix}
\frac{1}{2}   & 0           &  0           \\
0             & \frac{1}{2} &  0           \\
0             & 0           &  1           \\
\end{vmatrix}
\text{selected with a probability of }
\frac{1}{3}
\text{. (Pulls point towards Vertex A)}$

$F_{1}=
\begin{vmatrix}
\frac{1}{2}   & 0           &  \frac{1}{2} \\
0             & \frac{1}{2} &  0           \\
0             & 0           &  1           \\
\end{vmatrix}
\text{selected with a probability of }
\frac{1}{3}
\text{. (Pulls point towards Vertex B)}$

$F_{2}=
\begin{vmatrix}
\frac{1}{2}   & 0           &  0           \\
0             & \frac{1}{2} &  \frac{1}{2} \\
0             & 0           &  1           \\
\end{vmatrix}
\text{selected with a probability of }
\frac{1}{3}
\text{. (Pulls point towards Vertex C)}$


Each of these transformations pulls the current point halfway between one of the vertices of the triangle and the current point. $F_{0}$ performs scaling only. $F_{1}$ and $F_{2}$ perform scaling and translation.

We now begin the *chaos game*. We first select a random point on the biunit square. In this case we have pseudorandomly selected x = 0.40 and y = 0.20. We then pseudorandomly pick transformations. The first four transformations shown are $F_{0}$, $F_{2}$, $F_{1}$, and then $F_{0}$. These are shown in Figure \ref{sierpinski_application}.

\begin{figure}[h]
	\centering
	\includegraphics{./flame/sierpinski_vertex_pull.png}
	\caption{A visual explanation of a series of 4 affine transformations being applied.}
	\label{sierpinski_application}
\end{figure}


\definecolor{ForestGreen}{rgb}{0.13,.5,0.13}

Notice how the next point is the midpoint between the Vertex and current point. These mappings guarantee the convergence of the algorithm to the desired IFS. This process continues on with each point being plotted. We have provided coloring for a visual representation of what transformation was responsible for each point. Points transformed by $F_{0}$ are labeled \textcolor{ForestGreen}{Green}, $F_{1}$ are labeled \textcolor{red}{Red}, $F_{2}$ are labeled \textcolor{blue}{Blue}. Iterations 1,000, 7,500, 15,000, and 25,000 are displayed in Figure \ref{sierpinski_iterations}.

\begin{figure}[h]
	\centering
	\includegraphics{./flame/sierpinski_iterations.png}
	\caption{Sierpinski's Triangle after 1,000, 7,500, 15,000, and 25,000 iterations.}
	\label{sierpinski_iterations}
\end{figure}

The more one stochastically samples, the closer the output image is to the solution of the Iterated Function System being computed. 

###Classical Iterated Function System : Barnsley's Fern 
As a more intricate example we present the classical iterated functioni system called Barnsley's Fern. This system was introduced by the mathematician Michael Barnsley in *Fractals Everywhere* [CITE]. This example is suitable to show all elements of an affine transform : sheer, scale, rotation, and scaling.

To construct Barnsley's Fern using the Chaos Game we need to describe the affine transformations that will be used. Using the most basic version of an affine transformation described in variation 1, we can describe the system with the following 4 transformations seen below. As a note, these affine transformations are not equally weighted and have their own probabilistic model associated with each one. [CITE]

$A_{0}=
\begin{vmatrix}
0.00 	& 0.00   \\ 
0.00	& 0.16   \\
\end{vmatrix}
\text{ }b_{0}=
\begin{vmatrix}
0.00 \\
0.00 \\
 \end{vmatrix}
\text{ selected with a probability of 0.01.}$

$A_{1}=
\begin{vmatrix}
 0.85 	& 0.04   \\ 
-0.04	& 0.85   \\
\end{vmatrix}
\text{ }b_{1}=
\begin{vmatrix}
0.00 \\
1.60 \\
 \end{vmatrix}
\text{ selected with a probability of 0.85.}$

$A_{2}=
\begin{vmatrix}
0.20 	& -0.26   \\ 
0.23	&  0.22   \\
\end{vmatrix}
\text{ }b_{2}=
\begin{vmatrix}
0.00 \\
1.60 \\
 \end{vmatrix}
\text{ selected with a probability of 0.07.}$

$A_{3}=
\begin{vmatrix}
-0.15 	&  0.28  \\ 
 0.26	&  0.24   \\
\end{vmatrix}
\text{ }b_{3}=
\begin{vmatrix}
0.00 \\
0.44 \\
 \end{vmatrix}
\text{ selected with a probability of 0.07.}$

Using the affine transformation matrix described previously we can equivalently write the transformations more succinctly as:

$F_{0}=
\begin{vmatrix}
0.00   & 0.00 &  0.00 \\
0.00   & 0.16 &  0.00 \\
0.00   & 0.00 &  1.00 \\
\end{vmatrix}
\text{ selected with a probability of 0.01.}$

$F_{1}=
\begin{vmatrix}
 0.85   & 0.04 &  0.00 \\
-0.04   & 0.85 &  1.60 \\
 0.00   & 0.00 &  1.00 \\
\end{vmatrix}
\text{ selected with a probability of 0.85.}$

$F_{2}=
\begin{vmatrix}
0.20   & -0.26 &  0.00 \\
0.23   &  0.22 &  1.60 \\
0.00   &  0.00 &  1.00 \\
\end{vmatrix}
\text{ selected with a probability of 0.07.}$

$F_{3}=
\begin{vmatrix}
-0.15   &  0.28 &  0.00 \\
 0.26   &  0.24 &  0.44 \\
 0.00   &  0.00 &  1.00 \\
\end{vmatrix}
\text{ selected with a probability of 0.07.}$

Figure \ref{barnsleyfern} shows the procedure which results in the final system. This system resembles the Black Spleenwort fern [CITE]. This fern was not shown soley because it resembles a similar shape in nature but because of the explicit way the transforms were used to get the shape desired. Below in Table \ref{barnsleytable} is an explanation of what each transformation conceptually does [6].

\begin{table}[h]
	\begin{tabular}{|l|l|}
		\hline
		Name of Transform	& 	Conceptual Description  	\\
		\hline
		$F_{0}$				&	Maps the next point to the base of the stem.						\\
		\hline
		$F_{1}$				&	Maps the next point inside the leaflet described by the  \textcolor{red}{red} triangle in Figure \ref{barnsleyfern}.						\\
		\hline
		$F_{2}$				&	Maps the next point inside the leaflet described by the  \textcolor{blue}{blue} triangle in Figure \ref{barnsleyfern}.						\\
		\hline
		$F_{3}$				&	Maps the next point inside the leaflet represented by the  \textcolor{blue}{blue} triangle in Figure \ref{barnsleyfern}.						\\
		\hline
	\end{tabular}
	\caption{Conceptual descriptions of each affine transformation of Barnsley's Fern.}
	\label{barnsleytable}
\end{table}	

\begin{figure}[h]
	\centering
	\includegraphics{./flame/barnsley_formation.png}
	\caption{The formation of the Iterated Function System called Barnsley's Fern.}
	\label{barnsleyfern}
\end{figure}

##Fractal Flame Algorithm

###Differences from Classical Iterated Function System (IFS)

Fractal flames are a member of the Iterated Function System however differ from Classical Iterated Function Systems in three major respects[5]:

1.	Instead of affine transformations presented in the previous section nonlinear functions are used.
2.	Log-density display is used instead of linear or binary. 
3.	Structural Coloring
On top of the core differences, additional pyschovisual techniques such as spatial filtering and temporal filtering (motion blur) give rise to more aesthetically pleasing images with the illusion of motion.  

###History 

The flame algorithm was created in 1991 coinciding with the first implementation caled ``flame3``. The algorithm was created by Scott Draves who is software and visual artist. Drave's algorithm has allowed the process for artist creation by allowing the users to experiment with shapes, colors, and stylistic effects. More historical background can read about in Section \ref{flam3implementation}.

###Algorithm 

####Outline
The details of the algorithm as well as procedural psuedocode will be described below but will spare full-scale explanations for a specific reason: these will be saved for their own respective chapter in which we review the existing implementation and then present the improved implementation. We do this merely to partition the large sections of the paper and to bring attention to the relevant new approaches that will be described.

The following will give a coherent understanding of the algorithm minus the implementation details.

####Transforms
Unlike the classical IFS examples presented previously which apply one transformation to a set of points, the fractal flame applies multiple transformations. These transformations can be nonlinear unlike their classical IFS counterparts. Additionally not all mappings are contraction mappings[5] however the whole system is contractive on average. There are some fractal flame systems which are degenerate and are not contractive - however these are of no interest to us.

The multiple variations as well as their order of application on the initial point choosen at random are described below:

1.	**Affine Transformation**

The affine transformation we will be working with for the flame algorithm is of the form:

\begin{displaymath}
F_{i}(x,y)=(a_{i}x + b_{i}y+c_{i}, d_{i}x+e_{i}y+f_{i})
\end{displaymath}


Again, this transformation makes it possible to provide rotation, scaling, and sheer to the points. The information that is represented in this form is both space (x and y coordinates) as well as color - which will be expanded upon over the next sections.

2.	**Variation**

To provide the complex realm of shapes the algorithm can produce we introduce a non-linear functions called variations.

The affine transformed point is further applied to the variation resulting in the transformation being of this form:

\begin{displaymath}
F_{i}(x,y)=V_{j}(a_{i}x + b_{i}y+c_{i}, d_{i}x+e_{i}y+f_{i})
\end{displaymath}

Furthermore, multiple variations can be applied to an affine transformed point. Each point also is multiplied by a blending coefficient named vij which controls the intensity of the variation being applied. The expanding formula is the following:

\begin{displaymath}
F_{i}(x,y)=\sum_{j}^{ } v_{ij} V_{j}(a_{i}x + b_{i}y+c_{i}, d_{i}x+e_{i}y+f_{i})
\end{displaymath}

By applying variations, the resulting solution is changed in a particular way. Fundamentally there are 3 different types of variations in which can be applied. These are either: Simple Remappings, Dependent Variations, or Parametric Variations.

**Simple Remappings:**  A simple remapping is one such that it simply remaps the plane. This could for example be remapping of the cartesian coordinate system plane to a polar coordinate system plane or a sinusoidal plane.

**Dependent Variations:** A dependent variation is a remapping of the plane such that the mapping is a simple remapping but additionally controlled by coefficients that are dependent on the affine transformation being applied.

**Parametric Variations:** A parametric variation is a remapping of the plane such that the mapping is a simple remapping but additionally controlled by coefficients that are independent of the affine transformation applied.

For a visual supplement as well as an extensive collection of many catalogued variations please refer to the Appendix of the original Flame Algorithm Paper. [CITE and provide link]

3. **Post Transformation**

After applying the variations which shape the characteristics of the system we apply what is known as a post transform which allows the coordinate system to be altered. This is done with another affine transformtion labeled Pi. By adding to our previous definition the definition for all of the collective transformations is:

\begin{displaymath}
F_{i}(x,y)= P_{i}(\sum_{j}^{ } v_{ij} V_{j}(a_{i}x + b_{i}y+c_{i}, d_{i}x+e_{i}y+f_{i}))
\end{displaymath}

where $P_{i}$ is equal to:

\begin{displaymath}
P_{i}(x,y) = (\alpha_{i}x+\beta_{i}y+\gamma_{i}. \delta_{i}x + \epsilon_{i}y + \varsigma_{i})
\end{displaymath}

4. **Final Transformation**

Finally, because the image is eventually outputted to the user we apply the last transformation in which we applying a non-linear transformation

*Note:* isn't applied directly to the computational loop - merely for visual output
Non-linear camera

####Log-Density Display of Plotted Points
\label{logdensitydisplay}
In the classical Iterated Function System, described previously, points were either members in the set or not. For every subsequent time the chaos game selected a point that was already shown to have membership in the set we actually lost information about the density of the points. To remedy this for the fractal flame algorithm we instead use a histogram for plotting points in the chaos game. Given that points are now plotted onto the histogram we have several different methods we could go about plotting them into a resulting image which include:

1. **Binary Mapping:** As described before, this did result in the images we wished to produce but were not smooth and contained no shades of gray- only black and white. 

2. **Linear Mapping:** A linear mapping of the histogram provides an improvement but the range of data is lost in the process. The linear mapping has problems differentiating large scales of range. For example, a point plotted 1 time, 50 times, and 5,000 times would be a great illustrative example. Compared a point of density 5,000 both point densities 1 and 50 appear to be of relatively same magnitude however there is a great different in them.
 
3. **Logarithmic Mapping:** This mapping proves to be superior to it's counterparts. The logarithmic function allows a great range of densities relationship to oneanother to be persered. This is the type of mapping the flame algorithm employs. 


[TODO Reference figure in draves paper for pictorial]

As a note to avoid confusion, the logarithmic mapping allows the image to now displayed in shades of grays and not as the vibrant colorful flames readily available to be viewed on flame gallery websites. Structural coloring, color correction and enhancement techniques, and tone mapping take care of these and are all seperate algorithmic processes.

####Coloring (Tone Mapping) and Gamma Correction

[TODO Copy and paste stuff from the color and log scale section]


[TODO add references clean up]
Please refer to Chapter **X** for more detailed explaination covering the following:

-	Original Implementation Details
-	Color Correction Features
-	Improved Implementation Details

####Symmetry
The fractal flame algorithm inherently supports the concept of self-similarity but also supports the concept of *symmetry* of two kinds:

-	Rotational
-	Dihedral

[TODO below]
*TODO* This allow the algorithm to produce symmetrical images which are inherently attractive to the eye. 

**Rotational Symmetry** is introduced by adding extra rotational transformations. To produce n-way symmetry you are implying that you wish to have $\frac{360^\circ}{n}$ degrees symmetry. The set of transformations transformations necessary to add $\frac{360^\circ}{n}$ symmetry is:

\begin{displaymath}
\mbox{Rotational Transforms}_{i}= \left ( \frac{360^\circ}{n}\times i \mbox{  } | i = 1, 2,..,n\right ) \mbox{where n = number of way symmetry}
\end{displaymath}

For example, To produce six-way symmetry the following *5* transformations would be needed:

-	$\mbox{Rotational Transforms}_{1}= 60^\circ$
-	$\mbox{Rotational Transforms}_{2}= 120^\circ$
-	$\mbox{Rotational Transforms}_{3}= 180^\circ$
-	$\mbox{Rotational Transforms}_{4}= 240^\circ$
-	$\mbox{Rotational Transforms}_{5}= 300^\circ$

Each transformation is given an equal weighting, allowing the chaos game to realize the n-way symmetry the more it stochastically samples.

**Dihedral Symmetry** is introduced by adding a function that inverts the x-coordinate. This is a reflection of the axis. An equal weighting is given to this reflection function which allows the chaos game to realize the dihedral symmetry.

Both rotational and dihedral symmetry are shown in Figure \ref{symmetry}.  

\begin{figure}[h]
	\centering
	\includegraphics{./flame/symmetry.png}
	\caption{A visual depiction of what dihedral and rotational symmetry look like in a flame.}
	\label{symmetry}
\end{figure}


[TODO: Where in the algorithm is this performed, after the transforms]


####Filtering 
[TODO]


[TODO]
Please refer to Chapter **X** for more detailed explaination covering the following:

-	Original Implementation Details
-	Filtering background
-	Other Filtering Approaches
-	Improved Approach


####Motion Blur
[TODO]
Under Construction
 

####Procedure
[TODO Look at IFS procedure for hints]
Under Construction
 
 
[TODO Describe algorithm]
[TODO Flowchart of aLGORITHM]



[1] http://en.wikipedia.org/wiki/Iterated_function_system

[2] http://en.wiktionary.org/wiki/metric_space

[3] http://en.wikipedia.org/wiki/Affine_transformation

[4] http://www.maplesoft.com/support/help/AddOns/view.aspx?path=Definition/contraction

[5] Draves, Scott; Erik Reckase (July 2007). "The Fractal Flame Algorithm" (pdf). Retrieved 2008-07-17.

[6] http://en.wikipedia.org/wiki/Barnsley_fern