# Check whether a proposed parent link would create a hierarchy cycle.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Traversal guards cycles; repeated paths may revisit nodes and edges.
. as $edges | def reaches($n; $seen): if $n==$parent then true elif ($seen |
    index($n))!=null then false else any($edges[] | select(.parent==$n);
    reaches(.child; $seen + [$n])) end; reaches($child; []) | not
