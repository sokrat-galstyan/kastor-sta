# Build parent-choice labels for Epics matching the requested milestone.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
[.[] | select(.milestone.number==$ms and any(.labels[]?; .name=="epic")) |
    {label:(("#" + (.number | tostring) + " ") + .title), value:.number}]
