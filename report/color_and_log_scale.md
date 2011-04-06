# Fractal Flame Coloring and Log Filtering
## Overview

- As mentioned in the fractal flame section, the chaos game provides a way to show whether points in the biunit square are members of the system or are not however application of color and providing smoothed vibrant images are seperate processes that must be applied seperately!
- Again, describe that the basic concepts of certain matrial warrents discussion
- Next, the original fractal flame implementation : flam3 will be presented
- Finally, our implementation will be presented

##Relevant Applied Color Theory and Imaging Techniques

###Introduction

- What is color theory and why is necessary for our coloring techniques?
- What are imaging techniques and why are they necessary for our coloring techniques?

###High Dynamic Range

- What is it a high dynamic range?
- What is a low Dynamic Range?
- How is this relevant?
- Describe methods for HDR correction... next sections follow suit.

###Gamma

- Give a sentence describing it in plain English
- Describe non-linear effect
- Emphasize Image Preservation : highest and lowest colors
- Too little Gamma : What happens?
- Too much Gamma: What happens?

###Brightness

- Give a sentence describing it in plain English
- How do R,G, B colors change when brightness changes?
- Too much brightness: What happens?
- Too little brightness : What happens?

###Saturation

- Touch on colorfulness, chroma, and saturation. Describe differences and confusion.
- How do you calculate how colorful something is? Describe common methods and  possibly equations
- Linear

###Vibrancy

- Similar to Saturation
- Differences: Nonlinear
- How does it operate? Less saturated colors will get more of a saturation boost than colors that are already saturated.
Write between a paragraph or two desscribing this.

###Color Clipping

- What is it?
- How would an image fall outside min or max intensities?
- Problems: Loss of data. Values of densities above upper or lower bounds appear uniform.
- Possible remedies: Clip colors early to prevent this

##Log Transformation of Data

- Make case for it
- Show advantages of log transforming your data
 
##Tone Mapping

- Be general, we will later call back on this section to show that the flam3 algorithm is an adhoc implementation of tone mapping
- What is tone mapping?
- Why would we need it?
- Common methods
- but wait there's more...


##Flam3 : Original Coloring and Log Filtering Implementation

### Log Filtering of Chaos Game

- Recap that log transforming data is a plus
- What are we log transforming: points plotted by the chaos game
- What do we do with all these points? Image is still just shades of gray!

### Ad-Hoc Tone Mapping

- Why Ad-Hoc?
- Implementation, how to go from grayscale to color?
- Get detailed, very detailed! This will help when setting up new approach and comparing it

###The Palette

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

