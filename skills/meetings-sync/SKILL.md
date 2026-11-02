---
name: meetings-sync
description: Pull Granola meetings into the Brain vault as deep notes filed by workspace. Use when the user says `/meetings-sync`, "sync my meetings", "pull granola meetings", or "backfill meetings". Routes each meeting to the right workspace folder, generates Claude analysis on top of Granola's AI summary, tracks sync state to avoid duplicates.
---

# meetings-sync

Pulls Granola meetings into `~/Brain/` as filed notes. One file per meeting, routed to the right workspace folder.

## Prerequisites

- Granola MCP server connected (`claude mcp list` shows `granola: ✓ Connected`)
- Granola tools available: `list_meetings`, `get_meetings`, `query_granola_meetings`
- Note: transcripts require paid Granola tier; this skill works without them by using Granola's AI summary as the base

## Sync state

File: `~/Brain/_System/granola-sync-state.json` (gitignored — local-only)

Shape:
```json
{
  "synced_ids": ["<uuid>", "..."],
  "last_sync_at": "2026-05-14T18:42:00Z"
}
```

Read at start. Update at end. Never re-file an ID that's already in `synced_ids`.

## Run procedure

1. **Read sync state.** Load `_System/granola-sync-state.json` (create empty if missing).
2. **List meetings.** Call `mcp__granola__list_meetings` with `time_range: "last_30_days"` (or `"last_week"` for a quick top-up).
3. **Filter to new.** Drop any meeting whose ID is in `synced_ids`.
4. **Fetch details in batches of 10.** Call `mcp__granola__get_meetings` with up to 10 IDs at a time. Each returns: title, date, attendees, AI summary, private notes.
5. **For each meeting:**
   - Route to workspace folder (see Routing below).
   - Build the note file (see File format below).
   - Write to `{workspace}/YYYY-MM-DD — {slug}.md`.
   - Add ID to sync state.
6. **Save sync state.**
7. **Report:** filed count, skipped count (junk), inbox count (couldn't route), per-workspace breakdown.

## Routing

Read the **workspace registry** at `~/Brain/_System/workspaces.yaml` — single source of truth. Every workspace entry has `keywords`, `people`, and a `meetings` folder path.

Routing algorithm:
1. Lowercase the meeting title.
2. For each workspace in `workspaces.yaml`, check if any of its `keywords` appear in the title (substring match). Score = count of matched keywords.
3. Check attendee emails against each workspace's `people` (supports `*@domain.com` wildcards). +1 score per match.
4. Pick the highest-scoring workspace. Use its `meetings` field as the destination folder.
5. Ties → fall back to `_Inbox/meetings/`.
6. Score = 0 → fall back to `_Inbox/meetings/`.

Special cases (apply BEFORE registry lookup):
- Title is exactly `New note`, `Untitled`, or empty AND summary is under 100 chars → **skip entirely** (Granola junk).
- Title contains `private`, `therapy`, `medical`, `confidential` → **skip and log as `[redacted]`**.

If you encounter a meeting that scores 0 against every workspace and is clearly tied to a new company/project (e.g. an interview at a company not yet in the registry), surface it in the run report so the user can decide whether to add a new workspace entry.

## File format

```markdown
---
meeting_id: <uuid>
date: YYYY-MM-DD
time: HH:MM <tz>
source: granola
attendees:
  - "Name <email>"
tags: [meeting, <workspace-tag>]
---

# YYYY-MM-DD — <Title>

## Notes

<Claude's analysis. This is the value-add. Write tight, in the user's voice (third person OK). Cover:
- What this meeting was actually about (1-2 lines)
- Decisions made or signals received
- Action items (use `- [ ]` so Tasks plugin picks them up)
- What this changes for related projects — link with [[wikilinks]] to existing vault pages
- Open questions worth tracking

Do NOT just rehash the Granola summary — that's already below. Add the interpretation Granola can't.>

## Granola summary

<Verbatim Granola AI summary. Demoted to reference. Don't edit.>

## My notes

<User's private notes from the meeting if present. Skip the section if empty.>
```

## Slug rules

- Lowercase, ASCII only.
- Replace spaces with `-`.
- Strip punctuation except hyphens.
- Cap at 60 chars.
- Examples:
  - `Product Interview Round 2 - Contact A` → `product-interview-round-2-contact-a`
  - `Eng Sync first-half / Team Sync next-half` → `eng-sync-team-sync`

## Filename pattern

`{workspace-folder}/YYYY-MM-DD — {slug}.md`

The em-dash separator is intentional and visually clear in the file explorer.

## Backfill mode

When called with "backfill" or first run:
- Use `time_range: "last_30_days"` (API max).
- Dispatch up to 5 parallel subagents, each handling 5 meetings, to keep wall clock down.
- After backfill, update `_System/index.md` to reference new workspace meeting folders.

## Index updates

After filing, for each new workspace folder created (e.g. `<Workspace>/meetings/`), add a line to `_System/index.md` under the workspace section. Skip if already present.

## Cross-linking (v2, not yet implemented)

Future: after filing, update the workspace's main page with a `## Recent meetings` section linking new entries. For now, just write the meeting file; cross-linking is manual.

## Skipped meetings

Granola has junk entries (test recordings, empty "New note"). Detection:
- Title is exactly `New note`, `Untitled`, or empty
- Granola summary is empty or under 100 chars
- No attendees beyond the creator AND the meeting is under 5 min

If skipped, log it in the report but do NOT add to `synced_ids` — that way if Granola updates the title later, we'll pick it up on next sync.

## Privacy guard

Skip filing of meetings tagged `(private)` in the title or where the title contains words: `therapy`, `medical`, `confidential`. Log as `[redacted]` in the report. The user can manually pull these if they want.

## What this skill explicitly doesn't do

- Doesn't pull transcripts (paid tier required).
- Doesn't update project pages (v2).
- Doesn't delete or modify existing meeting files on re-sync — only adds new ones.
- Doesn't sync future meetings (Granola's `list_meetings` only returns past).

## Commit

After a successful sync, commit the changes:
```
git -C ~/Brain add -A && git -C ~/Brain commit -m "meetings-sync: filed N meetings from Granola"
```
Only commit if at least one file was written.
