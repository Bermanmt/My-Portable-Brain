#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG="$VAULT/06-Agent/cron/logs/$(date +%Y-%m-%d)-weekly-tag.log"
TAG=$(date +%Y-W%V)

echo "[$(date)] weekly-tag start — $TAG" >> "$LOG"
cd "$VAULT"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "[$(date)] tag $TAG already exists, skipping" >> "$LOG"
else
  git tag "$TAG" >> "$LOG" 2>&1
  echo "[$(date)] tagged $TAG" >> "$LOG"
fi
echo "[$(date)] done" >> "$LOG"
