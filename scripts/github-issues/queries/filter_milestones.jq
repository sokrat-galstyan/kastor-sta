# Filter and sort milestones by state, deadline, and completion.
# Parameters are supplied with jq --arg/--argjson by the calling shell
# function. Consumes its JSON input and emits only the transformed result.
# Collection scans are linear; sorting/grouping requires O(n log n) work.
[.[] | select($state=="all" or .state==$state) | select($search=="" or (.title
    | ascii_downcase | contains($search | ascii_downcase))) |
    select($before=="" or (.due_on!=null and .due_on<($before +
    "T00:00:00Z"))) | select($after=="" or (.due_on!=null and .due_on>($after
    + "T23:59:59Z"))) | select($overdue=="" or (.state=="open" and
    .due_on!=null and .due_on<$today)) | select($nodue=="" or .due_on==null) |
    select($inc=="" or .open_issues>0) | select($complete=="" or
    .open_issues==0)] | sort_by(.[$sort]) | if $dir=="desc" then reverse else
    . end
