# Replace one unambiguous level-two or level-three Markdown section.
# Arguments: body, label and replacement value. Input is unused.
# Returns the complete body or raises an error when the heading is ambiguous.
# Work and temporary storage scale with the supplied Markdown body.
($body | split("\n")) as $lines
| [
    $lines | to_entries[]
    | select(.value == ("### " + $label) or .value == ("## " + $label))
    | .key
] as $hits
| if ($hits | length) != 1 then
    error("Ambiguous/absent heading; use --body-file")
else
    $hits[0] as $start
    | ([
        $lines | to_entries[]
        | select(.key > $start and (.value | test("^#{1,6} ")))
        | .key
    ][0] // ($lines | length)) as $end
    | ($lines[:($start + 1)] + ["", $value, ""] + $lines[$end:])
    | join("\n")
end
