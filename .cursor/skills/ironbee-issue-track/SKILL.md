---
name: ironbee-issue-track
description: Work an issue-tracker ticket — read it, verify the code changes against its acceptance criteria, and report the outcome + captured evidence back to the ticket. Also handles read-only intake (`read:<ref>`), report-only (`report:<ref>`), and ad-hoc integration operations (search / create bug / transition / comment). Use when the user types /ironbee-issue-track or asks to work an integration ticket.
---

# IronBee Track

You (the main agent) drive the integration tools DIRECTLY — **run this skill INLINE, in THIS
conversation; never delegate it to a sub-agent via `Task`** (a sub-agent runs as a separate
session, so its integration calls and the attribution harvest land elsewhere and register nothing).
Integration operations are NOT a verification cycle: integration calls open no cycle, gate nothing, and
count as no cycle's evidence. **The provider section(s) at the bottom are your tool map** —
which tools implement read / search / report, the issue-ref shape, and search guidance.

## Provider (optional leading first word)

The arguments may begin with a provider name (`github`, case-insensitive) — a first-class
selector separate from the ref, valid for every mode (including ref-less ad-hoc). If the FIRST word
is one of those, that's the provider: use ONLY its section's tools and drop the word from the rest.
Otherwise decide from the provider sections present in THIS file: exactly ONE → use it; MULTIPLE →
**ask the user which provider** before proceeding. Echo the chosen provider in your reply
(`linear ENG-123 — <summary>`).

## Mode (dispatch on the arguments)

- **`read:<ref>`** → intake only (below). STOP after the digest.
- **`report:<ref>`** → report-only (below). It reports the LAST verification of this session;
  none ran → say "nothing to report — verify first". NEVER re-verify just to report (a re-run
  might not reproduce the verified state).
- **A bare `<ref>`** (issue key like `PROJ-123`, or a noun phrase naming a ticket) → the FULL
  LOOP: read → verify (the /ironbee-verify flow, using the ticket's acceptance criteria as the
  scenario; an optional `scenario:<name> [args:{...}]` tail applies verbatim) → report.
- **An imperative integration instruction** ("create a bug for …", "find my open QA tickets") →
  ad-hoc: the single matching integration operation.

## Resolving `<ref>`

Exact key (the provider section's ref shape) → use directly. Free text → the provider's SEARCH
tool (see its search guidance). 0 matches → say so; 1 → proceed (echo `KEY — summary`); N → ask
the user which one.

## read — ticket intake

Read the key with the provider's READ tool; digest: summary, status, type, acceptance criteria
(verbatim), key constraints, attachment names. No writes.

## report — post the verification outcome

1. Recover this cycle's evidence: `echo '{}' | ironbee hook verification-artifacts` (session_id from the
   session context if the environment doesn't resolve it) — prints
   `{"verification_id", "paths", "timeline_link"}`: the last verdict-closed cycle's captured
   artifacts + a console deep-link to the run. `{"error": …}` → nothing to report; say so and stop
   (the error still carries a `timeline_link`).
2. Post with the provider's REPORT tool: the key, the verdict `outcome` (pass/fail — the tool
   badges it), a `summary` describing WHAT was verified + issues (**don't restate pass/fail** in
   the body — the badge covers it), the `paths` as artifacts, AND the `timeline_link` appended as
   a Markdown link (renders clickable): `🔗 [View in IronBee](<timeline_link>)`. Write tools unavailable → show the composed report instead.

## Write gating

A provider's evidence/outcome/report tools exist only when the project enables integration writes.
When a write tool is missing, do the read part and say writes are disabled — never fake an
outcome.

<!--IRONBEE:INTEGRATIONS-->
## GitHub (configured integration — via the `gh` CLI)

GitHub is **CLI-delivered**: you (the main agent) drive it through the `gh` GitHub CLI using your
**terminal / Bash** tool — there is NO `github_*` MCP tool domain. Run this skill INLINE, never via a
`Task` sub-agent (a sub-agent runs as a separate session, so its `gh` calls and the attribution
harvest land elsewhere and register nothing). `gh` is already authenticated (that is what makes this
integration active); it targets the current repo's remote by default, or an explicit
`--repo <owner>/<name>`.

| Operation | `gh` command | Notes |
|---|---|---|
| read | `gh issue view <n> --json number,title,body,state,labels,assignees,milestone,comments` | full issue as JSON; acceptance criteria live in `body` |
| search | `gh issue list --search "<query>" --json number,title,state,labels` | GitHub search syntax; add `--repo <owner>/<name>` to scope |
| comment (write) | `gh issue comment <n> --body "<markdown>"` | posts a Markdown comment |
| outcome (write) | `gh issue close <n>` / `gh issue reopen <n>` / `gh issue edit <n> --add-label "<label>"` | |
| report (write) | `gh issue comment <n> --body "<verification report + 🔗 link>"` | GitHub has no report-verification tool — a comment IS the report |

**Issue-ref shape**: a bare number (`123`), `#123`, or a qualified `owner/repo#123`. A qualified ref
sets the repo (pass it as `--repo <owner>/<name>`); a bare number targets the current repo (`gh`'s
default remote). Note `#123` can be an ISSUE **or** a PULL REQUEST on GitHub (shared number space) —
`gh issue view` errors on a PR number; if it does, the ref was a PR, not an issue (report that,
don't guess).

**Search hints**: GitHub search syntax — `in:title <words>`, `state:open`, `label:"bug"`,
`assignee:@me`, `is:issue`. Keep it narrow — you want ≤ a handful of candidates. `gh issue list
--search` already scopes to the current repo's issues; use `gh search issues "<query>"` when you
need to search across repos.

**Report (GitHub specifics)**: GitHub's issue API has **no file-attach endpoint**, so you cannot
upload the screenshot/recording files themselves. Post the verification summary as a comment and
reference the captured evidence via the **`🔗 [View in IronBee](<timeline_link>)`** link from
`ironbee hook verification-artifacts` (that link is the portal to the artifacts). You may note the
artifact COUNT in the comment, but do NOT paste the local `paths` — they are not reachable by a
reviewer.

**Write gating**: before ANY write (comment / close / reopen / edit / report), confirm it is allowed
for this project — run `ironbee config get integrations.github.writeEnabled` (via your terminal) and
proceed ONLY if it prints `true`. (`gh` is always reachable via your terminal, so this is a
self-enforced check, not a removed tool.) When it is not `true`, do the read part and REPORT that
writes are off — return the composed comment text + the `🔗` link so the user can post it manually.
Never write without confirming the flag first.
<!--/IRONBEE:INTEGRATIONS-->
