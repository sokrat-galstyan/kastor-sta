# shellcheck shell=bash
# shellcheck disable=SC2153
# Read-only commands. All transport goes through explicit GET.
# Read-only handlers use BASE, O, FORMAT and LIMIT from initialized state.
# Collections use O(n) storage; sorting and grouping use O(n log n) work.
# Native graph and timeline views add per-resource requests. Recursive graphs
# can revisit shared paths, so cost depends on both edges and displayed paths.

# Fetch, filter and sort repository issues across all pages.
# Arguments/state: No arguments; reads O, LABELS and BASE.
# Result: Writes an issue array; excludes PRs and propagates API failures.
# Size exception: preserve the ordered validation and execution stages of this
# operation instead of splitting solely for line count.
fetch_issues() {
    local state=${O[state]:-open} path data label labels='' \
        milestone=${O[milestone]:-} x
    for label in "${LABELS[@]}" "${O[category]:-}"; do
        [[ -z $label ]] || labels+="${labels:+,}$label"
    done
    [[ ! ${O[area]:-} ]] || labels+="${labels:+,}area:${O[area]#area:}"
    [[ ! ${O[blocked]:-} ]] || labels+="${labels:+,}blocked"
    path="$BASE/issues?state=$state&per_page=100&sort=created&direction=desc"
    [[ ! $labels ]] || path+="&labels=$(uri "$labels")"
    if [[ $milestone ]]; then
        if [[ ! $milestone =~ ^[1-9][0-9]*$ ]]; then
            x=$(collection "$BASE/milestones?state=all&per_page=100") || return
            milestone=$(jq -r --arg t "$milestone" \
                '.[]|select(.title==$t)|.number' <<<"$x")
            [[ $milestone ]] || fail 'Milestone title not found.'
        fi
        path+="&milestone=$milestone"
    fi
    [[ ! ${O["no-milestone"]:-} ]] || path+='&milestone=none'
    [[ ! ${O[assignee]:-} ]] || path+="&assignee=$(uri "${O[assignee]}")"
    [[ ! ${O["no-assignee"]:-} ]] || path+='&assignee=none'
    [[ ! ${O[author]:-} ]] || path+="&creator=$(uri "${O[author]}")"
    [[ ! ${O["updated-after"]:-} ]] ||
        path+="&since=${O["updated-after"]}T00:00:00Z"
    data=$(collection "$path") || return
    data=$(jq --arg state "$state" --arg labels "$labels" --arg ms \
        "$milestone" \
        --arg assignee "${O[assignee]:-}" --arg author "${O[author]:-}" \
        --arg no_ms "${O["no-milestone"]:-}" \
        --arg no_as "${O["no-assignee"]:-}" \
        --arg search "${O[search]:-}" --arg created "${O["created-after"]:-}" \
        --arg updated "${O["updated-after"]:-}" --arg reason \
        "${O[reason]:-}" -f \
        "$ROOT/github-issues/queries/filter_issues.jq" <<<"$data")
    if [[ ${O[parent]:-} ]]; then
        local edges
        edges=$(relationship_edges) || return
        data=$(jq --arg p "${O[parent]}" --argjson edges "$edges" -f \
            "$ROOT/github-issues/queries/filter_parents.jq" <<<"$data")
    fi
    local sort=${O[sort]:-number}
    case $sort in
    created | updated)
        sort+=_at
        ;;
    number | title | \
        comments) ;; *)
        fail \
            'Issue sort: number, title, created, updated, comments.'
        ;;
    esac
    jq --arg sort "$sort" --arg dir "${O[direction]:-desc}" \
        'sort_by(.[$sort])|if $dir=="desc" then reverse else . end' <<<"$data"
}

# Apply the display limit after collecting all matches.
# Arguments/state: Input: JSON array on stdin; reads LIMIT and O[all].
# Result: Writes the bounded array; reports truncation only on stderr.
limit_data() {
    local data count
    data=$(cat)
    count=$(jq length <<<"$data")
    if [[ ${O[all]:-0} != 1 && $count -gt $LIMIT ]]; then
        say \
            "Showing $LIMIT of $count matches; use --all. All" \
            "API pages were inspected."
        jq --argjson n "$LIMIT" '.[:$n]' <<<"$data"
    else
        printf '%s\n' "$data"
    fi
}

# Render a resource collection in the selected output format.
# Arguments/state: $1: resource kind; input: JSON array on stdin. Reads FORMAT
# and REPO.
# Result: Writes formatted output; unsupported formats exit 2.
# Size exception: keep this cohesive command/format dispatch together so
# supported cases and their handling remain reviewable.
render() {
    local kind=$1 data total
    data=$(cat)
    total=$(jq length <<<"$data")
    data=$(limit_data <<<"$data")
    case $FORMAT in
    json)
        jq --arg kind "$kind" --arg repo "$REPO" --argjson total "$total" \
            '
        {schema_version:1 , repository:$repo , kind:$kind ,
            total_matches:$total , count:length , items:.}
    ' <<<"$data"
        ;;
    titles)
        jq -r \
            '.[]|if .number then "#\(.number) \(.title)" else .name end' \
                <<<"$data"
        ;;
    compact)
        jq -r \
            '
        .[] | ((if .number then ("#" + (.number | tostring)) else .name end |
            tostring) + " [" + (.state//"label" | tostring) + "] " +
            (.title//.description//"" | tostring))
    ' <<<"$data"
        ;;
    csv)
        jq -r -f "$ROOT/github-issues/queries/issue_csv.jq" <<<"$data"
        ;;
    markdown)
        jq -r -f "$ROOT/github-issues/queries/issue_markdown.jq" <<<"$data"
        ;;
    table)
        if [[ $kind == issue ]]; then
            jq -r -f "$ROOT/github-issues/queries/issue_table.jq" <<<"$data" |
                awk -F '\t' \
                    '{printf "%-6s %-8s %-18s %-24s %s\n",$1,$2,$3,$4,$5}'
        elif [[ $kind == label ]]; then
            jq -r \
                '
        (["NAME" , "COLOR" , "DESCRIPTION"] | @tsv) , (.[] | [.name , .color ,
            .description//""] | @tsv)
    ' <<<"$data"
        else
            jq -r -f \
                "$ROOT/github-issues/queries/milestone_table.jq" \
                <<<"$data" | awk -F \
                '\t' '{printf "%-6s %-8s %-6s %-7s %s\n",$1,$2,$3,$4,$5}'
        fi

        ;;
    details)
        jq -r -f "$ROOT/github-issues/queries/issue_details.jq" <<<"$data"
        ;;
    *)
        fail "Format $FORMAT is only supported by issue tree."
        ;;
    esac
}

# Render the current issue search scope.
# Arguments/state: No arguments; uses parsed filters and format.
# Result: Writes the listing and propagates read/render errors.
issue_list() {
    fetch_issues | render issue
}

# Inspect one issue and lazily requested related data.
# Arguments/state: No arguments; reads NUMBER and O detail flags.
# Result: Writes issue details, checklist or JSON; no modifying requests.
# Size exception: preserve the ordered validation and execution stages of this
# operation instead of splitting solely for line count.
issue_view() {
    local issue comments edges children blockers
    issue=$(get_issue "$NUMBER") || return
    if [[ ${O[relationships]:-} ]]; then
        edges=$(relationship_edges) || return
        children=$(collection \
            "$BASE/issues/$NUMBER/sub_issues?per_page=100") || return
        blockers=$(collection \
            "$BASE/issues/$NUMBER/dependencies/blocked_by?per_page=100") ||
            return
        issue=$(jq --argjson e "$edges" --argjson c "$children" --argjson b \
            "$blockers" \
            '
        .number as $n | . + {parents:[$e[] | select(.child==$n) | .parent] ,
            children:$c , blocking_dependencies:$b}
    ' <<<"$issue")
    fi
    if [[ ${O[comments]:-}${O[resolution]:-} ]]; then
        comments=$(collection \
            "$BASE/issues/$NUMBER/comments?per_page=100") || return
        if [[ ${O[resolution]:-} ]]; then
            comments=$(jq -L "$ROOT/github-issues" \
                'include "resolution"; [.[]|select(resolution_valid)]' \
                <<<"$comments")
            [[ $(jq length <<<"$comments") != 0 ]] || say \
                'No complete structured resolution found.'
        fi
        issue=$(jq --argjson c "$comments" '.+{comment_items:$c}' <<<"$issue")
    fi
    if [[ ${O[checklist]:-} ]]; then
        issue=$(jq -f "$ROOT/github-issues/queries/checklist_items.jq" \
            <<<"$issue")
        if [[ $FORMAT != json ]]; then
            jq -r \
                '.checklist|to_entries[]|"\(.key+1). \(.value.text)"' \
                <<<"$issue"
            return
        fi
    fi
    [[ ${O[format]:-} ]] || FORMAT=details
    jq '[.]' <<<"$issue" | render issue
    if [[ ${O[relationships]:-} && $FORMAT == details ]]; then
        jq -r -f "$ROOT/github-issues/queries/render_relationships.jq" \
            <<<"$issue"
    fi
}

# Filter, order and render milestone metadata.
# Arguments/state: No arguments; reads milestone filters in O and FORMAT.
# Result: Writes the listing; rejects contradictory progress filters.
milestone_list() {
    local data sort=${O[sort]:-number}
    case $sort in
    number | title | due_on) ;; created | \
        updated)
        sort+=_at
        ;;
    *)
        fail \
            'Milestone sort: number, title, due_on, created, updated.'
        ;;
    esac
    [[ ! ${O[complete]:-} || ! ${O[incomplete]:-} ]] || fail \
        'Contradictory progress filters.'
    data=$(collection \
        "$BASE/milestones?state=${O[state]:-open}&per_page=100") || return
    jq --arg state "${O[state]:-open}" --arg search "${O[search]:-}" --arg \
        before "${O["due-before"]:-}" --arg after "${O["due-after"]:-}" \
        --arg overdue "${O[overdue]:-}" --arg today "$(date -u +%FT%TZ)" \
        --arg nodue "${O["no-due"]:-}" --arg inc "${O[incomplete]:-}" --arg \
        complete "${O[complete]:-}" --arg sort "$sort" --arg dir \
        "${O[direction]:-asc}" -f \
        "$ROOT/github-issues/queries/filter_milestones.jq" <<<"$data" |
        render milestone
}
# Traverse native children because REST listings do not include bulk edges.
# A failed parent lookup never proves that an issue is standalone.

# Collect native parent-child edges for the repository.
# Arguments/state: No arguments; reads BASE and uses TMP/edges.
# Result: Writes unique edges; rejects inaccessible or cross-repository
# graphs.
relationship_edges() {
    local all n children
    all=$(collection "$BASE/issues?state=all&per_page=100") || return
    printf '' >"$TMP/edges"
    while read -r n; do
        children=$(collection "$BASE/issues/$n/sub_issues?per_page=100") ||
            return
        jq -e --arg repo "https://api.github.com/$BASE" \
            'all(.[]; .repository_url==null or .repository_url==$repo)' \
                <<<"$children" >/dev/null || fail \
                'Cross-repository sub-issues are unsupported;' \
            'refusing to confuse repository-local issue numbers.'
        jq -c --argjson p "$n" \
            '.[]|{parent:$p,child:.number,repository_url:.repository_url}' \
            <<<"$children" >>"$TMP/edges"
    done < <(jq -r \
        '
        .[] | select(has("pull_request") | not) |
            select((.sub_issues_summary.total//1)>0) | .number
    ' <<<"$all")
    jq -s 'unique_by([.parent,.child])' "$TMP/edges"
}

# Render a native graph with cycle and depth guards.
# Arguments/state: No arguments; reads filters, parent selection and depth
# from O.
# Result: Writes text or graph JSON; removes the parent list filter locally.
# Size exception: preserve the ordered validation and execution stages of this
# operation instead of splitting solely for line count.
issue_tree() {
    local issues edges parent=${O[parent]:-}
    unset 'O[parent]'
    issues=$(fetch_issues) || return
    edges=$(relationship_edges) || return
    if [[ $parent && $parent != none ]]; then
        positive "$parent"
        issues=$(jq --argjson parent "$parent" --argjson edges "$edges" -f \
            "$ROOT/github-issues/queries/select_descendants.jq" <<<"$issues")
    elif [[ $parent == none ]]; then
        issues=$(jq --argjson e "$edges" \
            'map(. as $i|select(all($e[];.child!=$i.number)))' <<<"$issues")
    fi
    [[ ! ${O[limit]:-} ]] || fail \
        'Tree uses the full selected graph; use --depth' \
        'instead of --limit.'
    case $FORMAT in
    json | tree | table | details | markdown) ;; *)
        fail \
            'Tree formats: tree, table, details, markdown, json.'
        ;;
    esac
    if [[ $FORMAT == json ]]; then
        jq -n --arg repo "$REPO" --argjson i "$issues" --argjson e "$edges" \
            '{schema_version:1,repository:$repo,issues:$i,edges:$e}'
        return
    fi
    jq -nr --argjson items "$issues" --argjson edges "$edges" --argjson \
        depth "${O[depth]:-100}" -f \
        "$ROOT/github-issues/queries/render_tree.jq"
}

# Aggregate issue counts without double-counting child links.
# Arguments/state: No arguments; sets O[state]=all and retains other issue
# filters.
# Result: Writes status with repository-wide milestone scope and issue scope.
status_report() {
    local data milestones result
    O[state]=all
    data=$(fetch_issues) || return
    milestones=$(collection "$BASE/milestones?state=all&per_page=100") || return
    result=$(jq --arg repo "$REPO" --argjson ms "$milestones" -f \
        "$ROOT/github-issues/queries/summarize_status.jq" <<<"$data")
    case $FORMAT in
    json | details)
        jq . <<<"$result"
        ;;
    table | compact | \
        markdown)
        jq -r -f \
            "$ROOT/github-issues/queries/render_status.jq" <<<"$result"
        ;;
    *)
        fail 'Status formats: json, details, table, compact, markdown.'
        ;;
    esac
}

# Compute the inclusive start of an activity window.
# Arguments/state: No arguments; reads O[since] or O[last], defaulting to
# seven days.
# Result: Writes a UTC ISO 8601 timestamp; invalid windows exit 2.
window_since() {
    if [[ ${O[since]:-} ]]; then
        printf '%sT00:00:00Z' "${O[since]}"
    else
        local days=${O[last]:-7d}
        [[ $days =~ ^[1-9][0-9]*d$ ]] || fail \
            '--last must be a positive number of days, e.g. 7d'
        date -u -d "${days%d} days ago" +%FT%TZ
    fi
}

# Collect factual timeline events and creation timestamps.
# Arguments/state: No arguments; reads time window and filters, using
# TMP/events.
# Result: Writes events in chronological order; never infers body edits.
activity_report() {
    local data since n events
    since=$(window_since)
    O[state]=all
    O["updated-after"]=${since:0:10}
    data=$(fetch_issues) || return
    : >"$TMP/events"
    while read -r n; do
        events=$(collection "$BASE/issues/$n/timeline?per_page=100") || return
        jq -c --argjson n "$n" --arg since "$since" -f \
            "$ROOT/github-issues/queries/timeline_events.jq" \
                <<<"$events" >>"$TMP/events"
    done < <(jq -r '.[].number' <<<"$data")
    jq -c --arg since "$since" \
        '
        .[] | select(.created_at>=$since) | {number , event:"created" ,
            at:.created_at , actor:.user.login}
    ' <<<"$data" >>"$TMP/events"
    case $FORMAT in
    json)
        jq -s --arg repo "$REPO" \
            '{schema_version:1,repository:$repo,items:sort_by(.at)}' \
            "$TMP/events"
        ;;
    table | compact | details | markdown)
        jq -sr \
            '
        sort_by(.at)[] | ((.at | tostring) + " #" + (.number | tostring) + " "
            + (.event | tostring) + " by " + (.actor//"unknown" | tostring))
    ' "$TMP/events"
        ;;
    *)
        fail \
            'Activity formats: json, table, compact, details, markdown.'
        ;;
    esac
}

# Run the selected read-only diagnostic report.
# Arguments/state: No arguments; ACTION selects the report and O supplies its
# scope.
# Result: Writes findings; propagates incomplete reads rather than repairing
# data.
# Size exception: keep this cohesive command/format dispatch together so
# supported cases and their handling remain reviewable.
diagnostic() {
    local data n comments edges result
    case $ACTION in
    blocked)
        O[state]=open
        O[blocked]=1
        issue_list

        ;;
    unassigned)
        O[state]=open
        O["no-assignee"]=1
        issue_list

        ;;
    completed)
        O[state]=closed
        O[reason]=completed
        data=$(fetch_issues)
        local since
        since=$(window_since)
        jq --arg s "$since" '[.[]|select(.closed_at>=$s)]' <<<"$data" |
            render issue

        ;;
    milestones)
        O[incomplete]=1
        milestone_list

        ;;
    missing-resolutions)
        O[state]=closed
        data=$(fetch_issues)
        : >"$TMP/missing"
        while read -r n; do
            comments=$(collection \
                "$BASE/issues/$n/comments?per_page=100") || return
            if ! jq -e -L "$ROOT/github-issues" \
                'include "resolution"; any(.[];resolution_valid)' \
                <<<"$comments" >/dev/null; then
                jq -c --argjson n "$n" \
                    '.[]|select(.number==$n)' <<<"$data" >>"$TMP/missing"
            fi
        done < <(jq -r '.[].number' <<<"$data")
        jq -s . "$TMP/missing" | render issue

        ;;
    hierarchy | workflow-check)
        O[state]=all
        data=$(fetch_issues)
        edges=$(relationship_edges)
        result=$(jq --argjson edges "$edges" -f \
            "$ROOT/github-issues/queries/workflow_warnings.jq" <<<"$data")
        case $FORMAT in
    json)
            jq --arg repo "$REPO" \
                '{schema_version:1,repository:$repo,warnings:.}' <<<"$result"
            ;;
        table | details | compact | markdown)
            jq -r '.[]|"#\(.number): \(.warning)"' <<<"$result"
            ;;
        *)
            fail 'Audit formats: json, table, details, compact, markdown.'
            ;;
        esac

        ;;
    *)
        fail "Unknown report: $ACTION"
        ;;
    esac
}
