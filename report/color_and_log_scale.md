# Fractal Flame Coloring and Log Scaling
## Overview
The *chaos game* provides a way to plot whether points in the plane[^planetwo] are members of the iterative function system or are not. However, the resulting image appears in black and white (lacking color or even shades of gray). The application of color as well as making these images vibranat are their own processes in the algorithm which deserves much text for several reasons:

[^planetwo]: Again by plane we are refering to a biunit square where x and y values can have a minimum value of -1 and a maximum value of 1.

1.	A flame is just simply not a flame without its structural coloring or if membership is binary (black and white) which results in a grainy image. Both of these shortcomings leave a lot to be desired but can be remedied.
2.	Much of the new *implementation* relies on reworking details on how coloring is done.


Section \ref{logdensitydisplay} of the fractal flame algorithm chapter describes the application of log scaling, a scheme for structural coloring as well as certain color correction techniques however the implementation details were spared. This section explores the color correction techniques are implementatios in the context of the original fractal flame implementation called ``flam3``. The inner algorithmic choices, data structures, and capabilities that the program has are analyzed. With that, in accordance to the challenge response style paper some of the difficulties with making improvements and transitioning the algorithm to the GPU are presented. Finally, the authors delve into the new *implementation* and the differences, similarities, and any relevant background information needed.

##Relevant Applied Color Theory and Imaging Techniques

###Introduction
In the case of the fractal flame algorithm when coloring is referred to what is meant is the act of tone mapping, structural coloring, any color theory techniques (such as colorimetry), and finally any imaging techniques (such as gamma correction) used. Luckily, all of these techniques have strong mathematical backgrounds and there is a vast information about each of them readily available because of advances in both computer graphics and digital photography. Additionally, because the flame algorithm's output is an image or series of images it often runs into the same complications which plague digital photographs such as color clipping and therefore these same image correction techniques are translated over to our domain and retrofitted to greatly improve the output image. A small detour is taken to visit all related techniques as one of the major requirements that must be adhered to for a new implementation is to produce images which are approximately visually equivalent. Without using some of these techniques, replicating flame would be increasingly more difficult.

###High Dynamic Range (HDR)
\label{hdrsection}
A fundamental concept which the whole coloring and log scaling approach tries to achieve is a high dynamic range or simply abbreviated as *HDR*. High dynamic range  means that it allows a greater dynamic range of luminance between the lightest and darkest areas of an image.[1] Dynamic range is the ratio between the largest and smallest possible values of changeable quantity (in our case light).[2] Lastly, *luminance* being the intensity of light being emitted from a surface per some unit area[3].

The techniques that allow going from a lower dynamic range to a high dynamic range are collectively called high dynamic range imaging (HDRI). The reason HDR and HDRI imaging is mentioned is because the output of the flame attempts to give the appearance of an HDR flame while being constrained to Low Dynamic Range (LDR) viewing mediums such as computer monitors (LCD and CRT) as well as printers.[4]


By observing common dynamic ranges of some typical mediums as well as various digital file formats we can begin to see why we are limited.

Both the file format technologies in which our images or videos and stored in as well as monitor or paper in which they are viewed on are interrelated limiting factors governing the dynamic range. Various typical contrast values that these scenes can emit or in the case of file formats are capable of representing are seen in Table \ref{hdrtable} [12][13].

\begin{table}[h]
	\begin{tabular}{|l|l|l|}
		\hline
		Medium					&	Ratio		&	Stop  	\\
		\hline
		JPEG Image File			&	256 : 1		&	8		\\
		\hline
		RAW Image File 			&	1,024 : 1	& 	10		\\
		\hline
		\bf{HDR Image File}	&	approx. 32,768 : 1 to 1 : 1,048,576	& approx. 15 - 20	\\
		\hline
		Standard Video			&	45 : 1		&	5.49	\\
		\hline
		Standard Negative Film	& 	128 : 1		& 	7		\\
		\hline
		\bf{LCD Technology}			&	500 : 1		&	8.96	\\
		\hline
		\bf{CRT Display}				&	50 : 1		&	5.64	\\
		\hline
		\bf{Glossy Print Paper}		&	60 : 1		&	5.90	\\
		\hline
		Newsprint				&	10 : 1		&	3.32	\\
		\hline
		\bf{Sunlit Scene}			& approx. 100,000 : 1	&	16.60	\\
		\hline
		\bf{Human Eye}				& approx. 10,000 : 1	&	13.28	\\
		\hline
	\end{tabular}
	\caption{Typical dynamic ranges of various scenes or typical dynamic ranges that able to be represented. }
		\label{hdrtable}
\end{table}


Where $Stop$ is defined as :	$log_{2}(Ratio)/log_{2}(2)$.

Let's take a look at what this table really means in the case of imagery. The table shows that a *HDR Image File* can represent an impressive range of contrast - far higher than the eye can observe. We also note that it could approximately even capture a *Sunlit Scene* which contains extreme contrast between the brightness and darkest intensity values. However, if we look at our viewing technologies we notice their limits of displaying contrast. *LCD Technology* has a Stop value of approx. 8.96, *CRT Technology* has a Stop value of approx. 5.64, and *Glossy Print Paper* has a Stop value of 5.90. Compared to the *Human Eye* whose Stop value is approx. 13.28, these values are incapable of being on par with the level of contrast the human eye can observe and therefore will not accurately represent how the colors ideally should be observed.

Luckily, we can work within our imposed limitations and there are many imaging techniques that can be applied to attempt to remedy the situation.  The following techniques described below are not only for aesthetics but also are some of the core techniques for representing HDR images on LDR mediums. This coincides with the goal the entire algorithm wishes to achieve and is paramount to fix our LDR dilemma.

###A RGB Color Model: Hue, Saturation, and Brightness Value (HSV)
To attempt to mathematically define certain color concepts (e.g. brightness, saturation, vibrancy) a color model for how our colors will be represented spatially is chosen so the relationship between colors can be talked about.

All of the color definitions and concepts are in terms of the *Hue, Saturation, and Value (HSV)* model. It is explained in this model simply because ``flam3`` uses this concept and by using the HSV model it will save additionally explanation on how this model works. It should also be noted that there are alternative color models such as:

- Hue, Saturation, and Lightness (HSL)
- Hue, Saturation, and Intensity (HSI)

The HSV color model spatially describes the relationship of red, green, and blue according to these following components:

- Hue
- Saturation
- Brightness

It does this by representing these using a cylindrical coordinate system. The axis representations are the following:

- **Rotational Axis:** The rotation axis represents *hue*. Hue refers to pure spectrum of colors - the same prism observed when splitting light. At $0^\circ$ on the axis the primary color red is represented, at $120^\circ$ the primary color green is represented, and at $240^\circ$ the primary color blue is represented. The rest of the degrees are filled in according to the color spectrum.

- **Vertical Axis:** The vertical axis represents brightness. Colors at the top of the spectrum have no brightness (value of 0 which would be the color black) and at the bottom have maximal brightness (value of 1 which would be the color white).

- **Horizontal Axis:** The horizontal axis represents saturation. Saturation is defined here as how prominent the hue is in the resulting color. The outer regions are that of the pure color spectrum whereas the inner regions are gray scale color where no hue is observed and the values depend purely on brightness.

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/hsv.png}
	\caption{HSV Color Model}
	\label{hsvmodel}
\end{figure}

Using the HSV model (Figure \ref{hsvmodel}) provides a simple way of representing the color space and describing the relationship between them. The calculations also require little computation. However, one of the major drawbacks is that the model gives no insight into color production or manipulation.

###Hue
\label{huesection}

The term *hue* refers to the pure spectrum of colors and is one of the fundamental properties of a color. The unique hues are red, yellow, green, and blue. Other hues are defined relative to these. Looking at a spectrum of light (such as the rainbow) would represent the spectrum of hues.


###Gamma and Gamma Correction
\label{gammasection}
The term *gamma* refers to the amount of light that will be emitted from each pixel on the monitor in terms of in a fraction of full power (pixel being shorthand for the red, green, and blue phosphors of a CRT[^LCD])[5].

[^LCD]: For LCDs the relationship between signal voltage and intensity is very non-linear and a simple gamma value cannot describe it. A correction factor can be applied however and the concepts are similar.

The main concept we're interested in is *gamma correction*. The reason *gamma correction* is needed is the following:

1. CRT and LCDs displays do not display the light proportional to the voltage given to each phosphor. Therefore the image does not appear in the way it was expected to be viewed.
3. A typical consumer grade printer works upon 8 or 16 bit color and result in a relatively low HDR as seen in Table \ref{hdrtable}.

To summarize, the RGB color system with red, green, and blue values ranging from 0 to 255 cannot be accurately represented. Some kind of correction must be performed in order to get the images that are expected to be seen rather than the images that are actually seen as output.

This concept of *gamma correction* can be applied at the hardware level however, but this varies depending on the vendor and hardware capabilities of the machine. For example:

- PCs typically do not implement gamma correction at the hardware level. A noteable exception is that certain graphics card may implement a gamma correction natively.
- Macintoshes typically provide a gamma correction at the hardware level of 1.4.

Besides being implemented at the hardware level, gamma correction can additionally be provided at the software level.

The formula for *gamma correction* is $b_{corrected} = b^{1/\gamma}$ where $\gamma$ is the correction factor.

To understand the non-linearity of the gamma function 4 gamma correction values are applied to an image for visual depiction of the concept. The results are seen in Figure \ref{gammacomparison}.


\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/gamma_comparison.png}
	\caption{Comparison of gamma correction values.}
	\label{gammacomparison}
\end{figure}


The second image of Figure \ref{gammacomparison} does not undergo any gamma correction and can be used as a baseline comparison to the other images. By observing both the higher and lower bounds of the images presented we can see that images become either too dark or too light (and their is little contrast between the colors). The third image has a gamma correction value of 2. Normal gamma correction is roughly around 2.2 which explains why this image appears more natural and has a higher dynamic range then the others.



###Brightness and Brightness Correction
\label{brightnesssection}
The term *brightness* is a term that must be defined with great finesse. Unlike *luminance*[^lum] which is empirical, *brightness* is subjective. The subjectiveness comes from that brightness is according to the range of lumens that the eye can perceive. This attribute is often more qualitative than quantitative and can range from very dim (black) to very bright (white) [8].

[^lum]: Again, *luminance* being the intensity of light being emitted from a surface per some unit area.

We can attempt to quantatively talk about brightness using the concept of a color model.  There are many models and they usually compute brightness in one of the following two ways:

1.	Give equal weights of each color component (R, G, and B)
2.	Give weighted values of each color component (R, G, and B). This is referred to as perceived brightness.

An example of the first application would be a naïve approach that goes on the notation that if black is $Red = 0$ , $Green = 0$, $Blue = 0$ and white is $Red = 255$ , $Green = 255$, and $Blue = 255$ then the brightness can be simply $Red + Green + Blue$.

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/rgb_wavelength.png}
	\caption{Wavelengths of Red, Blue, and Green}
	\label{rgbwavelength}
\end{figure}

This flaw can be seen in Figure \ref{rgbwavelength}. The red, green, and blue components of a color have different wavelengths and therefore have a different perceived effect on the eye. A good brightness calculation attempts to model how the eye perceives color rather than treating each color component with equal weights. A common flaw of a color model for brightness is the under or over represent one of the color components[9].

Some examples of weighted models to calculate brightness are below in Table \ref{brightnessmodel}. [14][15]

\begin{table}[h]
	\begin{tabular}{|l|l|}
		\hline
		Model					&	Formula	\\
		\hline
		Photometric/digital ITU-R		&	$0.2126 \times R + 0.7152 \times G + 0.0722 \times B$		\\
		\hline
		Digital CCIR601 				&	$0.299 \times R + 0.587 \times G + 0.114 \times B$		\\
		\hline
		HSP Color Model (Percieved Brightness) &	$\sqrt{0.241 \times  R^2 + 0.691 \times G^2 + 0.068 \times  B^2 }$		\\
		\hline
	\end{tabular}
	\caption{Weighted Brightness Calculations. }
	\label{brightnessmodel}
\end{table}

Later, the topic of *brightness correction* is of interest- the act of adjusting the brightness. Flame's brightness can be adjusted however care must be taken so that the minimum and maximum bounds are not exceeded.

With the addition of too much or too little brightness color clipping may occurs (See Section \ref{colorclippingsection}) and the colors fall outside of representable realms which result in a loss of data.

###Saturation and related terms

The concept this section intends of describing is that of *saturation* but as a building block concept it is felt necessary to talk first about the more broad concept in *color theory* which is the intensity of the color. There are different variations of measuring the intensity of the color. The three main terms as well as their distinctions between each other are below:

1. **Colorfulness:** The intensity of the color is a measure of the colors relative difference between gray. [11]

2.	**Chroma:** The intensity of the color is a measure of the relative brightness of another color which appears white under similar viewing conditions.[11]

3. **Saturation:** The intensity of the color is a measure of its colorfulness relative to its own brightness rather than gray[11].

The term that is of importance is that of *saturation*.

[TODO  Expand on a bit on this section. Possible ideas: Describe R, G, and B model as well as the steepness of the bell curve slope described here [9]. Linear]

Colors that are highly *saturated* are those closest to pure hues of color. Colors that have little saturation appear *washed out*. Also as a note, the changing of a color's saturation can be observed as linear effect.

###Vibrancy
\label{vibrancysection}
Now that saturation was explained, the term *vibrancy* can be explained. Vibrancy is similar to saturation however different in the following fashion:

Saturation is linear in nature whereas vibrancy works in a non-linear fashion. In vibrancy the less saturated colors of the image get more of a saturation boost than colors that already have higher saturation values. A simple non-linear saturation is applied to photograph shown in Figure \ref{vibrancyexample}.

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/vibrancy.png}
	\caption{Original image compared to a non-linearly saturated image.}
	\label{vibrancyexample}
\end{figure}


###Color Clipping
\label{colorclippingsection}
A problem that plagues images in digital photography and that of the flame algorithm is the concept of *color clipping*. Color clipping happens when color brightness values to be outputted to the image fall either below or above the maximum representable range.

In digital photography *color clipping* can happen from an improper exposure setting on the camera which results in effects, such as the lighting from the sun, overwhelming certain portions of the image. In the case of the flame algorithm, this concept can be viewed in a different context. One problem with flames is that certain areas of density in the histrograms from the *chaos game* can become so dense that their color setting exceed the bounds of representable brightness's.

When data exceeds the upper and lower bounds of representable brightness's a loss of data occurs. As a result, there is an inability to determine the differences between those regions of data as they default to the maximum or minimum brightness and appear uniform. A focus on the approach of the algorithm is to prevent this and preserve and be able to represent all contours of the image and their brightness's.

##Log Transformation of Data
\label{logtransformation}
Data transformations in statistics are a common method of transforming data points in order to improve the interpretability of visualization of the output (e.g. graphs)[7]. Some common transformations include:

- Square Root
- Logarithm
- Power Transform

Transformations are in the form of deterministic functions. For the specific purposes of this paper the logarithmic transformation of data is studied.

The ultimate goal again of the coloring and rendering is preservation. If a non-transformed histogram of densities of a flame are plotted information is lost about the least and most dense areas of the histogram. The logarithm transformation helps preserve the relationship between points to provide a more accurate histogram.

##Tone Mapping and Tone Operators
With a firm idea of High Dynamic Range (HDR) the concept of tone mapping is now described. What the process of tone mapping produces is a mapping from one set of colors to another that is applied to the image. This is heavily used in image processing. Because a flame is limited to a lower dynamic range when presenting images on monitors or printers tone mapping is applied in an attempt to closely resemble the appearance of an HDR image. This is one of the goals of tone mapping. The two typical application purposes of tone mapping are as follows:

1. Bring out all of the details of an image - or more specifically, maximizing image contrast. This approach focuses on producing realism and aims to render an image as accurately as possible.
2. Create an aesthetically pleasing image, often ignoring the realistic model that the first approach attempts to model but trying to create another desired effect. This effect is up to the person designing the tone operator which is applied to the image.

The method for applying this tone mapping is done via a tone mapping operator. The HDR image is processed by the tone mapping operator which provides one of the two above mentioned effects. There are two major classifications of tone mapping operators[6]:

1. **Global Tone Operators:** In a global tone operator the mapping of one color set to another is uniformly applied to the image. This mapping is in the form of a non-linear function that is determined to be the desired mapping [6]. Gamma correction is an example of a simple global tone operator.

2. **Local Tone Operators:** In a local tone operator the mapping of one color set to another varies according to the local features of the image. The tone operator takes into the regions of changing pixels in the image.

[TODO Great, so you've got a solid background on tone mapping. You still need to add that extra umph, describing where we will go from here.]

##``flam3`` : Original Coloring and Log Scaling Implementation
### Log Scaling of the Chaos Game
\label{flamecoloringimpsection}
In the classical IFS membership in the system is binary however in the fractal flame algorithm one of the goals is to expose as much detail as possible. As mentioned before, every successive time a point gets plotted in binary representation information is lost about the densities of regions of the output flame. This is remedied with the concept of a *histogram* which plots the distribution of the points.

[TODO wrong wrong wrong!]
 These histogram bins then need to be scaled to *gray scale*.  *Gray scale* is represented as a byte which has values ranging from 0 to 255. A mapping of densities ranging from ``[0, 1, 2, ..., DOUBLE_MAX]`` to ``[0, 1, 2, ..., 255]`` must be performed. If a linearly scaled mapping was applied it would suffer from the problems described in Section \ref{logdensitydisplay} hence the concept of log transformation is applied (Section \ref{logtransformation}). Flam3 implements log scaling of the histogram of point densities.

[TODO Describe how it is done in Flam3. Please articulate on the concepts of]
 In flam3,

-	Buckets / Accumulator
-	Batches
-	Aye aye aye!




The log scaling performed in ``flam3`` coincides with the overall goal of approximating a high dynamic range flame. The method described above is a straightforward implementation although the naming convention of the ``flam3`` fractal flame algorithm needs articulation. No additional information is needed and the understanding of the benefits of log scaling and why ``flam3`` implements it should be found in the referenced sections above.

### Ad-Hoc Tone Mapping and The Color Palette

\label{tonemapcolorpalette}
The flame algorithm's for mapping

- log density describe above along with the color correction techniques i
-

[TODO]
- Why Ad-Hoc? 
- Implementation, how to go from gray scale to color?
- Get detailed, very detailed! This will help when setting up new approach and comparing it

[TODO]
- R,G,B,Alpha
- Why Alpha? What does it do?

###Coloring Capabilities

####Overview
``flam3`` provides not just structural coloring but also exposes a vast amount of functionality which allows the resulting flame to undergoing image correction and other altercations. The image correction and other altercations are done using a configuration file. The section visually inspects:

- 	Color Palette
-	Gamma Correction
-	Gamma Threshold
-	Hue
-	Brightness Correction
-	Vibrancy
-	Color Clipping
-	Highlight Power.

After visually inspecting them as well as describing their purpose and how the output flames benefit from them, ``flam3``'s implementation will be examined. Next, the authors discuss what features are essential for our task at hand and which color correction techniques could be omitted while still providing an essential subset of functionality.

#### Visual Inspection of the Baseline Image
For reference to the reader a baseline image of a detailed flame containing several transforms with a vivid default coloring scheme is provided (See Figure \ref{baselineflame}). In the following sections adjustments are performed to one parameter of the flame while holding the others constant so that the parameter effect in question can be observed. The parameters of the following flame are shown in Figure \ref{flametable}.

[TODO Add Hue, user defined color palette]

\begin{table}[h]
	\begin{tabular}{|l|l|}
		\hline
		Correction Technique			&	Default Value		\\
		\hline
		Gamma Correction				&	3.54				\\
		\hline
		Gamma Threshold					&	0.01				\\
		\hline
		Brightness Correction			&	45.6391				\\
		\hline
		Vibrancy						&	1.0					\\
		\hline
		Early Clipping					&	Off 				\\
		\hline
		Highlight Power					&	0.0 				\\
		\hline		
		Hue								& $0^\circ$ Rotation to the Color Space	\\
		\hline
		Color Palette					& User Defined Palette			\\
		\hline
	\end{tabular}
	\caption{ Parameter values of our baseline image which modified versions of this flame will be compared to. }
		\label{flametable}
\end{table}

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/flame_baseline.png}
	\caption{Baseline image of the flame whose parameters will be altered.}
	\label{baselineflame}
\end{figure}

#### Color Palette Revisited and Explored
As mentioned in the *Ad-Hoc Tone Mapping and The Color Palette* (Section \ref{tonemapcolorpalette}) there are 701 standard palettes available. A minute amount of palettes are shown to give the reader an understanding of what a palette may look like. Figure \ref{TODO} shows 4 different palettes applied to the baseline flame. By observing both palette number 1 and 5, you can see that colors become clipped and their is varying degrees of detail loss. There is a careful balance of setting tweaking between brightness, gamma, that must be maintained in order to preserve a higher dynamic range. This is one of the reasons these features exist.

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/flame_palette.png}
	\caption{4 different predefine color palettes applied to the baseline flame.}
	\label{paletteflame}
\end{figure}

####Gamma Correction
As mentioned in the *Gamma Correction Background* (Section \ref{gammasection}) a non-linear function needs to be applied in order to produce an output flame that approximately replicates the expected image. The gamma correction formula's gamma (Seen in Section \ref{gammasection}) is left to be set by the user and is of the *positive float* data type. The 12 different gamma correction values that were applied to the baseline image are shown in Table \ref{gammacorrectiontable}. The resulting images from the altered gamma corrections can be seen in Figure \ref{gammaflame}. The first several images show the effects of when the gamma is set to values that are too low and show the characteristic signs of low gamma which is that the image looks washed out. The last images in the series show the effects of when the gamma is set to values that are too high and show characteristic signs of high gamma which is that the image looks too dark.

\begin{table}[h]
	\begin{tabular}{|l|l|}
		\hline
		Flame Number					&	$\gamma$ value	\\
		\hline
		1								&	0.00			\\
		\hline
		2								&	0.25			\\
		\hline
		3								&	0.50			\\
		\hline
		4								&	1.00			\\
		\hline
		5								&	2.00			\\
		\hline
		6								&	3.00			\\
		\hline
		7								&	5.00			\\
		\hline
		8								&	10.00			\\
		\hline
		9								&	50.00			\\
		\hline
		10								&	100.00			\\
		\hline
		11								&	1,000.00		\\
		\hline
		12								&	10,000.00		\\
		\hline
	\end{tabular}
	\caption{ Flame image numbers and their associated $\gamma$ correction values. }
		\label{gammacorrectiontable}
\end{table}

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/flame_gamma.png}
	\caption{12 different gamma threshold values are presented one the baseline flame.}
	\label{gammaflame}
\end{figure}



####Gamma Threshold
*Gamma Threshold* is a parameter setting which controls the threshold for which colors recieve the non-linear gamma correction mentioned above. Colors brighter than the threshold receieve the non-linear correction and colors darker than the threshold receive a linear correction instead [16]. The threshold is a *float* data type value ranging from 0.00 to 1.00 (where 0.00 to 1.00 maps to the entire color space). This parameter can be used to linearly correct certain parts of an image and non-linearly correct others in attempts to produce a greater dynamic range or a stylistic affect. The 12 different gamma threshold values that were applied to the baseline image are show in Table \ref{gammathresholdtable}. The resulting images from the altered gamma threshold values can be seen in Figure \ref{gammathresholdflame}.


[TODO Do we want to replicate this?]

\begin{table}[h]
	\begin{tabular}{|l|l|}
		\hline
		Flame Number					&	Gamma Threshold value	\\
		\hline
		1								&	0.00			\\
		\hline
		2								&	0.05			\\
		\hline
		3								&	0.10			\\
		\hline
		4								&	0.20			\\
		\hline
		5								&	0.30			\\
		\hline
		6								&	0.40			\\
		\hline
		7								&	0.50			\\
		\hline
		8								&	0.60			\\
		\hline
		9								&	0.70			\\
		\hline
		10								&	0.80			\\
		\hline
		11								&	0.90			\\
		\hline
		12								&	1.00			\\
		\hline
	\end{tabular}
	\caption{ Flame image numbers and their associated gamma threshold values. }
		\label{gammathresholdtable}
\end{table}

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/flame_gamma_threshold.png}
	\caption{12 different gamma threshold values are presented on the baseline flame.}
	\label{gammathresholdflame}
\end{figure}


####Hue
Hue is a *float* data type value ranging from 0.00 to 1.00. 0.00 means that the color space is not rotated while 1.00 means there is a $360^\circ$ rotation in the color space (which effectively is the same as 0.00). Any value in between rotates the color space by a certain degree. The 12 different hue values that provide rotation to the color space are shown in Table \ref{huetable}. The resulting images from the altered hue values can be seen in Figure \ref{hueflame}. To properly showcase hue, a light color palette has been applied which will be our new baseline image. This palette can be seen unmodified in Flame Number 1.  

[TODO analyze hue]


\begin{table}[h]
	\begin{tabular}{|l|l|l|}
		\hline
		Flame Number					&	Hue			& Rotates Color Space By \\
		\hline
		1								&	0.0000		&	$\approx 0^\circ$ \\
		\hline
		2								&	0.0833		& 	$\approx 30^\circ$	\\
		\hline
		3								&	0.1666		& 	$\approx 60^\circ$	\\
		\hline
		4								&	0.2499		& 	$\approx 90^\circ$	\\
		\hline
		5								&	0.3332		& 	$\approx 120^\circ$	\\
		\hline
		6								&	0.4165		& 	$\approx 150^\circ$	\\
		\hline
		7								&	0.4998		& 	$\approx 180^\circ$	\\
		\hline
		8								&	0.5831		& 	$\approx 210^\circ$	\\
		\hline
		9								&	0.6664		& 	$\approx 240^\circ$	\\
		\hline
		10								&	0.7497		& 	$\approx 270^\circ$	\\
		\hline
		11								&	0.8330		& 	$\approx 300^\circ$	\\
		\hline
		12								&	0.9163		& 	$\approx 330^\circ$	\\
		\hline
	\end{tabular}
	\caption{ [TODO] }
		\label{huetable}
\end{table}


\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/flame_hue.png}
	\caption{12 different hue values are presented to the baseline flame with a non-vibrant color palette.}
	\label{hueflame}
\end{figure}



####Brightness
Brightness correction is a function that changes the percieved intensity of light coming from the image can be enacted upon the image. Additional information is mentioned in the *Brightness Correction Background* (Section \ref{brightnesssection}). This percieved intensity can be set by the user and is a value of data type: *positive float*.  The 12 different brightness correction values that were applied to the baseline image are shown in Table \ref{brightnesscorrectiontable}. The resulting images from the altered brightness corrections can be seen in Figure \ref{brightnessflame}. Observe the first and last several images that color clipping occurs. There is absolute light in the flames with the highest brightness correction values (white) and there is an absense of light in the flames with the lowest correction values (black).


\begin{table}[h]
	\begin{tabular}{|l|l|}
		\hline
		Flame Number					&	Gamma Correction value	\\
		\hline
		1								&	0.00			\\
		\hline
		2								&	0.25			\\
		\hline
		3								&	0.50			\\
		\hline
		4								&	1.00			\\
		\hline
		5								&	5.00			\\
		\hline
		6								&	10.00			\\
		\hline
		7								&	25.00			\\
		\hline
		8								&	50.00			\\
		\hline
		9								&	100.00			\\
		\hline
		10								&	1,000.00		\\
		\hline
		11								&	10,000.00		\\
		\hline
		12								&	100,000.00		\\
		\hline
	\end{tabular}
	\caption{ Flame image numbers and their associated brightness correction values. }
		\label{brightnesscorrectiontable}
\end{table}

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/flame_brightness.png}
	\caption{12 brightness correction values are presented on the baseline flame.}
	\label{brightnessflame}
\end{figure}


####Vibrancy
Vibrancy, as stated in the *Vibrancy Background* (Section \ref{vibrancysection}), provides saturation in a non-linear fashion. In the case of flam3, the actual implementation details to visually produce vibrancy are not found in the common literature. The concept that flam3 uses to alter vibrancy is by what factor the gamma correction should be applied (independently or simulatenously). Vibrancy is a setting in flam3 which the user defines and is a *float* from 0.0 to 1.0. A value of 0.0 denotes to apply gamma correction to each channel independently whereas a value of 1.0 denotes to apply gamma corrections to color channels simulatenously. Applying gamma correction to each channel independently results in *pastel* or *washed out* images of low saturation. Consequently, applying gamma correction to color channels simulatenously results in colors becomming saturated. The 12 different vibrancy values that were applied to the baseline image are show in Table \ref{vibrancytable}. The resulting images from the altered vibrancy values can be seen in Figure \ref{vibrancyflame}.

[TODO ANALYSIS]

\begin{table}[h]
	\begin{tabular}{|l|l|}
		\hline
		Flame Number					&	Vibrancy Value	\\
		\hline
		1								&	0.00			\\
		\hline
		2								&	0.05			\\
		\hline
		3								&	0.10			\\
		\hline
		4								&	0.20			\\
		\hline
		5								&	0.30			\\
		\hline
		6								&	0.40			\\
		\hline
		7								&	0.50			\\
		\hline
		8								&	0.60			\\
		\hline
		9								&	0.70			\\
		\hline
		10								&	0.80			\\
		\hline
		11								&	0.90			\\
		\hline
		12								&	1.00			\\
		\hline
	\end{tabular}
	\caption{ Flame image numbers and their associated vibrancy values. }
		\label{vibrancytable}
\end{table}

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/flame_vibrancy.png}
	\caption{12 different vibrancy values are presented on the baseline flame.}
	\label{vibrancyflame}
\end{figure}

####Early Clipping
\label{earlyclipsection}
Earlier it was discussed that the user may experience regions of the flame that become so dense that the colors to fall outside of the representable range of color. These creates regions of uniform density which results in a loss of detail. More background information on this can be found in *Color Clipping Background* (Section \ref{colorclippingsection}).

Early clip takes this idea of color clipping and provides a means to rectify the problem. The problem occurs because in the typical algorithm all of the log scaled histrogram of points is mapped to the RGB color space *after* applying the filter kernel. A potential problem that can happen is that the spatial filter can blur dense regions of the image and then when color correction techniques are applied these blurred regions can become saturated. [17] Visually, this produces regions that look smeared and more dense than it was intended to look. This deviation between the output image and what was intended is a form of detail loss. The rectification of this problem lies in clipping the RGB color material before applying the filter which fixes this issue. This setting can either be turned on or off and can be set by the user.

[TODO]
-	Will we implement it?
-	How many / what guestimated percentage of flames really undergo this problem? And how dramatic are the results? REMEMBER: We're only approximating the appearance.

####Highlight Power
\label{highlightpowersection}
Highlight power is a value (the data type is a *float*) which controls how fast the flame's colors converge to white. The visual effect of this is to blend areas that have drastic color differences that were caused by unintended side effects. The implementation works by keeping the color vector (RGB) pointed in the intended direction until it begins to saturation. When this happens the color starts getting pulled towards white as the iterations continue. A highlight power of 0.0 indicates that saturated colors will not converge to white whereas any value higher than 0.00 is the rate at which saturated colors converge to white. [18] The 12 different highlight power values that were applied to the baseline image are show in Table \ref{highlighttable}. The resulting images from the altered highlight power values can be seen in Figure \ref{highlightflame}.


\begin{table}[h]
	\begin{tabular}{|l|l|}
		\hline
		Flame Number					&	Highlight Power Value	\\
		\hline
		1								&	0.00			\\
		\hline
		2								&	1.00			\\
		\hline
		3								&	2.00			\\
		\hline
		4								&	3.00			\\
		\hline
		5								&	4.00			\\
		\hline
		6								&	5.00			\\
		\hline
		7								&	10.00			\\
		\hline
		8								&	50.00			\\
		\hline
		9								&	100.00			\\
		\hline
		10								&	1,000.00		\\
		\hline
		11								&	10,000.00		\\
		\hline
		12								&	100,000.00		\\
		\hline
	\end{tabular}
	\caption{ Flame image numbers and their associated highlight power values. }
		\label{highlighttable}
\end{table}

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/flame_highlight.png}
	\caption{12 different highlight power values are presented on the baseline flame.}
	\label{highlightflame}
\end{figure}

[TODO look in stashed color and log scale notes for this info]

##Challenge

- Decent dynamic range
- Log-Scaled complications
	- Because we're using log scaled you will need exponentially more points in bright areas than dark areas which results in high quality images needing a whoppingly high number of iterations.


[TODO New Approach]



## Bibliography

[1] http://en.wikipedia.org/wiki/High-dynamic-range_imaging

[2] http://en.wikipedia.org/wiki/Dynamic_range

[3] http://en.wikipedia.org/wiki/Luminance

[4] http://www.dpreview.com/learn/?/key=tonal+range

[5] http://www.colormatters.com/comput_gamma.html

[6] http://en.wikipedia.org/wiki/Tone_mapping

[7] http://en.wikipedia.org/wiki/Data_transformation_(statistics)

[8] http://www.crompton.com/wa3dsp/light/lumin.html

[9] http://whatis.techtarget.com/definition/0,,sid9_gci212262,00.html

[10] http://www.nbdtech.com/Blog/archive/2008/04/27/Calculating-the-Perceived-Brightness-of-a-Color.aspx

[11] http://en.wikipedia.org/wiki/Saturation_(color_theory)

[12] http://web.ncf.ca/jim/photography/dynamicRange/index.html

[13] http://www.autopano.net/wiki-en/action/view/Dynamic_Range

[14]  http://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color

[15] http://alienryderflex.com/hsp.html

[16] http://code.google.com/p/flam3/wiki/GammaThreshold

[17] http://code.google.com/p/flam3/wiki/NewFeatures

[18] http://code.google.com/p/flam3/wiki/HighlightPower
