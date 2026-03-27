#!/bin/bash
# =============================================================================
# refresh-all.sh — Run all pure-bash cron jobs if their outputs are stale
# =============================================================================
# This is the fallback-as-primary mechanism. When launchd/cron can't run
# (macOS TCC blocks, new machine, portable vault), the agent calls this
# script at session start to ensure all data is fresh.
#
# Two tiers:
#   Tier 1 (pure bash) — runs here, unconditionally if stale
#   Tier 2 (LLM-dependent) — checked for staleness, flagged for the agent
#
# Usage:
#   bash refresh-all.sh           # refresh stale outputs
#   bash refresh-all.sh --force   # refresh everything regardless
#   bash refresh-all.sh --status  # just report what's stale, don't run
#
# Exit codes:
#   0 — everything fresh (or refreshed successfully)
#   1 — error during refresh
#   2 — (--status mode) some outputs are stale
# =============================================================================

set -e

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENT="$VAULT/06-Agent"
LOG="$AGENT/cron/logs/$(date +%Y-%m-%d)-refresh-all.log"

mkdir -p "$AGENT/cron/logs"

# --- Parse flags ---
FORCE=false
STATUS_ONLY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) FORCE=true; shift ;;
        --status) STATUS_ONLY=true; shift ;;
        *) shift ;;
    esac
done

# --- Date helpers (portable: macOS + Linux) ---
TODAY=$(date +%Y-%m-%d)
NOW=$(date +%s)

file_age_hours() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "999999"
        return
    fi
    local mod
    if [[ "$OSTYPE" == "darwin"* ]]; then
        mod=$(stat -f %m "$file" 2>/dev/null || echo "0")
    else
        mod=$(stat -c %Y "$file" 2>/dev/null || echo "0")
    fi
    echo $(( (NOW - mod) / 3600 ))
}

file_age_date() {
    # Returns the date (YYYY-MM-DD) the file was last modified
    local file="$1"
    [ -f "$file" ] || { echo "never"; return; }
    if [[ "$OSTYPE" == "darwin"* ]]; then
        date -r "$(stat -f %m "$file")" +%Y-%m-%d 2>/dev/null || echo "unknown"
    else
        date -d "@$(stat -c %Y "$file")" +%Y-%m-%d 2>/dev/null || echo "unknown"
    fi
}

# --- Staleness thresholds ---
# Each job has an output file and a max age before it's considered stale
declare -A TIER1_JOBS        # script → output file
declare -A TIER1_MAX_HOURS   # script → max age in hours
declare -A TIER1_NAMES       # script → human name

# Jobs that create/update daily notes and briefing data — must be today
TIER1_JOBS[daily-briefing]="$VAULT/07-Systems/goals/daily/${TODAY}.md"
TIER1_MAX_HOURS[daily-briefing]=12
TIER1_NAMES[daily-briefing]="Daily briefing"

# CRM scan — should be <24h old
TIER1_JOBS[crm-scan]="$AGENT/subagents/crm-manager/briefing.md"
TIER1_MAX_HOURS[crm-scan]=24
TIER1_NAMES[crm-scan]="CRM scan"

# Pattern check — should be <24h old
TIER1_JOBS[pattern-check]="$AGENT/workspace/pending-actions.md"
TIER1_MAX_HOURS[pattern-check]=24
TIER1_NAMES[pattern-check]="Pattern check"

# Vault health — should be <48h old (runs less frequently)
TIER1_JOBS[vault-health]="$AGENT/workspace/vault-health.md"
TIER1_MAX_HOURS[vault-health]=48
TIER1_NAMES[vault-health]="Vault health"

# Context pack — should be <12h old
TIER1_JOBS[rebuild-context]="$AGENT/workspace/CONTEXT-PACK.md"
TIER1_MAX_HOURS[rebuild-context]=12
TIER1_NAMES[rebuild-context]="Context pack rebuild"

# Daily backup (git) — should be <24h
TIER1_JOBS[daily-backup]="$AGENT/cron/logs/${TODAY}-daily-backup.log"
TIER1_MAX_HOURS[daily-backup]=24
TIER1_NAMES[daily-backup]="Daily git backup"

# --- Tier 2: LLM-dependent jobs (check only, don't run) ---
declare -A TIER2_JOBS
declare -A TIER2_MAX_HOURS
declare -A TIER2_NAMES

TIER2_JOBS[daily-closing]="$AGENT/cron/logs/${TODAY}-daily-closing.log"
TIER2_MAX_HOURS[daily-closing]=24
TIER2_NAMES[daily-closing]="Daily closing (LLM)"

TIER2_JOBS[inbox-sweep]="$AGENT/cron/logs/${TODAY}-inbox-sweep.log"
TIER2_MAX_HOURS[inbox-sweep]=24
TIER2_NAMES[inbox-sweep]="Inbox sweep (LLM)"

TIER2_JOBS[weekly-review]="$AGENT/cron/logs/${TODAY}-weekly-review.log"
TIER2_MAX_HOURS[weekly-review]=168  # weekly
TIER2_NAMES[weekly-review]="Weekly review (LLM)"

# =============================================================================
# RUN
# =============================================================================

echo "[$(date)] refresh-all start (force=$FORCE, status=$STATUS_ONLY)" >> "$LOG"

REFRESHED=0
SKIPPED=0
FAILED=0
STALE_LLM=""
STATUS_REPORT=""

# --- Tier 1: Pure bash jobs ---
# Order matters: daily-briefing first (creates daily note), then others, context pack last
TIER1_ORDER="daily-briefing crm-scan pattern-check vault-health daily-backup rebuild-context"

for job in $TIER1_ORDER; do
    output="${TIER1_JOBS[$job]}"
    max_hours="${TIER1_MAX_HOURS[$job]}"
    name="${TIER1_NAMES[$job]}"
    script="$SCRIPT_DIR/${job}.sh"

    if [ ! -f "$script" ]; then
        echo "  SKIP $job — script not found" >> "$LOG"
        continue
    fi

    age=$(file_age_hours "$output")
    age_date=$(file_age_date "$output")

    if [ "$FORCE" = true ] || [ "$age" -ge "$max_hours" ]; then
        if [ "$STATUS_ONLY" = true ]; then
            STATUS_REPORT="${STATUS_REPORT}STALE  ${name} (last: ${age_date}, threshold: ${max_hours}h)\n"
            continue
        fi

        echo "  RUN  $job (output age: ${age}h, threshold: ${max_hours}h)" >> "$LOG"
        if bash "$script" >> "$LOG" 2>&1; then
            REFRESHED=$((REFRESHED + 1))
            echo "  OK   $job" >> "$LOG"
        else
            FAILED=$((FAILED + 1))
            echo "  FAIL $job (exit $?)" >> "$LOG"
        fi
    else
        SKIPPED=$((SKIPPED + 1))
        echo "  SKIP $job (fresh — ${age}h old, threshold: ${max_hours}h)" >> "$LOG"
        if [ "$STATUS_ONLY" = true ]; then
            STATUS_REPORT="${STATUS_REPORT}FRESH  ${name} (last: ${age_date})\n"
        fi
    fi
done

# --- Tier 2: LLM jobs (check staleness, flag for agent) ---
for job in daily-closing inbox-sweep weekly-review; do
    output="${TIER2_JOBS[$job]}"
    max_hours="${TIER2_MAX_HOURS[$job]}"
    name="${TIER2_NAMES[$job]}"

    age=$(file_age_hours "$output")
    age_date=$(file_age_date "$output")

    if [ "$age" -ge "$max_hours" ]; then
        STALE_LLM="${STALE_LLM}- ${name}: last ran ${age_date} (>${max_hours}h threshold)\n"
        if [ "$STATUS_ONLY" = true ]; then
            STATUS_REPORT="${STATUS_REPORT}STALE  ${name} (last: ${age_date}, needs agent) ⚡\n"
        fi
    else
        if [ "$STATUS_ONLY" = true ]; then
            STATUS_REPORT="${STATUS_REPORT}FRESH  ${name} (last: ${age_date})\n"
        fi
    fi
done

# --- Status mode: just print and exit ---
if [ "$STATUS_ONLY" = true ]; then
    echo -e "$STATUS_REPORT"
    if echo -e "$STATUS_REPORT" | grep -q "^STALE"; then
        exit 2
    fi
    exit 0
fi

# --- Summary ---
SUMMARY="Refreshed: $REFRESHED | Skipped (fresh): $SKIPPED | Failed: $FAILED"
if [ -n "$STALE_LLM" ]; then
    SUMMARY="${SUMMARY}\nLLM jobs needing agent compensation:\n${STALE_LLM}"
fi

echo "[$(date)] refresh-all done — $SUMMARY" >> "$LOG"
echo -e "$SUMMARY"

# Print LLM compensation flags to stdout so the agent can read them
if [ -n "$STALE_LLM" ]; then
    echo ""
    echo "AGENT_COMPENSATE:"
    echo -e "$STALE_LLM"
fi

[ "$FAILED" -eq 0 ] || exit 1
exit 0
