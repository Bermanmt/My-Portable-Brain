#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENT="$VAULT/06-Agent"
DATE=$(date +%Y-%m-%d)
LOG="$AGENT/cron/logs/$DATE-daily-closing.log"
source "$AGENT/config/llm.conf"

SYSTEM=$(cat "$AGENT/workspace/AGENTS.md")
TASK=$(cat "$AGENT/cron/prompts/daily-closing.md")

echo "[$(date)] daily-closing start" >> "$LOG"
run_llm "$SYSTEM" "$TASK" >> "$LOG" 2>&1
echo "[$(date)] done" >> "$LOG"
