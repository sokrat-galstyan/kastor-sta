# GitHub Issue Manager

Run `./scripts/github-issues.sh` for a guided terminal menu. Run with a command
for automation; commands never prompt. **Writes require `--yes`**. Use
`--dry-run` to validate against GitHub and preview without modifying anything.
This tool does not bootstrap a tracker or create labels implicitly.

The project's [workflow](workflow.md) and committed issue forms remain the
source of truth.

## Installation and repository selection

On Ubuntu 24.04:

```bash
sudo apt install bash git gh jq coreutils
gh auth login
./scripts/github-issues.sh --help
./scripts/github-issues.sh --repo sokrat-galstyan/kastor-sta issue list
```

Bash 4.4+, jq 1.6+, GNU date, and GitHub CLI with `gh api --paginate --input`
are required. The transport pins REST API version **2026-03-10** and targets
github.com. GitHub Enterprise and older API deployments are not supported.

With no `--repo`, origin must be a github.com SSH or HTTPS remote. An interactive
session can ask for OWNER/REPO when origin is unavailable; command mode fails
instead. A renamed repository must be selected by its canonical name. Assets
are located relative to the executable, not the caller's working directory.
`GH_REPO` and `GH_HOST` do not override the explicit target.

Read commands need only repository visibility and Issues read permission;
there is no blanket write-permission or authentication-status preflight. The
installed gh may still require login even for public repositories: anonymous
HTTP transport is not implemented. Writes need appropriate Issues write
permission. Token scopes, organization policies and feature availability can
still cause a request to fail after preflight. Never put tokens in arguments.

## Interactive mode

```text
GitHub Issue Manager — Repository: sokrat-galstyan/kastor-sta
1 Create issue    2 Browse / search    3 Hierarchy    4 Update issue
5 Close issue     6 Reopen issue      7 Milestones   8 Labels
9 Overview       10 Activity/reports 11 Comment     0 Exit
```

Creation prompts for one field at a time, showing form help and required or
optional status. Milestones, areas, parent Epics and assignees come from GitHub.
Numbered choices accept `/text` to search. Enter accepts a displayed default;
`:cancel` cancels. Optional choices have an explicit zero/none selection.
`:editor` opens `$VISUAL`, `$EDITOR`, or `vi` for multiline text. The editor must
be a single executable name/path; use a wrapper script if it needs arguments.
Shell fragments are never evaluated.

Every mutation goes through validation and a full dry-run preview. Type `edit`
to revise an earlier captured answer, `yes` to validate again and apply, or
`no` to cancel. Ctrl+C exits safely, but cannot undo a request already accepted
by GitHub. An error returns to the root menu. Browse results let you select an
issue and view, comment, edit, close, reopen, or manage metadata/relationships;
returning retains the same result snapshot. Rerun browse to refresh it.

## Forms and issue creation

The checked-in JSON adapter mirrors form IDs, labels, required flags, help,
default content and title prefixes. Its source hashes are checked before
form writes. If a form changes, review and update the adapter together
with the form; an out-of-date adapter fails closed. No YAML parser is needed.

| Category | Required field IDs | Optional field IDs |
|---|---|---|
| task | `goal`, `done-when` | `notes` |
| research | `question`, `timebox`, `output` | `sources` |
| bug | `what`, `reproduce`, `version` | `environment` |
| epic | `goal`, `done-when` | none |

The Epic form is an explicit CLI default, since no checked-in Epic issue form
exists. Research defaults cover answers with public sources, limitations,
applicable supporting artifacts and experiments, and resulting decisions.
The Bug's **What happened** field includes expected behavior;
it has no separate expected-behavior section. Empty checkboxes and placeholder-only
required values are rejected. Replace the Task form's blank checklist starter.
Research outputs and time-box handling follow the
[research guide](research.md); a focused main question may have explicit
supporting questions. Non-interactive field values are supplied explicitly,
including required fields with defaults; interactive mode offers those
defaults. Title prefixes are offered interactively and are not silently
prepended to explicit command-line titles.

```bash
./scripts/github-issues.sh issue create \
  --category task --title '[Task] Document propagation requirements' \
  --field 'goal=Define the requirements for serial propagation' \
  --field-file done-when=/tmp/acceptance.md \
  --milestone 2 --area docs --parent 10 --assignee YOUR_LOGIN --dry-run
# Review the preview, then replace --dry-run with --yes to create.
```

Numbers here are examples; select real repository resources first. Every issue,
including a child, gets an explicit open milestone. A parent must be an open
Epic in that milestone. `--parent none` is an intentional standalone choice.
Areas are optional existing labels; `--area docs` and `--area area:docs` are
equivalent. Repeated `--label NAME` adds existing labels. No future area is
created automatically. Use `label create` separately for a new area.

Create an Epic first, then create or attach children. There is no batch
Epic-plus-children transaction. Successful creation followed by failed linking
reports the new issue number and a resume command; do not create the issue again.
The rule to detail only the current/next milestone is a human decision because
the workflow does not identify those milestones programmatically.

## Read, search and export

```bash
./scripts/github-issues.sh issue list --state all --format titles
./scripts/github-issues.sh issue list --milestone 'M1 Research cycle' --category research
./scripts/github-issues.sh issue list --area docs --state closed --reason completed
./scripts/github-issues.sh issue list --parent none --no-assignee
./scripts/github-issues.sh issue view 15 --comments
./scripts/github-issues.sh issue view 15 --resolution --format json
./scripts/github-issues.sh issue view 15 --checklist
./scripts/github-issues.sh issue view 15 --relationships --format json
./scripts/github-issues.sh issue list --format csv --all > /tmp/issues.csv
./scripts/github-issues.sh issue list --format markdown --output /tmp/issues.md
```

Issue filters: `--state open|closed|all`, milestone number or exact title,
`--label`, `--category` (category label), `--area`, `--assignee` (login),
`--author`, `--parent NUMBER|none`, `--blocked`, `--no-milestone`,
`--no-assignee`, `--search` (case-insensitive literal title/body substring),
`--created-after`, `--updated-after`, and `--reason completed|not_planned|duplicate`.
Use actual logins, not `@me`. Distinct filters are ANDed; repeated labels also
use AND. Other repeated options are rejected. Contradictory milestone or
assignee choices are rejected. Date bounds include midnight UTC on the given
day. Search is not GitHub's query language and has no 1,000-result search cap.

Sort issues with `--sort number|title|created|updated|comments` and
`--direction asc|desc` (defaults: number descending). State defaults to open.
REST handles state, labels, milestone, assignee, creator and updated-since;
remaining filters, stable sorting and PR exclusion are local.

All REST pages (100 entries per page) are read before local filters and display
limits. `--limit N` defaults to 100 returned matches; `--all` removes the display
limit. These options are mutually exclusive. This is correctness-oriented and
can be expensive for large repositories; the limit does not cap API requests.
Truncation is announced on stderr. JSON includes both `total_matches` and `count`.

| Command | Formats |
|---|---|
| issue list/view, milestone list/view, label list | titles, compact, table, details, json, csv, markdown |
| issue tree | tree, table, details, markdown (text tree), json (graph) |
| status | table, compact, details, markdown, json |
| activity | table, compact, details, markdown, json |
| issue/milestone reports | same as respective lists |
| hierarchy/workflow audits | table, compact, details, markdown, json |

`--help` (or `-h`) shows a short overview at the root, a command list for
resource groups, and focused usage, options, and examples for each subcommand.
For example, `issue --help` lists issue commands and `issue close --help`
explains resolution fields and outcomes. `help issue close` is equivalent.
Use `help filters` for issue filters and `help output` for export formats.
Help reads local text pages and needs no GitHub authentication or connection.
Unsupported option combinations are rejected rather than silently passed to gh. No ANSI color is emitted; `--no-color` is accepted.
Tables expand columns instead of truncating titles and escape embedded newlines
as `\n`. Details show full Markdown bodies. Dates are UTC; machine output keeps
GitHub ISO 8601 strings. Generic milestone/label CSV uses the same issue-oriented
columns; use JSON/details for due dates, colors and additional resource metadata.

JSON list schema: `{schema_version:1,repository,kind,total_matches,count,items}`.
`items` retains REST resource objects; new GitHub fields may appear. Tree JSON
has `issues` and `edges` (repository-local parent/child numbers). Status JSON has
scoped counts, `closed_by_reason`, `open_by_label`, milestone objects and ten
recent completed issues. Activity JSON contains timeline event records.
Audit JSON contains `warnings`. These envelopes are stable version 1; native
GitHub object fields follow the REST schema.

Diagnostics/previews go to stderr. Redirection receives only output. `--output`
writes a complete temporary file then installs it atomically; it refuses existing
files unless `--force`. No partial export is installed if a request fails. Without
force, an atomic hard-link installation also protects against a concurrent file
creator. Human-format Markdown escapes table pipes/newlines; CSV uses jq's
RFC-style quoting, including embedded quotes and newlines.

## Editing and relationships

```bash
./scripts/github-issues.sh issue edit 15 --field 'goal=Updated objective' --dry-run
./scripts/github-issues.sh issue edit 15 --toggle 2 --dry-run
./scripts/github-issues.sh issue edit 15 --body-file /tmp/body.md --dry-run
./scripts/github-issues.sh issue edit 15 --label blocked --remove-label area:docs --dry-run
./scripts/github-issues.sh issue edit 15 --milestone 2 --assignee alice --dry-run
./scripts/github-issues.sh issue edit 15 --milestone none --assignee none --dry-run
./scripts/github-issues.sh issue link 15 --parent 10 --dry-run
./scripts/github-issues.sh issue link 15 --parent 12 --move --dry-run
./scripts/github-issues.sh issue unlink 15 --parent 10 --dry-run
./scripts/github-issues.sh issue block 15 --summary 'Waiting for parser API' --target 16 --dry-run
./scripts/github-issues.sh issue unblock 15 --summary 'API agreed and verified' --dry-run
./scripts/github-issues.sh issue depend 15 --target 16 --dry-run
./scripts/github-issues.sh issue undepend 15 --target 16 --dry-run
```

Structured editing supports a unique exact `## Label` or `### Label` section;
it preserves other headings and their content. Ambiguous, missing, or fenced
layouts fail with instructions to edit the whole body. No arbitrary Markdown
parser is claimed. `--toggle N` addresses the Nth top-level `- [ ]`/`* [ ]`
checkbox in body order; use `view --checklist` first. Nested checkboxes are not
supported. Existing body and proposed changes are previewed, and updated_at is
rechecked before the PATCH. This is best-effort concurrency protection, not
an atomic compare-and-swap. Changing milestone may intentionally create a
hierarchy mismatch; run `report hierarchy` and update the related issues.

Assignee edits replace the assignment with one login, or clear it with `none`.
Label edits preserve unrelated labels; replacements are checked on read-back.
Native links use database IDs, not issue numbers. Cycles, duplicate links,
self-parenting, accidental reassignment, and milestone mismatches are rejected.
Dependency addition checks the native blocking graph for cycles. All relationship
validation is limited to this repository and fails on cross-repository graphs.
Unblocking requires a cause and removes the label; it does not infer that
blockers are resolved or remove dependency edges. `undepend` is a separate action.

## Resolution and closure

```bash
./scripts/github-issues.sh issue close 15 \
  --outcome done --summary 'Documented propagation requirements' \
  --evidence 'Commit abc123; requirements checks passed' \
  --docs 'docs/requirements/0.1.md' --followups none --dry-run
./scripts/github-issues.sh issue reopen 15 --dry-run
```

The CLI generates the exact field names in the [resolution template](workflow.md#resolution-comment-template).
Required inputs are outcome, summary, evidence, docs and followups. `none` can
be stated explicitly where applicable; it is not substituted silently.

| CLI outcome | Project comment | GitHub state/reason |
|---|---|---|
| done | done | closed / completed |
| wont-do | won't do | closed / not_planned |
| duplicate + target | duplicate of #N | closed / duplicate, canonical REST ID |
| superseded + target | superseded by #N | closed / not_planned |
| failed | progress comment (not a resolution) | remains open |

Completion checks the current state, body checkboxes, blocked label, native
children and native blockers. An Epic without checked criteria also requires
review. An unfinished completion requires `--exception 'specific justification'`,
which is recorded in the resolution. Not-planned closure can retain unfinished
criteria. No tool can prove that evidence is true or a prose objective is done.

The sequence is validate → preview → approve → post comment → close → read back.
Already-closed issues are never blindly commented on. Use `view --resolution`
to inspect a real complete structured comment (not just a heading or blank form).
If the comment succeeds but closing fails, retry with **identical resolution
fields** after inspecting the current issue. The exact existing comment is
reused. A changed summary is a different comment. Concurrent identical closers
can still race; serialize write automation. No write is automatically retried.
Unsupported dependency/closure APIs cause an explicit failure; nothing is
silently reported as successfully closed.

## Milestones and labels

```bash
./scripts/github-issues.sh milestone list --state all --format details
./scripts/github-issues.sh milestone list --overdue --incomplete --sort due_on
./scripts/github-issues.sh milestone view 2
./scripts/github-issues.sh milestone create --title 'M4 Serial engine' \
  --description 'Implement and validate serial timing propagation' --due 2026-12-01 --dry-run
./scripts/github-issues.sh milestone edit 2 --due none --dry-run
./scripts/github-issues.sh milestone close 2 --exception 'Remaining work deferred intentionally' --dry-run
./scripts/github-issues.sh milestone reopen 2 --dry-run
./scripts/github-issues.sh label create --name area:engine --color c5def5 --description 'Timing engine' --dry-run
./scripts/github-issues.sh label edit area:engine --color aabbcc --dry-run
./scripts/github-issues.sh label delete obsolete --confirm-name obsolete --dry-run
```

Milestone filters include state, literal title search, due-before/due-after
(exclusive dates), overdue (open and due before now), no-due, incomplete and
complete. Zero-total milestones count as having all associated items closed.
Sort by number/title/due_on/created/updated; default number ascending. Progress
is `closed / (open + closed)`, zero when total is zero. GitHub milestone counters
include PRs; issue-only status excludes PRs. Closing a milestone lists open
associated items and requires an explicit exception if any remain. It never
closes issues or Epics automatically. Kastor milestone descriptions are required
on creation and cannot be emptied through this tool.

Colors are six hex digits. Label create/rename checks duplicates; delete requires
both `--yes` and an exact `--confirm-name`. Deletion removes the label from all
issues. There is no inferred or background label maintenance.

## Overview, activity, hierarchy and audits

```bash
./scripts/github-issues.sh status --milestone 'M1 Research cycle' --format json
./scripts/github-issues.sh issue tree --parent 10 --depth 2
./scripts/github-issues.sh activity --since 2026-10-01 --format json
./scripts/github-issues.sh report completed --last 30d
./scripts/github-issues.sh report blocked
./scripts/github-issues.sh report unassigned
./scripts/github-issues.sh report milestones --incomplete
./scripts/github-issues.sh report missing-resolutions
./scripts/github-issues.sh report hierarchy
./scripts/github-issues.sh report workflow-check
```

Status counts each issue once regardless of hierarchy. Milestone totals always
cover the repository; issue counts honor filters, and the scope is labeled.
Open-by-label groups can overlap and must not be summed as distinct issues.
No current milestone or GitHub Projects status is guessed. Closed does not
mean Completed; reasons are kept separate.

Tree uses native sub-issues, includes the selected parent and descendants,
handles depth limits, and identifies cycles, including disconnected components.
Filtered-out nodes do not appear as connectors, so filters can split trees.
A tree has no issue count limit; use depth or filters. Native completion counts
are labeled as closed children, not proof of completed work. Cross-repository
children produce an explicit error rather than an incorrect number-based tree.

Activity uses issue timelines and explicit creation times. It does not infer a
body edit from updated_at, does not promise events GitHub does not expose, and
can include reopened/commented/milestoned/assigned and other native event types.
`--since` is inclusive UTC; `--last Nd` defaults to seven days. Completed reports
use actual `closed_at` and `state_reason=completed`.

Hierarchy/workflow audits warn about missing/mixed category labels, missing
milestones, open work in closed milestones, completed issues with unchecked
criteria, closed parents with open children, self-links and milestone mismatch.
Mixed category labels are a review warning, not automatically invalid: the
legacy bootstrap used some intentionally. The workflow audit is a partial
mechanical audit; use `missing-resolutions` alongside it, and review research
quality, evidence, commit/test practices and milestone timing manually.
Reports never repair resources. Blocking dependencies can be inspected with
`issue view N --relationships`; the blocked list itself is label-based.

## Reusing and extending configuration

`--config /path/adapter.json` loads JSON data, never shell code. Kastor's adapter
is automatically selected only for `sokrat-galstyan/kastor-sta`. Other repositories
can read/manage generic resources without an adapter; guided forms, structured
field edits and Epic/dependency policy helpers need one. Start with
`scripts/github-issues/kastor.json`, adjust forms/labels/requiredness/help/defaults,
`epic_label`, `blocked_label`, and `milestone_description_required`, and verify
against your own source forms. The schema has `schema:1` and a `forms` object;
each form has `title_prefix`, `labels`, and `fields` with unique `id`, `label`,
`required`, `help` and `default` values. Source hashes in the bundled adapter are
a local drift guard; keep custom adapters consistent with their source forms.

The supplied workflow audit, area prefix, resolution protocol, interactive
Epic discovery and category filters implement the documented lightweight
label-based convention. Arbitrary repository-specific resolution protocols,
GitHub Projects fields, and native issue-type configuration are not interpreted.
Use the whole-body editor for unfamiliar layouts. Do not assume an adapter makes
an unrelated workflow compliant without reviewing these shared defaults.

## Failures and recovery

Exit codes: 0 success (including dry-run/cancel at a menu), 2 input/configuration
error, 3 API read failure, 4 write or verification failure, 130 interrupt,
143 termination. Dependency/tool failures can retain their own nonzero codes.
401 asks for authentication; 403 covers permissions/policy/secondary limits;
404 means missing **or inaccessible**; 409 conflict; 422 validation; 429 rate limit;
network/5xx/unsupported endpoints give a conservative failure. Raw gh error
payloads are not printed, to avoid leaking request/private content.

There are no automatic retries. After ambiguous create/comment failures, inspect
GitHub before repeating; the server may have accepted the request. Successful
stages are reported to stderr and are not rolled back. A successful read-back is
required before claiming an issue state or relationship was verified. This is
not an atomic multi-request system or a persistent transaction journal.
