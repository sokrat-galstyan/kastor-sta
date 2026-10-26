# Recognize a complete resolution in an issue-comment object.
# Input: object with a Markdown body; output: boolean. Missing bodies fail.
# Multiline field values are accepted. Work is linear in body length for
# ordinary Markdown; regex matching can depend on the input layout.
def resolution_valid:
    (.body // "") as $body
    | ($body | test("(?m)^## Resolution[ \\t]*$"))
        and all(
            ["Outcome", "Summary", "Evidence", "Docs updated", "Follow-ups"][];
            . as $field
            | try (
                $body
                | capture(
                    "(?s)\\*\\*" + $field
                    + ":\\*\\*(?<value>.*?)(?=\\*\\*[A-Za-z -]+:\\*\\*|$)"
                )
                | .value | test("\\S")
            ) catch false
        )
        and ($body | test(
            "\\*\\*Outcome:\\*\\*[ \\t]*"
            + "(done|won't do|duplicate of #[1-9][0-9]*"
            + "|superseded by #[1-9][0-9]*)[ \\t]*(\\r?\\n|$)"
        ));
