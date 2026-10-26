# Render full details for each REST resource in an input array.
# No arguments. Output strings retain bodies and lazily supplied comments.
# Work and temporary output scale with the input and rendered text.

# Return the milestone progress paragraph, or an empty string for other kinds.
# Counts include GitHub's associated items; a zero total yields zero percent.
def milestone_progress:
    if has("open_issues") then
        (.open_issues + .closed_issues) as $total
        | (if $total == 0 then 0 else
            (100 * .closed_issues / $total | floor)
        end) as $percent
        | "Progress: \(.closed_issues)/\($total) closed (\($percent)%)\n"
    else
        ""
    end;

# Return supplied comments in their existing order, without fetching data.
def comment_details:
    if .comment_items then
        [.comment_items[] | "Comment by \(.user.login):\n\(.body)"]
        | join("\n\n")
    else
        ""
    end;

.[]
| "#\(.number // "") \(.title // .name)\n"
    + "State: \(.state // "n/a")  Reason: \(.state_reason // "n/a")\n"
    + "URL: \(.html_url // .url // "")\n"
    + "Milestone: \(.milestone.title // "none")\n"
    + "Labels: \([.labels[]?.name] | join(", "))\n"
    + "Assignees: \([.assignees[]?.login] | join(", "))\n"
    + "Created: \(.created_at // "n/a")  Updated: \(.updated_at // "n/a")\n"
    + "Due: \(.due_on // "none")\n"
    + milestone_progress
    + "\n\(.body // .description // "")\n"
    + comment_details
