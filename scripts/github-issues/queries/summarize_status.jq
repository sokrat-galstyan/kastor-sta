# Summarize filtered issue JSON with repository-wide milestone metadata.
# Arguments: repo (name), ms (milestone array). Returns one status object.
# Grouping and sorting require O(n log n) work and O(n) temporary storage.
{
    schema_version: 1,
    repository: $repo,
    scope: "filtered issues; all repository milestones",
    total: length,
    open: ([.[] | select(.state == "open")] | length),
    closed: ([.[] | select(.state == "closed")] | length),
    closed_by_reason: (
        [.[] | select(.state == "closed")]
        | group_by(.state_reason)
        | map({reason: .[0].state_reason, count: length})
    ),
    open_by_label: (
        [.[] | select(.state == "open") | .labels[]?.name]
        | group_by(.) | map({label: .[0], count: length})
    ),
    blocked: ([
        .[] | select(.state == "open" and any(.labels[]?; .name == "blocked"))
    ] | length),
    unassigned: ([
        .[] | select(.state == "open" and (.assignees | length) == 0)
    ] | length),
    no_milestone: ([
        .[] | select(.state == "open" and .milestone == null)
    ] | length),
    milestones: {
        total: ($ms | length),
        open: ([$ms[] | select(.state == "open")] | length),
        items: $ms
    },
    recently_completed: (
        [.[] | select(.state_reason == "completed" and .state == "closed")]
        | sort_by(.closed_at) | reverse | .[:10]
    )
}
