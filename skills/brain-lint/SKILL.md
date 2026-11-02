---
name: brain-lint
description: Audit the Brain vault for health issues — orphan pages, dead wikilinks, stale todos, empty pages, index drift, badly named files. Report only; never auto-fix. Trigger with /brain-lint, during weekly reviews, or after a big restructure.
---

# brain-lint

Audit the Brain vault for health issues. Reports problems but does NOT auto-fix — the user decides what to act on.

## When to use

- `/brain-lint` — manual trigger
- During weekly reviews — suggest running it
- After a big restructure or triage session

## How to run

### Step 1: Scan the vault

Run these checks across all `.md` files in the vault (excluding `_Claude/`, `_System/`, `_Sources/`, `attachments/`):

#### Dead links
Find all `[[wikilinks]]` and check if the target page exists. Report broken ones.

```bash
grep -roh '\[\[[^]]*\]\]' ~/Brain/ --include="*.md" | sort -u
```

Then verify each target resolves to a real file.

#### Orphan pages
Find pages with NO inbound links from any other page. Every wiki page should be reachable from at least one other page.

Exclude from orphan check: daily notes (`Daily/`), journal entries (`Journal/`), templates (`_System/`), index files.

#### Empty pages
Pages with only a heading and no real content (< 3 lines of non-blank text).

#### Stale todos
Tasks with past due dates (`📅 YYYY-MM-DD` where date < today) still marked `- [ ]`.

```bash
grep -rn '- \[ \].*📅' ~/Brain/ --include="*.md"
```

#### Index drift
Pages that exist in workspace folders but are missing from `_System/index.md`.

#### Unnamed files
Files with UUID-style names, `Pasted image` prefixes, or other non-descriptive filenames.

### Step 2: Write the report

Write findings to `_Claude/scratch/lint-report.md`:

```markdown
# Vault Lint Report — YYYY-MM-DD

## Dead Links (N)
- `[[target]]` in `File/path.md:line`

## Orphan Pages (N)
- `Path/to/page.md` — no inbound links

## Empty Pages (N)
- `Path/to/page.md` — only has heading

## Stale Todos (N)
- `- [ ] task text 📅 2026-04-15` in `File/path.md:line`

## Index Drift (N)
- `Path/to/page.md` — exists but not in index

## Unnamed Files (N)
- `Path/to/file.png` — non-descriptive filename

## Summary
X total issues found across Y categories.
```

### Step 3: Print summary to user

```
Lint complete — X issues found:
  • N dead links
  • N orphan pages
  • N empty pages
  • N stale todos
  • N index drift
  • N unnamed files

Full report: _Claude/scratch/lint-report.md
```

## Rules

- **Report only.** Never auto-fix. The user decides what to act on.
- **Skip private.** Don't lint files marked `#noTriage` or `(private)`.
- **Skip Claude's workspace.** `_Claude/`, `_System/`, `_Sources/` are not wiki pages.
- **Skip attachments.** Binary files in `attachments/` don't need inbound links.
- **Be precise.** Include file paths and line numbers so the user can navigate directly.
- **Don't over-report.** Daily notes without inbound links are fine. Journal entries without inbound links are fine. Only flag user-defined workspace pages as orphans.

## Related skills

- `/brain-triage` — the ingestion side
- `/brain-file` — filing research answers
- Weekly review template — suggest running lint during review
