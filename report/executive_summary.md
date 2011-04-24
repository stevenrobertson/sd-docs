# Executive Summary

This document is provided as a technical manual describing all design considerations for the senior design project Cuburn, discussed herein.

## Description

Cuburn is a completely software based project created for the purpose of creating visually appealing images and image sequences.

## Significance

Many implementations of the flam3 algorithm already exist and have existed for many years.  This project is significant because it is a modest improvement over all of the other implementations currently available at this time.  It is a GPU implementation of the flam3 algorithm, designed to produce images equivalent to the CPU implemented flam3 software, something that other GPU implementations have yet to do.  It should be noted that time moves quickly in the realm of software development and that there are others may be trying to accomplish today what is being described in this document.  However, being that this software is being designed with the bleeding edge of technology in mind and with many optimizations being performed on all levels, it should proove difficult for another project to offer any modest improvement over this design.

## Motivation

The team designing this project likes fractal flames, as do thousands of others.  Fractal flames do not offer much of a practical purpose, they were only created for the mere entertainment only.  It could be possible that they hold the key to unlocking the many mysteries of the universe, but for now, they just look pretty.  Current software for creating these mesmorizing image sequences are relatively slow or of low quality.  There is no hope to use any currently existing software to incorporate fractal flames into real time applications such as music visualization.  It is this condition that drives the motivation for this project.  The authors are set out to create a high quality, high performance, fractal flame renderer that can generate exceptional flames in, or closer to, real time.  This is not a trivial task, hence the reason it has not already been accomplished.  The goal for real time rendering is an optimistic one, but all the stops are being pulled out so that if there is anything in the way of accomplishing this, it will only be the computationial resources limit of current hardware technology.

## Goals and Objectives

The overall goal of this project is to create a piece of software that can render fractal flames of comparable quality to the original flam3 implementation that can do so in a fraction of the time.  To reach this goal, the following objectives have been set:

- Independently implement a working version of the fractal flame algorithm.

- Develop a ruthlessly optimized, composable, typesafe dialect of CUDA.
  Implement portions of a standard library with it.

- Develop a concrete and functionally complete understanding of GPU performance
  (for the particular architecture we select) through targeted
  microbenchmarking and statistical analysis.

- Using knowledge gained through microbenchmarking, rewrite the fractal flame
  algorithm for GPUs using the aforementioned dialect.

- Develop, implement, and test new optimization strategies to improve the speed
  of the renderer.

- Use statistical, graphical, and psychovisual techniques to improve the
  perceived quality per clock ratio.

Optionally:

- Add 3D support.

- Apply resulting renderers in real-world applications, including but not
  limited to:
    - Music visualization
    - Reactivity to environment
    - Real-time interactivity
    - Real-time evolution using genetic algorithms and user feedback
    
## Software Specifications

## User Requirements

Being that this project is a software application developed for use on personal computers, this section will outline what is required to run and use the software.  It should be clear that this project relies very much on a specific hardware device, the GPU.  Therefore, the designers have set strict requirements for this piece of hardware.  Other hardware devices such as the CPU and memory have less strict requirements and are more or less presented as a recommendation.  The required operating systems and software needed to run Cuburn are relatively easy to come by and available freely, but will nonetheless still be required.

- NVIDIA Cuda-enabled GPU supporting Compute Capability 2.1 (See http://www.nvidia.com/object/cuda_gpus.html).

- 2GHz or faster CPU

- 2GB or more RAM

- Linux or Windows operating systems [TODO: Be more detailed]

## Research

## Design