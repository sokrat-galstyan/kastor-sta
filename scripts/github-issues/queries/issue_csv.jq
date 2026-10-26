# Render issue fields as CSV with quoted values and a header row.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
(["number", "title", "state", "reason", "milestone", "labels", "url"] |
    @csv), (.[] | [.number//"", .title//.name, .state//"",
    .state_reason//"", .milestone.title//"", ([.labels[]?.name] | join(";"))
   , .html_url//.url//""] | @csv)
