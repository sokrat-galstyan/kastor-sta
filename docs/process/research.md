# Research outputs and reproducibility

This guide describes the convention accepted in
[ADR-0006](../adr/0006-research-outputs.md). The ADR records the decision and
alternatives; this guide provides the working instructions.

## Scope an issue

Use one focused main question, with one or more explicit supporting questions
when needed. Number supporting questions in learning order and state the depth
of the answer, assumptions, expected outputs, and exclusions. Each listed
question must be answered before the issue is considered complete. Avoid open
ended goals such as learning an entire input format or tool implementation.

Keep the work small enough for roughly one or two days. A broad learning topic
may span several issues under the research epic. Preserve the intended order
through issue links; a topic does not require an additional epic. Select the
milestone explicitly and name planned public sources in the research form.

Set a time box before starting. When it expires, write down findings and
unanswered questions and reassess the remaining work. Continue with a revised
time box within the issue's one-to-two-day scope, or split the remaining work
into linked issues if it exceeds that scope. Do not mark an
unanswered question complete merely because time ran out. Any change to the
agreed question set must be explicit in the issue; retain links to work moved
elsewhere rather than silently omitting it from the results.

## Outputs and locations

Every research issue produces one primary note. Other outputs are needed only
when they support the question or a resulting project decision.

| Output | When needed | Repository location |
| --- | --- | --- |
| Primary research note | Every research issue | `docs/research/NNN-short-topic.md` |
| Note-only diagrams or supporting derivations | When they clarify an answer | `docs/research/assets/NNN-short-topic/` |
| Circuit inputs, diagrams, hand calculations | Numerical experiments | `experiments/NNN-short-topic/` |
| Calculation and verification scripts | Executable experiments | `experiments/NNN-short-topic/` |
| Reproduction instructions | Every experiment directory | Its `README.md` |
| Selected results and tool reports | Evidence for a finding | The same experiment directory |
| ADR | A project decision with meaningful alternatives | `docs/adr/NNNN-short-decision.md` |
| Requirements or architecture changes | Findings change project commitments | Relevant files under `docs/` |

Use the next unused research-note number; it is independent of the GitHub
issue number. Use the primary note's number and slug for its experiment and
asset directories. Do not renumber published notes. Use lowercase names with
hyphens for directories, Markdown, and data files, except `README.md`;
Python modules use
`snake_case.py`. Keep stable case, node, and pin names across diagrams, inputs,
calculations, and reports.

Start with one flat experiment folder per research issue. Create only files
the investigation needs. The README may contain short inputs, hand calculations,
and results; separate files are useful when those details grow or a script
needs machine-readable data. For several circuits, use descriptive filenames
in the same folder. Add subfolders only when they make a larger experiment
easier to navigate; `cases/` and `results/` directories are not required.

The [sample experiment files](../../experiments/research-output-example/README.md)
show simple input, calculation, script, and result formats in a flat folder.
They are reference material and may be replaced when actual research is added.
Use the research-note template for the note itself.

The note links to its GitHub issue, supporting artifacts, and resulting ADRs or
requirements. Each experiment README links back to the note and issue. Issue
resolution links to the published note and evidence. If multiple notes are
necessary, identify the primary note and explain their relationship; independent
main questions usually warrant separate issues.

## Write the primary note

Use the [research template](../research/template.md). Answer the main question
and every supporting question in your own words, with references to public
sources. Cite source sections or pages when useful and exact tool/source
revisions for implementation claims. Distinguish sourced facts, observations,
assumptions, and proposed project decisions.

Keep the summary concise, aiming for about a page where practical. This is not
a limit on the evidence required to answer the questions. Link long derivations
and experiment details instead of compressing away essential reasoning.

An unresolved agreed question keeps the research incomplete. Record new,
out-of-scope questions separately with follow-up issue links when available.
A bounded investigation can establish that a tool capability is not documented
or was not reproducible in the tested environment: state exactly what was
checked, the limitation, and its effect on the conclusion. Do not turn missing
evidence into a claim that a feature does not exist.

## Preserve a numerical experiment

Each case must specify:

- The circuit topology and stable names, with an accompanying diagram where
  useful. Identify the authoritative input file rather than maintaining
  conflicting copies of the numerical inputs.
- Input quantities and units, initial conditions, constraints, and model
  assumptions. For timing experiments, identify relevant early/late delays,
  clock edges, operating conditions, and omitted effects.
- Hand-derived expected values, including intermediate steps that permit
  checking the calculation. Transcribe reviewed values into a separate expected
  data file when automated comparison is useful.
- The comparison rule: exact equality or justified absolute/relative tolerances
  with units. Rounding for display is separate from numerical comparison.

Keep the calculator's inputs separate from expected answers. The calculator
must not read expected results, and a verification run must not overwrite them
with its own output. When expected values are corrected, update the derivation
and explain why. Independently check formulas or use a different method where
practical; agreement between two copies of the same mistake is weak evidence.

An experiment README records its purpose, supported scope, input schema or file
formats, units, outputs, failure behavior, dependencies and versions, exact
commands, and expected outcome. Commands should run from a stated directory
without undocumented state. Prefer small standard-library Python programs;
record additional dependency versions when needed. Follow the
[coding guidelines](coding_guidelines.md), including Python documentation and
type annotations. Document unsupported cases instead of quietly generalizing.

Research scripts answer the issue's question. They need not be a reusable
framework, production parser, or timing engine. Check representative successful,
failing, and boundary cases where they matter to the claim. A comparison must
report disagreement and exit unsuccessfully. Small checks may be built into a
verification script; a separate testing framework is not required.

## External tools and stored results

For tool experiments, record the source repository and commit or release,
relevant platform and build details, dependencies, commands, all input files,
and settings affecting results. Match models, units, constraints, and operating
conditions before claiming numerical agreement between tools. Keep necessary
conversion steps and document differences that remain.

Commit original notes, diagrams and editable sources, small inputs, scripts,
hand calculations, reviewed expected values, and selected reports supporting
conclusions. Preserve public-source attribution and redistribution terms for
third-party fixtures. For large or non-redistributable inputs, provide a public
source, pinned version or checksum, retrieval instructions, and the resulting
reproducibility limitation instead of copying them into the repository.

Do not commit build trees, installed tools, virtual environments, caches, or
every rerun's output. Direct disposable output to an ignored location or a
temporary directory. Record a concise results summary in the experiment README
or a separate file when its size warrants one. Include the command,
environment, input/source revision, comparison outcome, and discrepancies.
If selected raw reports are evidence, retain them with their provenance; mark
them as observed output, not independently derived expected results.

Research artifacts are not automatically production regression tests. Promotion
requires an explicit implementation task to review the model, provenance,
expected values, supported behavior, and integration with the test suite. Keep
the link back to the original research.

## Completion and corrections

Before declaring the research done:

1. Map every agreed question to its answer and supporting evidence.
2. Reproduce applicable calculations or experiments and explain discrepancies.
3. Record assumptions, limitations, and separately scoped open questions.
4. Update ADRs, requirements, or architecture when a decision follows, or
   explicitly state that there is no immediate project change.
5. Publish the note and relevant artifacts with issue-referencing commits.
6. Add the resolution comment and close the issue under the
   [project workflow](workflow.md).

The note's `done` status means its findings and evidence are ready; issue closure
also requires the workflow's publication and resolution steps. If a published
finding is corrected, add a dated correction to the note, update affected
evidence and conclusions, and identify affected follow-up work. Accepted ADRs
are superseded rather than silently rewritten.
