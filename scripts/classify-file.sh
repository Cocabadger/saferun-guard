#!/bin/bash
# classify-file.sh — PreToolUse hook for Write and Edit tools
# Reads tool_input from stdin, checks file_path against file rules.
# Returns permissionDecision: allow / deny / ask
#
# Sprint 1: stub — allows everything.
# Sprint 3: real pattern matching against rules/*.json

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# TODO (Sprint 3): load rules, match file path patterns
# For now — allow all file operations
exit 0
