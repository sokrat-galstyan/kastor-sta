# Select issue objects in a subtree, including the requested parent.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Traversal guards cycles; repeated paths may revisit nodes and edges.
def descendants($n; $seen): if ($seen | index($n))!=null then empty else $n,
    ($edges[] | select(.parent==$n) | .child as $c | descendants($c; $seen +
    [$n])) end; [descendants($parent; [])] as $ids | map(select(.number as
    $n | $ids | index($n)))
