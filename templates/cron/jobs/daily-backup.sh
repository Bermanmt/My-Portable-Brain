#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG="$VAULT/06-Agent/cron/logs/$(date +%Y-%m-%d)-daily-backup.log"

echo "[$(date)] daily-backup start" >> "$LOG"
cd "$VAULT" || exit 1
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[$(date)] not a git repo — skipping" >> "$LOG"
  exit 0
fi
git add -A
if git diff --cached --quiet; then
  echo "[$(date)] nothing to commit" >> "$LOG"
else
  git commit -m "daily backup $(date +%Y-%m-%d)" >> "$LOG" 2>&1
  echo "[$(date)] committed" >> "$LOG"
fi
echo "[$(date)] done" >> "$LOG"
