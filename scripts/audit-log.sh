#!/bin/bash
# audit-log.sh — PostToolUse hook (async, non-blocking)
# Logs every executed tool action to ~/.saferun/audit.jsonl
#
# Runs AFTER tool execution. Only logs allowed actions
# (denied actions never reach PostToolUse).

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

# Extract a short summary of the input (no content — too large)
case "$TOOL_NAME" in
  Bash)
    SUMMARY=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null | head -c 200)
    ;;
  Write)
    SUMMARY=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    ;;
  Edit)
    SUMMARY=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    ;;
  Read)
    SUMMARY=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    ;;
  *)
    SUMMARY="$TOOL_NAME"
    ;;
esac

LOG_DIR="$HOME/.saferun"
LOG_FILE="$LOG_DIR/audit.jsonl"

mkdir -p "$LOG_DIR"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -cn \
  --arg ts "$TIMESTAMP" \
  --arg session "$SESSION_ID" \
  --arg tool "$TOOL_NAME" \
  --arg input "$SUMMARY" \
  --arg cwd "$CWD" \
  '{ts: $ts, session: $session, tool: $tool, input: $input, cwd: $cwd}' \
  >> "$LOG_FILE"

exit 0
