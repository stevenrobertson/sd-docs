# Fractal Flame Coloring and Log Scaling
## Overview
The *chaos game* provides a way to plot whether points in the biunit square are members of the system or are not. However, the resulting image appears in black and white - lacking color or even shades of gray! The application of color as well as providing smoothed vibrant images are their own process in the algorithm which deserves much text for several reasons:

1.	A flame is just simply not a flame without its structural coloring or if membership is binary (black and white) which results in a grainy image. Both of these shortcomings leave a lot to be desired but can be remedied.
2.	Much of the new *implementation* relies on reworking details on how coloring is done.

The previous section describing the flame algorithm describes the application of log scaling, a scheme for structural coloring as well as certain color correction techniques however the implementation details were spared. They are expanded upon here in the context of the original fractal flame implementation : *flam3*. The inner algorithmic choices, data structures, and capabilities that the program has are analyzed. With that, in accordance to the challenge response style paper some of the difficulties with making improvements and transitioning the algorithm to the Graphics Processing Unit are presented. Finally, the authors delve into the new *implementation* and the differences, similarities, and any relevant background information needed.

##Relevant Applied Color Theory and Imaging Techniques

###Introduction
In the case of the flame algorithm when coloring is referred to the authors are referring to the act of tone mapping, the structural coloring, and any color theory techniques (such as colorimetry) and imaging techniques (such as gamma correction) used. 

Luckily, these techniques have strong mathematical backgrounds and there is a vast information about them readily available because of advances in both computer graphics and digital photography. 

Additionally, because the flame algorithm's output is an image or series of images it often runs into the same complications which plague digital photographs such as color clipping and therefore these same image correction techniques are translated over and retrofitted to greatly improve the visual.

A small detour is taken to visit all related techniques as one of the major requirements that must be adhered to for a new implementation is the results these techniques achieve.

###High Dynamic Range (HDR)
A fundamental concept which the whole coloring and log scaling approach tries to achieve is a high-dynamic-range or simply abbreviated as **HDR**. High Dynamic Range  means that it allows a greater dynamic range of luminance between the lightest and darkest areas of an image.[1] Dynamic range is the ratio between the largest and smallest possible values of changeable quantity - in our case light.[2] Lastly, *luminance* being the intensity of light being emitted from a surface per some unit area[3].

The techniques that allow going from a lower dynamic range to a high dynamic range are collectively called high-dynamic-range imaging (HDRI). The reason HDR and HDRI imaging is mentioned is because the output of the flame attempts to give the appearance of an HDR flame while being constrained to Low Dynamic Range (LDR) viewing mediums such as computer monitors (LCD and CRT) as well as printers.[4]


By observing common dynamic ranges of some typical mediums as well as various digital file formats we can begin to see why we are limited.

Both the file format technologies in which our images or videos and stored in as well as monitor or paper in which they are viewed on are interrelated limiting factors governing the dynamic range. As seen in Table \ref{hdrtable} are various typical contrast values that these scenes can emit or in the case of file formats are capable of representing[12][13].

\begin{table}[h]
	\begin{tabular}{|l|l|l|}
		\hline
		Medium					&	Ratio		&	Stop  	\\
		\hline
		JPEG Image File			&	256 : 1		&	8		\\
		RAW Image File 			&	1,024 : 1	& 	10		\\
		\bf{HDR Image File}	&	approx. 32,768 : 1 to 1 : 1,048,576	& approx. 15 - 20	\\
		Standard Video			&	45 : 1		&	5.49	\\
		Standard Negative Film	& 	128 : 1		& 	7		\\
		\bf{LCD Technology}			&	500 : 1		&	8.96	\\
		\bf{CRT Display}				&	50 : 1		&	5.64	\\
		\bf{Glossy Print Paper}		&	60 : 1		&	5.90	\\
		Newsprint				&	10 : 1		&	3.32	\\
		\bf{Sunlit Scene}			& approx. 100,000 : 1	&	16.60	\\
		\bf{Human Eye}				& approx. 10,000 : 1	&	13.28	\\
		\hline		
	\end{tabular}
	\caption{Typical dynamic ranges of various scenes or typical dynamic ranges that able to be represented. }
		\label{hdrtable}
\end{table}


Where Stop is defined as :	$log_{2}(Ratio)/log_{2}(2)$.

Let's take a look at what this table really means in the case of imagery. The table shows that a **HDR Image File** can represent an impressive range of contrast - far higher than the eye can observe. We also note that it could approximately even capture a **Sunlit Scene** which contains extreme contrast between the brightness and darkest intensity values. However, if we look at our viewing technologies we notice their limits of displaying contrast. **LCD Technology** has a Stop value of approx. 8.96, **CRT Technology** has a Stop value of approx. 5.64, and **Glossy Print Paper** has a Stop value of 5.90. Compared to the **Human Eye** whose Stop value is approx. 13.28, these values incapable of being on par with the level of contrast the human eye can observe and therefore will not accurately represent how the colors ideally should be observed. 

Luckily, we can work within our imposed limitations and there are many imaging techniques that can be applied to attempt to remedy the situation.  The following techniques described below are not only for aesthetics but also are some of the core techniques for representing HDR images on LDR mediums. This coincides with the goal the entire algorithm wishes to achieve and is paramount to fix our LDR dilemma. 

###A RGB Color Model: Hue, Saturation, and Brightness Value (HSV)
To attempt to mathematically define certain color concepts (e.g. brightness, saturation, vibrancy) a color model for spatially how our colors will be represented is chosen so the relationship between colors can be talked about.

All of the color definitions and concepts are in terms of the *Hue, Saturation, and Value (HSV)* model. It is explained in this model simply because *flam3* uses this concept and by using the HSV model it will save additionally explanation on how this model works. It should also be noted that there are alternative color models such as:

- Hue, Saturation, and Lightness (HSL)
- Hue, Saturation, and Intensity (HSI)

The HSV color model spatially describes the relationship of Red, Green, and Blue according to these following components:

- Hue
- Saturation
- Brightness
 
It does this by representing these using a cylindrical coordinate system. The axis representations are the following:

- **Rotational Axis:** The rotation axis represents *hue*. Hue refers to pure spectrum of colors - the same prism observed when splitting light. At 0 degrees on the axis the primary color red is represented, at 120 degrees the primary color green is represented, and at 240 degrees the primary color blue is represented. The rest of the degrees are filled in according to the color spectrum.

- **Vertical Axis:** The vertical axis represents brightness. Colors at the top of the spectrum have no brightness (value of 0; or the color black) and at the bottom have maximal brightness (value of 1; or the color white).

- **Horizontal Axis:** The horizontal axis represents saturation. How saturation is defined here is how prominent the hue is in the resulting color. The outer regions are that of the pure color spectrum whereas the inner regions are gray scale color where no hue is observed and the values depend purely on brightness.

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/hsv.png}
	\caption{HSV Color Model}
	\label{hsvmodel}
\end{figure}

Using the HSV model (Figure \ref{hsvmodel}) provides a simple way of representing the color space and describing the relationship between them. The calculations also require little computation. However, one of the major drawbacks is that the model gives no insight into color production or manipulation.


###Gamma and Gamma Correction
The term *gamma* refers to the amount of light that will be emitted from each pixel on the monitor in terms of in fraction of full power[^LCD] (pixel being shorthand for the red, green, and blue phosphors of a CRT)[5].

[^LCD]: The relationship on LCDs between signal voltage and intensity is very non-linear and a simple gamma value cannot describe it. A correction factor can be applied however and the concepts are similar.

The main concept we're interested in is **gamma correction**. The reason *gamma correction* is needed is the following:

1. CRT and LCDs displays do not display the light proportional to the voltage given to each phosphor. Therefore the image does not appear in the way it was expected to be viewed.
3. A typical consumer grade printer works upon 8 or 16 bit color and result in a relatively low HDR as seen in Table \ref{hdrtable}.

To summarize, the RGB color system with red, green, and blue values ranging from 0 to 255 cannot be accurately represented. Some kind of correction must be performed in order to get the images that are expected to be seen rather than the images that are actually seen as output.

This concept of gamma correction can be applied at the hardware level however varies depending on the vendor, and hardware capabilities of the machine. For example:

- PCs typically do not implement gamma correction at the hardware level. A noteable exception is that certain graphics card may implement a gamma correction natively.
- Macintoshes typically provide a gamma correction at the hardware level of 1.4.

Besides being implemented at the hardware level, gamma correction can additionally be provided at the software level.

The formula for gamma correction is $b_{corrected} = b^{1/\gamma}$ where $\gamma$ is the correction factor.

To understand the non-linearity of the gamma function 4 gamma correction values are applied to an image for visual depiction of the concept. The results are seen in Figure \ref{gammacomparison}. 


\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/gamma_comparison.png}
	\caption{Comparison of gamma correction values.}
	\label{gammacomparison}
\end{figure}


The second image of Figure \ref{gammacomparison} does not undergo any gamma correction and can be used as a baseline comparison to the other images. By observing both the higher and lower bounds of the images presented we can see that images become either too dark or too light and their is little contrast between the colors. The third image has a gamma correction value of 2. Normal gamma correction is roughly around 2.2 which explains why this image appears more natural and has a higher dynamic range then the others.



###Brightness and Brightness Correction
The term *brightness* is a term that must be defined with great finesse. Unlike *luminance*[^lum] which is empirical, *brightness* is subjective. The subjectiveness comes from that brightness is according to the range of lumens that the eye can perceive. This attribute can have labels assigned to it which range from very dim (black) to very bright (white) [8].

[^lum]: Again, *luminance* being the intensity of light being emitted from a surface per some unit area.

To quantatively talk about brightness there are many models which compute brightness in one of the following two ways:

1.	Give equal Weights of each color component (R, G, and B)
2.	Give weighted values of each color component (R, G, and B) - referred to as perceived brightness.

An example of the first application would be a na\"{\i}ve approach that goes on the notation that if black is Red = 0 , Green = 0, Blue = 0 and white is Red = 255 , Green = 255, and Blue = 255 then the brightness can be simply Red + Green + Blue.

\begin{figure}[h]
	\centering
	\includegraphics{./color_and_log_scale/rgb_wavelength.png}
	\caption{Wavelengths of Red, Blue, and Green}
	\label{rgbwavelength}
\end{figure}

This flaw can be seen in Figure \ref{rgbwavelength}. The red, green, and blue components of a color have a different wavelength and therefore have a different perceived effect on the eye. A good brightness calculation attempts to model how the eye perceives color rather than treating each color component with equal weights. Many have flaws in them which either under or over represent one of the color components[9].

Some examples of weighted models to calculate brightness are below in Table \ref{brightnessmodel}. [14][15]

\begin{table}[h]
	\begin{tabular}{|l|l|}
		\hline
		Model					&	Formula	\\
		\hline
		Photometric/digital ITU-R		&	$0.2126 \times R + 0.7152 \times G + 0.0722 \times B$		\\
		Digital CCIR601 				&	$0.299 \times R + 0.587 \times G + 0.114 \times B$		\\
		HSP Color Model (Percieved Brightness) &	$\sqrt{0.241 \times  R^2 + 0.691 \times G^2 + 0.068 \times  B^2 }$		\\
		\hline		
	\end{tabular}
	\caption{Weighted Brightness Calculations. }
	\label{brightnessmodel}
\end{table}

Later, the topic of *brightness correction* is of interest- the act of adjusting the brightness. Flames brightness can be adjusted however care must be taken so that the minimum and maximum bounds are not exceeded.

With the addition of too much or too little brightness color clipping occurs (see below section) and the colors fall outside of representable realms which result in a loss of data.

###Saturation and related terms

The concept this section intends of describing is that of *saturation* but it is felt necessary to talk first about the more broad concept in *color theory* which is the intensity of the color. There are different variations of measuring the intensity of the color. The three main terms as well as their distinctions between each other are below:

1. *Colorfulness:** The intensity of the color is a measure of the colors relative difference between gray. [11]

2.	**Chroma:** The intensity of the color is a measure of the relative brightness of another color which appears white under similar viewing conditions.[11]

3. **Saturation:** The intensity of the color is a measure of its colorfulness relative to its own brightness rather than gray[11].

The term that is of importance is that of *saturation*. 

[TODO  Expand on a bit on this section. Possible ideas: Describe R, G, and B model as well as the steepness of the bell curve slope described here [9]. Linear]

Colors that are highly *saturated* are those closest to pure hues of color. Colors that have little saturation appear *washed-out*. Also as a note, the changing of a color's saturation can be observed as linear effect.

###Vibrancy

Now that saturation was explained, the term *vibrancy* can be explained. Vibrancy is similar to saturation however different in the following fashion:

Saturation is linear in nature whereas vibrancy works in a non-linear fashion. In vibrancy the less saturated colors of the image get more of a saturation boost than colors that already have higher saturation values.

*TODO* Why do we care? Tie into future talk about flam3.

###Color Clipping
A problem that plagues images in digital photography and that of the flame algorithm is the concept of *color clipping*. Color clipping happens when color brightness values to be outputted to the image fall either below or above the maximum representable range.

In digital photography *color clipping* can happen from an improper exposure setting on the camera which results in effects, such as the lighting from the sun, overwhelming certain portions of the image. In the case of the flame algorithm, this concept can be viewed in a different context. One problem with flames is that certain areas of the histogram bins from the *chaos game* can become so dense that their color setting exceed the bounds of representable brightness's. 

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

1. **Global Tone Operators:** In a global tone operator the mapping of one color set to another is uniformly applied to the image. This mapping is in the form of a non-linear function that is determined to be the desired mapping[6]. Gamma correction is an example of a simple global tone operator.

2. **Local Tone Operators:** In a local tone operator the mapping of one color set to another varies according to the local features of the image. The tone operator takes into the regions of changing pixels in the image.

[TODO Great, so you've got a solid background on tone mapping. You still need to add that extra umph, describing where we will go from here.]

##Flam3 : Original Coloring and Log Scaling Implementation

### Log Scaling of the Chaos Game

In the classical IFS membership in the system is binary however in the Fractal Flame Algorithm one of the goals is to expose as much detail as possible. As mentioned before, every successive time a point gets plotted in binary representation information is lost about the densities of regions of the output flame. This is remedied with the concept of a *histogram* which plots the distribution of the points. These histogram bins then need to be scaled to *gray scale*.  *Gray scale* is represented as a byte which has values ranging from 0 to 255. A mapping of densities ranging from *[0, 1, 2, ..., DOUBLE_MAX]* to *[0, 1, 2, ..., 255]* must be performed. If a linearly scaled mapping was applied it would suffer from the problems described in Section \ref{logdensitydisplay} hence the concept of log transformation is applied (Section \ref{logtransformation}). Flam3 implements log scaling of the histogram of point densities. In flam3,

EXAMPLE \ref{ls}

**TODO:** Describe how it is done in Flam3. Please articulate on the concepts of:
-	Buckets / Accumulator
-	Batches
-	Aye aye aye!

The log scaling performed in flam3 is in align with the overall goal of approximating a High Dynamic Range flame. The method described above is a straightforward implementation although the naming convention of the flam3 algorithm needs articulation. No additional information is needed and the understanding of the benefits of log scaling and why flam3 implements it should be found in the referenced sections above.

### Ad-Hoc Tone Mapping

- Why Ad-Hoc?
- Implementation, how to go from gray scale to color?
- Get detailed, very detailed! This will help when setting up new approach and comparing it

###The Palette

- R,G,B,Alpha
- Why Alpha? What does it do?

###Coloring Capabilities

####Overview
Flam3 provides not just structural coloring but also exposes a vast amount of functionality which allows the resulting flame to undergoing image correction and other altercations. The image correction and other altercations are done using a configuration file. The section visually inspects (1) Gamma Correction, (2) Gamma Threshold, (3) Brightness Correction, (4) Vibrancy, (5) Color Clipping, and (6) Highlight Power.

After visually inspecting them as well as describing their purpose and how the output flames benefit from them, flam3's implementation is examined. Next, the authors discuss what features are essential for our task at hand and which color correction techniques could be omitted while still providing an essential subset of functionality.

#### Visual Inspection of the Baseline Image
For reference of the reader the present a detailed flame containing several transforms with a vivid default coloring. In the following sections adjustments are performed to one parameter of the flame while holding the others constant so that the parameter effect in question can be observed.

The parameters of the following flame are the following:

-	**Gamma Correction:** **TODO**
-	**Gamma Threshold:** **TODO**
-	**Brightness Correction:** **TODO**
-	**Vibrancy:** **TODO**
-	**Early Clipping:** **TODO**
-	**Highlight Power:** **TODO**


**TODO:** Insert image of baseline image


####Gamma Correction
As mentioned in the Gamma Correction background section (**TODO** : Add reference to read about gamma correction) a nonlinear function needs to be applied in order to produce an output flame that approximately replicates the expected image. The gamma correction formula's gamma(**TODO** Insert formula) is left to be set by the user. 9 different values of the baseline image are shown below. The first several images show the effects of when the gamma is set to values that are too low and show the characteristic signs of low gamma which is that the image looks washed out. The last images in the series show the effects of when the gamma is set to values that are too high and show characteristic signs of high gamma which is that the image looks too dark.


**TODO:** Run flames with these settings

==========================================

1     2     3  4   5   6   7   8    9

0.00 0.25 0.50 1.0 2.0 3.0 5.0 10.0 50.0

==========================================

####Gamma Threshold

- What is this and how does it function?
- Why do we need this?
- Provide illustrative examples

####Brightness
As mentioned in the Brightness Correction background section (**TODO** : Add reference to read about brightness correction) a function that changes the percieved intensity of light coming from the image can be enacted upon the image. This percieved intensity is a value (the data type is a *double*) and can be set by the user. 9 different values of the baseline image are shown below. Observe the first and last several images that color clipping occurs. There is absolute light in the flames with the highest brightness correction values (white) and there is an absense of light in the flames with the lowest correction values (black).

**TODO:** Run flames with these settings

==========================================

1     2     3    4   5   6    7      8        9

0.00 0.25 0.50 1.0 10.0 50.0 100.0 1000.0 10000.0

==========================================



####Vibrancy
As mentioned in the Vibrancy section (**TODO**: Add reference to read about vibrancy) a **TODO** that **TODO** is **TODO** This concept of vibrancy is a value (the data type is a *double*) and can be set by the user. Again, 9 different values of the baseline image are shown below.

**TODO:**
- Observations
- Is this concept essential? or just visual sugar? Are we looking to keep this for our representation?

==========================================

1     2     3    4   5   6    7      8        9

0.00 0.25 0.50 1.0 1.25 1.50 2.00   5.00     10.0

==========================================


####Early Clipping
As mentioned in the Color Clipping section (**TODO**: Add references to read about color clipping), we may experience regions of the flame that become so dense that with the effects of other parameters consequently allow the colors to fall outside of the representable range of color. These creates regions of uniform density where there should not be and lose of detail occurs. Early clip takes this idea of color clipping and **TODO** : Provide Early Clip Explanation)

**TODO**: Insert picture of early clipping. Will the image you're using be able to visually convey early clipping?


-	Will we implement it?
-	How many / what guestimated percentage of flames really undergo this problem? And 
	how dramatic are the results? REMEMBER: We're only approximating the appearance.

####Highlight Power
Highlight power is a value (the data type is a *double*) which controls how fast the flame's colors converge to white. The visual effect of this is to blend areas that have drastic color differences that were caused by unintended side effects. The code works by keeping the color vector (RGB) pointed in the intended direction until it begins to saturation. When this happens the color starts getting pulled towards white as the iterations continue. (**TODO VERIFY**: A highlight value of -1 performs no highlighting however positive values apply this correction technique. A problem with flames with a highlight power that is too high is that the colors look drown out and lose any distanct vibrance they once had)

- Probably will *not* implement- only if there seems to be a need for it. 

**TODO**: Insert picture of highlight power. Will the image you're using be able to visually convery highlight power?

#### All Together Now: The Coloring Formula


**TODO** : Piece together where everything is being done. Clean up and use latex math to explain.

k1 =(cp.contrast * cp.brightness *
PREFILTER_WHITE * 268.0 *
batch_filter[batch_num]) / 256;

area = image_width * image_height / (ppux *
ppuy);

k2 = (oversample * oversample *
nbatches) / (cp.contrast * area *
WHITE_LEVEL * sample_density * sumfilt);



- Describe coloring formula, K1 and K2 in flam3
- What coloring correction and imaging technique features are in this formula?
- Where are other features applied?
- Should I explain the details how they are applied if there are applied in another section as that section will probably fail to mention them?

##Challenge

- Decent dynamic range
- Log-Scaled complications
	- Because we're using log scaled you will need exponentially more points in bright areas than dark areas which results in high quality images needing a whoppingly high number of iterations.

##New Approach

###Criteria

**TODO:** What we're looking for is reproduction of a flame that is approximately visually equivalent. 

###Tone-Mapping Operator

- Write about the new tone mapping operator implementation instead of log scaling and then coloring. 
- Possible Advantages : Hope to cut down on required points


###Implementation

- Detailed section that explains the gnitty gritty details of everything
- provide relevant background information
- Why? Why? Why? Provide detailed explanations for every step along the way? What was flam3 doing right? What could have been improved on?
- What are the pros and cons of the implementation we picked?



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
