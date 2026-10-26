# Find unfinished work that prevents closing an issue as completed.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
(.body//"" | test("(?m)^[-*] \\[ \\]")) or any(.labels[]?; .name=="blocked")
    or (any(.labels[]?; .name=="epic") and ((.body//"" |
    test("(?m)^[-*] \\[[xX]\\]")) | not))
