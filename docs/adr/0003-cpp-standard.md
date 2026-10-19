# 0003. Use C++20 as the language baseline

- **Status:** Accepted
- **Date:** 2026-10-19
- **Related:** [README toolchain baseline](../../README.md#building)

## Context

Kastor STA needs a consistent language baseline for implementation, builds, and
future tests. We want to use modern C++ while keeping the initial compiler
requirements explicit. The README identifies GCC 13+ and Clang 18+ on Linux as
the planned toolchains.

## Decision

We will use C++20 as the project's language baseline and initially target GCC
13+ and Clang 18+ on Linux. Features used by the project must work with both
supported compiler families. Build and test coverage will be introduced with
the walking skeleton.

## Alternatives considered

- **C++23:** Considered as the newer language version. We have not identified a
  project requirement that justifies adopting it for the initial baseline.
  C++20 is the conservative starting point; any future change will be based on
  concrete feature needs and support in the project's toolchains.

## Consequences

- **Easier:** One language baseline guides implementation and build configuration
  across both compiler families.
- **Harder:** Features requiring a newer standard need an alternative
  implementation or a future baseline change. Compiler and standard library
  support must be verified for the C++20 features we use.
- **Revisit when:** A concrete project requirement justifies a newer standard and
  the supported toolchains provide the necessary features. Otherwise, C++20
  remains the baseline.
