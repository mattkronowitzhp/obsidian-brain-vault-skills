#!/bin/zsh
#
# brain-daily — launchd wrapper
#
# launchd gives a process a near-empty environment, so PATH must be set
# explicitly or `claude` won't resolve. Invoked by
# ~/Library/LaunchAgents/com.example.brain-daily.plist every day at 16:32.
#
# Manual run:  ~/Brain/_System/bin/brain-daily.sh
# Dry run:     ~/Brain/_System/bin/brain-daily.sh --dry-run

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

VAULT="$HOME/Brain"
LOG_DIR="$VAULT/_System/logs"
LOG="$LOG_DIR/brain-daily.log"

mkdir -p "$LOG_DIR"

cd "$VAULT" || { echo "[$(date -u +%FT%TZ)] FATAL: vault not found at $VAULT" >>"$LOG"; exit 1; }

command -v claude >/dev/null 2>&1 || {
  echo "[$(date -u +%FT%TZ)] FATAL: claude not on PATH ($PATH)" >>"$LOG"
  exit 1
}

# Keep the log from growing without bound (mirrors the vault's own bounding philosophy).
if [[ -f "$LOG" ]] && [[ $(wc -c <"$LOG") -gt 5242880 ]]; then
  mv "$LOG" "$LOG.1"
fi

ARGS="${*:-}"

{
  echo ""
  echo "═══════════════════════════════════════════════════"
  echo "[$(date -u +%FT%TZ)] brain-daily starting ${ARGS:+($ARGS)}"
  echo "═══════════════════════════════════════════════════"
} >>"$LOG"

# MCP tools need explicit allowlisting: a headless run cannot surface an approval
# prompt, so an un-allowlisted connector call just fails with "you haven't granted it yet".
# These duplicate the grants in settings.local.json so the job still runs if a settings
# file is missing. READ-ONLY BY DESIGN — never widen these to a bare server name
# (e.g. "mcp__claude_ai_Gmail"), which would also grant trash_thread, create_draft,
# delete_event, and save_issue. brain-daily only ever reads from connectors.
ALLOWED_TOOLS="mcp__claude_ai_Gmail__search_threads mcp__claude_ai_Gmail__get_thread"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Gmail__get_message mcp__claude_ai_Gmail__list_labels"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Google_Calendar__list_events"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Google_Calendar__search_events"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Google_Calendar__get_event"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Google_Calendar__list_calendars"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Granola__list_meetings"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Granola__get_meetings"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Granola__query_granola_meetings"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Granola__list_meeting_folders"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Granola__get_meeting_transcript"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Linear__list_issues mcp__claude_ai_Linear__get_issue"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Linear__list_comments mcp__claude_ai_Linear__list_projects"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Linear__get_project mcp__claude_ai_Linear__list_teams"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Linear__list_users mcp__claude_ai_Linear__get_user"
ALLOWED_TOOLS="$ALLOWED_TOOLS mcp__claude_ai_Linear__list_cycles mcp__claude_ai_Linear__list_issue_statuses"
ALLOWED_TOOLS="$ALLOWED_TOOLS Read Write Edit Glob Grep Bash Skill TodoWrite"

# ~/.claude/projects holds the session transcripts and sits outside the vault,
# so it must be added explicitly or the jq prefilter is sandbox-blocked.
claude -p "/brain-daily ${ARGS}" \
  --model claude-sonnet-5 \
  --permission-mode acceptEdits \
  --add-dir "$HOME/.claude/projects" \
  --allowedTools "$ALLOWED_TOOLS" \
  >>"$LOG" 2>&1

STATUS=$?
echo "[$(date -u +%FT%TZ)] brain-daily finished (exit $STATUS)" >>"$LOG"
exit $STATUS
