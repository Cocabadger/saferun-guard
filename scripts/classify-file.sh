#!/bin/bash
# classify-file.sh — PreToolUse hook for Write and Edit tools
# Reads tool_input from stdin, checks file_path against file rules.
# Returns hookSpecificOutput with permissionDecision: allow / deny / ask
#
# Priority: BLOCK → ASK → default ALLOW
# match_type: basename, path_contains, path_prefix
# Fail-open: any error → allow the operation.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
RULES_DIR="$PLUGIN_ROOT/rules"

BASENAME=$(basename "$FILE_PATH")

# Check rules file against file path
# Supports match_type: basename, path_contains, path_prefix
check_file_rules() {
  local rules_file="$1"

  if [ ! -f "$rules_file" ]; then
    return
  fi

  jq -r --arg fp "$FILE_PATH" --arg bn "$BASENAME" '
    [.rules[] |
      .pattern as $p |
      .match_type as $mt |
      select(
        ($mt == "basename" and ($bn | test($p; "i"))) or
        ($mt == "path_contains" and ($fp | test($p; "i"))) or
        ($mt == "path_prefix" and ($fp | test($p; "i")))
      )
    ][0].reason // empty
  ' "$rules_file" 2>/dev/null || true
}

# Check BLOCK rules — deny
BLOCK_REASON=$(check_file_rules "$RULES_DIR/block-files.json")
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

# Check ASK rules — prompt user
ASK_REASON=$(check_file_rules "$RULES_DIR/ask-files.json")
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

# Default: allow
exit 0
