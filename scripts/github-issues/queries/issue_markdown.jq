# Render issue summaries as a Markdown table.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
def esc: tostring | gsub("\\|"; "\\|") | gsub("\r?\n"; "<br>");
    "| ID | Title | State | Reason |\n|---|---|---|---|", (.[] | ("| " +
    (.number//"" | esc | tostring) + " | " + (.title//.name | esc | tostring)
    + " | " + (.state//"" | esc | tostring) + " | " + (.state_reason//"" | esc
    | tostring) + " |"))
