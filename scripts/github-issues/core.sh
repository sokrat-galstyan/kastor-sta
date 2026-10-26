# shellcheck shell=bash
# shellcheck disable=SC2153
# Shared parsing, transport and safety. Sourced by github-issues.sh.
# Session infrastructure. Functions share parsed options O and resource context
# REPO/BASE/CONFIG; initialization owns TMP and its cleanup lifetime.
# Text helpers scale with argument size. Transport costs include API latency;
# collection() materializes all pages in memory. No write is retried.

# Write diagnostic text to stderr.
# Arguments/state: $@: message fragments joined with spaces.
# Result: No stdout; returns the printf status.
say() {
    printf '%s\n' "$*" >&2
}

# Report invalid input and terminate the current process.
# Arguments/state: $@: diagnostic fragments.
# Result: No stdout; exits with status 2.
fail() {
    say "Error: $*"
    exit 2
}

# Validate a positive decimal resource number.
# Arguments/state: $1: candidate string, with no leading zero.
# Result: No stdout; returns zero or exits 2.
positive() {
    [[ $1 =~ ^[1-9][0-9]*$ ]] || fail \
        "Expected a positive issue/milestone number: $1"
}

# Reject empty or placeholder-only required input.
# Arguments/state: $1: field label; $2: field text.
# Result: No stdout; returns zero or exits 2.
nonempty() {
    [[ ${2//[[:space:]]/} && ! $2 =~ \
        ^(TODO|TBD|N/A|\[Task\]|\[Bug\]|\[Research\])$ ]] || fail \
            "$1 must contain meaningful text."
}

# Require an option value in the parsed option map.
# Arguments/state: $1: option key; reads O.
# Result: No stdout; returns zero or exits 2.
need() {
    [[ -n ${O[$1]:-} ]] || fail "Missing --$1; see --help."
}

# Encode one value for use in a REST URL.
# Arguments/state: $1: arbitrary text.
# Result: Writes its URI encoding; propagates jq failures.
uri() {
    jq -rn --arg v "$1" '$v|@uri'
}

# Validate a real calendar date with GNU date.
# Arguments/state: $1: YYYY-MM-DD string, interpreted in UTC.
# Result: No stdout; returns zero or exits 2.
date_value() {
    if [[ ! $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || [[ $(date -u -d "$1" \
        +%F 2>/dev/null) != "$1" ]]; then
        fail "Invalid date: $1 (expected YYYY-MM-DD)."
    fi
}

# Parse command arguments into session state.
# Arguments/state: $@: CLI arguments; initializes O, LABELS, REMOVE_LABELS,
# FIELDS, POS.
# Result: No stdout except help; invalid arguments exit 2.
# Size exception: keep this cohesive command/format dispatch together so
# supported cases and their handling remain reviewable.
parse() {
    declare -gA O=()
    declare -ga LABELS=() REMOVE_LABELS=() FIELDS=() POS=()
    local key
    while (($#)); do
        case $1 in
        --help | -h)
            help_text "${POS[@]}"
            exit 0

            ;;
        --yes | --dry-run | --all | --force | --no-color | --comments | \
            --resolution | --checklist | --relationships | --blocked | \
            --no-milestone | --no-assignee | --overdue | --no-due | \
            --incomplete | --complete | --move)
            O[${1#--}]=1
            shift

            ;;
        --repo | --config | --format | --limit | --output | --state | \
            --milestone | --category | --area | --assignee | --author | \
            --parent | --search | --created-after | --updated-after | \
            --reason | --sort | --direction | --depth | --due-before | \
            --due-after | --since | --last | --title | --body-file | \
            --toggle | --outcome | --summary | --evidence | --docs | \
            --followups | --target | --exception | --description | --due | \
            --name | --color | --confirm-name)
            key=${1#--}
            (($# >= 2)) || fail "Missing value for $1"
            [[ ! ${O[$key]+set} ]] || fail "Repeated --$key"
            O[$key]=$2
            shift 2

            ;;
        --label | --remove-label | --field | --field-file)
            (($# >= 2)) || fail "Missing value for $1"
            case $1 in
            --label)
                LABELS+=("$2")
                ;;
            --remove-label)
                REMOVE_LABELS+=("$2")
                ;;
            --field)
                FIELDS+=("$2")
                ;;
            --field-file)
                [[ $2 == *=* && -r ${2#*=} ]] || fail \
                    "Expected ID=readable-file"
                FIELDS+=("${2%%=*}=$(cat -- "${2#*=}")")

                ;;
            esac
            shift 2

            ;;
        --*)
            fail "Unknown option $1"
            ;;
        *)
            POS+=("$1")
            shift

            ;;
        esac
    done
}
# Reject recognized options when they would otherwise be silently ignored.

# Reject options unsupported by the selected command.
# Arguments/state: No arguments; reads CMD, ACTION, NUMBER and parsed options.
# Result: No stdout; invalid or contradictory combinations exit 2.
# Size exception: keep this cohesive command/format dispatch together so
# supported cases and their handling remain reviewable.
validate_options() {
    local allowed=' repo config format limit all output force no-color ' k
    local modifying=0
    case "$CMD $ACTION" in
    'issue list' | 'issue tree' | 'status ' | 'report '* | \
        'activity ')
        allowed+=' state milestone category area assignee author '
        allowed+='parent search created-after updated-after reason '
        allowed+='sort direction blocked no-milestone no-assignee '
        ;;
    'issue view')
        allowed+=' comments resolution checklist relationships '
        ;;
    'issue create')
        allowed+=' category title milestone parent area assignee '
        allowed+='yes dry-run '
        ;;
    'issue edit')
        allowed+=' title body-file toggle milestone assignee yes '
        allowed+='dry-run '
        ;;
    'issue close')
        allowed+=' outcome summary evidence docs followups target '
        allowed+='exception yes dry-run '
        ;;
    'issue reopen')
        allowed+=' yes dry-run '
        ;;
    'issue comment')
        allowed+=' body-file yes dry-run '
        ;;
    'issue link' | 'issue unlink')
        allowed+=' parent move yes dry-run '
        ;;
    'issue block' | 'issue unblock')
        allowed+=' summary target yes dry-run '
        ;;
    'issue depend' | 'issue undepend')
        allowed+=' target yes dry-run '
        ;;
    'milestone list')
        allowed+=' state search due-before due-after overdue '
        allowed+='no-due incomplete complete sort direction '
        ;;
    'milestone view' | 'label list') ;;
    'milestone create' | \
        'milestone edit')
        allowed+=' title description due yes dry-run '
        ;;
    'milestone close' | \
        'milestone reopen')
        allowed+=' exception yes dry-run '
        ;;
    'label create' | \
        'label edit')
        allowed+=' name color description yes dry-run '
        ;;
    'label delete')
        allowed+=' confirm-name yes dry-run '
        ;;
    *)
        fail "Unknown command: $CMD $ACTION"
        ;;
    esac
    case "$CMD $ACTION" in
    'issue create' | 'issue edit' | 'issue close' | 'issue reopen' | \
        'issue comment' | 'issue link' | 'issue unlink' | 'issue block' | \
        'issue unblock' | 'issue depend' | 'issue undepend' | \
        'milestone create' | 'milestone edit' | 'milestone close' | \
        'milestone reopen' | 'label create' | 'label edit' | \
        'label delete')
        modifying=1
        ;;
    esac
    if [[ $modifying == 1 ]]; then
        for k in format limit all; do
            [[ ! ${O[$k]+set} ]] || fail \
                "--$k applies to read commands, not modifications."
        done
    fi
    if [[ $CMD == status ]]; then
        [[ ! ${O[limit]:-} ]] || fail \
            'Status aggregates the complete scope; --limit is' \
            'unsupported.'
        [[ ! ${O[state]:-} || ${O[state]} == all ]] || fail \
            'Status includes open and closed issues; omit' \
            '--state or use all.'
    fi
    if [[ $CMD == report ]]; then
        case $ACTION in
        blocked | unassigned)
            [[ ! ${O[state]:-} || ${O[state]} == open ]] || fail \
                'This report requires open state.'
            ;;
        completed | missing-resolutions)
            [[ ! ${O[state]:-} ||
                ${O[state]} == closed ]] || fail \
                'This report requires closed state.'
            ;;
        hierarchy | workflow-check)
            [[ ! ${O[state]:-} || ${O[state]} == all ]] || fail \
                'Audits require all states.'
            ;;
        esac
    fi
    [[ "$CMD $ACTION" != 'issue tree' ]] || allowed+=' depth '
    [[ $CMD != activity && "$CMD $ACTION" != 'report completed' ]] ||
        allowed+=' since last '
    [[ "$CMD $ACTION" != 'report milestones' ]] || allowed+=' incomplete '
    for k in "${!O[@]}"; do
        [[ $allowed == *" $k "* ]] || fail \
            "--$k is unsupported for $CMD $ACTION"
    done
    case "$CMD $ACTION" in
    'issue list' | 'issue tree' | 'issue create' | 'milestone list' | \
        'milestone create' | 'label list' | 'label create' | \
        'report '*)
        [[ ! $NUMBER ]] || fail 'Unexpected positional argument'
        ;;
    'status ' | 'activity ') ;;
    *)
        [[ $NUMBER ]] || fail "Missing resource number/name for $CMD $ACTION"
        ;;
    esac
    if ((${#FIELDS[@]})); then
        [[ "$CMD $ACTION" == 'issue create' ||
            "$CMD $ACTION" == 'issue edit' ]] || fail \
            '--field only supports issue create/edit'
    fi
    if ((${#REMOVE_LABELS[@]})); then
        [[ "$CMD $ACTION" == 'issue edit' ]] || fail \
            '--remove-label only supports issue edit'
    fi
    if ((${#LABELS[@]})); then
        [[ "$CMD $ACTION" == 'issue list' ||
            "$CMD $ACTION" == 'issue tree' || "$CMD $ACTION" == \
                'issue create' || "$CMD $ACTION" == 'issue edit' || \
                $CMD == report || $CMD == status || $CMD == activity ]] \
                || fail '--label unsupported here'
    fi
}

# Translate a captured gh error into a safe diagnostic.
# Arguments/state: $1: error text; never prints the raw payload.
# Result: Writes stderr only; the transport owns the failure status.
api_error() {
    local message=$1
    case $message in
    *401* | *'auth login'*)
        say 'Authentication required: run gh auth login.'
        ;;
    *429* | *'rate limit'*)
        say \
            'GitHub rate limit reached. Wait for reset before retrying.'
        ;;
    *403*)
        say \
            'Forbidden: check Issues permissions, organization' \
            'policy, or secondary rate limits.'
        ;;
    *404*)
        say \
            'Resource missing or inaccessible (404); check' \
            'repository and access.'
        ;;
    *409*)
        say 'Conflict (409): refresh the resource before retrying.'
        ;;
    *422*)
        say \
            'GitHub rejected the input (422): check resource' \
            'values and relationships.'
        ;;
    *)
        say \
            'GitHub request failed: network, service, or' \
            'unsupported endpoint. No automatic write retries.'
        ;;
    esac
}

# Fetch one REST resource using an explicit GET.
# Arguments/state: $1: endpoint; remaining arguments: trusted gh read flags.
# Result: Writes response data; returns 3 on request failure. Reads TMP.
read_api() {
    local path=$1
    shift
    if ! gh api --hostname github.com -H \
        'Accept: application/vnd.github+json' -H \
        'X-GitHub-Api-Version: 2026-03-10' --method GET "$path" \
        "$@" 2>"$TMP/api-error"; then
        api_error "$(cat "$TMP/api-error")"
        return 3
    fi
}

# Combine every page of a REST array collection.
# Arguments/state: $1: collection endpoint; requires initialized transport.
# Result: Writes one JSON array; propagates transport/schema errors.
collection() {
    local raw
    raw=$(read_api "$1" --paginate) || return
    jq -es \
        '
        if length>0 and all(.[] ; type=="array") then add else
            error("Expected paginated JSON arrays") end
    ' <<<"$raw"
}

# Perform one approved modifying REST request without retries.
# Arguments/state: $1: HTTP method; $2: endpoint; $3: JSON payload (default
# {}).
# Result: Writes response JSON; returns 4 on ambiguous failure. Requires
# APPROVED.
write_api() {
    local method=$1 path=$2 payload=${3:-'{}'} result
    [[ ${APPROVED:-0} == 1 ]] || fail \
        'Internal safety gate: write was not approved.'
    if [[ ${O["dry-run"]:-0} == 1 ]]; then
        say "DRY RUN: $method $path"
        printf '{}\n'
        return
    fi
    if ! result=$(printf '%s' "$payload" | gh api --hostname github.com -H \
        'Accept: application/vnd.github+json' -H \
        'X-GitHub-Api-Version: 2026-03-10' --method "$method" "$path" \
        --input - 2>"$TMP/api-error"); then
        api_error "$(cat "$TMP/api-error")"
        say \
            "Write may have reached GitHub: $method $path." \
            "Inspect the resource before retrying. Earlier" \
            "successful stages are not rolled back."
        return 4
    fi
    [[ $result ]] || result='{}'
    printf '%s\n' "$result"
}

# Preview a mutation and enforce the affirmative write gate.
# Arguments/state: $1: description; optional $2: JSON preview. Reads O and
# REPO.
# Result: Sets APPROVED=1 for --yes or dry-run; otherwise exits 2.
approve() {
    say "Repository: $REPO"
    say "$1"
    [[ -z ${2:-} ]] || jq . <<<"$2" >&2
    if [[ ${O["dry-run"]:-0} == 1 || ${O[yes]:-0} == 1 ]]; then
        APPROVED=1
        return
    fi
    fail 'Write requires --yes (or --dry-run); no changes made.'
}

# Read and validate an issue, excluding pull requests.
# Arguments/state: $1: positive repository-local issue number; reads BASE.
# Result: Writes the issue JSON; propagates errors or exits 2 on bad schema.
get_issue() {
    positive "$1"
    local data
    data=$(read_api "$BASE/issues/$1") || return
    jq -e --argjson n "$1" \
        '.number==$n and (.id|type=="number") and (.title|type=="string")' \
        <<<"$data" >/dev/null ||
        fail 'Malformed issue response; no write is safe.'
    jq -e 'has("pull_request")|not' <<<"$data" >/dev/null || fail \
        "#$1 is a pull request, not an issue."
    printf '%s\n' "$data"
}

# Release temporary files owned by this session.
# Arguments/state: No arguments; reads TMP and optional OUTPUT_STAGE.
# Result: No stdout; installed as the EXIT handler.
cleanup() {
    rm -rf -- "$TMP"
    if [[ ${OUTPUT_STAGE:-} ]]; then
        rm -f -- "$OUTPUT_STAGE"
    fi
}

# Report interruption without claiming rollback.
# Arguments/state: $1: signal exit status; $2: human-readable signal
# description.
# Result: Writes stderr and exits with the supplied status.
interrupt_session() {
    say "$2; inspect any previously reported writes before retrying."
    exit "$1"
}

# Initialize dependencies, repository identity and session options.
# Arguments/state: No arguments; reads O/POS and sets TMP, REPO, BASE, CONFIG,
# FORMAT, LIMIT.
# Result: Installs cleanup handlers; propagates preflight failures.
# Size exception: preserve the ordered validation and execution stages of this
# operation instead of splitting solely for line count.
init() {
    local dep remote
    for dep in gh jq git mktemp date; do
        command -v "$dep" >/dev/null ||
            fail "Missing dependency: $dep"
    done
    umask 077
    TMP=$(mktemp -d)
    trap 'cleanup' EXIT
    trap 'interrupt_session 130 Cancelled' INT
    trap 'interrupt_session 143 Terminated' TERM
    REPO=${O[repo]:-}
    if [[ -z $REPO ]]; then
        remote=$(git remote get-url origin 2>/dev/null) || remote=''
        case $remote in
        git@github.com:*)
            REPO=${remote#git@github.com:}
            ;;
        https://github.com/*)
            REPO=${remote#https://github.com/}
            ;;
        *)
            if ((${#POS[@]} == 0)); then
                prompt \
                    'Repository OWNER/REPO (required; origin unavailable)' ||
                    exit 130
                REPO=$ANSWER
            else
                fail 'Origin is not github.com; use --repo OWNER/REPO.'
            fi
            ;;
        esac
        REPO=${REPO%.git}
    fi
    [[ $REPO =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ && $REPO != *..* ]] ||
        fail 'Repository must be OWNER/REPO on github.com.'
    BASE="repos/$REPO"
    CONFIG=${O[config]:-}
    if [[ -z $CONFIG && ${REPO,,} == sokrat-galstyan/kastor-sta ]]; then
        CONFIG="$ROOT/github-issues/kastor.json"
    fi
    if [[ -n $CONFIG ]]; then
        jq -e \
            '.schema == 1 and (.forms|type == "object")' \
            "$CONFIG" >/dev/null || fail 'Invalid adapter configuration.'
    fi
    FORMAT=${O[format]:-table}
    LIMIT=${O[limit]:-100}
    case $FORMAT in
    titles | compact | table | details | json | csv | \
        markdown | tree) ;; *)
        fail "Invalid format: $FORMAT"
        ;;
    esac
    positive "$LIMIT"
    [[ ! ${O[all]:-} || ! ${O[limit]:-} ]] || fail \
        'Choose --all or --limit, not both.'
    [[ ! ${O[milestone]:-} || ! ${O["no-milestone"]:-} ]] || fail \
        'Contradictory milestone filters.'
    [[ ! ${O[assignee]:-} || ! ${O["no-assignee"]:-} ]] || fail \
        'Contradictory assignee filters.'
    [[ ! ${O[since]:-} || ! ${O[last]:-} ]] || fail 'Choose --since or --last.'
    local k
    for k in created-after updated-after due-before due-after \
        since; do
        [[ ! ${O[$k]:-} ]] || date_value "${O[$k]}"
    done
    [[ ! ${O[state]:-} || ${O[state]} =~ ^(open|closed|all)$ ]] || fail \
        'State must be open, closed or all.'
    [[ ! ${O[direction]:-} || ${O[direction]} =~ ^(asc|desc)$ ]] || fail \
        'Direction must be asc or desc.'
    [[ ! ${O[reason]:-} || ${O[reason]} =~ \
        ^(completed|not_planned|duplicate)$ ]] || fail \
            'Unsupported closing reason.'
    [[ ! ${O[depth]:-} ]] || positive "${O[depth]}"
    [[ ! ${O[parent]:-} || ${O[parent]} == none ]] || positive "${O[parent]}"
    if [[ ${O[output]:-} ]]; then
        [[ -d $(dirname -- "${O[output]}") && -w $(dirname -- \
            "${O[output]}") ]] || fail 'Output directory is not writable.'
        [[ ! -e ${O[output]} && ! -L ${O[output]} || ${O[force]:-0} == \
            1 ]] || fail 'Output exists; use --force.'
        [[ ! -d ${O[output]} ]] || fail 'Output path is a directory.'
    fi
    local identity
    identity=$(read_api "$BASE") || return
    jq -e --arg repo "$REPO" \
        '(.full_name|ascii_downcase)==($repo|ascii_downcase)' \
            <<<"$identity" >/dev/null || fail \
                'Repository identity differs (possibly renamed);' \
        'explicitly select the canonical repository.'
}

# Deliver buffered output to stdout or a protected export file.
# Arguments/state: Input: completed output on stdin; reads O[output] and
# O[force].
# Result: Never overwrites without force; reports file errors and tracks
# cleanup.
emit() {
    if [[ ${O[output]:-} ]]; then
        local dest=${O[output]} stage
        stage=$(mktemp "$(dirname -- "$dest")/.github-issues.XXXXXX")
        OUTPUT_STAGE=$stage
        if ! cat >"$stage"; then
            rm -f -- "$stage"
            return 3
        fi
        if [[ ${O[force]:-0} == 1 ]]; then mv -f -- "$stage" "$dest"; else
            if ! ln -- "$stage" "$dest"; then
                rm -f -- "$stage"
                fail 'Output appeared concurrently; not overwritten.'
            fi
            rm -f -- "$stage"
        fi
        say "Exported $dest"
    else
        cat
    fi
}

# Run a command or start the interactive session.
# Arguments/state: $@: CLI arguments; initializes session state before
# dispatch.
# Result: Buffers output until success; propagates command failure status.
main() {
    parse "$@"
    if [[ ${POS[0]:-} == help ]]; then
        help_text "${POS[@]}"
        return
    fi
    if ((${#POS[@]} == 0)); then
        init
        interactive
        return
    fi
    CMD=${POS[0]}
    ACTION=${POS[1]:-}
    NUMBER=${POS[2]:-}
    if [[ $CMD == status || $CMD == activity ]]; then
        [[ ${#POS[@]} == 1 ]] || fail 'Unexpected positional argument'
        ACTION=''
    else
        [[ ${#POS[@]} -le 3 ]] || fail 'Unexpected positional argument'
    fi
    validate_options
    init
    dispatch >"$TMP/result"
    emit <"$TMP/result"
}

# Route an initialized command to its resource handler.
# Arguments/state: No arguments; reads CMD, ACTION and NUMBER.
# Result: Preserves handler stdout and exit status.
# Size exception: keep this cohesive command/format dispatch together so
# supported cases and their handling remain reviewable.
dispatch() {
    case "$CMD $ACTION" in
    'issue list')
        issue_list
        ;;
    'issue view')
        issue_view
        ;;
    'issue tree')
        issue_tree

        ;;
    'milestone list')
        milestone_list
        ;;
    'milestone view')
        positive "$NUMBER"
        read_api "$BASE/milestones/$NUMBER" | jq '[.]' | render milestone

        ;;
    'label list')
        collection "$BASE/labels?per_page=100" | render label
        ;;
    'status ')
        status_report
        ;;
    'activity ')
        activity_report
        ;;
    'report '*)
        diagnostic

        ;;
    'issue '*)
        issue_write
        ;;
    'milestone '*)
        milestone_write
        ;;
    'label '*)
        label_write

        ;;
    esac
}
