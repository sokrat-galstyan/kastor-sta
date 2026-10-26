# Normalize issue timeline events into factual activity records.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
.[] | select((.created_at//"")>=$since) | {number:$n, event:.event,
    at:.created_at, actor:(.actor.login//.user.login), body:.body}
