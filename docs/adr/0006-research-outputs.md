# 0006. Store research notes with reproducible supporting artifacts

- **Status:** Accepted
- **Date:** 2026-10-27
- **Related:** [issue #22](https://github.com/sokrat-galstyan/kastor-sta/issues/22),
  [research workflow](../process/research.md)

## Context

Research produces explanations as well as calculations, circuits, scripts, and
tool reports. A short note alone cannot preserve all evidence needed to review
or reproduce an experiment. Conversely, requiring an experiment for every
conceptual question adds work without improving the answer. The existing
one-question, one-page guidance needs to accommodate supporting questions and
linked evidence without turning research into production implementation.

## Decision

We will give each research issue one primary Markdown note answering a focused
main question and its explicitly listed supporting questions. We will keep
notes in `docs/research/` and executable experiments with their inputs and
reviewed evidence in `experiments/`. Notes and experiment READMEs will link to
each other and to their issue. We will preserve independently derived expected
results separately from calculated outputs, document reproduction commands and
assumptions, and commit only the evidence needed to understand and verify the
findings. A time box triggers review of unfinished work, not automatic
completion. Detailed conventions belong in the research workflow.

## Alternatives considered

- **Everything in one note:** simple to browse, but executable inputs and
  substantial calculations become difficult to reproduce and maintain.
- **Experiments outside the repository:** keeps the repository small, but
  disconnects conclusions from the exact inputs, code, and evidence reviewed.
- **A uniform experiment framework for every issue:** standardizes execution,
  but imposes unnecessary machinery on conceptual research and small examples.

## Consequences

- **Easier:** Findings remain traceable to issues and reproducible evidence.
  Conceptual research stays lightweight; numerical research can retain detail.
- **Harder:** Inputs, expected results, and recorded outputs need separate
  review. Links and reproduction instructions must be maintained.
- **Revisit when:** Larger datasets, shared experiment code, or promotion into
  production regression tests makes these conventions inadequate.
