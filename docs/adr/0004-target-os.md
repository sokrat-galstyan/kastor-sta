# 0004. Target Ubuntu 24.04 for initial development

- **Status:** Accepted
- **Date:** 2026-10-19
- **Related:** [ADR-0003: C++20 baseline](0003-cpp-standard.md),
  [ADR-0002: Development infrastructure](0002-development-infrastructure.md)

## Context

Ubuntu 24.04 is available on the developer's physical machine. The initial
target platform should be one that developers can access directly to reproduce,
investigate, and fix failures reported by CI. Supporting several operating
systems immediately would add setup and maintenance work before the first
functional version exists.

## Decision

We will use Ubuntu 24.04 as the initial target operating system for development
and testing. When CI is introduced, it will use Ubuntu 24.04 so that failures can
be investigated locally on the same OS version. This makes the Linux baseline
in the README more specific.

## Alternatives considered

- **Other OS versions or platforms:** Not selected as initial targets because
  Ubuntu 24.04 is the environment physically available for development. A broad
  platform comparison is unnecessary for the first functional version.
- **Multiple initial targets:** Deferred to avoid maintaining environments that
  developers cannot readily use to diagnose failures.

## Consequences

- **Easier:** Developers have direct access to the target OS when reproducing
  CI failures, reducing environment setup work during debugging.
- **Harder:** Compatibility with other operating systems is not initially
  verified. Matching the OS version alone does not guarantee reproduction;
  compiler versions, dependencies, and build settings must also be recorded.
- **Revisit when:** The project needs another target platform and developers
  have access to an environment in which they can reproduce and fix its bugs,
  or the available development environment changes.
