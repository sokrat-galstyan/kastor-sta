# 0005. Use CMake as the initial build system

- **Status:** Accepted
- **Date:** 2026-10-19
- **Related:** [ADR-0003: C++20 baseline](0003-cpp-standard.md),
  [ADR-0004: Target OS](0004-target-os.md),
  [README build baseline](../../README.md#building)

## Context

The immediate goal is to reach the first functional version with minimal time
spent on infrastructure decisions. CMake's widespread use in C++ projects makes
it a practical starting point. Comparing many alternatives or maintaining
several build configurations at once would take time away from implementing
and testing STA functionality.

## Decision

We will use CMake as the initial build system, with CMake 3.28+ as specified in
the README. We will maintain one CMake configuration for the initial version.
Additional build options may be added later when there is a concrete need;
they will supplement CMake rather than replace it.

CMake generates files for native build tools such as GNU Make and Ninja; these
tools can therefore be used through CMake without maintaining an independent
build configuration. The README already names Ninja as the planned initial
build tool. See the [CMake generator documentation](https://cmake.org/cmake/help/latest/manual/cmake-generators.7.html).

## Alternatives considered

- **Other build configuration systems:** Not evaluated in depth. A broad
  comparison is deferred because CMake meets the current direction and the
  priority is a functional STA implementation.
- **Independent Makefiles or other build definitions:** Deferred. Maintaining
  parallel definitions would duplicate work before a concrete need exists.
  Supporting another CMake generator is a separate, smaller decision.

## Consequences

- **Easier:** One build configuration keeps initial setup and maintenance
  focused, and can generate build files for different native build tools.
- **Harder:** Contributors need CMake to configure the project. Any additional
  build options introduced later will need their own validation and maintenance.
- **Revisit when:** A user or development requirement justifies an additional
  generator or independent build configuration. New options will be added
  alongside the existing CMake support.
