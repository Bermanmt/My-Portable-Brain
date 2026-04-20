#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENT="$VAULT/06-Agent"
bash "$VAULT/05-Meta/vault-health.sh" >> "$AGENT/cron/logs/vault-lint.log" 2>&1
