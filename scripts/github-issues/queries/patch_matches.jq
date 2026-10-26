# Compare issue read-back fields with the requested update payload.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
. as $i | $p | to_entries | all(. as $v | if .key=="labels" then
    ([$i.labels[].name] | sort)==($v.value | sort) elif .key=="assignees" then
    ([$i.assignees[].login] | sort)==($v.value | sort) elif .key=="milestone"
    then $i.milestone.number==$v.value elif .key=="duplicate_issue_id" then
    true else $i[.key]==.value end)
