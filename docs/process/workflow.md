# How the project is run

This page describes the small process we use. It is deliberately light: one
person, short iterations, everything written down in the repository or in the
issue tracker.

## Where things live

| What | Where |
|---|---|
| Source code and documents | GitHub repository |
| Tasks, bugs, research questions | GitHub Issues |
| Releases | GitHub Releases and Git tags |
| Decisions | `docs/adr/` |
| Research notes | `docs/research/` |
| Requirements | `docs/requirements/` |
| Architecture | `docs/architecture.md` |

## Hierarchy in the tracker

```
Milestone   a time-boxed goal (one to a few weeks)
 └─ Epic    a theme inside a milestone (issue with label "epic")
     └─ Task / Research / Bug    one piece of work, small enough to finish in a day or two
```

- Epics hold tasks as GitHub **sub-issues**. Assign the milestone explicitly when creating each task.
- Create detailed tasks **just in time**: only for the current milestone and the next one.
  Later milestones get an epic and nothing more.
- If a task grows beyond about two days, split it.

## Research work

Follow the [research outputs and reproducibility guide](research.md), recorded
in [ADR-0006](../adr/0006-research-outputs.md). Each research issue has one
focused main question, explicit supporting questions where needed, a time box,
and observable outputs. Its primary note links to any supporting calculations,
inputs, scripts, and reports. Conceptual research does not require code.

Answer every agreed question before declaring the research complete. A time
box is a checkpoint: record findings and reassess or split unfinished work;
it does not automatically satisfy completion criteria. Keep note summaries
concise and store detailed evidence in linked artifacts.

## Labels

| Label | Meaning |
|---|---|
| `task` | Planned unit of work |
| `research` | Time-boxed question that ends with a research note |
| `bug` | Something behaves wrongly |
| `epic` | Parent issue that groups tasks |
| `blocked` | Waiting for something; say what in a comment |
| `area:infra` | Hosting, tracker, scripts |
| `area:docs` | Documents and templates |
| `area:build` | CMake, dependencies, CI |
| `area:parser`, `area:db`, `area:graph`, `area:delay`, `area:engine`, `area:cli` | Code areas, added as they appear |

## Life of an issue

1. **Open** an issue with one of the issue forms (task, research, bug).
2. Work on it. Write tests first where tests make sense.
3. Reference it in commits: `Refs #12` while working, `Closes #12` in the commit that finishes it.
4. **Close** it with a resolution comment (template below). If the commit says `Closes #12`,
   GitHub closes the issue automatically; add the resolution comment too.

## Resolution comment template

Paste this into the closing comment of every issue:

```markdown
## Resolution
**Outcome:** done | won't do | duplicate of #N | superseded by #N
**Summary:** what was done, in one to three sentences.
**Evidence:** commits, links, test names, benchmark results.
**Docs updated:** ADR-NNNN, research note NNN, requirements, CHANGELOG, or "none".
**Follow-ups:** #N, #M, or "none".
```

## Definition of done (every task)

- [ ] The change is committed with a clear message (Conventional Commits style).
- [ ] Tests exist and pass, where the change has behavior.
- [ ] Affected documents are updated (README, ADR, requirements, architecture, CHANGELOG).
- [ ] The issue has a resolution comment and is closed.

## Commit messages

Format: `type(scope): short description in imperative mood`

| Type | Use for |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `test` | Tests, fuzzers, benchmarks |
| `build` | CMake, presets, dependencies |
| `ci` | CI configuration |
| `refactor` | Restructuring without behavior change |
| `perf` | Performance improvement |
| `style` | Formatting only |
| `chore` | Other maintenance, repository structure |

A breaking change is marked with `!` after the type or a `BREAKING CHANGE:` footer.

## Versioning and releases

- Semantic Versioning. Versions `0.y.z` mean initial development: the API may change.
- `1.0.0` means the public API is stable.
- Pre-releases such as `0.1.0-alpha.1` come before `0.1.0`.
- Every release has a tag and a CHANGELOG entry (Keep a Changelog format).

## Repository descriptions

GitHub "About" description (short):

> Static timing analyzer in modern C++20: parallel timing propagation, incremental updates and measurable performance. Pre-alpha.

GitHub topics: `static-timing-analysis`, `timing-analysis`, `eda`, `vlsi`, `cpp20`, `parallel-computing`, `cmake`


