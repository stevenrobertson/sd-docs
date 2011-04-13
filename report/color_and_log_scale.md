# Fractal Flame Coloring and Log Scaling
## Overview
The *chaos game* provides a way to plot whether points in the biunit square are members of the system or are not. However, the resulting image appears in black and white - lacking color or even shades of gray! The application of color as well as providing smoothed vibrant images are a their own process in the algorithm which deserves much text for several reasons:

1.	A flame is just simply not a flame without its structural coloring or if membership is binary (black and white) which results in a grainy image. Both of these shortcomings leave a lot to be desired but can be remedied.
2.	Much of the new *implementation* relys on reworking details on how coloring is done.

The previous section describing the flame algorithm describes the application of log scaling, a scheme for structural coloring as well as certain color correction techniques however the implementation details were spared. They are expanded upon here in the context of the original fractal flame implementation : *flam3*. We present some of the inner algorithm choices, data structures, and capabilities that the program has. With that, in accordance to the challenge response style paper we present some of the difficulties with making improvements and transitioning the algorithm to the Graphics Processing Unit. Finally, we delve into our new *implenentation* and the differences, similarities, and any relevant backgroud information needed.

##Relevant Applied Color Theory and Imaging Techniques

###Introduction
In the case of the flame algorithm when we refer to coloring- we specifically mean tone mapping as well as color theory techniques (such as colorimetry) and imaging techniques (such as gamma correction). 

Luckily, theese techniques have strong mathematical backgrounds and there is a vast information about them readily available because of advances in both computer graphics and digital photography. 

Additionally, because the flame algorithm's output is an image or series of images we sometimes run into the same complications which plage digital photographs such as color clipping and therefore these same image correction techniques are translated over and retrofitted to greatly improve the visual.

We take a small detour and quickly visit all related techniques as one of the major requirements we must either adhere to these concepts or be able to achieve techniques that achieve comparable results.

###High Dynamic Range (HDR)
A fundamental concept which the whole coloring and log scaling approach tries to achieve is a high-dynamic-range or simply abbreviated as **HDR**. High Dynamic Range  means that it allows a greater dynamic range of luminance between the lighest and darkest areas of an image.[1] Dynamic range is the ratio between the largest and smallest possible values of changeable quantity - in our case light.[2] Lastly, *luminance* being the intensity of light being emitted from a surface per some unit area[3].

The techniques that allow going from a lower dynamic range to a high dynamic range are collectively called high-dynamic-range imaging (HDRI). The reason we mention HDR and HDRI is because we are attempting to give the appearance HDR flames while being constrained to Low Dynamic Range (LDR) viewing mediums such as computer monitors (LCD and CRT) as well as printers.[4]

*TODO:*
- Why are we constrained to  a low dynamic range? What makes a computer monitor or printer LDR or SDR?

- What can we do? There's gotta be a way to correct this! WE WANT TO VIEW OUR FLAMES ON OUR PRETTY LCD MONITOR AND WE WANT TO NOW!

- Alas,

The following techniques described below are not only for aethestics but also are some of the core techniques for represneting HDR images on LDR mediums. This coincides with the goal we wish to achieve and are paramount to fix our lDR dilemma. 

###A RGB Color Model: Hue, Sautration, and Brightness Value (HSV)
To attempt to mathematically define certain color concepts (e.g. brightness, saturation, vibrancy) we will first pick a color model for spatially how our colors will be represented so we can talk about the relationship between them.

We will put all color definitions and conepts in terms of the *Hue, Saturation, and Value (HSV)* model. We explain it this model simply because *flam3* uses this concept and will help understand the algorithmic approach the use for color correction. We wish to stress that there are alternative color models such as:

- Hue, Saturation, and Lightness (HSL)
- Hue, Saturation, and Intensity (HSI)

The HSV color model spatially describes the relationship of Red, Green, and Blue according to these following components:

- Hue
- Saturation
- Brightness
 
It does this by representing these using a cylindrical coordinate system. The axis representations are the following:

- **Rotational Axis:** The rotation axis represents *hue*. Hue refers to pure spectrum of colors - the same prism observed when splitting light. At 0 degrees on the axis the primary color red is represented, at 120 degrees the primary color green is represented, and at 240 degrees the primary color blue is represented. The rest of the degrees are filled in according to the color spectrum.

- **Vertical Axis:** The vertical axis represents brightness. Colors at the top of the spectrum have have no brightness (value of 0; or the color black) and at the bottom have maximal brightness (value of 1; or the color white).

- **Horizontal Axis:** The horizontal axis represents saturation. How saturation is defined here is how prominent the hue is in the resulting color. The outer regions are that of the pure color spectrum whereas the inner regions are grayscale color where no hue is observed and the values depend purely on brightness.

The below image shows all of these working together to represent the entire model:
 
![HSV Color Model](./color_and_log_scale/hsv.png)

*TODO:* What are some of the pros and cons of using HSV. Any flaws in it? Hint at this pargraph from Wikipedia (research this):

"Both of these representations are used widely in computer graphics, and one or the other of them is often more convenient than RGB, but both are also criticized for not adequately separating color-making attributes, or for their lack of perceptual uniformity. Other more computationally intensive models, such as CIELAB or CIECAM02 better achieve these goals."

###Gamma and Gamma Correction
The term *gamma* refers to the amount of light that will be emitted from each pixel on the monitor in terms of in fraction of full power. By pixel we mean the red green and blue phosphors for CRT. (**TODO: Talk about LCDs. More relevant. I need a better understanding on gamma correction for LCDs to write about it) [5]

The main concept we're interested in is **gamma correction**. The reason we need *gamma correction* is the following:

1. CRT displays do not display the light proportional to the voltage given to each phosphor. Therefore the image does not appear in the way it was expected to be viewed.
2. **TODO:** Say something about why LCDs need gamma correction.
3. **TODO:** Say something about why printers can't map the whole color range.

To summarize, the RGB color system with red, green, and blue values ranging from 0 to 255 cannot be accurately represnted. We must perform some kind of correction in order to get the images we expect to see rather than actually see as output.

*TODO:** Talk about hardware implementations of gamma correction.
- Windows and Linux do not gamma correct(?)
- Mac OS X - Partial Gamm Correction(?)
- Now mention that this must be done at the software level.

**TODO: Formula confusion - elaborate later**

\begin{displaymath}
b_{corrected} = b^{1/\gamma} 
\end{displaymath}

As seen above the gamma correction is a non-linear function whose graph looks like the follpwing:

Because we present 4 gamma values applied to an image. 

![Gamma Comparison](./color_and_log_scale/gamma_comparison.png)

*TODO IMPORTANT:* Clear up gamma confusion. In the wiki article they define gamma as:

\begin{displaymath}
v_{corrected} = v^{\gamma}
\end{displaymath}

Whereas Draves defines it as: 

\begin{displaymath}
b_{corrected} = b^{1/\gamma}.
\end{displaymath}

Either correct the image text or the formula. But for now there's inconsistancies.

- Emphasize Image Preservation : highest and lowest colors
- Too little Gamma : What happens? (Right image)
- Just right (Third Image)
- Linear unfiltered Image : What's wrong? (Second Image)
- Too much Gamma: What happens? (First Image)


###Brightness and Brightness Correction
The term *brightness* is a term that must be defined with great finesse. Unlike *luminance* \[#]_ which is empirical, *brightness* is subjective. The subjectiveness comes from that brightness is according to the range of lumens that the eye can percieve. This attribute can have labels assigned to it which go from very dim (black) to very bright (white) [8].

.. [#] Again, *luminance* being the intensity of light being emitted from a surface per some unit area.

To quantatively talk about brightness there are many models which compute brightness in one of the following two ways:

1.	Give equal Weights of each color component (R, G, and B)
2.	Give weighted values of each color component (R, G, and B) - refered to as perceived brightness.

An example of the first application would be a na\"{\i}ve approach that goes on the notation that if black is Red = 0 , Green = 0, Blue = 0 and white is Red = 255 , Green = 255, and Blue = 255 then the brightness can be simply Red + Green + Blue.

The flaw is shown below:

![Wavelengths of Red, Blue, and Green](./color_and_log_scale/rgb_wavelength.png)

As seen from the image the red, green, and blue components of a color have a different wavelength and therefore have a different percieved effect on the eye. A good brightness calculation attempts to model how the eye perceives color rather than treating each color component with equal weights. Many have flaws in them which either under or overrepresent one of the color components[9].

*TODO:* Talk about a weighted model of calculating brightness
*TODO:* If you use HSV talk about the following flaw: "The L component of the HSL and the V component of HSV describe the brightness of a color relative to a base color, if this base color is blue you will get a darker color than if this base color is yellow, HSL and HSV are very useful if you need to create a lighter or darker version of a color but aren't very useful if you want to know how bright a color is." [10]

Later, we will be interested in *brightness correction* - the act of adjusting the brightness. Flames brightness can be adjusted however we must be carefully of the minimum and maximum bounds and the effects of altering brightness.

With the addition of two much or too little brightness color clipping occurs (see below section) and the colors fall outside of representable realms which result in a loss of data.

###Saturation and related terms

The term we wish to describe is that of *saturation* but feel it necessary to talk about the more broad concept in *color theory* which is the intensity of the color. There are different variations of measuring the intensity of the color. The three main terms as well as their distinctions between eachother are below:

1. *Colorfulness:** The intensity of the color is a measure of the colors relative difference between gray. [11]

2.	**Chroma:** The intensity of the color is a measure of the relative brightness of another color which appears white under similar viewing conditions.[11]

3. **Saturation:** The intensity of the color is a measure of its colorfullness relative to its own brightness rather than gray[11].

The term we care about is that of *saturation*. 

*TODO:* Expand on a bit on this section. Possible ideas:
- Describe R, G, and B model as well as the stepness of the bell curve slope described here [9]
- Linear

Colors that are highly *saturated* are those closest to pure hues of color. Colors that have little saturation appear *washed-out*. Also as a note, the changing of a color's saturation can be observed as linear effect.

###Vibrancy

Now that saturation was explained, the term *vibrancy* can be explained. Vibrancy is similar to saturation however different in the following fashion:

Saturation is linear in nature whereas vibrancy works in a non-linear fashion. In vibrnacy the less saturated colors of the image get more of a saturation boost than colors that already have higher saturation values.

*TODO* Why do we care? Tie into future talk about flam3.

###Color Clipping
A problem that plagues images in digital photography and that of the flame algorithm is the concept of *color clipping*. Color clipping happens when color brightness values to be outputted to the image fall either below or above the maximum representable range.

In digital photography *color clipping* can happen from an improper exposure setting on the camera which results in effects, such as the lighting from the sun, overwhelming certain portions of the image. In the case of the flame algorithm, we can put this above analogy into a different context. Our problem is that certain areas of the histogram from the *chaos game* can become so dense that their color setting exceed the bounds of representable brightnesses. 

When data exceeds the upper and lower bounds of representable brightnesses a loss of data occurs. We are unable to determine the differences between those regions of data as they default to the maximum or minimum brightness and appear uniform. A focus on the approach of the algorithm is to prevent this and preserve and be able to represent all contours of the image and their brightnesses.

##Log Transformation of Data
Data transformations in statistics are a common method of transforming data points in order to improve the interpretability of visualization of the output (e.g. graphs)[7]. Some common transformations include:

- Square Root
- Logarithm
- Power Transform

Transformations are in the form of deterministic functions so that we can transform our output back if necessary. For our specific purposes we will study the logarithmic transformation of data.

The ultimate goal again of the coloring and rendering is preservation. If we plot a non transformed histogram of densities of a flame intact we loose information about the least and most dense areas of the histogram. The logarithm transformation helps perserve the relationship between points to provide a more accurate histogram.

##Tone Mapping and Tone Operators
With a firm idea of High Dynamic Range (HDR) we present the concept of tone mapping. What the process of tone mapping produces is a mapping from one set of colors to another that is applied to the image. This is heavily used in image processing. Because we are limited to a lower dynamic range when presenting images on monitors or printers we attempt to use tone mapping to closely resemble the appearance of an HDR image. This is one of the goals of tone mapping. The two typical application purposes of tone mapping are as follows:

1. Bring out all of the details of an image - or more specifically, maximizing image contrast. This approach focuses on producing realism and aims to render an image as accurately as possible.
2. Create a aethestically pleasing image, often ignoring the realistic model that the first approach attempts to model but trying to create another desired affect. This effect is up to the person designing the tone operator which is applied to the image.

*TODO:* Provide graphics to show what I mean in application #1 and application #2.

The method for applying this tone mapping is done via a tone mapping operator. The HDR image is processed by the tone mapping operator which provides one of the two above mentioned effects. There are two major classifications of tone mapping operators[6]:

1. **Global Tone Operators:** In a global tone operator the mapping of one color set to another is uniformly applied to the image. This mapping is in the form of a non-linear function that is determined to be the desired mapping[6]. Gamma correction is an example of a simple global tone operator.

2. **Local Tone Operators:** In a local tone operator the mapping of one color set to another varies according to the local features of the image. The tone operator takes into the regions of changing pixels in the image.

*TODO:* Great, so you've got a solid background on tone mapping. You still need to add that extra umph, describing where we will go from here.

##Flam3 : Original Coloring and Log Scaling Implementation

### Log Scaling of Chaos Game

- Recap that log transforming data is a plus
- What are we log transforming: points plotted by the chaos game
- What do we do with all these points? Image is still just shades of gray!


### Ad-Hoc Tone Mapping

- Why Ad-Hoc?
- Implementation, how to go from grayscale to color?
- Get detailed, very detailed! This will help when setting up new approach and comparing it

###The Palette
[4/8/11]

- R,G,B,Alpha
- Why Alpha? What does it do?

###Coloring Capabilities

####Overview

- Mention in our improved version we want to include a subset and if possible - all of the below features that make a flame- a flame.
- Now that we understand color theory and imaging techniques, what do they look like in the context of our flames?
- How are all of these implemented in the code?
- When in the code are these implemented? Be specific, include previous reference to the fractal flame section and try to 'point' at where this is happeneing

####Gamma 

- Provide illustrative examples
- Elaborate what happens when gamma is too high.
- Elaborate what happens when gamma is too low.

####Gamma Threshold

- What is this and how does it function?
- Why do we need this?
- Provide illustrative examples

####Brightness

- Provide illustrative examples
- Elaborate what happens when brightness is too high.
- Elaborate what happens when brightness is too low.

####Vibrancy

- Provide illustrative examples
- We have gamma and brightness... why do we need vibrancy too?

####Color Clipping

- Provide illustrative examples of color clipping in action and how it improves flame quality

####Highlight Power

- This is a specific feature and not a general technique (pretty sure)
- Explain the need for it
- Provide illustrative examples 
- Provide analysis
- Probably will *not* implement- only if there seems to be a need for it. 

#### All Together Now: The Coloring Formula

- Describe coloring formula, K1 and K2 in flam3
- What coloring correction and imaging technique features are in this formula?
- Where are other features applied?
- Should I explain the details how they are applied if there are applied in another section as that section will probably fail to mention them?

##Challenge

- Decent dynamic range
- Log-Scaled complications
	- Because we're using log scalled you will need exponentially more points in bright areas than dark areas which results in high quality images needing a whoppingly high number of iterations.

##New Approach

###Criteria

**TODO:** What we're looking for is reproduction of a flame that is approximately visually equivalant. 

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