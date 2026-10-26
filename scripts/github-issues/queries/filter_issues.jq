# Filter a REST issue array and deduplicate it by repository-local number.
# The caller supplies state, labels, ms, no_ms, no_as, assignee, author,
# search, created, updated and reason. Empty strings disable each filter.
# Scans scale with input text and label comparisons; deduplication sorts.
[
    .[]
    | select(has("pull_request") | not)
    | select($state == "all" or .state == $state)
    | select(
        . as $i
        | ($labels | split(",") | map(select(length > 0)))
        | all(. as $l | $i.labels | any(.name == $l))
    )
    | select($ms == "" or (.milestone.number | tostring) == $ms)
    | select($no_ms == "" or .milestone == null)
    | select($no_as == "" or (.assignees | length) == 0)
    | select($assignee == "" or any(.assignees[]?; .login == $assignee))
    | select($author == "" or .user.login == $author)
    | select(
        $search == ""
        or ((.title + "\n" + (.body // ""))
            | ascii_downcase | contains($search | ascii_downcase))
    )
    | select($created == "" or .created_at >= ($created + "T00:00:00Z"))
    | select($updated == "" or .updated_at >= ($updated + "T00:00:00Z"))
    | select($reason == "" or .state_reason == $reason)
]
| unique_by(.number)
