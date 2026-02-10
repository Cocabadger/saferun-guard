#!/bin/bash
# classify-command.sh — PreToolUse hook for Bash commands
# Reads tool_input from stdin, checks against command rules.
# Returns hookSpecificOutput with permissionDecision: allow / deny / ask
#
# Priority: BLOCK → ASK → default ALLOW
# Uses jq regex (Oniguruma engine) for pattern matching.
# Fail-open: any error → allow the command.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
RULES_DIR="$PLUGIN_ROOT/rules"

# Check BLOCK rules — deny immediately
if [ -f "$RULES_DIR/block-commands.json" ]; then
  BLOCK_REASON=$(jq -r --arg cmd "$COMMAND" \
    '[.rules[] | select(.pattern as $p | $cmd | test($p; "i"))][0].reason // empty' \
    "$RULES_DIR/block-commands.json" 2>/dev/null || true)

  if [ -n "$BLOCK_REASON" ]; then
    jq -cn --arg reason "$BLOCK_REASON" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
fi

# Check ASK rules — prompt user
if [ -f "$RULES_DIR/ask-commands.json" ]; then
  ASK_REASON=$(jq -r --arg cmd "$COMMAND" \
    '[.rules[] | select(.pattern as $p | $cmd | test($p; "i"))][0].reason // empty' \
    "$RULES_DIR/ask-commands.json" 2>/dev/null || true)

  if [ -n "$ASK_REASON" ]; then
    jq -cn --arg reason "$ASK_REASON" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
fi

# Default: allow
exit 0
