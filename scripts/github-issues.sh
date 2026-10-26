#!/usr/bin/env bash
# Entry point for interactive and command-line GitHub issue management.
# Loads the adjacent modules and dispatches CLI arguments to main().
# With no command, opens the terminal menu; --help is local and offline.
# Reads and writes use gh; writes require confirmation or explicit --yes.
# Setup, dependencies and usage: docs/process/github-issues-cli.md.
set -euo pipefail
shopt -s inherit_errexit
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/github-issues/core.sh
source "$ROOT/github-issues/core.sh"
# shellcheck source=scripts/github-issues/help.sh
source "$ROOT/github-issues/help.sh"
# shellcheck source=scripts/github-issues/read.sh
source "$ROOT/github-issues/read.sh"
# shellcheck source=scripts/github-issues/write.sh
source "$ROOT/github-issues/write.sh"
# shellcheck source=scripts/github-issues/ui.sh
source "$ROOT/github-issues/ui.sh"
main "$@"
