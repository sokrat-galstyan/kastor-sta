# Render native parent, child, and blocker relationships for an issue.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
("Parents: " + (.parents | tojson | tostring) + "\nChildren: " + ([.children[]
    | {number, state, state_reason}] | tojson | tostring) + "\nBlocked by: "
    + ([.blocking_dependencies[] | {number, state, html_url}] | tojson |
    tostring))
