# Find workflow metadata and parent/child inconsistencies in issue data.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
. as $all | [ (.[] | . as $i | ([.labels[]?.name | select(.=="task" or
    .=="research" or .=="bug" or .=="epic")]) as $cats | (if ($cats |
    length)==0 then {number, warning:"Missing category label"} else empty
    end), (if ($cats | length)>1 then {number,
    warning:"Mixed category labels; review intent (legacy backlog allows this)"}
    else empty end), (if .milestone==null then {number,
    warning:"Missing milestone; workflow calls for explicit assignment"} else
    empty end), (if .state=="open" and .milestone.state=="closed" then
    {number, warning:"Open issue in closed milestone"} else empty end), (if
    .state=="closed" and .state_reason=="completed" and ((.body//"") |
    test("(?m)^[-*] \\[ \\]")) then {number,
    warning:"Completed with unchecked criteria"} else empty end)), ($edges[]
    | . as $e | ($all[] | select(.number==$e.parent)) as $p | ($all[] |
    select(.number==$e.child)) as $c | (if $p.number==$c.number then
    {number:$c.number, warning:"Self-parent relationship"} else empty end),
    (if $p.state=="closed" and $c.state=="open" then {number:$p.number,
    warning:"Closed parent with open child", child:$c.number} else empty end)
   , (if $p.milestone.number!=$c.milestone.number then {number:$c.number,
    warning:"Parent/child milestone mismatch", parent:$p.number} else empty
    end))]
