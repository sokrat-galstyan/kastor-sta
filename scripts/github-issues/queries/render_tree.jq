# Render filtered native relationships as text while guarding graph cycles.
# Arguments: items (issues), edges (parent/child pairs), depth (display bound).
# Input is unused. Repeated graph paths can revisit nodes; scans and output
# grow with those paths. Visited-node arrays bound recursion through cycles.

def walk($number; $seen; $level):
    ($items[] | select(.number == $number)) as $issue
    | (
        ("  " * $level)
        + "#\($number) [\($issue.state)/\($issue.state_reason // "-")] "
        + ($issue.title | tostring)
        + (if $issue.sub_issues_summary.total > 0 then
            if $issue.sub_issues_summary.completed != null then
                " (\($issue.sub_issues_summary.completed)/"
                + "\($issue.sub_issues_summary.total) children closed)"
            else
                " (\($issue.sub_issues_summary.total) children; "
                + "completion count unavailable)"
            end
        else
            ""
        end)
    ),
    if ($seen | index($number)) != null then
        ("  " * ($level + 1)) + "[cycle detected]"
    elif $level >= $depth then
        ("  " * ($level + 1)) + "[depth limit]"
    else
        ($edges[] | select(.parent == $number) | .child) as $child
        | walk($child; $seen + [$number]; $level + 1)
    end;

def reachable($number; $seen):
    if ($seen | index($number)) != null then
        empty
    else
        $number,
        ($edges[] | select(.parent == $number) | .child as $child
            | reachable($child; $seen + [$number]))
    end;

[$items[].number] as $ids
| [
    $items[] | .number as $number
    | select(all(
        $edges[];
        .child != $number
        or (.parent as $parent | $ids | index($parent)) == null
    ))
    | .number
] as $roots
| [$roots[] as $root | reachable($root; [])] as $reachable
| (
    $roots[] as $number
    | ($items[] | select(.number == $number)
        | "Milestone: \(.milestone.title // "none")"),
    walk($number; []; 0)
), (
    ($ids[] | select(. as $number | $reachable | index($number) | not))
        as $orphan
    | "[Disconnected cycle/component]", walk($orphan; []; 0)
)
