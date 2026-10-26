# Attach top-level Markdown checkboxes with their 1-based body line numbers.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Work and temporary output scale with the input and rendered text.
. + {checklist:[(.body//"" | split("\n") | to_entries[]) | select(.value |
    test("^[-*] \\[([ xX])\\]")) | {line:(.key + 1), text:.value}]}
