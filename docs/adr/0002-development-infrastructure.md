# 0002. Use GitHub for development infrastructure

- **Status:** Accepted
- **Date:** 2026-10-19
- **Related:** issue #2, issue #4, issue #6,
  [project workflow](../process/workflow.md)

## Context

Kastor STA is a one-person project that needs version control, issue tracking,
releases, and continuous integration. Keeping these services together reduces
administrative work and leaves more time for STA research and implementation.
Development will proceed through research and small iterations, as described in
[the roadmap](../../README.md#roadmap).

## Decision

We will use Git for version control and GitHub for repository hosting, issues,
pull requests, and releases. GitHub Actions will run continuous integration
starting with the first test. Releases will follow Semantic Versioning and use
Git tags and GitHub Releases. The [project workflow](../process/workflow.md)
defines issue management, commit conventions, and the definition of done.

## Alternatives considered

Other hosting platforms and separate tools for each service were not evaluated
in depth. GitHub provides the services required for the initial development
stages, so a broader comparison is deferred until a concrete need arises.

## Consequences

- **Easier:** Code, issues, reviews, releases, and CI results are available in one
  place, with links between related work.
- **Harder:** Issue tracking and CI configuration depend on GitHub-specific
  features; moving platforms would require migration work beyond copying Git
  history.
- **Revisit when:** GitHub no longer meets the project's needs. The first stable
  API release, version 1.0.0, is also a natural point to review the setup.
