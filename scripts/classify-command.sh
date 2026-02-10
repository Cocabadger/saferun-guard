#!/bin/bash
# classify-command.sh — PreToolUse hook for Bash commands
# Reads tool_input from stdin, checks against command rules.
# Returns permissionDecision: allow / deny / ask
#
# Sprint 1: stub — allows everything.
# Sprint 2: real regex matching against rules/*.json

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# TODO (Sprint 2): load rules, match patterns
# For now — allow all commands
exit 0
