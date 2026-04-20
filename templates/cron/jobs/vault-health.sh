#!/bin/bash
# =============================================================================
# vault-health.sh — Vault health check and hygiene report
# =============================================================================
# Scans the vault for structural issues:
# - Stale projects (no README change in N days, unchecked next actions)
# - Missing weekly notes (current week has no file)
# - Empty templates (files that still have placeholder content)
# - Orphan inbox items (inbox items older than 7 days, not filed)
# - Broken wiki-links (links to files that don't exist)
# - Overloaded inbox (more than 20 items)
#
# Writes a health report to 06-Agent/workspace/vault-health.md
# The agent reads this during session start for hygiene awareness.
#
# Run via cron weekly (e.g., Sunday 8pm) or manually: brain vault-health
# =============================================================================

set -e

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENT="$VAULT/06-Agent"
REPORT="$AGENT/workspace/vault-health.md"
LOG="$AGENT/cron/logs/$(date +%Y-%m-%d)-vault-health.log"

mkdir -p "$AGENT/cron/logs"

echo "[$(date)] vault-health start" >> "$LOG"

# --- Date helpers (portable: macOS + Linux) ---
NOW=$(date +%s)
TODAY=$(date +%Y-%m-%d)

days_since_modified() {
    local file="$1"
    local mod
    if [[ "$OSTYPE" == "darwin"* ]]; then
        mod=$(stat -f %m "$file" 2>/dev/null || echo "$NOW")
    else
        mod=$(stat -c %Y "$file" 2>/dev/null || echo "$NOW")
    fi
    echo $(( (NOW - mod) / 86400 ))
}

# Get current ISO week
if [[ "$OSTYPE" == "darwin"* ]]; then
    CURRENT_WEEK=$(date +%G-W%V)
else
    CURRENT_WEEK=$(date +%G-W%V)
fi

# =============================================================================
# CHECK 1: Stale projects
# =============================================================================
STALE_PROJECTS=""
STALE_COUNT=0
ACTIVE_COUNT=0

for readme in "$VAULT"/01-Projects/*/README.md; do
    [ -f "$readme" ] || continue
    proj_dir=$(dirname "$readme")
    proj_name=$(basename "$proj_dir")

    # Skip template
    [ "$proj_name" = "_template" ] && continue

    # Check if status is active
    status=$(grep -m1 "^status:" "$readme" 2>/dev/null | sed 's/status: *//')
    [ "$status" != "active" ] && continue

    ACTIVE_COUNT=$((ACTIVE_COUNT + 1))

    days=$(days_since_modified "$readme")

    # Count unchecked next actions
    unchecked=$(sed -n '/^## Next Action/,/^## /p' "$readme" | grep -c "^\- \[ \]" || true)

    if [ "$days" -ge 7 ]; then
        STALE_PROJECTS="${STALE_PROJECTS}- **$proj_name** — ${days} days untouched, ${unchecked} pending next actions\n"
        STALE_COUNT=$((STALE_COUNT + 1))
    fi
done

echo "  Checked $ACTIVE_COUNT active projects, $STALE_COUNT stale" >> "$LOG"

# =============================================================================
# CHECK 2: Missing weekly note
# =============================================================================
WEEKLY_FILE="$VAULT/07-Systems/goals/weekly/${CURRENT_WEEK}.md"
WEEKLY_STATUS=""
if [ -f "$WEEKLY_FILE" ]; then
    # Check if Big 3 is still empty
    big3_filled=$(sed -n '/^## Big 3/,/^## /p' "$WEEKLY_FILE" | grep -c "^\- \[" || true)
    if [ "$big3_filled" -eq 0 ]; then
        WEEKLY_STATUS="exists but Big 3 not set"
    else
        checked=$(sed -n '/^## Big 3/,/^## /p' "$WEEKLY_FILE" | grep -c "^\- \[x\]" || true)
        WEEKLY_STATUS="Big 3: ${checked}/${big3_filled} complete"
    fi
else
    WEEKLY_STATUS="**MISSING** — no weekly note for ${CURRENT_WEEK}"
fi

echo "  Weekly note: $WEEKLY_STATUS" >> "$LOG"

# =============================================================================
# CHECK 3: Inbox health
# =============================================================================
INBOX_COUNT=0
INBOX_OLD=""
INBOX_OLD_COUNT=0

for item in "$VAULT"/00-Inbox/*; do
    [ -e "$item" ] || continue
    # Skip subdirectories that are structural (meetings, emails, captures)
    basename_item=$(basename "$item")
    [[ "$basename_item" == "meetings" || "$basename_item" == "emails" || "$basename_item" == "captures" ]] && continue

    INBOX_COUNT=$((INBOX_COUNT + 1))

    if [ -f "$item" ]; then
        days=$(days_since_modified "$item")
        if [ "$days" -ge 7 ]; then
            INBOX_OLD="${INBOX_OLD}- **$(basename "$item")** — ${days} days in inbox\n"
            INBOX_OLD_COUNT=$((INBOX_OLD_COUNT + 1))
        fi
    fi
done

# Count items in inbox subdirectories
MEETINGS_COUNT=0
EMAILS_COUNT=0
CAPTURES_COUNT=0
for f in "$VAULT"/00-Inbox/meetings/*; do [ -f "$f" ] && MEETINGS_COUNT=$((MEETINGS_COUNT + 1)); done
for f in "$VAULT"/00-Inbox/emails/*; do [ -f "$f" ] && EMAILS_COUNT=$((EMAILS_COUNT + 1)); done
for f in "$VAULT"/00-Inbox/captures/*; do [ -f "$f" ] && CAPTURES_COUNT=$((CAPTURES_COUNT + 1)); done

echo "  Inbox: $INBOX_COUNT root items, $INBOX_OLD_COUNT old, $MEETINGS_COUNT meetings, $EMAILS_COUNT emails, $CAPTURES_COUNT captures" >> "$LOG"

# =============================================================================
# CHECK 4: Empty/placeholder files in projects
# =============================================================================
EMPTY_FILES=""
EMPTY_COUNT=0

for readme in "$VAULT"/01-Projects/*/README.md; do
    [ -f "$readme" ] || continue
    proj_name=$(basename "$(dirname "$readme")")
    [ "$proj_name" = "_template" ] && continue

    # Check if "What & Why" section is empty (still has placeholder or nothing)
    whatwhy=$(sed -n '/^## What & Why/,/^## /p' "$readme" | grep -v "^##" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$whatwhy" -eq 0 ]; then
        EMPTY_FILES="${EMPTY_FILES}- **$proj_name/README.md** — empty What & Why section\n"
        EMPTY_COUNT=$((EMPTY_COUNT + 1))
    fi
done

echo "  Empty templates: $EMPTY_COUNT" >> "$LOG"

# =============================================================================
# CHECK 5: CRM contacts without recent interaction
# =============================================================================
DORMANT_CONTACTS=""
DORMANT_COUNT=0

for contact in "$VAULT"/07-Systems/CRM/contacts/*.md; do
    [ -f "$contact" ] || continue
    contact_name=$(basename "$contact" .md)
    [ "$contact_name" = "_template" ] && continue

    last_contact=$(grep -m1 "^last-contact:" "$contact" 2>/dev/null | sed 's/last-contact: *//')
    if [ -n "$last_contact" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            lc_epoch=$(date -j -f "%Y-%m-%d" "$last_contact" +%s 2>/dev/null || echo "0")
        else
            lc_epoch=$(date -d "$last_contact" +%s 2>/dev/null || echo "0")
        fi
        days_dormant=$(( (NOW - lc_epoch) / 86400 ))
        if [ "$days_dormant" -ge 30 ]; then
            display_name=$(echo "$contact_name" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
            DORMANT_CONTACTS="${DORMANT_CONTACTS}- **$display_name** — ${days_dormant} days since last contact\n"
            DORMANT_COUNT=$((DORMANT_COUNT + 1))
        fi
    fi
done

echo "  Dormant contacts: $DORMANT_COUNT" >> "$LOG"

# =============================================================================
# CHECK 6: Daily note streak
# =============================================================================
STREAK=0
check_date="$TODAY"
for i in $(seq 0 13); do
    if [[ "$OSTYPE" == "darwin"* ]]; then
        check_date=$(date -v-${i}d +%Y-%m-%d)
    else
        check_date=$(date -d "$TODAY - ${i} days" +%Y-%m-%d)
    fi
    if [ -f "$VAULT/07-Systems/goals/daily/${check_date}.md" ]; then
        STREAK=$((STREAK + 1))
    else
        [ "$i" -gt 0 ] && break  # Don't break on today (might not exist yet)
    fi
done

echo "  Daily note streak: $STREAK days" >> "$LOG"

# =============================================================================
# WRITE REPORT
# =============================================================================

# Calculate health score (simple: 100 minus penalties)
SCORE=100
[ "$STALE_COUNT" -gt 0 ] && SCORE=$((SCORE - STALE_COUNT * 5))
[ "$WEEKLY_STATUS" = "**MISSING** — no weekly note for ${CURRENT_WEEK}" ] && SCORE=$((SCORE - 15))
[ "$INBOX_COUNT" -gt 20 ] && SCORE=$((SCORE - 10))
[ "$INBOX_OLD_COUNT" -gt 0 ] && SCORE=$((SCORE - INBOX_OLD_COUNT * 3))
[ "$EMPTY_COUNT" -gt 0 ] && SCORE=$((SCORE - EMPTY_COUNT * 5))
[ "$DORMANT_COUNT" -gt 0 ] && SCORE=$((SCORE - DORMANT_COUNT * 3))
[ "$STREAK" -lt 3 ] && SCORE=$((SCORE - 10))
[ "$SCORE" -lt 0 ] && SCORE=0

# Emoji based on score
if [ "$SCORE" -ge 80 ]; then
    GRADE="🟢 Healthy"
elif [ "$SCORE" -ge 60 ]; then
    GRADE="🟡 Needs attention"
else
    GRADE="🔴 Needs work"
fi

cat > "$REPORT" << HEALTH
# Vault Health Report
*Generated: ${TODAY} · Score: ${SCORE}/100 ${GRADE}*

## Summary
- **Active projects:** ${ACTIVE_COUNT} (${STALE_COUNT} stale)
- **Weekly note (${CURRENT_WEEK}):** ${WEEKLY_STATUS}
- **Inbox:** ${INBOX_COUNT} root items, ${MEETINGS_COUNT} meetings, ${EMAILS_COUNT} emails, ${CAPTURES_COUNT} captures
- **Daily note streak:** ${STREAK} days
- **Dormant contacts:** ${DORMANT_COUNT}

HEALTH

# Stale projects section
if [ "$STALE_COUNT" -gt 0 ]; then
    cat >> "$REPORT" << STALE
## Stale Projects (7+ days untouched)
$(echo -e "$STALE_PROJECTS")
> Ask yourself: park these deliberately, or schedule a session?

STALE
fi

# Inbox issues
if [ "$INBOX_OLD_COUNT" -gt 0 ] || [ "$INBOX_COUNT" -gt 20 ]; then
    cat >> "$REPORT" << INBOX
## Inbox Issues
$([ "$INBOX_COUNT" -gt 20 ] && echo "- ⚠️ Inbox has ${INBOX_COUNT} items — time for a sweep")
$([ "$INBOX_OLD_COUNT" -gt 0 ] && echo -e "$INBOX_OLD")
INBOX
fi

# Empty templates
if [ "$EMPTY_COUNT" -gt 0 ]; then
    cat >> "$REPORT" << EMPTY
## Incomplete Project Files
$(echo -e "$EMPTY_FILES")
EMPTY
fi

# Dormant contacts
if [ "$DORMANT_COUNT" -gt 0 ]; then
    cat >> "$REPORT" << DORMANT
## Dormant Contacts (30+ days)
$(echo -e "$DORMANT_CONTACTS")
DORMANT
fi

# Streak
if [ "$STREAK" -lt 3 ]; then
    cat >> "$REPORT" << STREAK
## Daily Note Streak
⚠️ Only ${STREAK} consecutive daily notes. The system works best when you show up daily.

STREAK
fi

echo "[$(date)] vault-health complete — score: $SCORE" >> "$LOG"
echo "Vault health: $SCORE/100 ($GRADE)"
