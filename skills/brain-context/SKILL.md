---
name: brain-context
description: Load the most current context pack for a project from the Obsidian vault into the session, so work resumes cold after an old session ran out of context. Use when the user says `/brain-context`, "load my project context", "I ran out of context", "catch up on <project>", or starts a new session on work that was already in flight. Reads `<Workspace>/<Name>-context.md` plus the latest session primer.
---

# brain-context

The pull side of `/brain-daily`. That skill *writes* rolling per-project context packs; this one *loads* them into a fresh session.

**Use case:** a session hit its context limit. Rather than re-explaining the project, open a new session and run `/brain-context <project>` to come back up to speed in one shot.

## Modes

| Invocation | Behavior |
|---|---|
| `/brain-context` | Infer the project from cwd, then recent vault activity. Confirm before loading if ambiguous. |
| `/brain-context acme` | Load that project directly (matches key, folder, or alias) |
| `/brain-context --list` | List available packs with last-updated dates. Load nothing. |
| `/brain-context --full` | Also load the most recent full session log, not just the primer. Much heavier — only when the pack proves insufficient. |

## Step 1 — Resolve the project

1. **Explicit argument** → match against `_System/workspaces.yaml` keys, `folder` basenames, and `aliases` (case-insensitive). First match wins.
2. **No argument** → infer, in order:
   - `basename $PWD` matched against the registry (same algorithm `/brain-record` uses)
   - Most recently modified `*-context.md` in the vault
3. **Ambiguous or no match** → list available packs with their `updated` dates via `AskUserQuestion`. Never guess and load the wrong project — loading the wrong context is worse than loading none.

```bash
find ~/Brain -name '*-context.md' -not -path '*/Archive/*' -exec stat -f '%m %N' {} \; | sort -rn
```

## Step 2 — Load, cheapest first

Escalate only as needed. The pack alone is usually enough — that's what it's built for.

1. **The context pack** — `<Workspace>/<Name>-context.md`. Always read this. Bounded to ~400 lines by design.
2. **The latest session primer** — newest `_Claude/sessions/<project>/*-primer.md`, if one exists. Written by `/brain-record` at ~15-20% of a live log's size. Read only if it's newer than the pack's `updated` date, since otherwise the pack already covers it.
3. **The project page** — `<Workspace>/<Name>.md`, only if the pack is missing or thin (< 40 lines).
4. **Full session logs** — only under `--full`, and only the single most recent. These are the bulk dumps `/brain-record` warns are expensive; the pack exists specifically to avoid needing them.

**Do not** read the whole workspace folder, all meeting notes, or the vault index. Loading context should not itself consume the context it's meant to preserve.

## Step 3 — Check freshness

Compare the pack's `updated` frontmatter to today.

- **Same day** → current.
- **1-3 days** → note the gap; likely fine.
- **> 3 days, or a weekday gap** → warn. `/brain-daily` runs weekdays at 4:07pm, so a stale pack means runs failed or the project was quiet. Offer: *"Pack is N days old. Run `/brain-daily` to refresh before we start?"*

Also check for uncommitted vault changes — the user may have written notes the pack hasn't absorbed yet:

```bash
git -C ~/Brain status --short
```

## Step 4 — Report, then continue

Confirm what was loaded and stop. Do not summarize the pack back to the user — they know what's in their own vault, and re-narrating it wastes the context just loaded.

```
Loaded: acme (pack updated 2026-08-11, today)
  + session primer 2026-08-10-1430

Active threads: 3 · Open questions: 2
Ready — what are we working on?
```

If something looked off, say so in one line:

```
⚠ Pack is 6 days old — last /brain-daily run may have failed. Check _System/logs/brain-daily.log
```

## If no pack exists

Don't fail. Offer, in order of cost:

1. Run `/brain-daily` to generate one from recent activity across the connectors.
2. Load `<Workspace>/<Name>.md` directly if the project page exists.
3. If the project isn't in `workspaces.yaml` at all, offer to register it (same flow as `/brain-record`'s novel-project handling).

## Pairs with

- **`/brain-daily`** — writes the packs this reads
- **`/brain-record`** — session-level primers, complementary to project-level packs
- **`/brain-file`** — file a research answer as a permanent page
