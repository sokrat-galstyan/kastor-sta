# Render issue summary columns as tab-separated rows for table formatting.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
(["ID", "STATE", "MILESTONE", "LABELS", "TITLE"] | @tsv), (.[] | [.number
   , .state, .milestone.title//"none", ([.labels[]?.name] | join(",")),
    .title] | @tsv)
