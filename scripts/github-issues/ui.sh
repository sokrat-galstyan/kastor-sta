# shellcheck shell=bash
# shellcheck disable=SC2153
# Interactive shell: each operation executes the same CLI in a child process.
# Errors and cancellation return to the menu. No user input is evaluated.
# Terminal interfaces share ANSWER and initialized repository/configuration
# state.
# Prompts are linear in displayed text; choice filtering scans the choice array.
# API and child-command costs follow their respective read/write contracts.

# Read one terminal answer with an optional default.
# Arguments/state: $1: description; optional $2: default text.
# Result: Sets ANSWER; returns 130 on EOF or :cancel; prompts use stderr.
prompt() {
    local description=$1 default=${2:-} input
    printf '%s%s (:cancel to cancel): ' "$description" \
        "${default:+ [$default]}" >&2
    IFS= read -r input || return 130
    [[ $input != :cancel ]] || return 130
    ANSWER=${input:-$default}
}

# Read plain text or edit multiline text with the selected editor.
# Arguments/state: $1: label; optional $2: initial text; reads VISUAL/EDITOR.
# Result: Sets ANSWER; propagates cancellation or editor failure. No shell
# eval.
text_prompt() {
    local label=$1 default=${2:-} input editor
    prompt "$label (text, or :editor for multiline)" "$default" || return
    if [[ $ANSWER == :editor ]]; then
        printf '%s' "$default" >"$TMP/editor"
        editor=${VISUAL:-${EDITOR:-vi}}
        command -v "$editor" >/dev/null || {
            say 'Set VISUAL/EDITOR to an executable path (no shell' \
                'arguments).'
            return 2
        }
        "$editor" "$TMP/editor" || return
        ANSWER=$(cat "$TMP/editor")
    fi
}

# Offer numbered choices with optional substring search.
# Arguments/state: $1: label; $2: JSON label/value array; optional $3: allow-
# none flag.
# Result: Sets ANSWER to the selected value or none; cancellation returns 130.
choose() {
    local label=$1 json=$2 optional=${3:-0} selected original=$2
    say "$label"
    jq -r 'to_entries[]|"  \(.key+1). \(.value.label)"' <<<"$json" >&2
    [[ $optional == 0 ]] || say '  0. None / standalone / unassigned'
    while true; do
        prompt 'Choice number (or /text to search)' || return
        if [[ $ANSWER == /* ]]; then
            json=$(jq --arg q "${ANSWER#/}" \
                '[.[]|select(.label|ascii_downcase|
                    contains($q|ascii_downcase))]' <<<"$original")
            jq -r 'to_entries[]|"  \(.key+1). \(.value.label)"' <<<"$json" >&2
            continue
        fi
        if [[ $ANSWER == 0 && $optional == 1 ]]; then
            ANSWER=none
            return
        fi
        if [[ $ANSWER =~ ^[1-9][0-9]*$ ]] && [[ $ANSWER -le $(jq \
            length <<<"$json") ]]; then
            selected=$(jq -r --argjson n "$ANSWER" '.[$n-1].value' <<<"$json")
            ANSWER=$selected
            return
        fi
        say 'Choose one of the numbered items.'
    done
}

# Invoke the same CLI with this session repository and adapter.
# Arguments/state: $@: command arguments; reads REPO, CONFIG and ROOT.
# Result: Preserves child stdout and exit status; never adds confirmation.
ui_run() {
    local -a args=(--repo "$REPO")
    [[ ! $CONFIG ]] || args+=(--config "$CONFIG")
    "$ROOT/github-issues.sh" "${args[@]}" "$@"
}

# Preview a mutation, allow revisions and request confirmation.
# Arguments/state: $@: mutation command arguments; reads session dry-run
# option.
# Result: Returns child status or zero on cancellation; never writes in dry-
# run.
# Size exception: preserve the ordered validation and execution stages of this
# operation instead of splitting solely for line count.
ui_write() {
    local -a args=("$@") positions=()
    local i selected field
    while true; do
        say 'Validating and showing full preview…'
        if ! ui_run "${args[@]}" --dry-run; then
            say \
                'Validation failed. Choose edit to correct an' \
                'answer, or no to cancel.'
        fi
        if [[ ${O["dry-run"]:-0} == 1 ]]; then
            say 'Session is in dry-run mode; returning without writes.'
            return 0
        fi
        prompt \
            "$(printf '%s' \
                'Type yes to apply, edit to revise an earlier field, ' \
                'or no to cancel')" no || return
        case $ANSWER in
        yes)
            ui_run "${args[@]}" --yes
            return

            ;;
        edit)
            positions=()
            for ((i = 0; i < ${#args[@]} - 1; i++)); do
                if [[ ${args[i]} == --* ]]; then
                    positions+=("$((i + 1))")
                    say "${#positions[@]}. ${args[i]} ${args[i + 1]}"
                    ((i += 1))
                fi
            done
            prompt 'Field number to revise' || return
            [[ $ANSWER =~ ^[1-9][0-9]*$ && $ANSWER -le ${#positions[@]} ]] || {
                say 'Invalid field number.'
                continue
            }
            selected=${positions[ANSWER - 1]}
            field=${args[selected]}
            if [[ ${args[selected - 1]} == --field ]]; then
                text_prompt "${field%%=*}" "${field#*=}" || return
                args[selected]="${field%%=*}=$ANSWER"
            else
                text_prompt "${args[selected - 1]}" "$field" || return
                args[selected]=$ANSWER
            fi

            ;;
        *)
            say 'Cancelled; no writes made.'
            return

            ;;
        esac
    done
}

# Collect form fields and dynamic metadata before creation.
# Arguments/state: No arguments; reads CONFIG and repository choices.
# Result: Runs the shared preview/confirmation path; supports safe
# cancellation.
# Size exception: preserve the ordered validation and execution stages of this
# operation instead of splitting solely for line count.
ui_create() {
    require_config
    local category fields id label help required value options
    local -a args=(issue create)
    options=$(jq '[.forms|keys[]|{label:.,value:.}]' "$CONFIG")
    choose 'Issue category' "$options" || return
    category=$ANSWER
    args+=(--category "$category")
    prompt 'Title (required)' "$(jq -r --arg c "$category" \
        '.forms[$c].title_prefix' "$CONFIG")" || return
    args+=(--title "$ANSWER")
    fields=$(jq -c --arg c "$category" '.forms[$c].fields[]' "$CONFIG")
    while IFS= read -r -u 3 field; do
        id=$(jq -r .id <<<"$field")
        label=$(jq -r .label <<<"$field")
        help=$(jq -r '.help//""' <<<"$field")
        required=$(jq -r .required <<<"$field")
        say "$help"
        while true; do
            text_prompt "$label ($(if [[ $required == true ]]; then printf \
                required; else
                printf optional
            fi))" "$(jq -r \
                '.default//""' <<<"$field")" || return
            value=$ANSWER
            [[ $required != true || ${value//[[:space:]]/} ]] && break
            say 'A value is required.'
        done
        args+=(--field "$id=$value")
    done 3<<<"$fields"
    options=$(collection "$BASE/milestones?state=open&per_page=100" | jq \
        '[.[]|{label:.title,value:.number}]') || return
    choose \
        "$(printf '%s' \
            'Milestone (explicit assignment required; choose ' \
            'current or next for detailed work)')" "$options" || return
    args+=(--milestone "$ANSWER")
    local milestone=$ANSWER
    options=$(collection "$BASE/labels?per_page=100" | jq \
        '[.[]|select(.name|startswith("area:"))|
            {label:.name,value:.name}]') || return
    choose 'Area (optional)' "$options" 1 || return
    [[ $ANSWER == none ]] || args+=(--area "$ANSWER")
    options=$(collection "$BASE/issues?state=open&per_page=100" | jq \
        --argjson ms "$milestone" -f \
        "$ROOT/github-issues/queries/epic_choices.jq") || return
    choose 'Parent Epic (0 is intentional standalone)' "$options" 1 || return
    args+=(--parent "$ANSWER")
    options=$(collection "$BASE/assignees?per_page=100" | jq \
        '[.[]|{label:.login,value:.login}]') || return
    choose 'Assignee' "$options" 1 || return
    [[ $ANSWER == none ]] || args+=(--assignee "$ANSWER")
    ui_write "${args[@]}"
}

# Collect the conditional resolution fields for one issue.
# Arguments/state: $1: issue number.
# Result: Runs the shared closure preview; cancellation makes no changes.
ui_close() {
    local number=$1 field
    local -a args=(issue close "$number")
    choose 'Resolution outcome' \
        '[{"label":"Done","value":"done"},
    {"label":"Not planned","value":"wont-do"},
    {"label":"Duplicate","value":"duplicate"},
    {"label":"Superseded","value":"superseded"},
    {"label":"Failed attempt (leave open)","value":"failed"}]' || return
    args+=(--outcome "$ANSWER")
    if [[ $ANSWER == duplicate || $ANSWER == superseded ]]; then
        prompt 'Target issue number (required)' || return
        args+=(--target "$ANSWER")
    fi
    for field in summary evidence docs followups; do
        text_prompt \
            "$field (required; explicit none allowed for docs/followups)" \
                || return
        args+=("--$field" "$ANSWER")
    done
    text_prompt \
        "$(printf '%s' \
            'Completion exception (optional; explain any ' \
            'unfinished criteria/blockers)')" || return
    [[ ! $ANSWER ]] || args+=(--exception "$ANSWER")
    ui_write "${args[@]}"
}

# Offer details and actions for a selected issue.
# Arguments/state: $1: issue number; keeps navigation in the same browse
# session.
# Result: Returns to the caller on back/cancel; operations retain their
# safeguards.
# Size exception: keep this cohesive command/format dispatch together so
# supported cases and their handling remain reviewable.
ui_item() {
    local number=$1 item body action
    while true; do
        say \
            "Issue #$number: 1 Details  2 Comments  3 Checklist" \
            "4 Comment  5 Edit body  6 Close  7 Reopen  8" \
            "Relationships  9 Metadata / links  0 Back"
        prompt 'Action' 0 || return
        action=$ANSWER
        case $action in
        0)
            return
            ;;
        1)
            ui_run issue view "$number"
            ;;
        2)
            ui_run issue view \
                "$number" --comments
            ;;
        3)
            ui_run issue view "$number" \
                --checklist
            ;;
        4)
            text_prompt 'Comment (required)' || continue
            printf '%s' "$ANSWER" >"$TMP/comment"
            ui_write issue comment "$number" --body-file "$TMP/comment"

            ;;
        5)
            item=$(get_issue "$number") || continue
            body=$(jq -r .body <<<"$item")
            text_prompt \
                'Body (enter :editor to preserve and edit existing content)' \
                "$body" || continue
            printf '%s' "$ANSWER" >"$TMP/body"
            ui_write issue edit "$number" --body-file "$TMP/body"

            ;;
        6)
            ui_close "$number"
            ;;
        7)
            ui_write issue reopen "$number"
            ;;
        8)
            ui_run issue tree --parent "$number" --all

            ;;
        9)
            ui_metadata "$number"
            ;;
        *)
            say 'Unknown selection.'
            ;;
        esac
    done
}

# Collect metadata or relationship changes for one issue.
# Arguments/state: $1: issue number.
# Result: Invokes ui_write; unsupported actions return 2.
ui_metadata() {
    local number=$1 action field
    local -a args
    prompt "$(printf '%s' \
        'Action: edit, link, unlink, block, unblock, depend, ' \
        'undepend')" \
        edit || return
    action=$ANSWER
    args=(issue "$action" "$number")
    case $action in
    edit)
        for field in title milestone assignee label remove-label toggle; do
            prompt "$field (optional; Enter to leave unchanged)" || return
            [[ ! $ANSWER ]] || args+=("--$field" "$ANSWER")
        done

        ;;
    link | unlink)
        prompt 'Parent Epic number' || return
        args+=(--parent "$ANSWER")

        ;;
    block | unblock)
        text_prompt 'Cause / explanation (required)' || return
        args+=(--summary "$ANSWER")

        ;;
    depend | undepend)
        prompt 'Blocking issue number (required)' || return
        args+=(--target "$ANSWER")

        ;;
    *)
        say 'Unknown action'
        return 2

        ;;
    esac
    ui_write "${args[@]}"
}

# Collect filters and navigate a stable issue-result snapshot.
# Arguments/state: No arguments; reads the session repository.
# Result: Returns on back/cancel; detail actions do not refresh the snapshot.
ui_browse() {
    local number data field
    local -a args=(issue list --all)
    for field in state milestone category area assignee parent search \
        created-after updated-after; do
        prompt "Filter $field (optional; Enter for any)" "$(if [[ \
            $field == state ]]; then
            printf open
        fi)" || return
        [[ ! $ANSWER ]] || args+=("--$field" "$ANSWER")
    done
    data=$(ui_run "${args[@]}" --format json) || return
    while true; do
        jq -r '.items[]|"#\(.number) [\(.state)] \(.title)"' <<<"$data"
        prompt 'Issue number to inspect, or 0 to return' 0 || return
        number=$ANSWER
        [[ $number != 0 ]] || return
        if [[ $number =~ ^[1-9][0-9]*$ ]] && jq -e --argjson n "$number" \
            'any(.items[];.number==$n)' <<<"$data" >/dev/null; then ui_item \
                "$number"; else
            say 'Select an issue from these results.'
        fi
    done
}

# Collect milestone or label operations one field at a time.
# Arguments/state: $1: milestone or label.
# Result: Read actions run directly; modifications use preview and
# confirmation.
# Size exception: preserve the ordered validation and execution stages of this
# operation instead of splitting solely for line count.
ui_resource() {
    local resource=$1 action number field
    local -a args
    prompt \
        "$resource action: list, view, create, edit, close, reopen$(if [[
            $resource == label ]]; then
            printf ', delete'
        fi)" list || return
    action=$ANSWER
    args=("$resource" "$action")
    if [[ $action != list && $action != create ]]; then
        prompt 'Number (milestone) or exact name (label)' || return
        args+=("$ANSWER")
        number=$ANSWER
    fi
    if [[ $action == create || $action == edit ]]; then
        if [[ $resource == milestone ]]; then
            for field in title description due; do
                text_prompt "$field ($(if [[ $field == due ]]; then printf \
                    optional; else
                    printf required-on-create
                fi))" || return
                [[ ! $ANSWER ]] || args+=("--$field" "$ANSWER")
            done
        else
            for field in name color description; do
                prompt "$field (name/color required on create)" || return
                [[ ! $ANSWER ]] || args+=("--$field" "$ANSWER")
            done
        fi
    fi
    if [[ $action == delete ]]; then
        prompt \
            "$(printf '%s' \
                'Destructive: retype exact label name to remove it ' \
                'from every issue')" || return
        args+=(--confirm-name "$ANSWER")
    fi
    if [[ $action == close ]]; then
        text_prompt 'Exception if open items remain (optional)' || return
        [[ ! $ANSWER ]] || args+=(--exception "$ANSWER")
    fi
    case $action in
    list | view)
        ui_run "${args[@]}"
        ;;
    *)
        ui_write \
            "${args[@]}"
        ;;
    esac
}

# Run the root menu until exit or input cancellation.
# Arguments/state: No arguments; requires initialized session state.
# Result: Handles operation errors at the menu boundary; returns zero on exit.
# Size exception: keep this cohesive command/format dispatch together so
# supported cases and their handling remain reviewable.
interactive() {
    local selection number
    while true; do
        say "GitHub Issue Manager — Repository: $REPO"
        say \
            '1 Create issue    2 Browse / search    3 Hierarchy' \
            '  4 Update issue'
        say '5 Close issue     6 Reopen issue      7 Milestones' \
            ' 8 Labels'
        say '9 Overview       10 Activity/reports 11 Comment     0 Exit'
        prompt 'Select an option' 0 || return 0
        selection=$ANSWER
        case $selection in
        0)
            return
            ;;
        1)
            (ui_create) || say \
                'Creation cancelled or failed.'
            ;;
        2)
            (ui_browse) || say \
                'Browse cancelled or failed.'
            ;;
        3)
            ui_run issue tree --all || :
            ;;
        4 | 5 | 6 | 11)
            prompt 'Issue number' || continue
            number=$ANSWER
            case $selection in
            4)
                (ui_item "$number") || :
                ;;
            5)
                (ui_close "$number") || :
                ;;
            6)
                ui_write issue reopen "$number" || :
                ;;
            11)
                text_prompt 'Comment' || continue
                printf '%s' "$ANSWER" >"$TMP/comment"
                ui_write issue comment "$number" --body-file "$TMP/comment" || :

                ;;
            esac

            ;;
        7)
            (ui_resource milestone) || say \
                'Milestone operation cancelled or failed.'
            ;;
        8)
            (ui_resource \
                label) || say 'Label operation cancelled or failed.'
            ;;
        9)
            ui_run status || :
            ;;
        10)
            prompt \
                "$(printf '%s' \
                    'Report: activity, blocked, unassigned, completed, ' \
                    'milestones, missing-resolutions, hierarchy, ' \
                    'workflow-check')" activity || continue
            if [[ $ANSWER == activity ]]; then ui_run activity || :; else
                ui_run report "$ANSWER" || :
            fi

            ;;
        *)
            say 'Choose 0–11.'
            ;;
        esac
    done
}
