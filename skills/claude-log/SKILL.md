---
name: claude-log
description: Log session activity to ~/Brain/_Claude/sessions/ for cross-session context. Writes rich, timestamped entries with decisions, files touched, progress, and open questions. Use /log mid-session or auto-trigger at session end. This is Claude's own memory — not for the user's vault (use /brain-drop for that).
---

# claude-log

Write a structured session log entry to `~/Brain/_Claude/sessions/<project>/YYYY-MM-DD.md`.

## When to use

- **`/log`** — manual mid-session. Write what's notable right now.
- **End of session** — when the user is done or says goodbye, offer to log before closing.

## How to get the data

**CRITICAL: Do not guess or fabricate any of these. Use the exact commands.**

### Timestamp
```bash
date "+%A, %B %-d, %Y — %-I:%M %p %Z"
```
Output example: `Monday, May 4, 2026 — 6:30 PM PDT`

### Date for filename
```bash
date "+%Y-%m-%d"
```

### Project name
1. Check existing project folders — `ls ~/Brain/_Claude/sessions/` and match against the current working directory.
2. If no match exists, ask the user: "What should I call this project for logging?" Use that as the folder name.
3. Map: working directory → project slug. Examples:
   - `~/Code/example-app/` → `example-app`
   - `~/Brain/` → `brain`
   - `~/work/client-x/` → `client-x`

### Files touched
```bash
cd <project-root> && git diff --name-only HEAD~1 2>/dev/null; git diff --name-only 2>/dev/null; git diff --name-only --cached 2>/dev/null
```
Combine and deduplicate. If no git repo, note "no git tracking."

### Everything else
Summarize from the current conversation context. You have the full session — use it. The failure mode is **omission** (missing something), not **fabrication** (making something up). When in doubt, say "tentative" or "discussed but not confirmed."

## File structure

```
_Claude/sessions/
  brain/
    2026-05-04.md
    2026-05-03.md
  example-app/
    2026-05-04.md
```

One folder per project. One file per day. If multiple sessions happen on the same day, append to the same day's file with a new timestamped section.

## Entry format

```markdown
# <project> — <day>, <month> <date>, <year>

### <time> <timezone>

**What was done:**
- Concrete actions, not vague summaries
- One bullet per distinct thing

**Progress:**
- What moved forward, what milestone was hit, what percentage if applicable

**Decisions made:**
- Decision — rationale (why this over alternatives)

**Files touched:**
- `path/to/file.ext` — what changed and why

**Open questions / blockers:**
- What the next session needs to know or resolve

**Preferences / feedback learned:**
- Anything the user corrected, confirmed, or expressed a preference about

**Related vault notes:**
- [[Note/path]] — why it's relevant

**Todos generated:**
- [ ] Concrete next actions from this session
```

## Writing the entry

1. Run the timestamp command via Bash. Use the exact output.
2. Run the date command for the filename.
3. Determine the project name (check existing folders or ask).
4. Run git diff commands for files touched.
5. Write the entry by reading back through the conversation for decisions, progress, open questions, preferences, and todos.
6. Create the project folder if it doesn't exist: `mkdir -p ~/Brain/_Claude/sessions/<project>`
7. Write to `~/Brain/_Claude/sessions/<project>/YYYY-MM-DD.md`. If the file already exists (same-day second session), append a new timestamped section.

## Rules

- **Never fabricate timestamps** — always use the shell command.
- **Never fabricate file lists** — always use git diff.
- **Never invent decisions that weren't made** — if you're unsure, mark as "discussed" not "decided."
- **One file per day per project** — multiple sessions in a day append to the same file.
- **Don't ask permission to log** — when triggered, just do it. The user already consented by invoking /log or ending the session.
- **Git commit after writing** — `cd ~/Brain && git add _Claude/sessions/ && git commit -m "claude-log: <project> <date>"` and push.

## How other Claude instances use this

Any Claude instance on this machine can read `~/Brain/_Claude/sessions/<project>/` at session start to get context. Read the latest 2-3 files (sorted by name = sorted by date).

A new session in `~/Code/example-app/` should:
1. Check if `~/Brain/_Claude/sessions/example-app/` exists
2. Read the latest 2-3 `.md` files for recent context
3. Proceed with that context in mind

This read behavior should be configured in each project's CLAUDE.md, not in this skill.
