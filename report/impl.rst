Tools and components
====================

Computers are complicated. For any computer-based project, choosing the
right tool for the job is a task commensurate with that complexity. Many
software projects rely on standards and abstractions to make these
decisions tractable, but when the goal is raw performance, engineers must
go beneath the abstractions to the often messy intersection between
software and hardware. Tuning algorithms for particular hardware
configurations can lead to dramatic performance improvements, but this
process imposes constraints which can be felt throughout the project. Just
as in hardware projects, low-level software must first start with a careful
analysis of requirements.

In this section, we describe the platform decisions made for this project
and the reasoning behind each. Although an effort has been made to describe
each decision in a causal order, each part of the platform influences
others, and the entire set was considered as a whole during our original
analysis. Consequently, there may be (TODO: make definite) some page
flipping required.

Decision criteria
-----------------

As discussed in "Existing Implementations" (TODO: reflink this), we intend
to pursue what are essentially two independent rendering techniques inside
our implementation. For the conventional pipeline — that is, the one
designed to produce images compatible with ``flam3`` — the required
algorithm is fairly fixed, and it is possible to estimate required
resources with a reasonable degree of accuracy. These estimates will appear
in subsequent sections where relevant.

It is more difficult to derive the requirements of the real-time pipeline,
as it is without even a CPU-based reference at this time. Because the goal
of real-time rendering is so far from current approaches, his algorithm
will be adapted to the hardware and programming model throughout its
development, rather than after the fact. If the tools are insufficiently
flexible to accomodate a suitable algorithm, however, its use will be
avoided, meaning that we have a strong incentive to consider more flexible
parts even at a small performance disadvantage.


The hardware
------------

Modern, high-performance graphics cards consist of one or more GPU ICs
[#]_, memory, audio/video IO, and other interface components. The GPU IC
has its own BIOS, scheduler, processors, and physical address space; some
can even serve as a DMA host on the PCI express bus [CITE].  While today's
GPU is not entirely independent, requiring a CPU to provide an initial
instruction stream and control some hardware features, it otherwise earns
the description "system-on-a-card".  [#]_

.. [#]: As with "CPU", "GPU" can refer to either the integrated circuit
        containing most of the graphics card's processing and control
        logic, or to all subsystems accessable from that IC, including
        memory, host interface, and other components. Because these
        components are only accessable through the ISA exposed by the
        drivers, there is no way for our application to interact with the
        GPU IC apart from its associated components on the card, and so we
        always use "GPU" to refer to the system, and save "GPU IC" to
        denote the physical chip.

.. [#]: Whether NVIDIA's rather optimistic "supercomputer-on-a-card" [CITE]
        should be accepted is another question, but one not addressed here.

.. expand:

    if needed, can tell a nice little story about how GPUs got that way,
    starting from 3Dfx; explaining influence of OpenGL and DirectX on ATI
    and NVIDIA, why a skunkworks program to redesign their primary volume
    architecture (as Intel did with Yonah, and AMD with SledgeHammer) would
    be exceedingly risky and so was never attempted; how that process led
    to the current chips. A shorter version of this is below.

Fixed-function to unified shading: a smooth path
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Before the advent of programmable shading on GPUs, their capabilities were
limited to those exposed by the graphics languages. The conceptual path of
data through a GPU was referred to as the *fixed-function pipeline*, and
the devices were only capable of computations which could be described in
terms of steps along this pipeline. While some attempts were made to use
GPUs for general-purpose computation by adapting computation to
fixed-function stages [CITE], this was in practice quite limited.

Despite the requirement that the driver present a view of a fixed-function
pipeline to graphics languages, hardware manufacturers were in fact free to
implement the pipeline in whatever way they saw fit. Additionally, the
behavior of many components remains only loosely defined, leading to
further variations among components; for instance, texture interpolation
hardware differs in implementation of anisotropic filtering between
manufacturers, resulting in variations in quality and clock-for-clock
performance for the same workload. [CITE]

The introduction of programmable shading has perhaps halted this trend of
divergence in approaches, but has not yet reversed it. The earliest
inclusion of programmable components in the fixed-function pipeline allowed
their use only at two locations, and placed severe restrictions on the
programs to be executed by the shader hardware. The specification, and its
limitations, were designed carefully to ensure that it could be implemented
in the major GPU architectures of the day without requiring too much of an
overhaul [CITE], which meant that the programmability exposed in the spec
was the common subset of what all major manufacturers felt they could
support. This was a sound approach; without these compromises, the spec was
unlikely to be implemented. However, it also meant that there was little
incentive to reduce differences between hardware platforms.

Like most computing hardware, GPUs continued to improve at a blistering
pace; DirectX (and, typically a hardware generation later, OpenGL) kept up
by reducing the restrictiveness of the programming model. Yet the shaders
were still part of the fixed-function


... oh, i blather on. skipping to more concrete section ...


tk: Catchy title
----------------





