#!/bin/bash

# =============================================================================
# Brain Vault — Upgrade Script
# =============================================================================
# Usage:
#   brain update              → upgrade vault to latest version
#   bash upgrade.sh ~/Brain   → upgrade vault at specified path
#   bash upgrade.sh --dry-run → preview changes without applying
# =============================================================================

set -e

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Parse args ---
DRY_RUN=false
VAULT_ROOT=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) [ -z "$VAULT_ROOT" ] && VAULT_ROOT="$arg" ;;
    esac
done

# --- Find vault ---
if [ -z "$VAULT_ROOT" ]; then
    # Try common locations
    if [ -d "$HOME/Brain" ]; then
        VAULT_ROOT="$HOME/Brain"
    elif [ -d "$HOME/Documents/Brain" ]; then
        VAULT_ROOT="$HOME/Documents/Brain"
    else
        echo -e "${RED}Could not find vault. Specify path: bash upgrade.sh ~/Brain${NC}"
        exit 1
    fi
fi

VAULT_ROOT="${VAULT_ROOT/#\~/$HOME}"

if [ ! -f "$VAULT_ROOT/CLAUDE.md" ]; then
    echo -e "${RED}Not a Brain vault: $VAULT_ROOT (no CLAUDE.md found)${NC}"
    exit 1
fi

# --- Find repo ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$REPO_ROOT/templates"

if [ ! -d "$TEMPLATES_DIR" ]; then
    echo -e "${RED}Can't find templates directory. Run from inside the repo.${NC}"
    exit 1
fi

# --- Helpers ---
today=$(date +%Y-%m-%d)
CHANGES=0
SKIPPED=0
CREATED=0

info() { echo -e "  ${BLUE}ℹ${NC} $1"; }
created() { echo -e "  ${GREEN}+${NC} $1"; CREATED=$((CREATED + 1)); }
updated() { echo -e "  ${GREEN}↑${NC} $1"; CHANGES=$((CHANGES + 1)); }
skipped() { echo -e "  ${DIM}· $1${NC}"; SKIPPED=$((SKIPPED + 1)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }

# Create file only if it doesn't exist
create_if_missing() {
    local path="$1"
    local content="$2"
    local label="$3"

    if [ -f "$path" ]; then
        skipped "$label"
        return
    fi

    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$(dirname "$path")"
        printf '%s\n' "$content" > "$path"
    fi
    created "$label"
}

# Replace file unconditionally (system files only)
replace_file() {
    local src="$1"
    local dest="$2"
    local label="$3"

    if [ ! -f "$src" ]; then
        warn "Source not found: $src"
        return
    fi

    if [ -f "$dest" ]; then
        if diff -q "$src" "$dest" > /dev/null 2>&1; then
            skipped "$label (already current)"
            return
        fi
    fi

    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
    fi
    updated "$label"
}

# Append a section to AGENTS.md if the header doesn't exist yet
append_section_if_missing() {
    local agents_file="$1"
    local section_header="$2"
    local section_file="$3"
    local label="$4"

    if grep -q "^## $section_header" "$agents_file" 2>/dev/null; then
        skipped "AGENTS.md section: $section_header (exists)"
        return
    fi

    if [ ! -f "$section_file" ]; then
        warn "Section source not found: $section_file"
        return
    fi

    if [ "$DRY_RUN" = false ]; then
        printf '\n' >> "$agents_file"
        cat "$section_file" >> "$agents_file"
    fi
    created "AGENTS.md section: $section_header"
}

# =============================================================================
# START UPGRADE
# =============================================================================

echo ""
echo -e "${BOLD}Brain Vault Upgrade${NC}"
echo -e "${DIM}Vault: $VAULT_ROOT${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN — no changes will be made${NC}"
fi
echo ""

# --- Read user's name from existing USER.md for any templated files ---
USER_NAME=""
if [ -f "$VAULT_ROOT/06-Agent/workspace/USER.md" ]; then
    USER_NAME=$(grep -m1 "^## " "$VAULT_ROOT/06-Agent/workspace/USER.md" | sed 's/^## //' | head -1)
fi
if [ -z "$USER_NAME" ]; then
    USER_NAME=$(grep -m1 "Name:" "$VAULT_ROOT/06-Agent/workspace/USER.md" 2>/dev/null | sed 's/.*Name:[[:space:]]*//' | head -1)
fi
[ -z "$USER_NAME" ] && USER_NAME="User"

AGENT_NAME=""
if [ -f "$VAULT_ROOT/06-Agent/workspace/SOUL.md" ]; then
    AGENT_NAME=$(grep -m1 "^##\|^#" "$VAULT_ROOT/06-Agent/workspace/SOUL.md" | sed 's/^#* //' | sed 's/ —.*//' | head -1)
fi
[ -z "$AGENT_NAME" ] && AGENT_NAME="Agent"

# =============================================================================
# 1. SYSTEM FILES — Replace with latest
# =============================================================================

echo -e "${BOLD}System files (cron scripts, specialist agents):${NC}"

# Cron jobs
replace_file "$TEMPLATES_DIR/cron/jobs/daily-briefing.sh" \
    "$VAULT_ROOT/06-Agent/cron/jobs/daily-briefing.sh" \
    "cron/daily-briefing.sh"

replace_file "$TEMPLATES_DIR/cron/jobs/crm-scan.sh" \
    "$VAULT_ROOT/06-Agent/cron/jobs/crm-scan.sh" \
    "cron/crm-scan.sh"

replace_file "$TEMPLATES_DIR/cron/jobs/vault-health.sh" \
    "$VAULT_ROOT/06-Agent/cron/jobs/vault-health.sh" \
    "cron/vault-health.sh"

replace_file "$TEMPLATES_DIR/cron/jobs/pattern-check.sh" \
    "$VAULT_ROOT/06-Agent/cron/jobs/pattern-check.sh" \
    "cron/pattern-check.sh"

# Specialist agent instructions (AGENT.md only — never touch briefing.md or processing-log.md)
for agent_dir in "$TEMPLATES_DIR"/agent/subagents/*/; do
    agent_name=$(basename "$agent_dir")
    if [ -f "$agent_dir/AGENT.md" ]; then
        replace_file "$agent_dir/AGENT.md" \
            "$VAULT_ROOT/06-Agent/subagents/$agent_name/AGENT.md" \
            "subagents/$agent_name/AGENT.md"
    fi
done

echo ""

# =============================================================================
# 2. NEW FILES — Create if missing
# =============================================================================

echo -e "${BOLD}New files (added in this version):${NC}"

# State directory
mkdir -p "$VAULT_ROOT/06-Agent/state" 2>/dev/null || true

create_if_missing "$VAULT_ROOT/06-Agent/state/handoff.md" \
"---
updated: $today
---
# Session Handoff

*Agent writes here at end of every session. Agent reads here at start of every session.*

## Last Session
(Nothing yet — first session pending)

## Open Loops
(Things started but not finished — carry forward until resolved)

## Proposals Declined
(User said \"not yet\" — with date, so agent knows when to revisit)

## Next Session Context
(What the agent should know going in — primed context, follow-ups promised, mood/energy signals)" \
    "06-Agent/state/handoff.md"

create_if_missing "$VAULT_ROOT/06-Agent/workspace/observations.md" \
"---
started: $today
---
# Agent Observations

*Private pattern map. Never shown to user directly.*
*Feeds proposals after 14+ days of consistent signal.*

## Topics Recurring
(Agent tracks here — topic, count, first seen, last seen)

## Behavioral Patterns
(Capture time, response patterns, preferred formats, energy by day-of-week)

## Tools Detected
(External tools mentioned — feeds integration discovery)

## People Signals
(Contacts mentioned frequently — seeds CRM proposals)

## Emotional Signals
(Areas of stress, excitement, avoidance — informs greeting tone)

## Emerging Areas
(Topics approaching the proposal threshold)" \
    "06-Agent/workspace/observations.md"

create_if_missing "$VAULT_ROOT/06-Agent/state/created.md" \
"---
created: unknown
---
Vault creation date unknown — created.md added during upgrade.
Manually update the 'created' date to when you first ran onboard.sh." \
    "06-Agent/state/created.md"

# Area files — STATE.md, GOALS.md, RULES.md for each existing area
if [ -d "$VAULT_ROOT/02-Areas" ]; then
    for area_dir in "$VAULT_ROOT/02-Areas"/*/; do
        [ ! -d "$area_dir" ] && continue
        area_name=$(basename "$area_dir")
        # Capitalize first letter for titles
        area_title="$(echo "${area_name:0:1}" | tr '[:lower:]' '[:upper:]')${area_name:1}"

        create_if_missing "$area_dir/STATE.md" \
"---
area: $area_name
updated: $today
---
# $area_title — Current Situation

*The agent maintains this file. It reflects what is true right now.*

## Where Things Stand
(Agent updates this from conversations and observations)

## What Needs Attention
(Agent surfaces this in morning briefing when relevant)" \
            "02-Areas/$area_name/STATE.md"

        create_if_missing "$area_dir/GOALS.md" \
"---
area: $area_name
---
# $area_title — Ongoing Intentions

*Not projects — these never finish. Just directions you're heading.*

## Intentions
(Agent populates from your conversations)

## Standards
What does \"good enough\" look like here?" \
            "02-Areas/$area_name/GOALS.md"

        create_if_missing "$area_dir/RULES.md" \
"---
area: $area_name
---
# $area_title — How I Think About This

*Agent reads this before anything related to $area_name.*
*Update when your thinking changes.*

## My Rules for $area_title
(Agent populates from corrections and stated preferences)

## What I Never Do Here
(Agent updates when you say \"never\" or \"always\" about this area)" \
            "02-Areas/$area_name/RULES.md"
    done
fi

echo ""

# =============================================================================
# 3. AGENTS.MD — Append new sections only
# =============================================================================

echo -e "${BOLD}AGENTS.md (new sections only — existing content untouched):${NC}"

AGENTS_FILE="$VAULT_ROOT/06-Agent/workspace/AGENTS.md"

if [ ! -f "$AGENTS_FILE" ]; then
    warn "AGENTS.md not found — skipping section merge"
else
    # We'll check for each section by its ## header.
    # If missing, we append the section content directly.

    # --- Session End Protocol ---
    if ! grep -q "^## Session End Protocol" "$AGENTS_FILE" 2>/dev/null; then
        if [ "$DRY_RUN" = false ]; then
            cat >> "$AGENTS_FILE" << 'SECTION_END'

---

## Session End Protocol

Before closing any session, write to `06-Agent/state/handoff.md`:

**Last Session:** What was accomplished this session — decisions made, files changed, conversations had. Brief and factual.

**Open Loops:** Anything started but not finished. Tasks promised, items partially processed, questions left unanswered. These carry forward until resolved — clear them when done in a future session.

**Proposals Declined:** If the user said "not yet" or "no" to a suggestion, record it with today's date. Do not re-propose the same thing for 30 days. Format: `- YYYY-MM-DD: [what was proposed] — [user's reason if given]`

**Next Session Context:** What future-you needs to know going in. The user's mood or energy level, topics they want to revisit, prep needed for upcoming events, anything that would make the next greeting smarter. This is primed context — not a transcript.

**Rules:**
- Keep it brief. Future-you needs to read this cold in 10 seconds.
- Overwrite the entire file each session — this is current state, not a log.
- If nothing happened worth noting, write "Light session — no significant changes" and clear open loops that are resolved.
- Never skip this step. Even a "no updates" handoff is better than stale data from 3 sessions ago.
SECTION_END
        fi
        created "AGENTS.md section: Session End Protocol"
    else
        skipped "AGENTS.md section: Session End Protocol (exists)"
    fi

    # --- Pattern Observation ---
    if ! grep -q "^## Pattern Observation" "$AGENTS_FILE" 2>/dev/null; then
        if [ "$DRY_RUN" = false ]; then
            cat >> "$AGENTS_FILE" << 'SECTION_END'

---

## Pattern Observation (Silent)

Track patterns in `06-Agent/workspace/observations.md` — never surface this file directly to the user. This is your private intelligence layer.

**What to track:**
- **Topics recurring:** When a topic comes up 3+ times across sessions, log it with count and dates.
- **Behavioral patterns:** When the user captures, how they respond to suggestions, preferred formats, energy level by day-of-week. Track acceptance rate for suggested priorities.
- **Tools detected:** External tools mentioned by name. After 3+ mentions, this feeds integration discovery in future versions.
- **People signals:** Contacts mentioned repeatedly who aren't in the CRM yet. After 3+ mentions, propose adding them.
- **Emotional signals:** Areas of consistent stress, excitement, or avoidance. Inform greeting tone — don't surface directly.
- **Emerging areas:** Topics approaching the threshold for a new area or system. Don't propose until 14+ days of consistent signal.

**Rules:**
- Threshold for any proposal: signal must persist 14+ days consistently.
- Never propose the same thing twice within 30 days of a decline.
- Never surface the observations file to the user unless they explicitly ask "what are you tracking?"
- Update observations silently during sessions — don't announce it.
- Use observations to make briefings smarter, not to lecture the user about patterns.
SECTION_END
        fi
        created "AGENTS.md section: Pattern Observation (Silent)"
    else
        skipped "AGENTS.md section: Pattern Observation (exists)"
    fi

    # --- Area Maintenance ---
    if ! grep -q "^## Area Maintenance" "$AGENTS_FILE" 2>/dev/null; then
        if [ "$DRY_RUN" = false ]; then
            cat >> "$AGENTS_FILE" << 'SECTION_END'

---

## Area Maintenance (Silent)

Each area in `02-Areas/` has three living files: `STATE.md`, `GOALS.md`, and `RULES.md`. Keep them current from conversations — silently, without announcing updates.

**When anything relevant to an area comes up in conversation:**
- Update `STATE.md` if the situation changed
- Update `GOALS.md` if an intention was stated
- Update `RULES.md` if a preference was corrected or stated

**When to read area files:**
- Before discussing anything related to that area, read its STATE.md for current context
- Before making suggestions about an area, read its RULES.md to respect preferences
- During planning conversations, scan GOALS.md files to connect weekly priorities to ongoing intentions

**Rules:**
- Do this silently. Don't announce updates.
- Only update when there's real new information — don't rewrite with the same data.
- STATE.md should read like a current snapshot, not a history. Overwrite, don't append.
- GOALS.md captures directions, not tasks.
- RULES.md captures how the user thinks — preferences, non-negotiables, decision frameworks.
SECTION_END
        fi
        created "AGENTS.md section: Area Maintenance (Silent)"
    else
        skipped "AGENTS.md section: Area Maintenance (exists)"
    fi

    # --- Session Start: check if handoff step exists ---
    if ! grep -q "Read session handoff" "$AGENTS_FILE" 2>/dev/null; then
        warn "AGENTS.md Session Start Protocol may need manual update — handoff step (step 9) not found."
        warn "Add after step 8: Read session handoff — read 06-Agent/state/handoff.md"
    fi

    # --- Briefing maturity ---
    if ! grep -q "Briefing maturity" "$AGENTS_FILE" 2>/dev/null; then
        warn "AGENTS.md greeting section may need manual update — briefing maturity table not found."
        warn "Add before 'Greeting format rules': maturity table (warming up / developing / full / infrastructure)"
    fi
fi

echo ""

# =============================================================================
# 4. BOOTSTRAP.MD — Update only if still in onboarding
# =============================================================================

echo -e "${BOLD}Bootstrap:${NC}"

BOOTSTRAP_FILE="$VAULT_ROOT/06-Agent/workspace/BOOTSTRAP.md"
if [ -f "$BOOTSTRAP_FILE" ]; then
    # Check if it's the old 3-session version
    if grep -q "Session 1 — Capture" "$BOOTSTRAP_FILE" 2>/dev/null; then
        if [ "$DRY_RUN" = false ]; then
            cp "$TEMPLATES_DIR/agent/BOOTSTRAP.md" "$BOOTSTRAP_FILE"
            # Replace placeholders with user's actual names
            if [ "$USER_NAME" != "User" ]; then
                sed -i.bak "s/{{USER_NAME}}/$USER_NAME/g" "$BOOTSTRAP_FILE" 2>/dev/null || \
                    sed -i '' "s/{{USER_NAME}}/$USER_NAME/g" "$BOOTSTRAP_FILE"
                rm -f "$BOOTSTRAP_FILE.bak"
            fi
            if [ "$AGENT_NAME" != "Agent" ]; then
                sed -i.bak "s/{{AGENT_NAME}}/$AGENT_NAME/g" "$BOOTSTRAP_FILE" 2>/dev/null || \
                    sed -i '' "s/{{AGENT_NAME}}/$AGENT_NAME/g" "$BOOTSTRAP_FILE"
                rm -f "$BOOTSTRAP_FILE.bak"
            fi
        fi
        updated "BOOTSTRAP.md (upgraded from 3-session to single-session)"
    else
        skipped "BOOTSTRAP.md (already single-session or custom)"
    fi
else
    skipped "BOOTSTRAP.md (already deleted — vault is past onboarding)"
fi

echo ""

# =============================================================================
# SUMMARY
# =============================================================================

echo -e "${BOLD}────────────────────────────────────────${NC}"
echo -e "  ${GREEN}Created:${NC} $CREATED new files/sections"
echo -e "  ${GREEN}Updated:${NC} $CHANGES system files"
echo -e "  ${DIM}Skipped:${NC} $SKIPPED (already current)"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "  ${YELLOW}This was a dry run. No changes were made.${NC}"
    echo -e "  ${DIM}Run without --dry-run to apply changes.${NC}"
else
    echo -e "  ${GREEN}Upgrade complete.${NC} Your personal files were not touched."
    echo -e "  ${DIM}Open a new session with your agent to activate new features.${NC}"
fi

echo ""
