Existing implementations
========================

The fractal flame algorithm is relatively old, but unlike most antiquated
image synthesis techniques, its output is still considered to be visually
appealing today. As might be imagined for such a classic algorithm, there
are several implementations available; a few even target GPUs. To ensure
that our implementation provides a benefit, we must consider the strengths
and weaknesses of each implementation, and carefully target our renderer to
fill these gaps.

To that end, a brief survey of each publicly-available implementation is
below.

flam3
-----

Considered by most to be the "reference implementation" of the flame
algorithm, flam3_ was created in 1999 [CHECK] by Scott Draves, the creator
of the fractal flame algorithm. In TK, Erik Reckase took over development,
and continues to add features and release updates to this day.

Because of ``flam3``'s status as a reference implementation, each new
version is regression-tested against the output of previous versions to
ensure it can still produce (nearly-)identical images. To retain this
property while still accomodating new features, the code now includes a
dizzying array of parameters, flags, and downright hacks. This makes it
difficult to optimize and experiment with.

Since the Electric Sheep project uses ``flam3`` to produce all its images,
however, scrapping this mess is not an immediate option. The Electric Sheep
screensaver obtains its content from pre-rendered video sequences, and
until an implementation fast enough to re-render the entire back catalogue
of pre-rendered flames from scratch at sufficient quality is produced,
backwards compatibility is needed to guarantee seamless transitions.

An implementation that could produce ``flam3``-compatible images at high
speeds would therefore be useful to the Electric Sheep project.

Apophysis
---------

Apophysis_ is an aging application for the interactive design of flames,
and is one of the most popular tools to do so. Apophysis includes its own
rendering backend, which has proved to be somewhat easier to modify than
``flam3``; as a consequence, many variations now included in ``flam3``
started out as community experimentation within Apophysis, and more are yet
being considered.

The Apophysis renderer lacks some of ``flam3``'s newer
visual-quality-oriented features, so while it remains a viable choice for
users and interesting to watch, there is no particular need to fully
support it.

flam4
-----

One of the more complete implementations of the flame algorithm for GPUs,
flam4_ nevertheless sits in an uncomfortable position in terms of its
output: the implementation suffers from compromises necessary to allow
reasonable performance on the GPU, reducing its perceptual output quality,
yet it is not fast enough to render images for display on the fly. Since
CPUs are fast enough to deliver offline renders at normal resolutions in
reasonable size, there is little need for acceleration for the mid-range
renders, as a bit of patience can usually accomodate most use cases.

Since ``flam4`` provides good acceleration at moderate loss of quality, we
should not attempt to do the same. A novel implementation should target
either acceleration without loss of quality, or fully real-time performance
at an acceptable quality.

Fractron 9000
-------------

TODO: test `Fractron 9000`_. Say something snarky about it.

Chaotica
--------

Chaotica_ is the only closed-source implementation of the flame algorithm
known to the authors. This is moderately disappointing, as Chaotica's goals
are interesting: produce images of superior visual quality to ``flam3``, in
less time. The software does indeed accomplish this. Thomas Ludwig,
Chaotica's author, is also a developer of `Indigo Renderer`_, a
professional ray-tracing application, and we believe that his experience in
ray-tracing is what gives his software such an edge. This is difficult to
confirm, however, as the developer has been notoriously quiet about his
improvements.

Mr. Ludwig may be pursuing an offline GPU renderer with similar goals. Such
an implementation would be difficult to beat, and since we are interested
in open-sourcing our version, head-on competition with a paid product at
the outset may not result in the largest benefit to the community. Mr.
Ludwig has declined our invitation to cooperate on this project.

Our implementation
------------------

Given that no accelerated renderer explicitly targets ``flam3``
compatibility, despite the desire among the community for such a tool, it
seems prudent to pursue that subfield of image compatibility. In addition
to being able to compare images directly against the output of a CPU
renderer, which simplifies testing, such a renderer would lower the
operating cost of the Electric Sheep project and see widespread adoption as
part of that software.

However, an implementation capable of real-time rendering has a greater
potential novelty, both in terms of the rendering techniques used and the
applications in which such a renderer would be used. The techniques
required to produce such a renderer have not yet been developed; in the
current generation of hardware, there is simply not enough computing power
available to implement the traditional algorithm, however optimized, at HD
resolutions and update rates with sufficient quality. Focusing on a
real-time renderer would therefore be an ambitious risk, but one which
might generate substantial interest.

In light of this, we have decided to divide our efforts between both goals.
For this project, we will produce a single application, but one that
contains two different render paths. This approach has many implications
for our project, and applies constraints to the design of the application
and libraries. It is believed that this balances the risk of having an
unsuccessful project with the rewards offered by a novel, real-time
implementation.

.. _flam3:      http://flam3.com
.. _Apophysis:  http://apophysis.org
.. _flam4:      http://sourceforge.net/projects/flam4/
.. _Fractron 9000: http://fractron9000.sourceforge.net
.. _Chaotica: http://www.indigorenderer.com/forum/viewtopic.php?f=6&t=10205
.. _Indigo Renderer: http://www.indigorenderer.com/

