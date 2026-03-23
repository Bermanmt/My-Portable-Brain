#!/bin/bash
# =============================================================================
# pattern-check.sh — Detect patterns, pending actions, and recurring carries
# =============================================================================
# Scans daily notes, weekly notes, and project files to surface:
# - Unchecked action items across daily notes (last 7 days)
# - Repeated carries (same item carried 2+ weeks)
# - Projects with next actions that haven't changed in 2+ weeks
# - Open loops from CRM contacts
# - Uncommitted tasks from weekly notes
#
# Writes to 06-Agent/workspace/pending-actions.md
# Pepe reads this during session start to nag about forgotten things.
#
# Run via cron nightly (e.g., 9:30pm) or manually: brain pattern-check
# =============================================================================

set -e

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENT="$VAULT/06-Agent"
OUTPUT="$AGENT/workspace/pending-actions.md"
LOG="$AGENT/cron/logs/$(date +%Y-%m-%d)-pattern-check.log"

mkdir -p "$AGENT/cron/logs"

echo "[$(date)] pattern-check start" >> "$LOG"

# --- Date helpers (portable: macOS + Linux) ---
TODAY=$(date +%Y-%m-%d)
NOW=$(date +%s)

date_n_days_ago() {
    local n="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        date -v-${n}d +%Y-%m-%d
    else
        date -d "$TODAY - ${n} days" +%Y-%m-%d
    fi
}

# =============================================================================
# SCAN 1: Unchecked action items from recent daily notes (last 7 days)
# =============================================================================
UNCHECKED_ACTIONS=""
UNCHECKED_COUNT=0

for i in $(seq 0 6); do
    d=$(date_n_days_ago "$i")
    daily="$VAULT/07-Systems/goals/daily/${d}.md"
    [ -f "$daily" ] || continue

    # Find unchecked items (- [ ] lines) — skip empty checkboxes
    while IFS= read -r line; do
        item=$(echo "$line" | sed 's/^- \[ \] //' | sed 's/^[[:space:]]*//')
        # Skip empty or whitespace-only items
        [ -z "$item" ] && continue
        UNCHECKED_ACTIONS="${UNCHECKED_ACTIONS}- ${d}: ${item}\n"
        UNCHECKED_COUNT=$((UNCHECKED_COUNT + 1))
    done < <(grep "^\- \[ \]" "$daily" 2>/dev/null | grep -v "^\- \[ \][[:space:]]*$" || true)
done

echo "  Unchecked daily actions (7d): $UNCHECKED_COUNT" >> "$LOG"

# =============================================================================
# SCAN 2: Repeated carries across weekly notes
# =============================================================================
# Look at the last 3 weekly notes' "Carries forward" sections
# If the same item appears in 2+ weeks, it's a pattern

WEEKLY_DIR="$VAULT/07-Systems/goals/weekly"
CARRY_ITEMS=""
CARRY_PATTERNS=""
CARRY_PATTERN_COUNT=0

# Get last 3 weekly files (sorted, most recent first)
RECENT_WEEKS=$(ls "$WEEKLY_DIR"/202*.md 2>/dev/null | grep -v _template | sort -r | head -3)

declare -A CARRY_MAP  # item text → count

for wfile in $RECENT_WEEKS; do
    week_name=$(basename "$wfile" .md)

    # Extract carries forward section
    in_carries=0
    while IFS= read -r line; do
        if echo "$line" | grep -qi "carries forward\|carry forward"; then
            in_carries=1
            continue
        fi
        if [ "$in_carries" -eq 1 ]; then
            # Stop at next section
            if echo "$line" | grep -q "^##\|^\*\*"; then
                in_carries=0
                continue
            fi
            # Extract carry item (strip markdown formatting)
            item=$(echo "$line" | sed 's/^- //' | sed 's/\*\*//g' | sed 's/→.*$//' | sed 's/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
            [ -z "$item" ] && continue
            # Simple dedup key: first 30 chars
            key=$(echo "$item" | cut -c1-30)
            if [ -n "$key" ]; then
                current=${CARRY_MAP["$key"]:-0}
                CARRY_MAP["$key"]=$((current + 1))
                # Store the full text on first occurrence
                if [ "$current" -eq 0 ]; then
                    eval "CARRY_TEXT_${key//[^a-zA-Z0-9]/_}=\"$line\""
                fi
            fi
        fi
    done < "$wfile"
done

for key in "${!CARRY_MAP[@]}"; do
    count=${CARRY_MAP["$key"]}
    if [ "$count" -ge 2 ]; then
        CARRY_PATTERNS="${CARRY_PATTERNS}- **Carried ${count} weeks:** ${key}...\n"
        CARRY_PATTERN_COUNT=$((CARRY_PATTERN_COUNT + 1))
    fi
done

echo "  Repeated carries: $CARRY_PATTERN_COUNT" >> "$LOG"

# =============================================================================
# SCAN 3: Stale project next actions (same content, 14+ days)
# =============================================================================
STALE_ACTIONS=""
STALE_ACTION_COUNT=0

for readme in "$VAULT"/01-Projects/*/README.md; do
    [ -f "$readme" ] || continue
    proj_name=$(basename "$(dirname "$readme")")
    [ "$proj_name" = "_template" ] && continue

    status=$(grep -m1 "^status:" "$readme" 2>/dev/null | sed 's/status: *//')
    [ "$status" != "active" ] && continue

    # Get modification age
    if [[ "$OSTYPE" == "darwin"* ]]; then
        mod=$(stat -f %m "$readme" 2>/dev/null || echo "$NOW")
    else
        mod=$(stat -c %Y "$readme" 2>/dev/null || echo "$NOW")
    fi
    days_old=$(( (NOW - mod) / 86400 ))

    if [ "$days_old" -ge 14 ]; then
        # Get first unchecked next action
        next_action=$(sed -n '/^## Next Action/,/^## /p' "$readme" | grep -m1 "^\- \[ \]" | sed 's/^- \[ \] //')
        if [ -n "$next_action" ]; then
            STALE_ACTIONS="${STALE_ACTIONS}- **$proj_name** (${days_old}d): $next_action\n"
            STALE_ACTION_COUNT=$((STALE_ACTION_COUNT + 1))
        fi
    fi
done

echo "  Stale project actions (14d+): $STALE_ACTION_COUNT" >> "$LOG"

# =============================================================================
# SCAN 4: Open loops from CRM contacts
# =============================================================================
OPEN_LOOPS=""
OPEN_LOOP_COUNT=0

for contact in "$VAULT"/07-Systems/CRM/contacts/*.md; do
    [ -f "$contact" ] || continue
    contact_name=$(basename "$contact" .md)
    [ "$contact_name" = "_template" ] && continue

    # Extract open loops (unchecked items under Open Loops section)
    in_loops=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "^## Open Loops"; then
            in_loops=1
            continue
        fi
        if [ "$in_loops" -eq 1 ]; then
            if echo "$line" | grep -q "^##"; then
                in_loops=0
                continue
            fi
            if echo "$line" | grep -q "^\- \[ \]"; then
                item=$(echo "$line" | sed 's/^- \[ \] //')
                # Skip empty checkboxes
                [ -z "$item" ] && continue
                [ "$item" = "- [ ]" ] && continue
                display_name=$(echo "$contact_name" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
                OPEN_LOOPS="${OPEN_LOOPS}- **$display_name**: $item\n"
                OPEN_LOOP_COUNT=$((OPEN_LOOP_COUNT + 1))
            fi
        fi
    done < "$contact"
done

echo "  CRM open loops: $OPEN_LOOP_COUNT" >> "$LOG"

# =============================================================================
# SCAN 5: Uncommitted weekly tasks
# =============================================================================
WEEKLY_TASKS=""
WEEKLY_TASK_COUNT=0

# Current week's file
CURRENT_WEEK=$(date +%G-W%V)
CURRENT_WEEKLY="$WEEKLY_DIR/${CURRENT_WEEK}.md"

if [ -f "$CURRENT_WEEKLY" ]; then
    in_tasks=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "^## Tasks"; then
            in_tasks=1
            continue
        fi
        if [ "$in_tasks" -eq 1 ]; then
            if echo "$line" | grep -q "^##"; then
                in_tasks=0
                continue
            fi
            if echo "$line" | grep -q "^\- \[ \]"; then
                item=$(echo "$line" | sed 's/^- \[ \] //')
                WEEKLY_TASKS="${WEEKLY_TASKS}- $item\n"
                WEEKLY_TASK_COUNT=$((WEEKLY_TASK_COUNT + 1))
            fi
        fi
    done < "$CURRENT_WEEKLY"
fi

echo "  Uncommitted weekly tasks: $WEEKLY_TASK_COUNT" >> "$LOG"

# =============================================================================
# WRITE REPORT
# =============================================================================

TOTAL=$((UNCHECKED_COUNT + CARRY_PATTERN_COUNT + STALE_ACTION_COUNT + OPEN_LOOP_COUNT + WEEKLY_TASK_COUNT))

cat > "$OUTPUT" << REPORT
# Pending Actions & Patterns
*Generated: ${TODAY} · ${TOTAL} items detected*

REPORT

# Repeated carries (most important — things that keep slipping)
if [ "$CARRY_PATTERN_COUNT" -gt 0 ]; then
    cat >> "$OUTPUT" << SECTION
## Recurring Carries
These items have been carried across 2+ weekly reviews. Decide: do them, delegate them, or drop them.

$(echo -e "$CARRY_PATTERNS")
SECTION
fi

# Stale project actions
if [ "$STALE_ACTION_COUNT" -gt 0 ]; then
    cat >> "$OUTPUT" << SECTION
## Stale Project Actions (14+ days unchanged)
These next actions haven't moved. Either the project is parked (make it official) or the action needs breaking down.

$(echo -e "$STALE_ACTIONS")
SECTION
fi

# Open loops from contacts
if [ "$OPEN_LOOP_COUNT" -gt 0 ]; then
    cat >> "$OUTPUT" << SECTION
## CRM Open Loops
Commitments to people that haven't been closed.

$(echo -e "$OPEN_LOOPS")
SECTION
fi

# Weekly tasks
if [ "$WEEKLY_TASK_COUNT" -gt 0 ]; then
    cat >> "$OUTPUT" << SECTION
## This Week's Uncompleted Tasks (${CURRENT_WEEK})
$(echo -e "$WEEKLY_TASKS")
SECTION
fi

# Unchecked daily actions
if [ "$UNCHECKED_COUNT" -gt 0 ]; then
    cat >> "$OUTPUT" << SECTION
## Unchecked Items from Daily Notes (last 7 days)
$(echo -e "$UNCHECKED_ACTIONS")
SECTION
fi

# If nothing found
if [ "$TOTAL" -eq 0 ]; then
    cat >> "$OUTPUT" << SECTION
## All Clear
No pending actions, recurring carries, or open loops detected. Clean slate.

SECTION
fi

echo "[$(date)] pattern-check complete — $TOTAL items" >> "$LOG"
echo "Pattern check: $TOTAL items detected"
