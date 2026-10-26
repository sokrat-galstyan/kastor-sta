# Select issues by their native parent relationship.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
[.[] | . as $i | select(if $p=="none" then all($edges[]; .child!=$i.number)
    else any($edges[]; .child==$i.number and (.parent | tostring)==$p) end)]
