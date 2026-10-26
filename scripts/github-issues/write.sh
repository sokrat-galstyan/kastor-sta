# shellcheck shell=bash
# shellcheck disable=SC2153
# Modifying commands: build/validate first, approve once, report partial stages.
# Mutation handlers share initialized session state and parsed command options.
# Payload construction scales with the affected text. Validation may scan all
# metadata or relationship pages; dependency traversal can revisit shared paths.
# Every write requires approval, and failed stages are never silently retried.

# Require a valid form adapter and detect bundled source drift.
# Arguments/state: No arguments; reads CONFIG and ROOT.
# Result: No stdout; missing configuration or changed bundled forms exit 2.
require_config() {
    [[ $CONFIG ]] || fail \
        'This repository needs --config adapter.json for' \
        'form/policy operations. See the guide.'
    if [[ $CONFIG == "$ROOT/github-issues/kastor.json" ]]; then
        local file expected actual
        while IFS=$'\t' read -r file expected; do
            [[ -f $ROOT/../$file ]] || fail "Adapter source missing: $file"
            actual=$(sha256sum "$ROOT/../$file")
            actual=${actual%% *}
            [[ $actual == "$expected" ]] || fail \
                "Issue form changed: $file. Review and update the" \
                "JSON adapter before writing."
        done < <(jq -r '.source_hashes|to_entries[]|[.key,.value]|@tsv' \
            "$CONFIG")
    fi
}

# Convert explicit structured-field assignments into JSON.
# Arguments/state: No arguments; reads FIELDS, requiring unique ID=TEXT pairs.
# Result: Writes one object; malformed or duplicate IDs exit 2.
fields_json() {
    local pair id value result='{}'
    for pair in "${FIELDS[@]}"; do
        [[ $pair == *=* ]] || fail 'Field must be ID=TEXT'
        id=${pair%%=*}
        value=${pair#*=}
        jq -e --arg id "$id" 'has($id)|not' <<<"$result" >/dev/null || fail \
            "Repeated field: $id"
        result=$(jq --arg id "$id" --arg value "$value" \
            '.+{($id):$value}' <<<"$result")
    done
    printf '%s\n' "$result"
}

# Build a Markdown body from the configured issue form.
# Arguments/state: $1: form category; reads CONFIG and FIELDS.
# Result: Writes validated Markdown; missing fields or empty criteria exit 2.
form_body() {
    require_config
    local category=$1 fields spec id value required label body=''
    spec=$(jq -ce --arg c "$category" '.forms[$c] // empty' "$CONFIG") ||
        fail "Unknown form category: $category"
    fields=$(fields_json)
    jq -e --argjson s "$spec" \
        'keys-[$s.fields[].id]|length==0' <<<"$fields" >/dev/null || fail \
        'Unknown form field; inspect the configured field IDs.'
    while IFS=$'\t' read -r id label required; do
        value=$(jq -r --arg id "$id" '.[$id]//""' <<<"$fields")
        if [[ $required == true ]]; then
            nonempty "$label" "$value"
        fi
        if [[ $value ]]; then
            if jq -en --arg value "$value" \
                '$value|test("(?m)^[-*] \\[[ xX]\\][ \\t]*$")' >/dev/null; then
                fail \
                    "$label contains an empty checkbox; give every item" \
                    "meaningful text."
            fi
            body+="### $label"$'\n\n'"$value"$'\n\n'
        fi
    done < <(jq -r '.fields[]|[.id,.label,.required]|@tsv' <<<"$spec")
    printf '%s' "$body"
}

# Confirm that all supplied labels already exist.
# Arguments/state: $@: label names; reads BASE.
# Result: No stdout; invalid names exit 2 and read failures propagate.
validate_labels() {
    local label available
    available=$(collection "$BASE/labels?per_page=100") || return
    for label in "$@"; do
        [[ $label && $label != *,* ]] || fail \
            'Label must be nonempty and cannot contain comma' \
            '(filter delimiter).'
        jq -e --arg name "$label" \
            'any(.[];.name==$name)' <<<"$available" >/dev/null || fail \
            "Unknown label '$label'; create it explicitly first."
    done
}

# Require an existing open milestone.
# Arguments/state: $1: positive milestone number; reads BASE.
# Result: No stdout; closed or invalid milestones exit 2.
validate_milestone() {
    local m
    positive "$1"
    m=$(read_api "$BASE/milestones/$1") || return
    [[ $(jq -r .state <<<"$m") == open ]] || fail 'Choose an open milestone.'
}

# Validate a login and repository assignment eligibility.
# Arguments/state: $1: GitHub login; reads BASE.
# Result: No stdout; malformed logins exit 2, API failures propagate.
validate_assignee() {
    [[ $1 =~ ^[A-Za-z0-9-]+$ ]] || fail 'Invalid assignee login.'
    read_api "$BASE/assignees/$1" >/dev/null
}

# Validate an intended same-repository Epic-child relationship.
# Arguments/state: $1: child number or new; $2: parent number; $3: explicit
# milestone.
# Result: No stdout; rejects cycles, duplicate links and unintended
# reassignment.
validate_link() {
    local child=$1 parent=$2 milestone=$3 p edges
    positive "$parent"
    [[ $child != "$parent" ]] || fail 'An issue cannot parent itself.'
    p=$(get_issue "$parent") || return
    require_config
    local epic
    epic=$(jq -r '.epic_label' "$CONFIG")
    jq -e --arg label "$epic" \
        '.state=="open" and any(.labels[]?; .name==$label)' <<<"$p" \
            >/dev/null || fail 'Parent must be an open Epic.'
    [[ $(jq -r '.milestone.number//"none"' <<<"$p") == "$milestone" ]] ||
        fail \
            'Parent and child must have the same explicitly' \
            'assigned milestone.'
    edges=$(relationship_edges) || return
    if [[ $child != new ]]; then
        jq -e --argjson child "$child" --argjson parent "$parent" -f \
            "$ROOT/github-issues/queries/parent_link_is_acyclic.jq" \
            <<<"$edges" \
                >/dev/null || fail 'Relationship would create a cycle.'
        local old
        old=$(jq -r --argjson c "$child" \
            '.[]|select(.child==$c)|.parent' <<<"$edges")
        [[ $old != "$parent" ]] || fail \
            'Relationship already exists; no write needed.'
        [[ ! $old || ${O[move]:-0} == 1 ]] || fail \
            "Child already belongs to #$old; use --move to" \
            "intentionally replace its parent."
    fi
}

# Read back an issue and compare fields with the requested patch.
# Arguments/state: $1: issue number; $2: JSON patch. Reads BASE.
# Result: Writes verified identifiers; returns 4 on a mismatch or read
# failure.
verify_update() {
    local number=$1 payload=$2 after
    after=$(get_issue "$number") || {
        say \
            'Write succeeded but read-back failed. Inspect' \
            'GitHub before retrying.'
        return 4
    }
    jq -e --argjson p "$payload" -f \
        "$ROOT/github-issues/queries/patch_matches.jq" <<<"$after" \
            >/dev/null || {
        say \
            'Write response received, but read-back differs from' \
            'requested values. Inspect GitHub; do not retry' \
            'blindly.'
        return 4
    }
    jq '{number,state,state_reason,html_url}' <<<"$after"
}

# Execute the selected issue mutation with approval and recovery.
# Arguments/state: No arguments; reads ACTION, NUMBER and parsed mutation
# fields.
# Result: Reports completed stages; propagates failures without retry or
# rollback.
# Size exception: keep this cohesive command/format dispatch together so
# supported cases and their handling remain reviewable.
issue_write() {
    local issue payload result body labels assignees value n
    if [[ $ACTION != create ]]; then
        issue=$(get_issue "$NUMBER") || return
    fi
    case $ACTION in
    create)
        need category
        need title
        need milestone
        need parent
        nonempty Title "${O[title]}"
        body=$(form_body "${O[category]}")
        validate_milestone "${O[milestone]}"
        labels=$(jq -c --arg c "${O[category]}" '.forms[$c].labels' "$CONFIG")
        for value in "${LABELS[@]}"; do
            labels=$(jq --arg v "$value" \
                '.+[$v]|unique' <<<"$labels")
        done
        [[ ! ${O[area]:-} ]] || labels=$(jq --arg v "area:${O[area]#area:}" \
            '.+[$v]|unique' <<<"$labels")
        mapfile -t label_values < <(jq -r '.[]' <<<"$labels")
        validate_labels "${label_values[@]}"
        assignees='[]'
        if [[ ${O[assignee]:-} ]]; then
            validate_assignee "${O[assignee]}"
            assignees=$(jq -n --arg v "${O[assignee]}" '[$v]')
        fi
        if [[ ${O[parent]} != none ]]; then
            validate_link new \
                "${O[parent]}" "${O[milestone]}"
        fi
        payload=$(jq -n --arg title "${O[title]}" --arg body "$body" \
            --argjson labels "$labels" --argjson milestone \
            "${O[milestone]}" --argjson assignees "$assignees" \
            '
        {title:$title , body:$body , labels:$labels , milestone:$milestone ,
            assignees:$assignees}
    ')
        approve \
            "$(printf '%s' \
                "Create issue; parent: ${O[parent]} (explicit " \
                "milestone ${O[milestone]})")" "$payload"
        [[ ${O["dry-run"]:-0} != 1 ]] || {
            say 'DRY RUN: issue creation and optional linking validated.'
            return
        }
        result=$(write_api POST "$BASE/issues" "$payload") || return
        n=$(jq -er .number <<<"$result") || {
            say \
                'Creation response missing number: inspect GitHub' \
                'before retrying.'
            return 4
        }
        say "Created #$n: $(jq -r .html_url <<<"$result")"
        verify_update "$n" "$payload" || return
        if [[ ${O[parent]} != none ]]; then
            payload=$(jq -n --argjson id "$(jq .id <<<"$result")" \
                '{sub_issue_id:$id}')
            write_api POST "$BASE/issues/${O[parent]}/sub_issues" \
                "$payload" >/dev/null || {
                say \
                    "Partial success: #$n exists but linking is" \
                    "unverified. Resume using issue link $n --parent" \
                    "${O[parent]}."
                return 4
            }
            verify_link "$n" "${O[parent]}" present
        fi

        ;;
    edit)
        payload='{}'
        [[ ! ${O[title]+set} ]] || {
            nonempty Title "${O[title]}"
            payload=$(jq --arg v "${O[title]}" '.+{title:$v}' <<<"$payload")
        }
        if [[ ${O["body-file"]:-} ]]; then
            [[ -r ${O["body-file"]} ]] || fail 'Body file is unreadable.'
            if ((${#FIELDS[@]})) || [[ ${O[toggle]:-} ]]; then
                fail \
                    'Do not combine whole-body and structured edits.'
            fi
            body=$(cat -- "${O["body-file"]}")
            nonempty Body "$body"
            payload=$(jq --arg v "$body" '.+{body:$v}' <<<"$payload")
        elif ((${#FIELDS[@]})) || [[ ${O[toggle]:-} ]]; then
            body=$(structured_edit "$issue") || return
            payload=$(jq --arg v "$body" '.+{body:$v}' <<<"$payload")
        fi
        if ((${#LABELS[@]} + ${#REMOVE_LABELS[@]})); then
            validate_labels "${LABELS[@]}"
            labels=$(jq '[.labels[].name]' <<<"$issue")
            for value in "${LABELS[@]}"; do
                labels=$(jq --arg v "$value" \
                    '.+[$v]|unique' <<<"$labels")
            done
            for value in "${REMOVE_LABELS[@]}"; do
                labels=$(jq --arg v \
                    "$value" 'map(select(.!=$v))' <<<"$labels")
            done
            payload=$(jq --argjson v "$labels" '.+{labels:$v}' <<<"$payload")
        fi
        if [[ ${O[milestone]:-} ]]; then
            value=${O[milestone]}
            if [[ $value == none ]]; then value=null; else
                validate_milestone "$value"
            fi
            payload=$(jq --argjson v "$value" '.+{milestone:$v}' <<<"$payload")
        fi
        if [[ ${O[assignee]:-} ]]; then
            assignees='[]'
            if [[ ${O[assignee]} != none ]]; then
                validate_assignee "${O[assignee]}"
                assignees=$(jq -n --arg v "${O[assignee]}" '[$v]')
            fi
            payload=$(jq --argjson v "$assignees" \
                '.+{assignees:$v}' <<<"$payload")
        fi
        [[ $payload != '{}' ]] || fail 'No edits supplied.'
        approve "Edit #$NUMBER. Existing body:" "$(jq \
            '{title,body,labels,assignees,milestone}' <<<"$issue")"
        say 'Proposed changes:'
        jq . <<<"$payload" >&2
        result=$(get_issue "$NUMBER")
        [[ $(jq -r .updated_at <<<"$result") == "$(jq -r \
            .updated_at <<<"$issue")" ]] || fail \
            'Issue changed during preview; refresh and retry.'
        write_api PATCH "$BASE/issues/$NUMBER" "$payload" >/dev/null || return
        [[ ${O["dry-run"]:-0} == 1 ]] || verify_update "$NUMBER" "$payload"

        ;;
    close)
        close_issue "$issue"
        ;;
    reopen)
        [[ $(jq -r .state <<<"$issue") == closed ]] || fail \
            'Issue is already open.'
        payload='{"state":"open","state_reason":"reopened"}'
        approve "Reopen #$NUMBER" "$payload"
        write_api PATCH "$BASE/issues/$NUMBER" "$payload" >/dev/null || return
        [[ ${O["dry-run"]:-0} == 1 ]] || verify_update "$NUMBER" "$payload"

        ;;
    comment)
        need body-file
        [[ -r ${O["body-file"]} ]] || fail 'Body file unreadable.'
        body=$(cat -- "${O["body-file"]}")
        nonempty Comment "$body"
        payload=$(jq -n --arg body "$body" '{body:$body}')
        approve "Comment on #$NUMBER" "$payload"
        write_api POST "$BASE/issues/$NUMBER/comments" "$payload"

        ;;
    link | unlink)
        need parent
        positive "${O[parent]}"
        if [[ $ACTION == link ]]; then
            validate_link "$NUMBER" "${O[parent]}" "$(jq -r \
                '.milestone.number//"none"' <<<"$issue")"
            payload=$(jq -n --argjson id "$(jq .id <<<"$issue")" --argjson \
                move "${O[move]:-0}" \
                '{sub_issue_id:$id,replace_parent:($move==1)}')
            approve "Attach #$NUMBER to #${O[parent]} (move=${O[move]:-0})" \
                "$payload"
            write_api POST "$BASE/issues/${O[parent]}/sub_issues" \
                "$payload" >/dev/null || return
            [[ ${O["dry-run"]:-0} == 1 ]] || verify_link "$NUMBER" \
                "${O[parent]}" present
        else
            result=$(collection \
                "$BASE/issues/${O[parent]}/sub_issues?per_page=100")
            jq -e --argjson n "$NUMBER" \
                'any(.[];.number==$n)' <<<"$result" >/dev/null || fail \
                'That parent/child link does not exist.'
            payload=$(jq -n --argjson id "$(jq .id <<<"$issue")" \
                '{sub_issue_id:$id}')
            approve "Detach #$NUMBER from #${O[parent]}" "$payload"
            write_api DELETE "$BASE/issues/${O[parent]}/sub_issue" \
                "$payload" >/dev/null || return
            [[ ${O["dry-run"]:-0} == 1 ]] || verify_link "$NUMBER" \
                "${O[parent]}" absent
        fi

        ;;
    block | unblock)
        block_issue "$issue"
        ;;
    depend | undepend)
        dependency_write "$issue"
        ;;
    esac
}

# Check whether a native parent-child link has the expected state.
# Arguments/state: $1: child number; $2: parent number; $3: present or absent.
# Result: Writes a verification message; returns 4 on uncertain/mismatched
# state.
verify_link() {
    local children present
    children=$(collection "$BASE/issues/$2/sub_issues?per_page=100") || {
        say 'Link write completed; verification unavailable.'
        return 4
    }
    present=$(jq --argjson n "$1" 'any(.[];.number==$n)' <<<"$children")
    [[ $present == true && $3 == present || $present == false && $3 == \
        absent ]] || {
        say 'Relationship read-back differs; inspect GitHub' \
            'before retrying.'
        return 4
    }
    printf 'Relationship verified: #%s / #%s (%s)\n' "$2" "$1" "$3"
}

# Edit simple unique Markdown sections or a top-level checklist.
# Arguments/state: $1: issue JSON; reads FIELDS, CONFIG and O[toggle].
# Result: Writes the updated body; rejects ambiguous/fenced layouts without
# writes.
# Size exception: preserve the ordered validation and execution stages of this
# operation instead of splitting solely for line count.
structured_edit() {
    local issue=$1 fields body id label value
    require_config
    fields=$(fields_json)
    body=$(jq -r '.body//""' <<<"$issue")
    [[ $body != *'```'* && $body != *'~~~'* ]] || fail \
        'Structured edits do not support fenced bodies; use' \
        '--body-file (editor).'
    for id in $(jq -r 'keys[]' <<<"$fields"); do
        label=$(jq -r --arg id "$id" \
            '
        [.forms[].fields[] | select(.id==$id) | .label] | unique | if
            length==1 then .[0] else empty end
    ' "$CONFIG")
        [[ $label ]] || fail "Unknown or ambiguous field $id; use --body-file."
        value=$(jq -r --arg id "$id" '.[$id]' <<<"$fields")
        nonempty "$label" "$value"
        [[ ! $value =~ (^|$'\n')\# ]] || fail \
            'Replacement field must not contain Markdown' \
            'headings; use --body-file.'
        body=$(jq -nr --arg body "$body" --arg label "$label" --arg value \
            "$value" -f \
            "$ROOT/github-issues/queries/replace_section.jq") || return
    done
    if [[ ${O[toggle]:-} ]]; then
        positive "${O[toggle]}"
        body=$(jq -nr --arg body "$body" --argjson n "${O[toggle]}" -f \
            "$ROOT/github-issues/queries/toggle_checklist.jq") || return
    fi
    printf '%s\n' "$body"
}

# Build the standardized resolution Markdown.
# Arguments/state: $1: outcome; $2: summary; $3: evidence; $4: docs; $5:
# follow-ups.
# Result: Writes the complete comment; text arguments are never interpreted.
build_resolution_comment() {
    printf '%s\n' '## Resolution'
    printf '**Outcome:** %s\n' "$1"
    printf '**Summary:** %s\n' "$2"
    printf '**Evidence:** %s\n' "$3"
    printf '**Docs updated:** %s\n' "$4"
    printf '**Follow-ups:** %s\n' "$5"
}

# Validate, post or reuse a resolution, close and verify an issue.
# Arguments/state: $1: current issue JSON; reads NUMBER and required
# resolution options.
# Result: Reports partial success explicitly; failed attempts leave the issue
# open.
# Size exception: preserve the ordered validation and execution stages of this
# operation instead of splitting solely for line count.
close_issue() {
    local issue=$1 outcome reason target='' payload comment \
        comments children blockers final field
    [[ $(jq -r .state <<<"$issue") == open ]] || fail \
        'Already closed. Use issue view --resolution or' \
        'reopen; no comment posted.'
    for field in outcome summary evidence docs followups; do
        need "$field"
        nonempty "$field" "${O[$field]}"
    done
    case ${O[outcome]} in
    done)
        outcome='done'
        reason=completed

        ;;
    wont-do)
        outcome="won't do"
        reason=not_planned

        ;;
    duplicate | superseded)
        need target
        positive "${O[target]}"
        [[ ${O[target]} != "$NUMBER" ]] || fail \
            'Target cannot be the same issue.'
        target=$(get_issue "${O[target]}")
        if [[ ${O[outcome]} == duplicate ]]; then
            outcome="duplicate of #${O[target]}"
            reason=duplicate
        else
            outcome="superseded by #${O[target]}"
            reason=not_planned
        fi

        ;;
    failed)
        outcome='failed attempt; work continuing'
        reason=''

        ;;
    *)
        fail 'Outcome: done, wont-do, duplicate, superseded, failed.'
        ;;
    esac
    children=$(collection \
        "$BASE/issues/$NUMBER/sub_issues?per_page=100") || return
    blockers=$(collection \
        "$BASE/issues/$NUMBER/dependencies/blocked_by?per_page=100") || return
    if [[ $reason == completed ]]; then
        if jq -e -f \
            "$ROOT/github-issues/queries/completion_obstacles.jq" <<<"$issue" \
                >/dev/null ||
            jq -e 'any(.[];.state=="open")' <<<"$children" >/dev/null || jq \
            -e 'any(.[];.state=="open")' <<<"$blockers" >/dev/null; then
            say \
                'Completion has unchecked criteria, a blocked label,' \
                'open children, or open blockers.'
            need exception
            nonempty Exception "${O[exception]}"
        fi
    fi
    final=$(get_issue "$NUMBER") || return
    [[ $(jq -r .updated_at <<<"$final") == "$(jq -r \
        .updated_at <<<"$issue")" ]] || fail \
        'Issue changed during validation; refresh before closing.'
    comment=$(build_resolution_comment "$outcome" "${O[summary]}" \
        "${O[evidence]}" "${O[docs]}" "${O[followups]}")
    if [[ ${O[outcome]} == failed ]]; then
        comment=${comment/'## Resolution'/'## Progress — failed attempt'}
    fi
    [[ ! ${O[exception]:-} ]] ||
        comment+=$'\n\n'"**Completion exception:** ${O[exception]}"
    payload=$(jq -n --arg body "$comment" '{body:$body}')
    approve \
        "$(printf '%s' \
            "Resolution for #$NUMBER; GitHub result: " \
            "${reason:-leave open}. Children/blockers were " \
            "checked.")" "$payload"
    [[ ${O["dry-run"]:-0} != 1 ]] || {
        say 'DRY RUN: would post resolution, then update and' \
            'verify state.'
        return
    }
    comments=$(collection "$BASE/issues/$NUMBER/comments?per_page=100") ||
        return
    if jq -e --arg body "$comment" \
        'any(.[];.body==$body)' <<<"$comments" >/dev/null; then
        say 'Identical comment already exists; reusing it for' \
            'safe retry.'
    else
        write_api POST "$BASE/issues/$NUMBER/comments" \
            "$payload" >/dev/null || return
        say \
            "Comment posted on #$NUMBER. If the next stage" \
            "fails, retry with identical resolution fields."
    fi
    if [[ ! $reason ]]; then
        verify_update "$NUMBER" '{"state":"open"}'
        return
    fi
    payload=$(jq -n --arg reason "$reason" \
        '{state:"closed",state_reason:$reason}')
    [[ $reason != duplicate ]] || payload=$(jq --argjson id "$(jq \
        .id <<<"$target")" '.+{duplicate_issue_id:$id}' <<<"$payload")
    write_api PATCH "$BASE/issues/$NUMBER" "$payload" >/dev/null || {
        say \
            'Partial success: resolution comment exists; closure' \
            'is unverified. Retry identical fields after' \
            'inspecting current state.'
        return 4
    }
    verify_update "$NUMBER" "$payload"
}

# Add or remove one native blocking dependency.
# Arguments/state: $1: current issue JSON; reads ACTION, NUMBER and O[target].
# Result: Writes verification results; requires approval and rejects cycles.
# Size exception: preserve the ordered validation and execution stages of this
# operation instead of splitting solely for line count.
dependency_write() {
    local issue=$1 target payload current id
    need target
    positive "${O[target]}"
    [[ ${O[target]} != "$NUMBER" ]] || fail 'Self dependency is invalid.'
    target=$(get_issue "${O[target]}") || return
    id=$(jq .id <<<"$target")
    current=$(collection \
        "$BASE/issues/$NUMBER/dependencies/blocked_by?per_page=100") || return
    if [[ $ACTION == depend ]]; then
        jq -e --argjson id "$id" \
            'all(.[];.id!=$id)' <<<"$current" >/dev/null || fail \
            'Dependency already exists.'
        dependency_cycle_check "${O[target]}" "$NUMBER" ''
        payload=$(jq -n --argjson id "$id" '{issue_id:$id}')
        approve "#$NUMBER depends on #${O[target]}" "$payload"
        write_api POST "$BASE/issues/$NUMBER/dependencies/blocked_by" \
            "$payload" >/dev/null || return
    else
        jq -e --argjson id "$id" \
            'any(.[];.id==$id)' <<<"$current" >/dev/null || fail \
            'Dependency does not exist.'
        approve \
            "$(printf '%s' \
                "Remove blocker #${O[target]} from #$NUMBER; blocked " \
                "label is unchanged.")"
        write_api DELETE \
            "$BASE/issues/$NUMBER/dependencies/blocked_by/$id" >/dev/null \
                || return
    fi
    [[ ${O["dry-run"]:-0} != 1 ]] || return 0
    current=$(collection \
        "$BASE/issues/$NUMBER/dependencies/blocked_by?per_page=100") || {
        say 'Dependency write succeeded; read-back unavailable.'
        return 4
    }
    if [[ $ACTION == depend ]]; then
        jq -e --argjson id "$id" 'any(.[];.id==$id)' <<<"$current" >/dev/null
    else
        jq -e --argjson id "$id" \
            'all(.[];.id!=$id)' <<<"$current" >/dev/null
    fi || {
        say 'Dependency read-back mismatch.'
        return 4
    }
    printf 'Dependency %s verified: #%s / #%s\n' "$ACTION" "$NUMBER" \
        "${O[target]}"
}

# Traverse blockers to reject a new or existing cycle.
# Arguments/state: $1: node; $2: prohibited target; $3: visited numbers
# separated by spaces.
# Result: No stdout; cross-repository graphs and detected cycles exit 2.
dependency_cycle_check() {
    local n=$1 target=$2 seen=$3 blockers next
    [[ $n != "$target" ]] || fail 'Dependency would create a cycle.'
    [[ " $seen " != *" $n "* ]] || fail \
        'Existing dependency cycle; repair in GitHub before' \
        'adding a link.'
    blockers=$(collection \
        "$BASE/issues/$n/dependencies/blocked_by?per_page=100") || return
    jq -e --arg repo "https://api.github.com/$BASE" \
        'all(.[]; .repository_url==$repo)' <<<"$blockers" >/dev/null ||
        fail \
            'Cross-repository dependency graph cannot be' \
            'validated by this version.'
    while read -r next; do
        dependency_cycle_check "$next" "$target" \
            "$seen $n" || return
    done < <(jq -r '.[].number' <<<"$blockers")
}

# Record a blocking explanation and update the blocked label.
# Arguments/state: $1: current issue JSON; reads ACTION, NUMBER, summary and
# optional target.
# Result: Reports stages; unblocking does not silently remove dependency
# edges.
# Size exception: preserve the ordered validation and execution stages of this
# operation instead of splitting solely for line count.
block_issue() {
    local issue=$1 payload labels target
    require_config
    need summary
    nonempty Summary "${O[summary]}"
    local blocked
    blocked=$(jq -r '.blocked_label' "$CONFIG")
    validate_labels "$blocked"
    labels=$(jq '[.labels[].name]' <<<"$issue")
    if [[ $ACTION == block ]]; then labels=$(jq --arg v "$blocked" \
        '.+[$v]|unique' <<<"$labels"); else
        labels=$(jq --arg v "$blocked" \
            'map(select(.!=$v))' <<<"$labels")
    fi
    if [[ ${O[target]:-} ]]; then
        [[ $ACTION == block ]] || fail \
            'Unblock removes label only; remove dependencies' \
            'explicitly in GitHub.'
        positive "${O[target]}"
        [[ ${O[target]} != "$NUMBER" ]] || fail 'Self dependency is invalid.'
        target=$(get_issue "${O[target]}")
        dependency_cycle_check "${O[target]}" "$NUMBER" ''
    fi
    payload=$(jq -n --argjson labels "$labels" '{labels:$labels}')
    approve \
        "$(printf '%s' \
            "$ACTION #$NUMBER: ${O[summary]}; dependency: " \
            "${O[target]:-none}")" \
        "$payload"
    [[ ${O["dry-run"]:-0} != 1 ]] || {
        say 'DRY RUN: dependency/comment/label plan validated.'
        return
    }
    if [[ ${O[target]:-} ]]; then
        write_api POST "$BASE/issues/$NUMBER/dependencies/blocked_by" "$(jq \
            -n --argjson id "$(jq .id <<<"$target")" \
            '{issue_id:$id}')" >/dev/null || return
        say 'Dependency added.'
    fi
    write_api POST "$BASE/issues/$NUMBER/comments" "$(jq -n --arg body \
        "$ACTION: ${O[summary]}" '{body:$body}')" >/dev/null || return
    say 'Explanation posted; updating labels next.'
    write_api PATCH "$BASE/issues/$NUMBER" "$payload" >/dev/null || return
    verify_update "$NUMBER" "$payload"
}

# Create or update one milestone, including closure guards.
# Arguments/state: No arguments; reads ACTION, NUMBER and milestone options.
# Result: Writes verified milestone identifiers; never closes associated
# issues.
# Size exception: keep this cohesive command/format dispatch together so
# supported cases and their handling remain reviewable.
milestone_write() {
    local payload='{}' result field value existing
    if [[ $ACTION != create ]]; then
        positive "$NUMBER"
        existing=$(read_api "$BASE/milestones/$NUMBER") || return
    fi
    case $ACTION in
    create | edit)
        if [[ $ACTION == create ]]; then
            need title
            nonempty Title "${O[title]}"
            if [[ $CONFIG ]] && jq -e '.milestone_description_required' \
                "$CONFIG" >/dev/null; then
                need description
                nonempty Description "${O[description]}"
            fi
        fi
        for field in title description; do
            [[ ! ${O[$field]+set} ]] || payload=$(jq --arg key "$field" \
                --arg v "${O[$field]}" '.+{($key):$v}' <<<"$payload")
        done
        [[ ! ${O[title]+set} ]] || nonempty Title "${O[title]}"
        if [[ ${O[description]+set} && $CONFIG ]] && jq -e \
            '.milestone_description_required' "$CONFIG" >/dev/null; then
            nonempty Description "${O[description]}"
        fi
        if [[ ${O[due]:-} ]]; then
            value=${O[due]}
            if [[ $value == none ]]; then payload=$(jq \
                '.+{due_on:null}' <<<"$payload"); else
                date_value "$value"
                payload=$(jq --arg v "${value}T23:59:59Z" \
                    '.+{due_on:$v}' <<<"$payload")
            fi
        fi

        ;;
    close)
        if [[ $(jq .open_issues <<<"$existing") -gt 0 ]]; then
            say "Milestone has $(jq \
                .open_issues \
                <<<"$existing") open items (GitHub counts issues and PRs)."
            collection \
                "$BASE/issues?milestone=$NUMBER&state=open&per_page=100" |
                jq -r '.[]|"#\(.number) \(.title)"' >&2
            need exception
            nonempty Exception "${O[exception]}"
        fi
        payload='{"state":"closed"}'

        ;;
    reopen)
        payload='{"state":"open"}'
        ;;
    esac
    [[ $payload != '{}' ]] || fail 'No milestone changes supplied.'
    approve \
        "$(printf '%s' \
            "$ACTION milestone ${NUMBER:-new}; exception: " \
            "${O[exception]:-none}")" "$payload"
    if [[ $ACTION == create ]]; then
        result=$(write_api POST "$BASE/milestones" "$payload") || return
    else
        result=$(write_api PATCH "$BASE/milestones/$NUMBER" "$payload") ||
            return
    fi
    if [[ ${O["dry-run"]:-0} != 1 ]]; then
        result=$(read_api "$BASE/milestones/$(jq -er \
            .number <<<"$result")") || {
            say 'Write completed but verification failed.'
            return 4
        }
        jq -e --argjson p "$payload" \
            '. as $r|$p|to_entries|all(.value==$r[.key])' <<<"$result" \
                >/dev/null || {
            say 'Milestone read-back mismatch.'
            return 4
        }
        jq '{number,title,state,html_url}' <<<"$result"
    fi
}

# Create, rename, edit or explicitly delete a label.
# Arguments/state: No arguments; reads ACTION, NUMBER and label options.
# Result: Writes resource data; deletion requires an exact confirmation name.
# Size exception: keep this cohesive command/format dispatch together so
# supported cases and their handling remain reviewable.
label_write() {
    local payload='{}' field result name=${O[name]:-$NUMBER}
    [[ $ACTION != create ]] || {
        need name
        need color
    }
    if [[ ${O[color]:-} ]]; then
        [[ ${O[color]} =~ ^[0-9a-fA-F]{6}$ ]] ||
            fail 'Color must be six hexadecimal digits without #.'
    fi
    if [[ $ACTION == delete ]]; then
        need confirm-name
        [[ ${O["confirm-name"]} == "$NUMBER" ]] || fail \
            '--confirm-name must exactly match the label being deleted.'
        read_api "$BASE/labels/$(uri "$NUMBER")" >/dev/null
        approve "DELETE label '$NUMBER' from every issue in $REPO."
        write_api DELETE "$BASE/labels/$(uri "$NUMBER")" >/dev/null || return
        say 'Label deletion request succeeded.'
        return
    fi
    for field in name color description; do
        [[ ! ${O[$field]+set} ]] || payload=$(jq --arg key "$field" --arg \
            value "${O[$field]}" '.+{($key):$value}' <<<"$payload")
    done
    nonempty Name "$name"
    if [[ $ACTION == create || $name != "$NUMBER" ]]; then
        result=$(collection "$BASE/labels?per_page=100")
        jq -e --arg name "$name" \
            'all(.[];(.name|ascii_downcase)!=($name|ascii_downcase))' \
                <<<"$result" >/dev/null || fail 'Label name already exists.'
    fi
    [[ $payload != '{}' ]] || fail 'No label edits supplied.'
    if [[ $ACTION == edit ]]; then
        read_api "$BASE/labels/$(uri "$NUMBER")" >/dev/null
        payload=$(jq \
            'if has("name") then .new_name=.name|del(.name) else . end' \
                <<<"$payload")
    fi
    approve "$ACTION label '$NUMBER' → '$name'" "$payload"
    if [[ $ACTION == create ]]; then
        write_api POST "$BASE/labels" "$payload" >/dev/null || return
    else
        write_api PATCH "$BASE/labels/$(uri "$NUMBER")" \
            "$payload" >/dev/null || return
    fi
    [[ ${O["dry-run"]:-0} == 1 ]] || read_api "$BASE/labels/$(uri "$name")"
}
