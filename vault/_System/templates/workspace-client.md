# Client workspace template

Standard structure for a client under `clients/<slug>/`. Keep one finished client as the reference implementation.

```
clients/<slug>/
├── <slug>.md          # main page (see stub below)
├── TODO.md            # cross-session todos — merge + dedupe, never re-add
├── FRD.md             # findings & remediation — create when findings accumulate
├── discovery/notes/   # timestamped session notes: YYYY-MM-DD-HHMM-topic-slug.md
└── meetings/          # meeting notes (meetings-sync target)
```

Register every client in `_System/workspaces.yaml` with `parent:` set to its umbrella
workspace and the `structure:` map filled in — that's what makes brain-drop and
brain-triage file into the right subsection automatically.

## Main page stub (`<slug>.md`)

```markdown
---
client: <slug>
client_name: <Name>
phase: discovery | build | live | refresh
go_live: null
linear_project_id: null
last_synthesized_at: YYYY-MM-DD
---

# <Name>

One paragraph: who the client is, what phase the engagement is in, what the
current stream of work actually is.

## Contents

- [[FRD]] — Findings and Remediation Strategies
- `discovery/notes/` — raw session notes
- `TODO.md` — cross-session todos

## Recent activity

- **YYYY-MM-DD** — One-to-three-sentence summary of the session. See [[note-file-name]].

## Open questions

- Things not yet answered — deduped, removed when resolved.
```

## Conventions

- **Recent activity** is newest-first, one line per day per stream of work —
  update today's entry rather than stacking a second (rewrite-not-append).
- **TODO.md** items reference FRD IDs (R-1, Q-2) when they exist.
- **Session notes** are immutable once written; corrections go in a newer note
  or the FRD, with a `contradiction::` marker if the old note is now wrong.
