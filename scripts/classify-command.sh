#!/bin/bash
# classify-command.sh — PreToolUse hook for Bash commands
# Reads tool_input from stdin, checks against command rules.
# Returns hookSpecificOutput with permissionDecision: allow / deny / ask
#
# Compound-aware: splits on &&, ||, ; and checks each segment.
# Pipes (|) are NOT split — they form a single pipeline.
# Priority: REDIRECT → BLOCK → ASK → default ALLOW
# Redirect rules suggest safer alternatives when available.
# Uses jq regex (Oniguruma engine) for pattern matching.
# Fail-open: any error → allow the command.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
RULES_DIR="$PLUGIN_ROOT/rules"

# --- REDIRECT: deny with safer alternative ---
if [ -f "$RULES_DIR/redirect-commands.json" ]; then
  REDIRECT_REASON=$(jq -r --arg cmd "$COMMAND" '
    ($cmd | [splits("\\s*(?:&&|\\|\\||;)\\s*")] | map(select(length > 0))) as $segments |
    [.rules[] | . as $rule | select(
      ($rule.pattern as $p | ($cmd | test($p; "i")) or ($segments | any(test($p; "i")))) and
      (if $rule.safe_pattern then ($cmd | test($rule.safe_pattern; "i") | not) else true end)
    )][0].reason // empty
  ' "$RULES_DIR/redirect-commands.json" 2>/dev/null || true)

  if [ -n "$REDIRECT_REASON" ]; then
    jq -cn --arg reason "🛡️ SafeRun Guard: $REDIRECT_REASON" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
fi

# --- BLOCK: deny immediately ---
if [ -f "$RULES_DIR/block-commands.json" ]; then
  BLOCK_REASON=$(jq -r --arg cmd "$COMMAND" '
    ($cmd | [splits("\\s*(?:&&|\\|\\||;)\\s*")] | map(select(length > 0))) as $segments |
    [.rules[] | . as $rule | select($rule.pattern as $p | ($cmd | test($p; "i")) or ($segments | any(test($p; "i"))))][0].reason // empty
  ' "$RULES_DIR/block-commands.json" 2>/dev/null || true)

  if [ -n "$BLOCK_REASON" ]; then
    jq -cn --arg reason "🛡️ SafeRun Guard: $BLOCK_REASON" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
fi

# --- ASK: prompt user ---
if [ -f "$RULES_DIR/ask-commands.json" ]; then
  ASK_REASON=$(jq -r --arg cmd "$COMMAND" '
    ($cmd | [splits("\\s*(?:&&|\\|\\||;)\\s*")] | map(select(length > 0))) as $segments |
    [.rules[] | . as $rule | select($rule.pattern as $p | ($cmd | test($p; "i")) or ($segments | any(test($p; "i"))))][0].reason // empty
  ' "$RULES_DIR/ask-commands.json" 2>/dev/null || true)

  if [ -n "$ASK_REASON" ]; then
    jq -cn --arg reason "🛡️ SafeRun Guard: $ASK_REASON" '{
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
