---
name: brain-triage
description: Triage the user's `~/Brain/` vault — read today's daily note + `_Inbox/`, classify each item, file it to the right workspace, update project pages in-place (rewrite-not-append), and commit. Use when user says `/brain-triage`, "triage my brain", "organize the vault", "process my inbox", or after a dump of unstructured notes in the daily note.
---

# brain-triage

You are processing the user's knowledge vault at `~/Brain/`. They write freely in today's daily note and drop things in `_Inbox/`. Your job is to turn that raw dump into a clean, well-filed vault without demanding any format from them.

## Before you start

1. `cd ~/Brain && git pull --ff-only` — pick up anything mobile/agent processes pushed
2. Read:
   - `~/Brain/CLAUDE.md` (the contract, light)
   - `~/Brain/_System/index.md` (vault catalog — use this to find relevant pages)
   - Today's daily note: `~/Brain/Daily/$(date +%Y-%m-%d).md`
   - Everything in `~/Brain/_Inbox/`
3. List the user's top-level workspace folders to know what pages exist (every vault is different — read `~/Brain/_System/workspaces.yaml` for the canonical list).

## Classify each item in the dump

For each line or paragraph, decide which of these it is:

| Kind | Example | Action |
|------|---------|--------|
| **Log entry** | "coffee with contact A, they mentioned company B hiring" | leave in daily note; add backlink or cross-reference if relevant |
| **Todo** | "- [ ] email someone about latency", "need to prep for the interview tomorrow" | extract to the right project page as a plain `- [ ] text` checkbox. Add `📅 YYYY-MM-DD` ONLY if there's a clear deadline. No priority emoji unless the user explicitly said it's urgent. No `[[project]]` tags — the task is IN the project page, that's enough context. |
| **Fact about a project** | "bug in auth middleware: token refresh after 24h" | append to the matching workspace `.md` page under `## Log` with the date; if it contradicts existing content, flag with `contradiction::` |
| **Question / research** | "did pricing for tool X go up?" | create/update a relevant page or ask the user |
| **Reflection / throwaway** | "tool A is nicer than tool B" | leave in daily note as a log line |
| **New person / entity** | "met with a founder named Person A at Company B" | create `<workspace>/people/<name>.md` with a stub; cross-link |
| **Journal content** | voice-to-text dump, personal narrative, diary-style writing | MOVE to `Journal/YYYY-MM-DD.md`. Format with bold `**~time**` markers + paragraph breaks. Fix speech-to-text typos, preserve voice. Remove from daily note after moving. |

## @claude inline instructions

During triage, scan daily notes, journal entries, and inbox files for `@claude` tags. These are inline instructions from the user — execute whatever the surrounding text says.

After executing, change `@claude` to `@claude ✓` in the source file. Keep the surrounding text intact.

Example:
- Before: `(explain this one further @claude on next triage -- 3rd person)`
- After: `(explain this one further @claude ✓ on next triage -- 3rd person)`

## How to figure out WHICH project/area a thing goes in

**Routing source of truth:** `~/Brain/_System/workspaces.yaml`. Read it at start of every triage run. Each entry has `folder`, `keywords`, `people`, `status`, and `notes`. Same algorithm as `~/.claude/skills/meetings-sync/SKILL.md` — score each workspace by keyword matches (substring, case-insensitive, against body + filename) + people matches (emails / names, supports `*@domain` wildcards). Highest score wins.

In order of precedence:
1. **Explicit `[[link]]`** — user already tagged it, done.
2. **Registry routing (workspaces.yaml)** — score each workspace, pick highest. Ties → `_Inbox/` for human disposition. Don't fall back to inline keyword lists; the registry IS the keyword list.
3. **Context from nearby lines** — if the line above this one was about workspace X, this one probably is too. Use only as a tiebreaker.
4. **Last resort: ambiguous** — use `AskUserQuestion` with a/b/c options.

**Child workspaces (`parent:` set):** clients and sub-projects nest under an umbrella workspace (e.g. `client-a` under `acme`). A child beats its parent on ties — content naming the client routes to the client; only general umbrella content routes to the parent. A tie between two *unrelated* workspaces still falls back to `_Inbox/`.

**Subsection-aware filing (`structure:` set):** when a workspace declares a `structure:` map, file into the named subsection instead of guessing:
- session summaries / investigation write-ups → a timestamped note in `notes` (match sibling notes' naming and heading style), plus one `- **YYYY-MM-DD** — …` line in `main`'s `## Recent activity` (newest first) linking the note
- todos → merge into `todos`, deduping against existing items (including reworded duplicates — check meaning, not string match)
- durable findings / remediation items → `frd` if one exists, keeping its numbering scheme
- meeting notes → `meetings`
- open questions → `main`'s `## Open questions`, deduping
Rewrite-not-append applies to `main`: update today's entry rather than stacking a second one for the same stream of work.

**Archived workspaces (`status: archived`):** do NOT auto-file there — this keeps consolidated catalog pages from getting silently corrupted. If a match scores against an archived workspace, surface it in the run report and route the item to `_Inbox/` for manual disposition. Exception: if the archived workspace has its own folder, filing into that folder is OK.

## Scaffolding a new client workspace

When triage (or `/brain-drop`) encounters content clearly about a distinct client that has no workspace entry, ask the user (AskUserQuestion) before scaffolding. On yes:

1. Create `clients/<slug>/` with the standard structure (template: `_System/templates/workspace-client.md`):
   - `<slug>.md` — main page: frontmatter stub, one-paragraph description, `## Contents`, `## Recent activity`, `## Open questions`
   - `TODO.md` — `# <Name> — TODO` with an empty checklist
   - `discovery/notes/` — empty dir for timestamped session notes
   - `meetings/` — empty dir
   - `FRD.md` — only when findings start accumulating; don't pre-create
2. Register it in `workspaces.yaml`: `folder`, `parent` (the umbrella it belongs to), the `structure:` map, keywords the user actually uses for this client, `status: active`.
3. Add the main page to `_System/index.md`.
4. File the triggering content into it per the subsection rules above.

## Hard rules

- **Never demand format from the user.** They write plain text, plain bullets, natural language dates ("tomorrow", "next Friday"). You parse.
- **Rewrite-not-append when ingesting into project pages.** If you're adding a bug note to a project page, check if there's already a `## Known bugs` section — if yes, append there. If the new fact contradicts an existing line, leave BOTH in and mark with `contradiction:: <short explanation>`. Don't silently overwrite.
- **One canonical source per topic.** If a topic already has a page, don't make a second one.
- **Archive inbox files, don't delete.** After processing an inbox file, move it to `_Sources/YYYY-MM/`. Create the month folder if needed. This preserves an immutable trail of raw inputs.
- **Update the index.** When creating a new wiki page, add a one-liner to `_System/index.md` under the appropriate section.
- **Dates**: convert natural language to ISO. "tomorrow" when run on 2026-04-16 = `2026-04-17`. "next Friday" = the upcoming Friday. If truly ambiguous, ask.
- **Future-dated tasks go to the backlog.** File: `_System/backlog.md`. Add the task with its date. Do NOT create future daily notes. Each triage run checks the backlog and moves anything dated today (or past due) into today's daily note, then removes it from the backlog.
- **Timestamps**: if a specific time is known or mentioned ("9am call", "met at 3pm"), include it as a prefix like `9:00 —` or `15:00 —`. If no time is known, don't invent one — just write the entry without a timestamp.
- **Ambiguous? Ask.** Use `AskUserQuestion` with concrete a/b/c options. Don't guess past a reasonable threshold.
- **Private items stay put.** If the user wrote `(private)` or `#noTriage` on a line, skip it entirely.
- **Never delete from daily notes — except journal content.** Triage COPIES items out to project pages but does NOT remove them from the daily note. **Exception:** journal-style personal writing (voice-to-text dumps, diary paragraphs) gets MOVED to `Journal/YYYY-MM-DD.md` and removed from the daily note. The daily note keeps structured stuff (tasks, log lines, notes). The journal gets the personal voice.
- **Clean up diary/journal formatting lightly.** Fix obvious typos, punctuation, capitalization, paragraph breaks — but do NOT change the wording, tone, or meaning. The essence of what they said stays intact. This is copy-editing, not rewriting.

## Commit behavior

After all items processed:

```bash
cd ~/Brain && git add -A
git commit -m "triage $(date +%Y-%m-%d): N items — <one-line summary>"
git push
```

If no changes, say "nothing to triage, vault is clean".

## Report format (what you say to the user at the end)

```
Triaged N items from Daily/YYYY-MM-DD.md and _Inbox/ (M files):

  • "<quoted item>"
    → <action> → <target file>

  • "<quoted item>"
    → <action> → <target file>
    → flagged: <any contradiction or follow-up>

Untriaged (stayed in daily note): K items — mostly log entries / reflections

Contradictions flagged: X (review next weekly)
Commit: <hash> pushed to origin/main
```

Keep it tight. One line per item, no ceremony.

## Writing style when filing to project pages

**Be brief.** When adding a log entry or task to a project page, write 1-2 sentences max. Don't write paragraphs. Don't add context the user didn't write. Don't expand abbreviations or flesh out shorthand. If they wrote "bug in auth — token expiry >24h", file exactly that, not a three-line explanation of what the bug is and why it matters. Match their voice — terse, lowercase-ish, no filler.

## When NOT to run

- If the user is mid-writing in the daily note, DO NOT triage silently. Only run when explicitly invoked.
- If vault has uncommitted merge conflicts, surface that first and stop.
- If `_Inbox/` has > 50 files, warn the user first — triage might be a big operation.

## Related skills

- `/brain-drop` — drop a human-readable session summary into `_Inbox/`
- `/brain-record` — live session journaling under `_Claude/sessions/<project>/`
- `/brain-file` — file a research answer as a wiki page (for compounding queries)
- `/brain-lint` — audit vault health (orphans, dead links, stale todos)
- `/claude-log` — write a rich session log to `_Claude/sessions/<project>/`

## Notes

- This skill assumes the vault structure documented in `~/Brain/CLAUDE.md` (workspace-first folders, `_System/` registry, `_Inbox/` quick captures, `Daily/` notes).
- Workspaces are user-defined — read `_System/workspaces.yaml` for the current set.
