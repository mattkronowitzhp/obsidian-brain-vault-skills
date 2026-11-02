---
name: brain-record
description: Continuous session journaling for the user's Brain vault. Captures decisions, discoveries, files touched, and open questions as a live session log under `~/Brain/_Claude/sessions/<project>/`. Invoke `/brain-record` at session start or mid-session — each call appends a new checkpoint. Pair with `/loop 10m /brain-record` for automatic periodic capture. On `/brain-record stop`, finalizes the log, writes a token-efficient primer for the next AI session, and routes vault-worthy bits to workspace pages per workspaces.yaml. Use when the user says `/brain-record`, "start recording", "log this session", or asks to capture work-in-progress.
---

# brain-record

Live session journaling. Opt-in via `/brain-record`. Captures what matters as the session unfolds — not just at the end.

## Mental model (read this first)

Two surfaces, separate purposes:

1. **The live log under `_Claude/sessions/<project>/`** — the **bulk dump.** Verbose. Everything Claude is actually doing. Files touched, decisions, dead ends, half-built things. This is Claude's notebook, written for the user to read later if they want the full picture. New checkpoints append here on every `/brain-record` tick.

2. **Workspace pages under user-defined top-level folders** — the **distilled main vault.** Only the key events land here, and only on `/brain-record stop`. Narrative paragraphs covering what happened and why, with wikilinks back to the full live log. This is the "main part of the Brain" the user reads day to day.

3. **The primer (NEW)** — a token-efficient digest written alongside the finalized live log, sized at ~15-20% of the live log. Designed to be read by the *next* AI session at startup to recover context without re-ingesting 10k tokens of live log.

**The inbox (`_Inbox/`) is NOT involved.** `/brain-record` bypasses it. Inbox is reserved for `/brain-drop` (small one-shot captures) and `_Inbox/meetings/` (Granola). When `/brain-record` is running, it knows where things go — no triage middleman needed.

## Where the log lives

```
~/Brain/_Claude/sessions/<project>/YYYY-MM-DD-HHMM-live.md       # in-progress
~/Brain/_Claude/sessions/<project>/YYYY-MM-DD-HHMM.md            # after stop
~/Brain/_Claude/sessions/<project>/YYYY-MM-DD-HHMM-primer.md     # after stop
```

- `<project>` = matched workspace key from `_System/workspaces.yaml`, else `general`
- `-live` suffix marks the file as in-progress
- On `stop`, the `-live` suffix is dropped to mark it finalized; the primer is written adjacent

## Modes of invocation

| Command | Action |
|---|---|
| `/brain-record` | First call: create live log + write a "Session start" section. Subsequent calls: append a new checkpoint. |
| `/brain-record stop` | Finalize: append "Session end" + route vault-worthy items to workspace pages + write the primer + rename to drop `-live` suffix. |
| `/loop 10m /brain-record` | Auto-pace: Claude Code's loop wrapper runs `/brain-record` every 10 minutes. Pair with this for hands-off recording. |

## What to capture in the live log (the BULK — go exhaustive)

**The live log is for reconstruction.** The user reads this later when they need the picture of what happened and why. Far more detailed than a typical session summary — lossy compression of context is the failure mode we're fixing — but not a verbatim transcript.

Each checkpoint captures everything that's happened since the last tick, in detail. Include:

- **Decisions** — full reasoning. Not just "decided X" but "decided X over Y because Z; tradeoff is W; reconsider if V happens." Include alternatives considered and rejected.
- **Discoveries / facts** — quote sources, payload shapes, exact error messages, API responses. If you found out a payload field is missing, quote what fields ARE present.
- **Files created or edited** — path + a real description of what changed and why. Include relevant code snippets inline (5-30 lines) if they capture the change.
- **Tool calls of substance** — bash commands with output (trimmed if huge), git operations with commit hashes, agent dispatches with prompt and key findings. Skip pure-exploration reads of files Claude already knew about.
- **Conversations with the user** — quote their exact phrasing on requests, corrections, redirections, preferences. Their words are the highest-signal input; never paraphrase them away.
- **Reasoning chains** — when you went down a path and either landed or backed out, capture both the path and the conclusion.
- **Errors, failures, dead ends** — bug encountered, what was tried, what worked. Failed attempts are data; they prevent re-attempting the same dead end next session.
- **People, tools, contexts encountered** — names, emails, role, conversation gist. New tools picked up with a one-sentence summary.
- **Open questions / blockers** — phrased as a question with what's known and what's needed to resolve.
- **Todos generated** — anything actionable in `- [ ]` form, with context.

**Default to more, not less — but not transcription.** A checkpoint of 10-20 bullets across 3-4 sub-sections is normal. 3 bullets = under-captured. 50+ bullets = transcribing; distill harder.

## What to skip in the live log (the genuine noise floor)

Only skip stuff that would actively confuse a later reader:

- Verbatim large file dumps (cite file + line range instead)
- Filler chitchat ("ok", "let me check", "give me a sec")
- Tool calls Claude made and immediately abandoned because of a typo or wrong flag
- Repeated re-reads of the same file in the same checkpoint window

Everything else: capture it.

## Project detection (matching cwd to a workspace)

Detection is registry-driven — don't hardcode a list.

1. Compute candidate: `CANDIDATE=$(basename "$PWD")`.
2. Read `~/Brain/_System/workspaces.yaml`. For each entry, check if `CANDIDATE` matches any of: the entry's key, its `folder` basename, or any of its `aliases`. Case-insensitive. First match wins.
3. If matched → `PROJECT=<entry-key>`. Use that for the session folder name.
4. If no match → enter the **novel-project flow** below.

## Novel-project flow (new or unrecognized cwd)

When no workspace matches the current directory, the skill asks once and remembers via the registry. Three options:

```
This cwd (`<full-path>`) doesn't match any workspace in workspaces.yaml. Pick one:

  a) Add it as a NEW workspace (I'll write a minimal entry to workspaces.yaml — folder, keywords, status: active — and create _Claude/sessions/<slug>/). Best when this is a project you'll keep coming back to.

  b) File under an EXISTING workspace (I'll list active workspaces; you pick one). Best when the work belongs to something already tracked, just happens to live in a different dir.

  c) File as a ONE-OFF under _Claude/sessions/general/, with the dir name in the filename (e.g. 2026-05-18-1900-<slug>-live.md). No registry change. Best for scratch / exploration that won't recur.
```

Use `AskUserQuestion` for this; don't proceed silently. Default in the recommendation: (a) if cwd is a real git repo with > 5 tracked files, (c) otherwise.

### If (a) chosen — add new workspace

- Slug the cwd basename (lowercase, hyphens, ASCII-only).
- Append to `~/Brain/_System/workspaces.yaml` before the `# === FALLBACK ===` divider:

```yaml
<slug>:
  folder: <path-relative-to-Brain-or-absolute>
  meetings: _Inbox/meetings/
  keywords: [<slug>, <other obvious keywords from dir name or README>]
  people: []
  aliases: []
  status: active
  notes: |
    Auto-registered by /brain-record on YYYY-MM-DD. Invoked from `<full-cwd>`. Edit to tune keywords/people.
```

- If the cwd is OUTSIDE `~/Brain/` (e.g. a separate repo at `~/Code/foo`), `folder` should be the absolute path. The session log still goes under `~/Brain/_Claude/sessions/<slug>/`.
- Use that slug as `PROJECT` going forward.
- Mention the registry edit in the first checkpoint.

### If (b) chosen — file under existing workspace

- Use the picked workspace's key as `PROJECT`. No registry change. Note in the first checkpoint that the user overrode auto-detection.

### If (c) chosen — file as one-off under general

- `PROJECT=general`. Filename gets the cwd basename slugged in: `YYYY-MM-DD-HHMM-<slug>-live.md`. No registry change.

## First-invocation procedure

1. Run project detection (and novel-project flow if needed) to pick `PROJECT`.
2. Compute path: `~/Brain/_Claude/sessions/<PROJECT>/YYYY-MM-DD-HHMM-live.md`.
3. Check if a `-live` file already exists for today + PROJECT. If yes, go to the subsequent-invocation procedure.
4. **Load context from recent primers.** Before creating the live log, look for primer files in the same project from the last 7 days:

   ```bash
   find ~/Brain/_Claude/sessions/<PROJECT>/ -maxdepth 1 -name "*-primer.md" -mtime -7 2>/dev/null | sort
   ```

   For each primer found (cap at most-recent 3), read it. Include a "Recent context loaded from primers" section in the live log's "Session start" block:

   ```markdown
   ## Session start (HH:MM)

   **Recent context loaded from primers:**
   - YYYY-MM-DD HH:MM primer ([[YYYY-MM-DD-HHMM-primer]]): <1-line summary>
   - YYYY-MM-DD HH:MM primer: <1-line summary>

   If any of those primers contains open questions/blockers, surface them at the top of the new session's "What's the focus" so they're not forgotten.

   **What's been done so far this session:**
   ...
   ```

   If no recent primers exist: skip this step silently. Don't fabricate context.

5. Create the file with frontmatter + initial section:

```markdown
---
project: <project>
session_start: YYYY-MM-DDTHH:MM:SS
status: live
---

# <project> — <day name>, <Month Day, Year>

## Session start (HH:MM)

**What's been done so far this session:**
- <bullet 1>
- <bullet 2>

**What's the focus:**
<1-2 sentences on the active goal>
```

6. Report: "Started recording at `<path>`. Next checkpoint when you `/brain-record` again, or set `/loop 10m /brain-record` for auto-pacing."

## Subsequent-invocation procedure

1. Find the live file for today + project. If none, treat as first invocation.
2. Read the file to know what's already captured (avoid duplicates).
3. Append a new section:

```markdown

### HH:MM checkpoint

- <new decision or discovery>
- <file touched: `path` — what changed>
- <new open question>
```

4. Keep it tight — 3-8 bullets per checkpoint. If nothing meaningful happened: `### HH:MM — no meaningful progress to log`.
5. Do NOT commit (rely on Obsidian Git autocommit).
6. Report: "Checkpoint added to `<path>`."

## Stop procedure (`/brain-record stop`)

This is where the bulk → distilled distinction matters most.

1. Find the live file for today + project. If none, say "no live session to stop" and exit.
2. Append a final section to the live log:

```markdown

## Session end (HH:MM)

**Overall summary:** <4-8 sentences capturing what this session was about, what was figured out, what got built or shipped, and any pivots along the way.>

**Files touched:**
- <list with brief notes>

**Workspaces written to on stop:**
- `<workspace>.md` — <one line on what was distilled there>

**Open for next session:**
- <list>
```

3. **Rename the live file first** so wikilinks resolve: drop the `-live` suffix.

4. **Write a narrative session summary into each relevant workspace page.** Walk the captured checkpoints and group items by workspace (using `workspaces.yaml` matching on keywords/people). For each **active** workspace the session touched, append a dated entry under a `## Log` section. The entry is a **human-readable paragraph or two**, not bullets. End with a wikilink back to the full live log.

   Format template:

   ```markdown
   ### YYYY-MM-DD — <short headline of what this session did for THIS workspace>

   <Paragraph 1: what the session was about as it relates to this workspace. Cover the WHY.>

   <Paragraph 2: what concretely got done. Files touched, decisions, things shipped. Name files, name tools, name people.>

   <Paragraph 3 (optional): what's open or comes next.>

   Full session log: [[_Claude/sessions/<project>/YYYY-MM-DD-HHMM]]
   ```

   **What goes into the narrative:**
   - Decisions that affect future work, with reasoning
   - Discoveries / facts worth keeping
   - Completed milestones or closed-out items
   - New people, tools, or contexts the workspace now needs to know about
   - Open questions that will affect next session

   **What stays in the live log only:**
   - Routine file edits / tool calls (already in git)
   - Exploration / dead ends (preserved for future-self; not workspace-relevant)
   - Conversational back-and-forth that didn't lead anywhere
   - Failed attempts that were superseded

   **Length:** typically 2-4 paragraphs (150-400 words). If the session was tiny, a single paragraph + wikilink is fine. If it was a 4-hour deep dive, 5 paragraphs is fine.

   **Routing edge cases:**
   - Multiple workspaces touched → write a separate narrative entry for each.
   - Matching workspace has `status: archived` → skip the workspace write. Note in the stop report.
   - No workspace matched the session → don't write any workspace entry. Note in the stop report.

5. **Write a token-efficient context primer** for the next AI session.

   **File:** `~/Brain/_Claude/sessions/<project>/YYYY-MM-DD-HHMM-primer.md` (adjacent to the renamed live log)

   **Purpose:** When a future Claude Code session in this project starts, the first thing it should be able to read is a ~15-20% size digest of recent sessions, not the full live log. The primer is the entry point. The live log is the drill-down.

   **Target size:** 15-20% of the live log's character count. If the live log is 8KB, the primer is ~1.5KB.

   **Format:**

   ```markdown
   ---
   project: <project>
   session_date: YYYY-MM-DD
   session_time_start: HH:MM
   session_time_end: HH:MM
   live_log: [[YYYY-MM-DD-HHMM]]
   primer_for: future-ai-session-startup
   ---

   # <project> primer — YYYY-MM-DD HH:MM

   **What this session was about:** <1-2 sentence elevator pitch>

   **Key decisions:**
   - <terse decision> — see [[YYYY-MM-DD-HHMM#section-name]] for reasoning
   - <terse decision>
   (3-7 bullets; just enough to know what was decided)

   **Files touched:**
   - `path/to/file.ext` — one-liner on what changed
   (paths only; no snippets; `(major rewrite)` if heavily reworked)

   **Open questions / blockers for next session:**
   - <question> — context in [[YYYY-MM-DD-HHMM#section-name]]

   **Pointers into the live log:**
   - For details on <topic>, see [[YYYY-MM-DD-HHMM#<heading>]]
   (3-6 pointers — what future-AI is most likely to need to drill into)
   ```

   **What NOT to include:**
   - File contents or code snippets (live log has them)
   - Full reasoning chains (live log has them)
   - Routine tool calls or exploration steps
   - Conversational filler
   - Anything in the workspace narrative paragraph

6. **Write a high-level line in today's daily note.** Append to `~/Brain/Daily/YYYY-MM-DD.md` (create from `_System/daily-template.md` if missing). Under a `## Sessions` heading (create if absent):

   ```markdown
   - HH:MM — <one-sentence summary>. [[_Claude/sessions/<project>/YYYY-MM-DD-HHMM|full log]] · [[<workspace-page>]]
   ```

   Keep it to one sentence. The daily note is the "what got done today at a glance" surface, not a digest.

7. **Wikilink everything for the graph.** Obsidian's graph view only connects notes via `[[wikilinks]]`. Across all three writes (live log finalization, workspace narrative, daily note line), make sure every entity mentioned gets a wikilink — people, clients, tools, sibling workspace pages. Unresolved links still create graph nodes — better unresolved than absent. Default to MORE wikilinks rather than fewer.

8. Report:

```
Session ended. Live log: ~/Brain/_Claude/sessions/<project>/YYYY-MM-DD-HHMM.md
Primer: ~/Brain/_Claude/sessions/<project>/YYYY-MM-DD-HHMM-primer.md (Nk → Mk tokens)

Workspace narratives:
  - <workspace>.md (## Log — <headline>)

Daily note: ~/Brain/Daily/YYYY-MM-DD.md (## Sessions — 1 line added)

Wikilinks created: N new graph edges

Workspaces NOT written (kept in live log only):
  - <name> (archived — skipped per routing rule)
```

## Auto-pacing with /loop

```
/loop 10m /brain-record
```

The loop skill runs `/brain-record` every 10 minutes. Each tick appends a checkpoint. User cancels with `/cancel-loop`. Stop explicitly with `/brain-record stop` when done.

## Multiple sessions in the same project on the same day

If a `-live` file exists for today + project but it was clearly from an earlier abandoned session (e.g., last checkpoint > 2 hours old and no `/brain-record stop`), prompt: "Found an unfinished live log from HH:MM. Resume it (a), finalize it as-is and start a new one (b), or discard the old one (c)?"

## Failure mode: forgot to stop

If the session ends without `/brain-record stop` (Claude Code closed, user walked away):
- The `-live` file stays in place
- Next time `/brain-record` runs in this project, the multi-session check kicks in
- Or run `/brain-record stop` manually any time to finalize

## What this skill explicitly does NOT do

- Doesn't auto-trigger from hooks. Manual opt-in is the design.
- Doesn't summarize transcripts. The model has the conversation in its context; just write what matters.
- Doesn't replace `/brain-drop` or `/claude-log`. Complements both.
- Doesn't ever delete or overwrite — only appends within a session, and only renames (`-live` → finalized) on stop.

## Related skills

- `/brain-triage` — files inbox items into workspace pages (same `workspaces.yaml` routing)
- `/brain-drop` — drops a one-shot session summary into `_Inbox/`
- `/claude-log` — writes a rich formal session log (different format, cross-instance memory focus)
- `/loop` — periodic invocation wrapper (auto-pace `/brain-record`)
