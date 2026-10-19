# Requirements for version X.Y.Z

- **Status:** draft | accepted | frozen (after release)
- **Date:** YYYY-MM-DD

<!--
How to use this template
- Copy it to docs/requirements/X.Y.md. Keep it to about two pages.
- One requirement is one testable sentence with an ID. If you cannot imagine a test for it, rewrite it.
- The "Out of scope" section is the most useful part. Fill it in honestly.
- The document is living until the release. After the release it is frozen; the next version gets a new file.
-->

## 1. Goal of this release

One sentence.

## 2. Requirements

| ID | Requirement | Verified by |
|----|-------------|-------------|
| R-01 | The program does ... | test name or "manual check" |

## 3. Out of scope

- Things this release will deliberately not do.

## 4. Non-functional requirements

- **Platforms and toolchains:**
- **Correctness criterion:** how we decide a result is correct (reference tool, tolerance).
- **Performance:** what we measure. We report numbers; we do not promise them.

## 5. Open questions

- Question, owner, and the issue that tracks it.

## 6. Definition of done for this release

- [ ] All requirements verified, or explicitly moved to the next version.
- [ ] Architecture document and ADRs are up to date.
- [ ] CHANGELOG updated.
- [ ] Release tagged.
