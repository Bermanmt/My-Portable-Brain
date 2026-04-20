#!/bin/bash

# =============================================================================
# rebuild-context.sh — Generates CONTEXT-PACK.md
# =============================================================================
# Assembles a single file from vault sources so any LLM session can load
# full context in one read instead of seven.
#
# Output: 06-Agent/workspace/CONTEXT-PACK.md
# Designed to run via cron 2x/day (6am, noon) or manually: brain context
#
# This file is a read-only derived cache. Delete it → rebuilt next cycle.
# Never manually edit CONTEXT-PACK.md.
# =============================================================================

set -e

# --- Resolve vault root ---
# If VAULT_ROOT is set, use it. Otherwise derive from script location.
if [ -z "$VAULT_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    VAULT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

OUTPUT="$VAULT_ROOT/06-Agent/workspace/CONTEXT-PACK.md"
NOW=$(date +"%Y-%m-%dT%H:%M:%S")
TODAY=$(date +"%Y-%m-%d")
YESTERDAY=$(date -v-1d +"%Y-%m-%d" 2>/dev/null || date -d "yesterday" +"%Y-%m-%d" 2>/dev/null || echo "")

# --- Helpers ---
read_file() {
    local path="$1"
    if [ -f "$path" ]; then
        cat "$path"
    else
        echo "(not found)"
    fi
}

# Strip frontmatter (lines between --- delimiters at top of file)
strip_frontmatter() {
    local path="$1"
    if [ -f "$path" ]; then
        awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2||fm==0{print}' "$path"
    fi
}

# Count files in a directory (non-hidden, non-directory)
count_files() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -maxdepth 1 -type f -not -name '.*' -not -name '_*' | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

# =============================================================================
# COLLECT DATA
# =============================================================================

# --- Identity ---
SOUL=$(strip_frontmatter "$VAULT_ROOT/06-Agent/workspace/SOUL.md")
USER_PROFILE=$(strip_frontmatter "$VAULT_ROOT/06-Agent/workspace/USER.md")

# --- Memory ---
MEMORY=$(strip_frontmatter "$VAULT_ROOT/06-Agent/workspace/memory.md")

# Today's memory log
TODAY_MEMORY=""
if [ -f "$VAULT_ROOT/06-Agent/workspace/memory/$TODAY.md" ]; then
    TODAY_MEMORY=$(cat "$VAULT_ROOT/06-Agent/workspace/memory/$TODAY.md")
fi

# Yesterday's memory log
YESTERDAY_MEMORY=""
if [ -n "$YESTERDAY" ] && [ -f "$VAULT_ROOT/06-Agent/workspace/memory/$YESTERDAY.md" ]; then
    YESTERDAY_MEMORY=$(cat "$VAULT_ROOT/06-Agent/workspace/memory/$YESTERDAY.md")
fi

# --- Active Projects ---
PROJECTS=""
if [ -d "$VAULT_ROOT/01-Projects" ]; then
    for proj_dir in "$VAULT_ROOT/01-Projects"/*/; do
        [ -d "$proj_dir" ] || continue
        proj_name=$(basename "$proj_dir")
        [ "$proj_name" = "_template.md" ] && continue

        readme="$proj_dir/README.md"
        if [ -f "$readme" ]; then
            # Extract status from frontmatter
            status=$(grep -m1 '^status:' "$readme" 2>/dev/null | sed 's/status: *//' | tr -d ' ')
            [ "$status" != "active" ] && continue

            # Extract area
            area=$(grep -m1 '^area:' "$readme" 2>/dev/null | sed 's/area: *//')

            # Last modified (most recent .md file in project — maxdepth 2 to skip nested repos)
            last_mod_date=$(find "$proj_dir" -maxdepth 2 -name '*.md' -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | awk '{ts=int($1); "date -d @"ts" +%Y-%m-%d" | getline d; print d}')
            if [ -z "$last_mod_date" ]; then
                # macOS fallback
                last_mod_date=$(find "$proj_dir" -maxdepth 2 -name '*.md' -type f -exec stat -f "%m" {} \; 2>/dev/null | sort -rn | head -1 | xargs -I{} date -r {} +"%Y-%m-%d" 2>/dev/null || echo "unknown")
            fi

            # Count open/closed tasks (README.md only — project-level tasks, not nested docs)
            open_tasks=$(grep -c '^\- \[ \]' "$readme" 2>/dev/null; true)
            closed_tasks=$(grep -c '^\- \[x\]' "$readme" 2>/dev/null; true)

            PROJECTS="${PROJECTS}- **${proj_name}** — ${area:-no area} | last active: ${last_mod_date} | open: ${open_tasks} / done: ${closed_tasks}
"
        fi
    done
fi

# --- Inbox ---
INBOX_COUNT=$(count_files "$VAULT_ROOT/00-Inbox")

# --- Corrections / Patterns ---
CORRECTIONS=""
if [ -f "$VAULT_ROOT/06-Agent/workspace/corrections.md" ]; then
    # Extract active observations table rows (non-empty, non-header)
    active=$(awk '/^## Active Observations/,/^## /{print}' "$VAULT_ROOT/06-Agent/workspace/corrections.md" | grep '^|' | grep -v '^| Pattern' | grep -v '^|-' | grep -v '| *|' || true)
    if [ -n "$active" ]; then
        CORRECTIONS="$active"
    fi
    # Extract pending suggestion
    pending=$(awk '/^## Pending Suggestion/,/^## /{print}' "$VAULT_ROOT/06-Agent/workspace/corrections.md" | grep -v '^## ' | grep -v '^\*' | grep -v '^$' | grep -v '^```' || true)
    if [ -n "$pending" ]; then
        CORRECTIONS="${CORRECTIONS}
Pending: ${pending}"
    fi
fi

# --- Pending Actions ---
PENDING_ACTIONS=""
PENDING_COUNT=0
if [ -f "$VAULT_ROOT/06-Agent/state/pending-actions.md" ]; then
    PENDING_COUNT=$(grep -c '^\- \[ \]' "$VAULT_ROOT/06-Agent/state/pending-actions.md" 2>/dev/null || echo "0")
    PENDING_ACTIONS=$(cat "$VAULT_ROOT/06-Agent/state/pending-actions.md")
fi

# =============================================================================
# WRITE CONTEXT-PACK.md
# =============================================================================

cat > "$OUTPUT" << CTXEOF
# CONTEXT-PACK.md
> Auto-generated — do not edit manually.
> Source: SOUL.md, USER.md, memory.md, project READMEs, corrections.md
> Last updated: ${NOW}

---

## Identity

${SOUL}

---

## User Profile

${USER_PROFILE}

---

## Long-Term Memory

${MEMORY}

---

## Active Projects (${PROJECTS:+$(echo "$PROJECTS" | grep -c '^\-')} total)

${PROJECTS:-No active projects found.}

---

## Vault Status

- Inbox items: ${INBOX_COUNT}
- Pending actions: ${PENDING_COUNT}
- Date: ${TODAY}

---

## Recent Session Memory

### Today (${TODAY})
${TODAY_MEMORY:-No session log for today yet.}

### Yesterday (${YESTERDAY:-unknown})
${YESTERDAY_MEMORY:-No session log for yesterday.}

---

## Patterns Learned

${CORRECTIONS:-No active patterns being tracked.}

---

*End of context pack. For full details, read individual source files.*
CTXEOF

echo "✓ CONTEXT-PACK.md updated — $(date)"
