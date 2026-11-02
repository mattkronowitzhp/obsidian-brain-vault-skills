---
name: brain-drop
description: Drop a summary of the current session into the user's Brain vault. Routes directly to the matching workspace (client folder, project page) when the match is confident — filing the note, merging TODOs, and updating the workspace's main page in one pass — and falls back to `~/Brain/_Inbox/` only when routing is ambiguous. Triggered by /brain-drop.
---

# brain-drop

Capture the current session into the user's vault at `~/Brain/`. This is for **the user's vault** — human-readable, terse. For Claude's own session log, use `/claude-log` separately.

Since routing is built in, a drop usually lands filed and committed — `/brain-triage` remains for daily notes, mobile captures, and anything this skill couldn't confidently place.

## What to do

1. Get the timestamp (do NOT guess):
   ```bash
   date "+%Y-%m-%d-%H%M"
   ```
2. Read back through the current conversation to understand what was worked on.
3. Generate a summary (see format below).
4. **Route it** — read `~/Brain/_System/workspaces.yaml` and score the session against each workspace exactly as `/brain-triage` does: keyword matches (substring, case-insensitive) + people matches (`*@domain` wildcards supported). Precedence:
   - A workspace with `parent:` set beats its parent on ties — client workspaces are more specific than their umbrella (e.g. a session about Client A matches both `client-a` and `acme`; `client-a` wins).
   - `status: archived` workspaces never receive drops.
   - Clear single winner → **file directly** (step 6a).
   - Tie between unrelated workspaces, or no match → **inbox fallback** (step 6b). When the session obviously spans two workspaces, you may split the summary and file each part; otherwise don't guess.
5. **Reconcile before writing — do this every time.** A drop that adds a second, contradictory open item is worse than no drop at all. Search the target workspace for anything this session updates, supersedes, answers, or contradicts, then classify. This is cheap; the failure is expensive and silent.

   **Search these four places** (grep the workspace, don't rely on memory):
   - the `todos` file — is there an open item on this exact topic?
   - the main page's `## Recent activity` — is there already an entry from this same stream of work?
   - the numbered register (`FRD.md` Q-/F-/R- rows, or equivalent) — does a question here now have an answer?
   - prior session notes — grep for the specific claim, and **grep the whole vault for any figure this session changed** (a corrected number usually appears in three or four places, including context packs)

   **Then classify:**

   | Situation | Action |
   |---|---|
   | Supersedes an existing claim | **Update in place**, mark the correction, say what's now wrong. Do NOT file a competing item |
   | Answers an open todo or question | **Close it inline with the answer** — check the box and write what the answer turned out to be. Don't add a separate "we found X" item elsewhere |
   | Extends a same-day stream | **Append to today's note / entry**, don't stack a second one |
   | Genuinely new topic | New note, as normal |

   **Corrections belong where the wrong claim lives, not only where the right one was found.** If a superseded claim sits in a historical record — a meeting note, a past session note, an `_Inbox` capture — do not rewrite its body. Add a short correction banner at the top saying what is dead **and what still stands**, so the good findings survive the bad numbers. Living documents (todos, main pages, registers, context packs) get edited in place instead.

   **When in doubt, ask.** The surrounding vault context usually makes update-vs-new obvious; if it genuinely isn't, ask before writing rather than filing both.

6. File it:

   **6a. Direct filing (confident match)** — use the workspace's `structure:` map from workspaces.yaml (fall back to sensible defaults if absent: notes → the workspace folder itself, todos → `TODO.md` if it exists, main → the folder's eponymous `.md`):
   - Write the summary as a timestamped note in the `notes` dir: `{timestamp}-{topic-slug}.md`, with a one-line `#` title and dated heading matching the sibling notes' style.
   - Merge any TODOs into the `todos` file — check for duplicates/overlap with existing items first; never re-add something already tracked.
   - Add one line to the main page's `## Recent activity` (newest first, `- **YYYY-MM-DD** — …`), ending with a `[[wikilink]]` to the new note. Rewrite-not-append: if an entry for today already exists from this same stream of work, update it instead of stacking a second one.
   - If the session produced a durable artifact (published page, PR, doc), include its link in the note.
   - Commit **only the files you touched**:
     ```bash
     cd ~/Brain && git add <files> && git commit -m "drop: <slug> → <workspace>"
     ```
   - Do NOT also write an `_Inbox/` copy — the filed note is the record.

   **6b. Inbox fallback (ambiguous)** — write to `~/Brain/_Inbox/{timestamp}-{topic-slug}.md`, plain text, no frontmatter, and tell the user why routing was ambiguous so they can register the workspace or run `/brain-triage`.

7. Confirm to the user: where it landed, what was merged (TODOs, main-page line), **what was updated or closed rather than added**, and the commit hash — or the ambiguity if it fell back to inbox.
8. Remind: "Run `/claude-log` too if you want this session logged for Claude's cross-session memory."

## New client or project with no workspace yet

If the session is clearly about a distinct client/project that has **no workspace entry**, don't silently inbox it — ask the user (AskUserQuestion) whether to scaffold one. On yes, follow the client-workspace scaffold in `~/.claude/skills/brain-triage/SKILL.md` (create the folder structure, register it in workspaces.yaml), then file the drop there.

## Summary format

**Code / professional work** — terse. A quick session is 1-2 lines; a session with real findings gets a short structured note (findings / decisions / TODOs), matching the depth of the sibling notes already in that workspace's notes folder:

```
added Celery async task for VOB lookup, tested against sandbox
```

**Non-code work** (research, planning, interview prep, writing) — a few bullets:

```
Interview prep for Company X:
- Built prep doc for the recruiter screen
- Screen confirmed for Apr 29 1pm
- TODO: review system design patterns before call
```

## Rules

- Inbox-fallback notes: no frontmatter, no YAML — just plain text. Direct-filed notes: match the conventions of their sibling notes.
- Don't over-describe — but do preserve every TODO and action item that came up.
- Include enough context that a cold reader (or later triage) can follow it.
- Never file into an archived workspace.
- **One claim, one home.** A fact should be current in exactly one place; everywhere else points to it. Two open items saying different things about the same question is the failure this skill exists to prevent.
- **Resolved items are kept, not deleted** — especially when they corrected an earlier wrong answer. The correction is usually the most useful part of the record.
- Commits are scoped to the drop — never `git add -A` (the vault may hold unrelated uncommitted work).

## Related skills

- `/claude-log` — rich session log to `_Claude/sessions/<project>/` (for Claude's memory, not the user's vault)
- `/brain-triage` — processes `_Inbox/` and daily notes into workspace pages; owns the client-workspace scaffold
- `/brain-record` — live session journaling (richer than brain-drop; pair with `/loop` for auto-pacing)
