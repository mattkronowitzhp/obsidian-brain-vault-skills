# obsidian-brain-vault-skills

Nine Claude Code skills that turn an Obsidian vault into a working memory for AI coding sessions. Sessions write to the vault, the vault feeds the next session, and a daily job keeps it current from your meetings, mail, calendar, and tickets.

## What each skill does

| Skill | Run it when | Writes to |
|---|---|---|
| `brain-record` | At session start, then `/loop 10m /brain-record` | `_Claude/sessions/<project>/` live log, a primer, and the workspace page on `stop` |
| `brain-context` | A new session needs the state of a project | Nothing. Reads `<Workspace>/<Name>-context.md` and the latest primer |
| `brain-drop` | A session ends and nothing was recorded | The matching workspace page, or `_Inbox/` when routing is unclear |
| `brain-file` | An answer is worth keeping as a wiki page | A new page under the right workspace, plus `_System/index.md` |
| `brain-triage` | The daily note or `_Inbox/` has unsorted items | Workspace pages, rewritten in place |
| `brain-daily` | Unattended, once a day via launchd | Daily note, per-project context packs, new workspace stubs |
| `meetings-sync` | You want Granola meetings in the vault | `<Workspace>/meetings/` |
| `brain-lint` | Weekly, or after a restructure | Nothing. Reports orphans, dead links, stale todos |
| `claude-log` | Claude needs its own cross-session notes | `_Claude/sessions/` |

`brain-daily` and `meetings-sync` read Granola, Gmail, Google Calendar, and Linear through the claude.ai connectors. The other seven need only the filesystem.

## Vault layout the skills expect

```
~/Brain/
├── _System/
│   ├── workspaces.yaml      # routing registry; every skill reads it
│   ├── index.md             # one line per page
│   ├── daily-template.md
│   └── templates/           # workspace-generic, -project, -client, -job-search
├── _Inbox/                  # unsorted; brain-triage empties it
├── _Claude/sessions/        # live logs and primers, one folder per project
├── Daily/                   # YYYY-MM-DD.md
├── Archive/
└── <Workspace>/             # one folder per domain, e.g. Acme/, clients/<slug>/
```

`workspaces.yaml` is the only file you must edit by hand. Each entry maps a folder to keywords, people, and aliases. Skills score content against those fields and file it in the highest-scoring workspace. A child workspace with `parent:` set beats its parent on ties. See `vault/_System/workspaces.example.yaml`.

## Install

```bash
git clone https://github.com/<you>/obsidian-brain-vault-skills.git
cd obsidian-brain-vault-skills
./install.sh            # symlinks skills/* into ~/.claude/skills/
./install.sh --vault    # also scaffolds ~/Brain/_System from vault/ if it does not exist
```

Set `BRAIN_VAULT=/path/to/vault` before running if your vault is not at `~/Brain`. The skills themselves hardcode `~/Brain`; search and replace that path in `skills/*/SKILL.md` for a different location.

### Daily job

`launchd/com.example.brain-daily.plist` runs `vault/_System/bin/brain-daily.sh` at 16:32 local time. Replace `__HOME__` with your home directory, copy the plist to `~/Library/LaunchAgents/`, and load it:

```bash
sed "s#__HOME__#$HOME#g" launchd/com.example.brain-daily.plist > ~/Library/LaunchAgents/com.example.brain-daily.plist
launchctl load ~/Library/LaunchAgents/com.example.brain-daily.plist
```

The script passes an explicit read-only allowlist of connector tools to `claude -p`. Do not widen an entry to a bare server name. That would also grant the delete and send tools on that connector.

## Conventions the skills enforce

- Rewrite, don't append. Status sections on a workspace page are overwritten. Only `## Log` sections grow.
- Session notes are immutable. A correction goes in a newer note with a `contradiction::` marker.
- Never read the whole vault. Skills read `index.md`, `workspaces.yaml`, and the pages the task touches.
- Todos merge and dedupe. A todo that already exists is never re-added.
- Unclear routing goes to `_Inbox/`, never to a guessed workspace.

## License

MIT. See `LICENSE`.
