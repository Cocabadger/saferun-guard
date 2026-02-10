#!/bin/bash
# audit-log.sh — PostToolUse hook (async)
# Logs every tool action to ~/.saferun/audit.jsonl
#
# Sprint 1: stub — logs basic info.
# Sprint 4: full structured logging with event types.

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "PostToolUse"')

# Extract a short summary of the input
case "$TOOL_NAME" in
  Bash)
    SUMMARY=$(echo "$INPUT" | jq -r '.tool_input.command // empty' | head -c 200)
    ;;
  Write|Edit)
    SUMMARY=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
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
  --arg decision "allow" \
  --arg reason "" \
  --arg type "auto_resolved" \
  --arg layer "stub" \
  '{ts: $ts, session: $session, tool: $tool, input: $input, decision: $decision, reason: $reason, type: $type, layer: $layer}' \
  >> "$LOG_FILE"

exit 0
