# shellcheck shell=bash
# Local help pages are separate from parsing and GitHub initialization.

# Select and print local help, without configuration or network access.
# Arguments/state: $1: optional command/topic; $2: optional subcommand.
# A leading help is accepted; trailing resource arguments are ignored so
# `issue view 42 --help` selects issue-view. Reads the entrypoint's ROOT.
# Result: Writes plain text; unknown topics exit 2. Work scales with page size.
help_text() {
    [[ ${1:-} != help ]] || shift
    local topic=${1:-root} action=${2:-} page
    [[ $topic =~ ^[a-z]+$ && $action =~ ^[a-z-]*$ ]] ||
        fail 'Unknown help topic. Run scripts/github-issues.sh --help.'
    page=$topic
    case $topic in
    issue | milestone | label | report)
        [[ ! $action ]] || page+="-$action"
        ;;
    *)
        [[ ! $action ]] || fail "Unexpected help subcommand: $action"
        ;;
    esac
    [[ -f $ROOT/github-issues/help/$page.txt ]] ||
        fail "Unknown help topic: $topic $action. See --help."
    cat -- "$ROOT/github-issues/help/$page.txt"
    help_append_options "$page"
}

# Append only the option groups applicable to a concrete command's page.
# Arguments/state: $1: validated page identifier; reads ROOT.
# Result: Writes shared help fragments; propagates file errors.
# Size exception: a cohesive command-to-fragment dispatch avoids duplicating
# shared option descriptions across command pages.
help_append_options() {
    local fragment='' page=$1
    case $page in
    root | issue | milestone | label | report | filters | output) return ;;
    issue-list | milestone-list | label-list | report-blocked | \
        report-unassigned | report-completed | report-milestones | \
        report-missing-resolutions) fragment=_list ;;
    issue-view | milestone-view) fragment=_view ;;
    issue-tree | status | activity | report-hierarchy | \
        report-workflow-check) ;;
    *) fragment=_write ;;
    esac
    if [[ $fragment ]]; then
        printf '\n'
        cat -- "$ROOT/github-issues/help/$fragment.txt"
    fi
    printf '\n'
    cat -- "$ROOT/github-issues/help/_global.txt"
    printf '\n%s\n' 'Full guide: docs/process/github-issues-cli.md'
}
