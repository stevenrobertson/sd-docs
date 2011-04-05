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

- Conclusions presented in causal order, but they are all interrelated, and
  evaluation was (is) challenging

- Possibly restore section about the ability to estimate algorithmic
  requirements, and the preference for flexibility, but it feels like a
  cop-out

GPU architecture
----------------

- NVIDIA GPUs are the typical choice for compute

- AMD GPUs have more than twice theoretical, but (as discussed) it's very
  hard to realize that gain

- GTX 580 is current fastest single GPU solution; if we need it, that's
  what we can use

- NVIDIA's public commitment to compute is stronger than AMD's, for these
  reasons... so it's probably a safer bet

Compute platform
----------------

- OpenCL has more portability; we like open standards

- CUDA has PTX, UVA, a fast and kickass runtime optimizer, less ambiguity,
  more developer tools

- But for CUDA, we have to write a metric buttload of tools

- Realistically, we want jobs, and so it's worth the extra effort. Perhaps
  this isn't the typical choice, but there you go.

Host language
-------------

- Variations -> requires dynamic compilation.

- C, C++, other systems programming languages. Much harder to do e.g.
  dynamic data structures, multithreading. Unpleasant experience.

- Python. Very good bindings to CUDA, expressive language, popular.
  However, rapid prototyping style incompatible with GPU design due to
  extreme failure modes. Would have to write an entire type engine in
  Python. Could not do static checking of all branches.

- Haskell. Exceptionally expressive type system can contain entire PTX type
  system. SSA doesn't feel out of place. Lot of research done in language
  recently. Easy to link to C code (pulls from compiled code).

- Considered other languages. Ruby has pretty good DSL support, and Scala
  has strong EDSL support. Excluded because of a lack of precedent and a
  lack of author knowledge, but doesn't necessarily mean they would be a
  bad fit.

Interface language
------------------

- Dynamic compilation required.

- C-style templates? Oh, heck no. What a nightmare.

- Really, choice comes down to DSL versus EDSL. Explain more...

- Reference PyPTX, Shard somehow

- Final decision: SSA-based EDSL, with stackless recursive notation for
  loops. Easy to port to LLVM if we need to.


