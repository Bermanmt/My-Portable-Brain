#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENT="$VAULT/06-Agent"
DATE=$(date +%Y-%m-%d)
LOG="$AGENT/cron/logs/$DATE-inbox-sweep.log"
source "$AGENT/config/llm.conf"

SYSTEM=$(cat "$AGENT/subagents/inbox-processor/AGENT.md")
TASK=$(cat "$AGENT/cron/prompts/inbox-sweep.md")

echo "[$(date)] inbox-sweep start" >> "$LOG"
run_llm "$SYSTEM" "$TASK" >> "$LOG" 2>&1
echo "[$(date)] done" >> "$LOG"
