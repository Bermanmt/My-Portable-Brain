#!/bin/bash
# =============================================================================
# daily-briefing.sh — Create today's daily note + write morning briefing
# =============================================================================
# 1. Creates today's daily note from template (if it doesn't exist)
# 2. Creates this week's weekly note from template (if it doesn't exist)
# 3. Detects day type (regular, week_start, planning_day, quarterly_review)
# 4. Collects vault data via bash (inbox, CRM, projects, pending actions)
# 5. Writes day-aware briefing to the 🤖 Morning Briefing section
#
# The briefing adapts based on the day:
#   - Regular (Tue-Thu): dashboard + weekly Big 3 + project next actions
#   - Monday: above + last week's carries-forward
#   - Friday: above + weekly review data + quarterly alignment nudge
#   - Quarter-end Friday: above + quarterly progress summary
#
# Run via cron at 7:30am or manually: brain briefing
# =============================================================================

set -e

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENT="$VAULT/06-Agent"
source "$AGENT/config/llm.conf"

# --- Date vars ---
DATE=$(date +%Y-%m-%d)
WEEK=$(date +%Y-W%V)
YEAR=$(date +%Y)
MONTH=$(date +%-m)
QUARTER="Q$(( (MONTH - 1) / 3 + 1 ))"
QUARTER_LABEL="${YEAR}-${QUARTER}"
DOW=$(date +%A)
DOW_NUM=$(date +%u)  # 1=Monday, 5=Friday, 7=Sunday

# Calculate days left in quarter
QUARTER_END_MONTH=$(( ((MONTH - 1) / 3 + 1) * 3 ))
# Last day of quarter-end month (portable)
if date -v1d 2>/dev/null >&2; then
    # macOS
    QUARTER_END=$(date -v"${QUARTER_END_MONTH}m" -v1d -v+1m -v-1d +%Y-%m-%d 2>/dev/null)
else
    # Linux
    QUARTER_END=$(date -d "${YEAR}-${QUARTER_END_MONTH}-01 +1 month -1 day" +%Y-%m-%d 2>/dev/null)
fi
if [ -n "$QUARTER_END" ]; then
    DAYS_LEFT_Q=$(( ( $(date -d "$QUARTER_END" +%s 2>/dev/null || date -jf "%Y-%m-%d" "$QUARTER_END" +%s 2>/dev/null) - $(date +%s) ) / 86400 ))
else
    DAYS_LEFT_Q=99
fi

# --- Determine day type ---
DAY_TYPE="regular"
if [ "$DOW_NUM" -eq 1 ]; then
    DAY_TYPE="week_start"
elif [ "$DOW_NUM" -eq 5 ]; then
    if [ "$DAYS_LEFT_Q" -le 14 ]; then
        DAY_TYPE="quarterly_review"
    else
        DAY_TYPE="planning_day"
    fi
fi

# --- File paths ---
DAILY="$VAULT/07-Systems/goals/daily/$DATE.md"
DAILY_TEMPLATE="$VAULT/07-Systems/goals/daily/_template.md"
WEEKLY_FILE="$VAULT/07-Systems/goals/weekly/$WEEK.md"
WEEKLY_TEMPLATE="$VAULT/07-Systems/goals/weekly/_template.md"
QUARTERLY_FILE="$VAULT/07-Systems/goals/quarterly/$QUARTER_LABEL.md"
YEARLY_FILE="$VAULT/07-Systems/goals/yearly/$YEAR.md"
LOG="$AGENT/cron/logs/$DATE-daily-briefing.log"

mkdir -p "$AGENT/cron/logs"

echo "[$(date)] daily-briefing start (day_type=$DAY_TYPE)" >> "$LOG"

# =============================================================================
# STEP 1: Create today's daily note from template
# =============================================================================
if [ ! -f "$DAILY" ]; then
    if [ -f "$DAILY_TEMPLATE" ]; then
        cp "$DAILY_TEMPLATE" "$DAILY"
        sed "s/YYYY-MM-DD/$DATE/g" "$DAILY" | sed "s/YYYY-WNN/$WEEK/g" > "$DAILY.tmp" && mv "$DAILY.tmp" "$DAILY"
        echo "[$(date)] created daily note: $DATE" >> "$LOG"
    else
        echo "[$(date)] ERROR: daily template not found at $DAILY_TEMPLATE" >> "$LOG"
        exit 1
    fi
fi

# =============================================================================
# STEP 1b: Create this week's weekly note from template (if missing)
# =============================================================================
if [ ! -f "$WEEKLY_FILE" ]; then
    if [ -f "$WEEKLY_TEMPLATE" ]; then
        cp "$WEEKLY_TEMPLATE" "$WEEKLY_FILE"

        # Calculate daily links for Mon-Fri of this week
        # Get Monday of current ISO week
        if date -v1d 2>/dev/null >&2; then
            # macOS
            MONDAY=$(date -v-"$((DOW_NUM - 1))"d +%Y-%m-%d)
        else
            # Linux
            MONDAY=$(date -d "$DATE - $((DOW_NUM - 1)) days" +%Y-%m-%d)
        fi

        DAILY_LINKS=""
        for i in 0 1 2 3 4; do
            if date -v1d 2>/dev/null >&2; then
                DAY_DATE=$(date -j -v+"${i}"d -f "%Y-%m-%d" "$MONDAY" +%Y-%m-%d)
            else
                DAY_DATE=$(date -d "$MONDAY + ${i} days" +%Y-%m-%d)
            fi
            DAILY_LINKS="${DAILY_LINKS}[[${DAY_DATE}]] "
        done

        # Replace template placeholders
        sed "s/YYYY-WNN/$WEEK/g" "$WEEKLY_FILE" \
            | sed "s/YYYY-QN/$QUARTER_LABEL/g" \
            | sed "s/\[\[YYYY-MM-D1\]\] \[\[YYYY-MM-D2\]\] \[\[YYYY-MM-D3\]\] \[\[YYYY-MM-D4\]\] \[\[YYYY-MM-D5\]\]/$DAILY_LINKS/" \
            > "$WEEKLY_FILE.tmp" && mv "$WEEKLY_FILE.tmp" "$WEEKLY_FILE"

        echo "[$(date)] created weekly note: $WEEK" >> "$LOG"
    else
        echo "[$(date)] WARNING: weekly template not found at $WEEKLY_TEMPLATE" >> "$LOG"
    fi
fi

# =============================================================================
# STEP 2: Collect vault data
# =============================================================================

# --- Inbox ---
INBOX_COUNT=$(find "$VAULT/00-Inbox" -maxdepth 1 -type f -not -name '.*' -not -name '_*' | wc -l | tr -d ' ')

# --- Active projects with next actions ---
PROJECTS=""
PROJ_COUNT=0
for proj_dir in "$VAULT/01-Projects"/*/; do
    [ -d "$proj_dir" ] || continue
    readme="$proj_dir/README.md"
    [ -f "$readme" ] || continue
    status=$(grep -m1 '^status:' "$readme" 2>/dev/null | sed 's/status: *//' | tr -d ' ')
    [ "$status" != "active" ] && continue

    proj_name=$(basename "$proj_dir")
    PROJ_COUNT=$((PROJ_COUNT + 1))

    # Get the first unchecked task from ## Next Action section
    next_action=$(sed -n '/^## Next Action/,/^## [^N]/p' "$readme" | grep -m1 '^\- \[ \]' | sed 's/^\- \[ \] //' 2>/dev/null || true)

    if [ -n "$next_action" ]; then
        PROJECTS="${PROJECTS}  - **${proj_name}** → ${next_action}\n"
    else
        PROJECTS="${PROJECTS}  - **${proj_name}** — ⚠ no next action defined\n"
    fi
done

# --- CRM overdue ---
CRM_OVERDUE=""
CRM_COUNT=0
if [ -d "$VAULT/07-Systems/CRM/contacts" ]; then
    for contact in "$VAULT/07-Systems/CRM/contacts"/*.md; do
        [ -f "$contact" ] || continue
        nad=$(grep -m1 '^next-action-date:' "$contact" 2>/dev/null | awk '{print $2}')
        if [ -n "$nad" ] && [[ "$nad" < "$DATE" || "$nad" == "$DATE" ]]; then
            name=$(grep -m1 '^# ' "$contact" 2>/dev/null | sed 's/^# //')
            action=$(grep -m1 '^next-action:' "$contact" 2>/dev/null | sed 's/^next-action: *//')
            CRM_OVERDUE="${CRM_OVERDUE}  - **${name:-$(basename "$contact" .md)}** — ${action:-follow up} (due: $nad)\n"
            CRM_COUNT=$((CRM_COUNT + 1))
        fi
    done
fi

# --- Pending actions ---
PENDING_COUNT=0
if [ -f "$AGENT/state/pending-actions.md" ]; then
    PENDING_COUNT=$(grep -c '^\- \[ \]' "$AGENT/state/pending-actions.md" 2>/dev/null; true)
fi

# --- Task Registry ---
TASK_REGISTRY="$VAULT/07-Systems/tasks/registry.md"
TASK_ACTIVE_COUNT=0
TASK_WAITING_COUNT=0
TASK_CONTEXTS=""
if [ -f "$TASK_REGISTRY" ]; then
    # Count active tasks (unchecked in Active section)
    TASK_ACTIVE_COUNT=$(sed -n '/^## Active/,/^## /p' "$TASK_REGISTRY" | grep -c '^\- \[ \]' 2>/dev/null; true)
    # Count waiting tasks
    TASK_WAITING_COUNT=$(sed -n '/^## Waiting/,/^## /p' "$TASK_REGISTRY" | grep -c '^\- \[ \]' 2>/dev/null; true)
    # Count by context (only from Active section)
    active_tasks=$(sed -n '/^## Active/,/^## /p' "$TASK_REGISTRY" | grep '^\- \[ \]' 2>/dev/null || true)
    if [ -n "$active_tasks" ]; then
        for ctx in errands home office digital phone deep-work waiting; do
            count=$(echo "$active_tasks" | grep -c "@${ctx}" 2>/dev/null; true)
            if [ "$count" -gt 0 ]; then
                TASK_CONTEXTS="${TASK_CONTEXTS}${ctx}:${count} "
            fi
        done
    fi
fi

# --- Weekly data ---
WEEKLY_FOCUS=""
WEEKLY_BIG3=""
WEEKLY_BIG3_DONE=0
WEEKLY_BIG3_TOTAL=0
if [ -f "$WEEKLY_FILE" ]; then
    # Extract Focus
    focus=$(awk '/^## Focus/,/^## /' "$WEEKLY_FILE" | grep -v '^## ' | grep -v '^\*' | grep -v '^$' | head -3)
    [ -n "$focus" ] && WEEKLY_FOCUS="$focus"

    # Extract Big 3 with status
    big3=$(sed -n '/^## Big 3/,/^## [^B]/p' "$WEEKLY_FILE" | grep '^\- \[' | head -3)
    if [ -n "$big3" ]; then
        WEEKLY_BIG3="$big3"
        WEEKLY_BIG3_TOTAL=$(echo "$big3" | wc -l | tr -d ' ')
        WEEKLY_BIG3_DONE=$(echo "$big3" | grep -c '^\- \[x\]'; true)
    fi

    # Extract Tasks (errands)
    WEEKLY_TASKS=""
    tasks=$(sed -n '/^## Tasks/,/^## [^T]/p' "$WEEKLY_FILE" | grep '^\- \[ \]' | head -5)
    [ -n "$tasks" ] && WEEKLY_TASKS="$tasks"
fi

# --- Last week data (for Monday carries) ---
LAST_WEEK_CARRIES=""
if [ "$DAY_TYPE" = "week_start" ]; then
    # Calculate last week's ISO week
    if date -v1d 2>/dev/null >&2; then
        LAST_WEEK=$(date -v-7d +%Y-W%V)
    else
        LAST_WEEK=$(date -d "$DATE - 7 days" +%Y-W%V)
    fi
    LAST_WEEKLY_FILE="$VAULT/07-Systems/goals/weekly/$LAST_WEEK.md"
    if [ -f "$LAST_WEEKLY_FILE" ]; then
        carries=$(sed -n '/\*\*Carries forward:\*\*/,/\*\*/p' "$LAST_WEEKLY_FILE" | grep -v '^\*\*' | grep -v '^$' | head -5)
        [ -n "$carries" ] && LAST_WEEK_CARRIES="$carries"
        # Also check for incomplete Big 3
        incomplete_big3=$(sed -n '/^## Big 3/,/^## [^B]/p' "$LAST_WEEKLY_FILE" | grep '^\- \[ \]' | head -3)
        if [ -n "$incomplete_big3" ]; then
            LAST_WEEK_CARRIES="${LAST_WEEK_CARRIES}
Incomplete Big 3 from last week:
${incomplete_big3}"
        fi
    fi
fi

# --- Quarterly data (for Friday planning context) ---
QUARTERLY_FOCUS=""
QUARTERLY_ROCKS=""
if [ "$DAY_TYPE" = "planning_day" ] || [ "$DAY_TYPE" = "quarterly_review" ]; then
    if [ -f "$QUARTERLY_FILE" ]; then
        q_focus=$(awk '/^## Focus/,/^## /' "$QUARTERLY_FILE" | grep -v '^## ' | grep -v '^$' | head -3)
        [ -n "$q_focus" ] && QUARTERLY_FOCUS="$q_focus"
        q_rocks=$(sed -n '/^## Big Rocks/,/^## [^B]/p' "$QUARTERLY_FILE" | grep '^\- \[' | head -5)
        [ -n "$q_rocks" ] && QUARTERLY_ROCKS="$q_rocks"
    fi
fi

# --- Yearly themes (for quarterly review) ---
YEARLY_THEMES=""
if [ "$DAY_TYPE" = "quarterly_review" ]; then
    if [ -f "$YEARLY_FILE" ]; then
        themes=$(awk '/^## Themes/,/^## /' "$YEARLY_FILE" | grep -v '^## ' | grep -v '^$' | head -3)
        [ -n "$themes" ] && YEARLY_THEMES="$themes"
    fi
fi

# --- Yesterday's session memory ---
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d 2>/dev/null || echo "")
YESTERDAY_NOTE=""
if [ -n "$YESTERDAY" ] && [ -f "$AGENT/workspace/memory/$YESTERDAY.md" ]; then
    YESTERDAY_NOTE="yes"
fi

# =============================================================================
# STEP 3: Write the day-aware briefing
# =============================================================================

# --- Header ---
BRIEFING="**${DOW}, ${DATE}** — Week ${WEEK#*-W}, ${YEAR} ${QUARTER}"

# Tag the day type so the agent knows what conversation to start
case $DAY_TYPE in
    week_start)      BRIEFING="${BRIEFING}  ·  🟢 New week" ;;
    planning_day)    BRIEFING="${BRIEFING}  ·  📋 Planning day" ;;
    quarterly_review) BRIEFING="${BRIEFING}  ·  📋 Planning day · 🎯 Quarter ends in ${DAYS_LEFT_Q} days" ;;
esac

# --- Dashboard ---
BRIEFING="${BRIEFING}

### Dashboard
- Inbox: **${INBOX_COUNT}** items
- Active projects: **${PROJ_COUNT}**
- CRM follow-ups due: **${CRM_COUNT}**
- Pending actions: **${PENDING_COUNT}**
- Tasks: **${TASK_ACTIVE_COUNT}** active${TASK_WAITING_COUNT:+, **${TASK_WAITING_COUNT}** waiting}${TASK_CONTEXTS:+ (${TASK_CONTEXTS%% })}"

# --- Weekly priorities (always shown) ---
if [ -n "$WEEKLY_FOCUS" ]; then
    BRIEFING="${BRIEFING}

### This Week
**Focus:** ${WEEKLY_FOCUS}"
fi

if [ -n "$WEEKLY_BIG3" ]; then
    BRIEFING="${BRIEFING}
**Big 3** (${WEEKLY_BIG3_DONE}/${WEEKLY_BIG3_TOTAL} done):
${WEEKLY_BIG3}"
fi

if [ -n "$WEEKLY_TASKS" ]; then
    BRIEFING="${BRIEFING}
**Tasks:**
${WEEKLY_TASKS}"
fi

# --- Monday: last week's carries ---
if [ "$DAY_TYPE" = "week_start" ] && [ -n "$LAST_WEEK_CARRIES" ]; then
    BRIEFING="${BRIEFING}

### Carried from Last Week
${LAST_WEEK_CARRIES}"
fi

# --- Friday: weekly review context + quarterly alignment ---
if [ "$DAY_TYPE" = "planning_day" ] || [ "$DAY_TYPE" = "quarterly_review" ]; then
    BRIEFING="${BRIEFING}

### 📋 Planning Day — Review & Prioritize
*Your agent will walk you through the weekly review and next week's planning.*
**Big 3 status this week:** ${WEEKLY_BIG3_DONE}/${WEEKLY_BIG3_TOTAL} completed"

    if [ -n "$QUARTERLY_FOCUS" ]; then
        BRIEFING="${BRIEFING}

### Quarterly Context ([[${QUARTER_LABEL}]])
**Focus:** ${QUARTERLY_FOCUS}"
    fi
    if [ -n "$QUARTERLY_ROCKS" ]; then
        BRIEFING="${BRIEFING}
**Big Rocks:**
${QUARTERLY_ROCKS}"
    fi
fi

# --- Quarterly review: yearly themes ---
if [ "$DAY_TYPE" = "quarterly_review" ] && [ -n "$YEARLY_THEMES" ]; then
    BRIEFING="${BRIEFING}

### 🎯 Quarter Ending — Yearly Themes
${YEARLY_THEMES}
*Time to assess: are these themes showing up in your work?*"
fi

# --- Projects with next actions (always shown) ---
if [ -n "$PROJECTS" ]; then
    BRIEFING="${BRIEFING}

### Next Actions by Project
$(echo -e "$PROJECTS")"
fi

# --- CRM overdue ---
if [ -n "$CRM_OVERDUE" ]; then
    BRIEFING="${BRIEFING}

### CRM — Overdue Follow-ups
$(echo -e "$CRM_OVERDUE")"
fi

# --- Yesterday context ---
if [ -n "$YESTERDAY_NOTE" ]; then
    BRIEFING="${BRIEFING}

### Continuity
Session memory from yesterday available — check \`memory/${YESTERDAY}.md\` for context."
fi

# =============================================================================
# STEP 4: Insert briefing into daily note
# =============================================================================

# Replace the 🤖 Morning Briefing section (handles both fresh and re-runs)
# Clears everything between the header+subheader and the next ---
if grep -q '## 🤖 Morning Briefing' "$DAILY"; then
    awk -v briefing="$BRIEFING" '
    /^## 🤖 Morning Briefing/ {
        print
        getline  # print the *(agent writes this)* line
        print
        print ""
        print briefing
        # Skip all existing content until the next ---
        while ((getline line) > 0) {
            if (line == "---") {
                print ""
                print line
                break
            }
        }
        next
    }
    { print }
    ' "$DAILY" > "$DAILY.tmp" && mv "$DAILY.tmp" "$DAILY"

    echo "[$(date)] briefing written to daily note (day_type=$DAY_TYPE)" >> "$LOG"
else
    echo "[$(date)] WARNING: Morning Briefing section not found in daily note" >> "$LOG"
fi

echo "[$(date)] done" >> "$LOG"
