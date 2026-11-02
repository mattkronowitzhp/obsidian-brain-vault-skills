---
name: brain-daily
description: Daily automated vault update. Pulls new context since the last run from Granola, Google Calendar, Gmail, Linear, and Claude Code session transcripts; infers projects; files project-first and general-second; maintains rolling per-project context packs. Runs unattended via launchd every day at 4:32pm, or manually with `/brain-daily`. Supports `--dry-run` and `--since <ISO8601>`.
---

# brain-daily

The vault's daily heartbeat. Everything else in `~/Brain/` is manually triggered — this is the one thing that runs on its own.

Pulls **only what is new since the last recorded run**, files it project-first, and keeps a rolling context pack per project that can be pasted into a fresh AI session.

## Non-negotiable invariants

Violating any of these makes the skill worse than not running:

1. **Incremental only.** Every source is gated on the watermark. Never re-index the vault. Never re-process material an earlier run already handled.
2. **Never commit.** Leave all changes uncommitted so the user reviews the diff in Obsidian. This includes suppressing the commit step of any skill delegated to.
3. **Early exit is a success.** Zero deltas → write nothing, update nothing, report "no new activity." A quiet day must be nearly free.
4. **Never read the whole vault.** Only `_System/index.md`, `_System/workspaces.yaml`, and the specific project pages the delta actually touches.
5. **Bounded output.** Context packs are capped. A file that grows without limit defeats its own purpose.

## Modes

| Invocation | Behavior |
|---|---|
| `/brain-daily` | Normal incremental run |
| `/brain-daily --dry-run` | Report what *would* be written. Touch nothing — not even the watermark. |
| `/brain-daily --since 2026-08-01T00:00:00Z` | Override the watermark for this run. Does not rewrite history. |

---

## Step 1 — Read the watermark

`~/Brain/_System/daily-sync-state.json` (gitignored — per-user local state, same pattern as `granola-sync-state.json`):

```json
{
  "last_run_at": "2026-08-11T20:07:00Z",
  "sources": {
    "granola":  "2026-08-11T20:07:00Z",
    "calendar": "2026-08-11T20:07:00Z",
    "gmail":    "2026-08-11T20:07:00Z",
    "linear":   "2026-08-11T20:07:00Z",
    "sessions": "2026-08-11T20:07:00Z"
  },
  "known_projects": {
    "acme-migration": { "sightings": 2, "sources": ["gmail", "granola"], "first_seen": "2026-08-10" }
  }
}
```

Per-source watermarks matter: if Gmail fails but Linear succeeds, only Linear's watermark advances, and the next run retries Gmail from where it left off. **Never advance a watermark for a source that errored.**

**Missing file** → treat as 24h ago. Do **not** backfill history; a first run should be small. Backfill is a separate, explicit `--since` invocation.

Get the current time with `date -u +%Y-%m-%dT%H:%M:%SZ`. Never guess it.

## Step 2 — Pull deltas (caps are hard limits)

Run these concurrently where possible. If a source errors, log it, leave its watermark untouched, and continue — one dead connector must not kill the run.

### Granola
Delegate to the existing `/meetings-sync` skill. It already handles dedupe via `_System/granola-sync-state.json`, routing, junk filtering, and the privacy guard. Do not reimplement any of that.

**Override:** skip its final `git commit` step (invariant 2).

### Google Calendar
`list_events` for **yesterday + today only**. Not a range, not a lookahead. Yesterday for what actually happened, today for what the daily note should show.

### Gmail — all mail, metadata-first
Full mailbox coverage, made affordable by triaging on metadata before fetching bodies.

1. `search_threads` with `after:<gmail watermark>`. **No sender/recipient filter** — all mail is in scope.
2. Cap **75 threads/run**. If the cap is hit, log it explicitly (never silently truncate) and advance the watermark only to the newest thread actually processed, so the remainder is picked up next run.
3. **Read only subject + sender + snippet first.** From that alone, classify each thread:
   - **Project-relevant** → fetch the full thread with `get_thread`
   - **Noise** (newsletters, receipts, notifications, promotions, automated alerts) → drop, never fetch the body
4. Cap full-body fetches at **25 threads/run**. Rank by project-match confidence when over.

This is what keeps "all Gmail" from being the thing that blows the token budget: metadata for everything, bodies only for what earns it.

### Linear
`list_issues` filtered to assignee = the user, `updatedAt > watermark`. Cap **25**. Capture status transitions and new comments — the state *change* is the signal, not the issue text.

### Claude Code session transcripts
Sessions all live under one cwd (`~/.claude/projects/-Users-<you>/`), so project cannot be inferred from directory — it must come from content. Raw JSONL is far too expensive to ingest whole, so **prefilter in shell**:

```bash
find ~/.claude/projects -name '*.jsonl' -newermt "<watermark>" -print0 \
  | xargs -0 -I{} sh -c 'jq -r "select(.type==\"user\" or .type==\"assistant\") | .message.content | if type==\"array\" then map(select(.type==\"text\").text) | join(\" \") else . end" {} 2>/dev/null | head -c 20000'
```

Cap **8 transcripts/run**, newest first. Extract only: what was worked on, decisions made, files touched, open questions. Skip tool-call spam and file dumps.

### Early exit
All sources zero → update `last_run_at`, write nothing else, report "No new activity since `<timestamp>`." Stop here.

## Step 3 — Infer projects

Pool the whole delta and cluster it into projects.

1. **Registry first.** Score against `_System/workspaces.yaml` using the same algorithm `meetings-sync` uses — keyword substring hits on titles/bodies, plus `people` email matches (`*@domain` wildcards supported). Highest score wins.
2. **Then infer unregistered projects.** A candidate is a recurring named effort — a product, a codename, a migration, a client — that appears across the delta. Signals: repeated proper nouns across sources, an email thread plus a meeting on the same subject, a Linear project name, a repo worked on in a session.
3. **Not projects:** one-off requests, admin/scheduling chatter, anything appearing exactly once from exactly one source.

### Registering a new project

Only auto-add to `workspaces.yaml` when a candidate has appeared **across ≥2 sources OR on ≥2 separate days** (tracked in `known_projects.sightings`). Otherwise increment its sighting count and write a proposal to `_Inbox/project-proposal-<slug>.md` for the user to approve.

Only `acme` exists today, so this gate is what prevents the registry filling with noise while inference is still cold.

On auto-add, append before the `# === FALLBACK ===` divider:

```yaml
<slug>:
  folder: <Slug>/
  meetings: <Slug>/meetings/
  keywords: [<slug>, <observed terms>]
  people: [<observed emails>]
  aliases: []
  status: active
  notes: |
    Auto-registered by /brain-daily on YYYY-MM-DD from: <sources>. Edit keywords/people to tune routing.
```

Create the folder, a stub project page from `_System/templates/workspace-generic.md`, and an initial context pack.

## Step 4 — File it (project-first, then general)

### Per matched project
1. **Update the project page** (`<Workspace>/<Name>.md`) — append dated entries under `## Log`. Follow the vault's **rewrite-not-append** rule from `CLAUDE.md`: update existing statements rather than dumping duplicates. Contradictions get marked `contradiction:: <explanation>`, never silently resolved.
2. **Update the context pack** (see below).
3. **File meeting notes** to the workspace's `meetings/` folder (handled by `meetings-sync`).
4. **Extract todos** as plain `- [ ]` on the project page. Add `📅 YYYY-MM-DD` only for a clear deadline. No priority emoji unless explicitly urgent.

### General info (no project match)
Append to today's daily note `Daily/YYYY-MM-DD.md` under the existing `## Morning` / `## Afternoon` / `## Evening` headings by time of day, creating the file from `_System/daily-template.md` if missing. Anything ambiguous goes to `_Inbox/` for `/brain-triage`.

Respect the existing opt-outs: skip any line prefixed `(private)` or tagged `#noTriage`.

## Step 5 — Write watermarks and report

Advance only the watermarks of sources that succeeded. Then report:

```
brain-daily — 2026-08-11 16:07

Sources:   granola 3 · calendar 5 · gmail 47 scanned / 8 read · linear 4 · sessions 2
Projects:  acme (updated), acme-migration (NEW — registered, 2 sources)
Filed:     3 meetings, 11 log entries, 4 todos
Packs:     2 updated
Proposals: 1 → _Inbox/project-proposal-vendor-x.md
Caps hit:  none
Uncommitted — review with `git -C ~/Brain diff`
```

Always surface caps hit and skipped sources. Silent truncation reads as full coverage when it wasn't.

---

## Context pack format

`<Workspace>/<Name>-context.md` — sibling to the human-readable project page. One file the user reads, one file they feed an AI.

Distinct from `/brain-record`'s primer, which is per-session. **This is cumulative and rolling across days.** It is the answer to "my session ran out of context, get me back up to speed."

```markdown
---
project: acme
updated: 2026-08-11
pack_version: 3
---

# Acme — context pack

> Paste this whole file into a new session to resume work cold.

## What this is
2-3 sentences. Stable across runs — only rewrite if the project's nature actually changed.

## Current state
Where things stand right now. **Rewritten every run, never appended.** This is the section that
would rot into a changelog if appended, so don't.

## Active threads
- **<thread name>** — status, blocker, next action. 1-3 lines each.

## Key decisions
Append-only, dated, each with the *why*. The reasoning is the expensive part to reconstruct.
- **2026-08-11** — Chose X over Y because Z. Tradeoff: W. Revisit if V.

## People
- **Name** (email) — role — what they own

## Open questions
- Question, what's known, what would resolve it.

## Recent activity
Last ~14 days, newest first. Rolls off the bottom.
- **2026-08-11** — what happened (source)

---
*Maintained by `/brain-daily`. Full session logs: `_Claude/sessions/<project>/`*
```

### Bounding rules — these are the point

- **Hard cap ~400 lines.** Over cap → compress `Recent activity` first, then oldest `Key decisions`.
- **`Current state` is rewritten**, never appended.
- **`Recent activity` rolls off at 14 days** into `Archive/<name>-context-YYYY-MM.md`.
- **`Key decisions` is append-only** but compresses: decisions older than 90 days collapse to one line without the tradeoff detail.
- Write for an AI reading cold. No "as discussed" or "the usual approach" — name things explicitly.

Only rewrite a pack when its project actually had a delta this run. Untouched project, untouched file.

---

## Failure handling

- **MCP auth failure** (likely in headless launchd runs — claude.ai OAuth may not survive): log clearly, skip that source, leave its watermark, continue with the rest. Never advance a watermark past data that was never read.
- **Malformed watermark file**: back it up to `.bak`, reinitialize to 24h ago, warn in the report.
- **Empty vault-side state** (no `index.md`, no workspaces): still write to the daily note. Degrade, don't fail.

## Explicitly does not

- Commit anything (user reviews the diff).
- Run `/brain-triage` (that stays manual — misrouting risk while the registry is thin).
- Delete or archive existing notes.
- Pull Slack (not connected — `! Needs authentication`).
- Read Granola transcripts (paid tier).
