# Design summary

This implementation of the fractal flame library is split into several Haskell
libraries, with a small front-end application for demonstration purposes.
Together, these programs build, run, and retrieve the results of a CUDA kernel.
The actual rendering is done entirely on the CUDA device.

## Host software

This project will produce a platform-independent console application that will
accept one or more flames in the standard `flam3` XML genome format and save a
fractal flame image for each input flame. More elaborate applications, such as
a long-running process with socket communication for use in quasi-real-time
applications such as the `fr0st` fractal flame editor, are expected to be
produced, but these applications fall outside the scope of this document. The
high-level flow of the rendering application is depicted in Figure [FIG].

The host application parses command-line arguments to determine operating mode,
and then loads a `flam3`-compatible XML stream, either through a specified
filename or through standard input. This information is then passed to the
`flam3` library via the `flam3-hs` bindings for parsing and validation. The
resulting flames are returned in a binary format that can be unpacked to a
genome type from `flam3-types`.

A control point near the center of the requested animation range is selected as
the prototype control point. This information, in addition to information about
the device gathered from the CUDA driver and from the running environment, is
passed to the `cuburn` library, where it is used to generate the CUDA kernel
and context for uploading to the device, as well as the functions needed to
pack control points for use by this algorithm.



<!--

Most of the code in this project is contained in

- Host software

 - Load genome

  - Parse arguments

  - Load file or stream

  - Flam3 bindings

 - Render

  - Generate kernel

  - Upload and pack data

  - Launch kernel per control point

  - Collect results

 - Output

  - Fetch data from buffer

  - Compress

  - Write to file

- Device software

 - Initialize

  - Load RNG, buffer addresses, control structure

  - Clear buffers

 - Iterate

  - Load RNG,

 - Filter

 - Deinitialize


- Top-down perspective, minimalist binary:

    - Load flam3 file with genomes

    - Interpolate genome with flam3

- socket application is most illustrative; let's describe that first

- control from file, stdin, tcp, or unix socket; protocol all the same

- make an output pipeline

- flam3-hs provides bindings to the flam3 library for interpolation

- shard is the combinator library

- cuburn

-->
