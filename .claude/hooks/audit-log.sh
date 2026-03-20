#!/usr/bin/env bash
# Audit log hook for PostToolUse
# Requires: bash/zsh, jq
# Log rotation: daily (YYYY-MM-DD suffix)

LOG_DIR="${HOME}/.claude/audit-logs"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y-%m-%d)
LOG_FILE="${LOG_DIR}/audit-${DATE}.jsonl"

# Read stdin
INPUT=$(cat)

# Extract fields
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$INPUT"  | jq -r '.tool_name   // "unknown"')
CWD=$(echo "$INPUT"        | jq -r '.cwd          // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input   // {}')

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Write log entry as a single JSONL line
printf '%s\n' "$(jq -cn \
  --arg ts         "$TIMESTAMP" \
  --arg session    "$SESSION_ID" \
  --arg tool       "$TOOL_NAME" \
  --arg cwd        "$CWD" \
  --argjson input  "$TOOL_INPUT" \
  '{timestamp: $ts, session_id: $session, tool_name: $tool, cwd: $cwd, tool_input: $input}'
)" >> "$LOG_FILE"

exit 0
