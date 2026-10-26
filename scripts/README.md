# Development scripts

This directory is intended for automation and helper scripts used during
project development and maintenance. These tools are not part of the core
project functionality.

## Organization

- Top-level scripts are executable entry points for development tasks.
- A tool-specific subdirectory holds its internal modules, configuration,
  queries, and other runtime resources. Keep these alongside the entry point.
- Each script and source module documents its purpose in its file header.
  Detailed usage belongs in `docs/`, rather than this directory overview.

## Current contents

| Path | Purpose |
| --- | --- |
| `github-issues.sh` | Interactive and command-line GitHub issue management. |
| `github-issues/` | Internal modules and runtime resources for that tool. |

Within `github-issues/`, Bash modules handle parsing, reads, writes, help, and
terminal interaction. The `queries/` directory contains jq transformations,
`help/` contains local help text, and `kastor.json` defines the workflow
adapter.
`resolution.jq` recognizes structured resolution comments.

For setup, behavior, and usage, see the
[GitHub Issue Manager guide](../docs/process/github-issues-cli.md).
