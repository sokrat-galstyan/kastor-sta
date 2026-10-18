# Kastor STA

A static timing analyzer (STA) written from scratch in modern C++20.
It is built around three goals: **parallel timing propagation**, **incremental timing updates**, and **performance you can measure**.

> **Status: pre-alpha (planning and research).** There is no usable code yet.
> This README describes where the project is going, not what exists today.

## What it will do

Read a gate-level netlist, a cell library and timing constraints, then compute
arrival times, required times and slack, and report the critical paths.

Planned inputs (small, documented subsets only):

- Gate-level Verilog
- Liberty (`.lib`) cell libraries
- SDC constraints
- SPEF parasitics (later, for RC wire delay)

The exact subsets for the first release will be chosen during the research
cycle and written down in `docs/requirements/0.1.md`.

## Goals

- A clean, layered design: parsers, design database, timing graph, delay models,
  propagation engine, front ends.
- Serial and parallel propagation behind one interface, so they can be
  benchmarked against each other.
- Incremental timing: after a change (for example resizing a cell), recompute
  only the affected part of the graph.
- Correctness checked against independent tools (differential tests), not only
  against our own expectations.

## Non-goals

- Sign-off quality accuracy or replacing commercial timers.
- Complete Verilog, Liberty or SDC support.
- Anything beyond timing analysis (no placement, no routing).

## Roadmap

The project is developed in small steps. Research and documents come first,
then a thin working skeleton, then the first release.

| Stage | Result |
|---|---|
| 0. Repository setup | Empty remotes, license, README, issue tracker, templates, first ADRs |
| 1. Research cycle | STA basics understood; hand-computed reference results; research notes; every important decision written down as a short Architecture Decision Record
  (ADR) |
| 2. Requirements and architecture | `docs/requirements/0.1.md` and a first `docs/architecture.md` |
| 3. Walking skeleton | Build system, dependencies, first test, local check script, CI |
| 4. Version 0.1.0 | Smallest complete path: read a tiny netlist and library, compute serial slack, print a report |
| 5. Later versions | Parallel propagation, incremental timing, Elmore RC delay, statistical timing (order may change after research) |
| 6. Version 1.0.0 | Stable API, Python bindings, documentation |

Progress is tracked in the issue tracker milestones (see below).

## How the project is run

- **Issues and milestones:** GitHub Issues. Tasks, research questions and bugs
  each have an issue form. Work is grouped as milestone, epic, task.
- **Documents:** short Markdown files in the repository.

  | Document | Location |
  |---|---|
  | Decisions (ADRs) | `docs/adr/` |
  | Research notes | `docs/research/` |
  | Requirements per version | `docs/requirements/` |
  | Architecture | `docs/architecture.md` (planned) |
  | Process, labels, resolution template | `docs/process/workflow.md` |

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) style
  (`feat:`, `fix:`, `docs:`, `build:`, `ci:`, `test:`, ...).
- **Versions:** [Semantic Versioning](https://semver.org/). Versions `0.y.z` are
  initial development and the API may change. Pre-releases look like `0.1.0-alpha.1`.
- **Testing:** tests come first where the behavior is known (parsers, database,
  graph algorithms, parallel result equals serial result). Numerical results
  are checked against hand-computed examples and against reference tools.
- **Continuous integration:** will start together with the first test (stage 3).
  Until then, the same checks are run locally.

## Building

Not available yet. The planned baseline is a C++20 compiler (GCC 13+ or
Clang 18+), CMake 3.28+ and Ninja, on Linux.

## References

Kastor STA is developed from public sources only: papers, textbooks and the
documentation of open-source tools. We compare results against
[OpenTimer](https://github.com/OpenTimer/OpenTimer) and
[OpenSTA](https://github.com/The-OpenROAD-Project/OpenSTA), and plan to use the
public TAU timing analysis contest benchmarks.

## License

Copyright (C) 2026 Sokrat Galstyan

Kastor STA is free software: you can redistribute it and/or modify it under the
terms of the GNU Lesser General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

It is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
details.

The full texts are in [`COPYING.LESSER`](COPYING.LESSER) (LGPL-3.0) and
[`COPYING`](COPYING) (GPL-3.0, which the LGPL refers to).
SPDX identifier: `LGPL-3.0-or-later`.

## Project hosting

- **GitHub:** source, issues and milestones, continuous integration
  (link: `https://github.com/sokrat-galstyan/kastor-sta`, to be filled in)

Please report problems and ideas on GitHub.
