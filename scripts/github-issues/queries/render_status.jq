# Render aggregate issue and milestone status as plain text.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
("Repository: " + (.repository | tostring) + "\nScope: " + (.scope | tostring)
    + "\nIssues: " + (.total | tostring) + " total; " + (.open | tostring) +
    " open; " + (.closed | tostring) + " closed\nMilestones: " +
    (.milestones.total | tostring) + " total; " + (.milestones.open |
    tostring) + " open\nBlocked: " + (.blocked | tostring) + "  Unassigned: "
    + (.unassigned | tostring) + "  No milestone: " + (.no_milestone |
    tostring) + "\nClosed by reason: " + (.closed_by_reason | tojson |
    tostring) + "\nOpen by label: " + (.open_by_label | tojson | tostring))
