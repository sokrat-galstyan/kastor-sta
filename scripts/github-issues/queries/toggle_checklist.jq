# Toggle a selected top-level Markdown checkbox without replacing its text.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary storage scale with the supplied Markdown body.
($body | split("\n")) as $lines | [$lines | to_entries[] | select(.value |
    test("^[-*] \\[[ xX]\\] .+")) | .key] as $items | if $n>($items | length)
    then error("Checklist item does not exist") else $items[$n-1] as $i |
    $lines | .[$i]=(if .[$i] | test("^[-*] \\[ \\]") then .[$i] |
    sub("\\[ \\]"; "[x]") else .[$i] | sub("\\[[xX]\\]"; "[ ]") end) |
    join("\n") end
