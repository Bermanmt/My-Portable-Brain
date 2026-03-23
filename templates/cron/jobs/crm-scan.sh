#!/bin/bash
# =============================================================================
# crm-scan.sh — Nightly CRM contact detection and briefing update
# =============================================================================
# Scans today's daily note for contact mentions (wiki-links and known names).
# Updates last-contact dates in frontmatter.
# Flags new mentions in the CRM manager's briefing.md.
# The smart processing (extracting context, updating preferences) happens
# in the next LLM session when the agent reads the briefing.
#
# This is the "dumb detection" layer. The LLM is the "smart processing" layer.
#
# Run via cron nightly (e.g., 9pm) or manually: brain crm-scan
# =============================================================================

set -e

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENT="$VAULT/06-Agent"

# --- Date vars ---
DATE=$(date +%Y-%m-%d)
DAILY="$VAULT/07-Systems/goals/daily/$DATE.md"
CRM_DIR="$VAULT/07-Systems/CRM/contacts"
BRIEFING="$AGENT/subagents/crm-manager/briefing.md"
PROC_LOG="$AGENT/subagents/crm-manager/processing-log.md"
LOG="$AGENT/cron/logs/$DATE-crm-scan.log"

mkdir -p "$AGENT/cron/logs"

echo "[$(date)] crm-scan start" >> "$LOG"

# =============================================================================
# STEP 1: Build list of known contacts
# =============================================================================
declare -A CONTACT_FILES    # display name → filename
declare -A CONTACT_SLUGS    # slug → filename

if [ -d "$CRM_DIR" ]; then
    for contact_file in "$CRM_DIR"/*.md; do
        [ -f "$contact_file" ] || continue
        [ "$(basename "$contact_file")" = "_template-contact.md" ] && continue

        filename=$(basename "$contact_file" .md)

        # Get display name from first H1
        display_name=$(grep -m1 '^# ' "$contact_file" 2>/dev/null | sed 's/^# //')
        if [ -n "$display_name" ]; then
            CONTACT_FILES["$display_name"]="$filename"
        fi

        # Also index by slug (filename) for wiki-link matching
        CONTACT_SLUGS["$filename"]="$filename"
    done
fi

KNOWN_COUNT=${#CONTACT_FILES[@]}
echo "[$(date)] loaded $KNOWN_COUNT known contacts" >> "$LOG"

# =============================================================================
# STEP 2: Scan today's daily note for mentions
# =============================================================================
MENTIONED_CONTACTS=""
MENTIONED_COUNT=0
NEW_MENTIONS=""
NEW_COUNT=0

if [ -f "$DAILY" ]; then
    DAILY_CONTENT=$(cat "$DAILY")

    # --- Check for wiki-link mentions: [[contact-slug]] ---
    wiki_links=$(echo "$DAILY_CONTENT" | grep -oP '\[\[([a-z0-9-]+)\]\]' | sed 's/\[\[//;s/\]\]//' | sort -u)

    for link in $wiki_links; do
        if [ -n "${CONTACT_SLUGS[$link]+x}" ]; then
            MENTIONED_CONTACTS="${MENTIONED_CONTACTS}${link}\n"
            MENTIONED_COUNT=$((MENTIONED_COUNT + 1))
        fi
    done

    # --- Check for plain name mentions of known contacts ---
    for display_name in "${!CONTACT_FILES[@]}"; do
        slug="${CONTACT_FILES[$display_name]}"
        # Skip if already found via wiki-link
        if echo -e "$MENTIONED_CONTACTS" | grep -q "^${slug}$"; then
            continue
        fi
        # Case-insensitive search for full name
        if echo "$DAILY_CONTENT" | grep -qi "$display_name"; then
            MENTIONED_CONTACTS="${MENTIONED_CONTACTS}${slug}\n"
            MENTIONED_COUNT=$((MENTIONED_COUNT + 1))
        fi
    done

    echo "[$(date)] found $MENTIONED_COUNT contact mentions in daily note" >> "$LOG"
else
    echo "[$(date)] no daily note found for $DATE" >> "$LOG"
fi

# =============================================================================
# STEP 3: Scan inbox for new items with potential contact references
# =============================================================================
INBOX_ITEMS=""
INBOX_CONTACT_FLAGS=""

for inbox_dir in "$VAULT/00-Inbox/meetings" "$VAULT/00-Inbox/emails" "$VAULT/00-Inbox/captures"; do
    [ -d "$inbox_dir" ] || continue
    for item in "$inbox_dir"/*.md; do
        [ -f "$item" ] || continue
        item_name=$(basename "$item")
        item_content=$(cat "$item")

        # Check for known contact mentions in inbox items
        for display_name in "${!CONTACT_FILES[@]}"; do
            slug="${CONTACT_FILES[$display_name]}"
            if echo "$item_content" | grep -qi "$display_name"; then
                INBOX_CONTACT_FLAGS="${INBOX_CONTACT_FLAGS}  - [[${slug}]] mentioned in inbox: ${item_name}\n"
            fi
        done
    done
done

# =============================================================================
# STEP 4: Update last-contact dates for mentioned contacts
# =============================================================================
for slug in $(echo -e "$MENTIONED_CONTACTS" | sort -u); do
    [ -z "$slug" ] && continue
    contact_file="$CRM_DIR/${slug}.md"
    [ -f "$contact_file" ] || continue

    # Update last-contact in frontmatter
    current_last=$(grep -m1 '^last-contact:' "$contact_file" 2>/dev/null | awk '{print $2}')
    if [ "$current_last" != "$DATE" ]; then
        if [ -n "$current_last" ] && [ "$current_last" != "" ]; then
            sed -i "s/^last-contact: .*/last-contact: $DATE/" "$contact_file" 2>/dev/null || \
            sed -i '' "s/^last-contact: .*/last-contact: $DATE/" "$contact_file" 2>/dev/null
        else
            sed -i "s/^last-contact:.*/last-contact: $DATE/" "$contact_file" 2>/dev/null || \
            sed -i '' "s/^last-contact:.*/last-contact: $DATE/" "$contact_file" 2>/dev/null
        fi
        echo "[$(date)] updated last-contact for $slug → $DATE" >> "$LOG"
    fi
done

# =============================================================================
# STEP 5: Collect follow-ups due and upcoming dates
# =============================================================================
FOLLOWUPS=""
UPCOMING_DATES=""
DORMANT=""

THIRTY_DAYS_AGO=""
if date -v1d 2>/dev/null >&2; then
    THIRTY_DAYS_AGO=$(date -v-30d +%Y-%m-%d)
else
    THIRTY_DAYS_AGO=$(date -d "$DATE - 30 days" +%Y-%m-%d 2>/dev/null || echo "")
fi

THIRTY_DAYS_AHEAD=""
if date -v1d 2>/dev/null >&2; then
    THIRTY_DAYS_AHEAD=$(date -v+30d +%Y-%m-%d)
else
    THIRTY_DAYS_AHEAD=$(date -d "$DATE + 30 days" +%Y-%m-%d 2>/dev/null || echo "")
fi

if [ -d "$CRM_DIR" ]; then
    for contact_file in "$CRM_DIR"/*.md; do
        [ -f "$contact_file" ] || continue
        [ "$(basename "$contact_file")" = "_template-contact.md" ] && continue

        slug=$(basename "$contact_file" .md)
        display_name=$(grep -m1 '^# ' "$contact_file" 2>/dev/null | sed 's/^# //')
        name="${display_name:-$slug}"

        # Follow-ups due
        nad=$(grep -m1 '^next-action-date:' "$contact_file" 2>/dev/null | awk '{print $2}')
        na=$(grep -m1 '^next-action:' "$contact_file" 2>/dev/null | sed 's/^next-action: *//')
        if [ -n "$nad" ] && [ -n "$na" ] && [[ "$nad" < "$DATE" || "$nad" == "$DATE" ]]; then
            FOLLOWUPS="${FOLLOWUPS}- [[${slug}]]: ${na} — due ${nad}\n"
        fi

        # Upcoming birthday
        bday=$(grep -m1 '^birthday:' "$contact_file" 2>/dev/null | awk '{print $2}')
        if [ -n "$bday" ] && [ -n "$THIRTY_DAYS_AHEAD" ]; then
            bday_md=$(echo "$bday" | grep -oP '\d{2}-\d{2}$')
            current_year_bday="${YEAR}-${bday_md}"
            if [ -n "$bday_md" ] && [[ "$current_year_bday" > "$DATE" || "$current_year_bday" == "$DATE" ]] && [[ "$current_year_bday" < "$THIRTY_DAYS_AHEAD" ]]; then
                UPCOMING_DATES="${UPCOMING_DATES}- ${name}: birthday — ${current_year_bday}\n"
            fi
        fi

        # Dormant contacts (no contact in 30+ days)
        last_contact=$(grep -m1 '^last-contact:' "$contact_file" 2>/dev/null | awk '{print $2}')
        contact_status=$(grep -m1 '^status:' "$contact_file" 2>/dev/null | awk '{print $2}')
        if [ "$contact_status" = "active" ] && [ -n "$last_contact" ] && [ -n "$THIRTY_DAYS_AGO" ]; then
            if [[ "$last_contact" < "$THIRTY_DAYS_AGO" ]]; then
                DORMANT="${DORMANT}- [[${slug}]]: last contact ${last_contact}\n"
            fi
        fi
    done
fi

# =============================================================================
# STEP 6: Write CRM briefing
# =============================================================================
YEAR=$(date +%Y)

cat > "$BRIEFING" << BRIEFING_EOF
# CRM Briefing
*Updated: $(date +%Y-%m-%d\ %H:%M)*

## Follow-ups Due
$(if [ -n "$FOLLOWUPS" ]; then echo -e "$FOLLOWUPS"; else echo "*(none)*"; fi)

## Upcoming Dates (next 30 days)
$(if [ -n "$UPCOMING_DATES" ]; then echo -e "$UPCOMING_DATES"; else echo "*(none with dates set)*"; fi)

## Recent Changes
$(if [ "$MENTIONED_COUNT" -gt 0 ]; then
    for slug in $(echo -e "$MENTIONED_CONTACTS" | sort -u); do
        [ -z "$slug" ] && continue
        echo "- [[${slug}]]: mentioned in daily note $DATE — **pending LLM review** (context extraction, interaction log update)"
    done
else
    echo "*(no contact mentions detected today)*"
fi)
$(if [ -n "$INBOX_CONTACT_FLAGS" ]; then
    echo ""
    echo "### Inbox Contact References"
    echo -e "$INBOX_CONTACT_FLAGS"
fi)

## New Contact Candidates (needs approval)
*(run LLM review to detect unnamed people in daily notes)*

## Dormant (30+ days no contact)
$(if [ -n "$DORMANT" ]; then echo -e "$DORMANT"; else echo "*(none — or no contacts with last-contact dates yet)*"; fi)
BRIEFING_EOF

echo "[$(date)] briefing.md updated" >> "$LOG"

# =============================================================================
# STEP 7: Append to processing log
# =============================================================================
cat >> "$PROC_LOG" << LOG_EOF

## $DATE — crm-scan.sh
- Scanned: daily note ($DATE)
- Contacts mentioned: $MENTIONED_COUNT $(echo -e "$MENTIONED_CONTACTS" | sort -u | tr '\n' ',' | sed 's/,$//')
- Follow-ups due: $(echo -e "$FOLLOWUPS" | grep -c '^\-' 2>/dev/null || echo 0)
- last-contact dates updated: $MENTIONED_COUNT
- Pending LLM review: context extraction for mentioned contacts
LOG_EOF

echo "[$(date)] crm-scan done — $MENTIONED_COUNT mentions, briefing updated" >> "$LOG"
