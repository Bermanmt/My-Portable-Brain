#!/bin/bash

# =============================================================================
# Brain Vault — Interactive Onboarding Wizard
# =============================================================================
# Usage:
#   bash onboard.sh                     → interactive setup
#   bash onboard.sh --vault ~/Brain     → skip path question
#   bash onboard.sh --dry-run           → preview without creating files
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$(dirname "$SCRIPT_DIR")/templates"

# --- stamp_template ---
# Usage: stamp_template <template_path> <output_path>
# Reads a template file, replaces {{PLACEHOLDERS}} with current variable
# values, writes the result to output_path (or prints if dry-run).
stamp_template() {
    local tmpl="$1"
    local dest="$2"

    if [ ! -f "$tmpl" ]; then
        warn "Template not found: $tmpl — skipping"
        return 1
    fi

    # Read template and substitute all {{VAR}} tokens with shell variable values.
    # We use envsubst-style replacement via sed, mapping each known token.
    local content
    content=$(sed \
        -e "s|{{USER_NAME}}|${USER_NAME}|g" \
        -e "s|{{USER_ROLE}}|${USER_ROLE}|g" \
        -e "s|{{USER_COMMS}}|${USER_COMMS}|g" \
        -e "s|{{USER_ALWAYS_KNOW}}|${USER_ALWAYS_KNOW}|g" \
        -e "s|{{USER_TIMEZONE}}|${USER_TIMEZONE}|g" \
        -e "s|{{USER_STACK}}|${USER_STACK}|g" \
        -e "s|{{AGENT_NAME}}|${AGENT_NAME}|g" \
        -e "s|{{AGENT_EMOJI}}|${AGENT_EMOJI}|g" \
        -e "s|{{AGENT_PERSONALITY}}|${AGENT_PERSONALITY}|g" \
        -e "s|{{AGENT_TONE}}|${AGENT_TONE}|g" \
        -e "s|{{AGENT_NEVER}}|${AGENT_NEVER}|g" \
        -e "s|{{WORK_PRINCIPLE}}|${WORK_PRINCIPLE}|g" \
        -e "s|{{YEAR_THEMES}}|${YEAR_THEMES}|g" \
        -e "s|{{YEAR_MISOGI}}|${YEAR_MISOGI}|g" \
        -e "s|{{TODAY}}|${today}|g" \
        -e "s|{{YEAR}}|${year}|g" \
        -e "s|{{QUARTER}}|${quarter}|g" \
        -e "s|{{WEEK}}|${week}|g" \
        -e "s|{{VAULT_ROOT}}|${VAULT_ROOT}|g" \
        "$tmpl")

    mkf "$dest" "$content"
}

# --- Colors & formatting ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Parse flags ---
DRY_RUN=false
PRESET_VAULT=""
CONFIG_FILE=""

NEXT_IS=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --vault) NEXT_IS="vault" ;;
        --config) NEXT_IS="config" ;;
        *)
            case "$NEXT_IS" in
                vault) PRESET_VAULT="$arg" ;;
                config) CONFIG_FILE="$arg" ;;
            esac
            NEXT_IS=""
            ;;
    esac
done

# --- Helpers ---
divider() {
    echo -e "${DIM}$(printf '─%.0s' {1..60})${NC}"
}

section() {
    echo ""
    echo -e "${BOLD}${BLUE}$1${NC}"
    divider
}

label() {
    echo -e "${CYAN}▸ $1${NC}"
}

hint() {
    echo -e "${DIM}  $1${NC}"
}

success() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

warn() {
    echo -e "${YELLOW}  ⚠ $1${NC}"
}

ask() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    echo ""
    if [ -n "$default" ]; then
        echo -ne "${BOLD}$prompt${NC} ${DIM}[$default]${NC}: "
    else
        echo -ne "${BOLD}$prompt${NC}: "
    fi
    read -r input
    if [ -z "$input" ] && [ -n "$default" ]; then
        input="$default"
    fi
    eval "$var_name=\"\$input\""
}

ask_multiline() {
    local prompt="$1"
    local hint_text="$2"
    local var_name="$3"
    echo ""
    echo -e "${BOLD}$prompt${NC}"
    [ -n "$hint_text" ] && hint "$hint_text"
    hint "Enter one per line. Empty line to finish."
    local result=""
    local line
    while true; do
        echo -ne "  ${DIM}→${NC} "
        read -r line
        [ -z "$line" ] && break
        if [ -z "$result" ]; then
            result="$line"
        else
            result="$result
$line"
        fi
    done
    eval "$var_name=\"\$result\""
}

ask_yn() {
    local prompt="$1"
    local default="$2"   # y or n
    local var_name="$3"
    echo ""
    if [ "$default" = "y" ]; then
        echo -ne "${BOLD}$prompt${NC} ${DIM}[Y/n]${NC}: "
    else
        echo -ne "${BOLD}$prompt${NC} ${DIM}[y/N]${NC}: "
    fi
    read -r input
    input="${input:-$default}"
    if [[ "$input" =~ ^[Yy] ]]; then
        eval "$var_name=true"
    else
        eval "$var_name=false"
    fi
}

mkd() {
    [ "$DRY_RUN" = false ] && mkdir -p "$1"
}

mkf() {
    local path="$1"
    local content="$2"
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$(dirname "$path")"
        printf '%s\n' "$content" > "$path"
    fi
}

today=$(date +%Y-%m-%d)
year=$(date +%Y)
month=$(date +%Y-%m)
quarter="Q$(( (10#$(date +%m) - 1) / 3 + 1 ))"
week=$(date +%Y-W%V)

VAULT_TIER="${BRAIN_TIER:-2}"
MINIMAL=false
[ "$VAULT_TIER" = "3" ] && MINIMAL=true

# =============================================================================
# WELCOME
# =============================================================================

clear
echo ""
echo -e "${BOLD}Hey.${NC}"
echo ""
echo -e "I'm setting up your Brain — a system that organizes"
echo -e "your work and life so you don't have to think about"
echo -e "the system. You just capture things. I handle the rest."
echo ""

if [ "$DRY_RUN" = true ]; then
    warn "DRY RUN mode — no files will be created"
    echo ""
fi

FIRST_CAPTURE=""
if [ -z "$CONFIG_FILE" ]; then
    echo -e "${DIM}Before I ask you anything —${NC}"
    echo ""
    echo -e "${BOLD}What's the one thing on your mind right now"
    echo -e "that you haven't dealt with yet?${NC}"
    echo ""
    echo -ne "  → "
    read -r FIRST_CAPTURE
    echo ""
    if [ -n "$FIRST_CAPTURE" ]; then
        echo -e "${GREEN}Got it.${NC} I'll make sure that doesn't get lost."
    else
        echo -e "${DIM}No worries — we'll capture things as we go.${NC}"
    fi
    echo ""
    echo -e "${DIM}Now let me learn a little about you so I can"
    echo -e "set everything up properly.${NC}"
    echo ""
    sleep 1
fi

# =============================================================================
# SECTION 1 — VAULT LOCATION
# =============================================================================

section "① Where should your vault live?"

echo ""
echo -e "  This is the root folder for your entire system."
echo -e "  You'll open this folder in Obsidian and Claude."
echo ""
hint "Recommended: ~/Brain or ~/Documents/Brain"

if [ -n "$PRESET_VAULT" ]; then
    VAULT_ROOT="${PRESET_VAULT/#\~/$HOME}"
    echo -e "  Using: ${BOLD}$VAULT_ROOT${NC}"
else
    ask "Vault path" "~/Brain" VAULT_ROOT
    VAULT_ROOT="${VAULT_ROOT/#\~/$HOME}"
fi

if [ "$DRY_RUN" = false ] && [ -d "$VAULT_ROOT" ]; then
    echo ""
    warn "That folder already exists."
    ask_yn "Continue and add files to it?" "y" CONTINUE_EXISTING
    if [ "$CONTINUE_EXISTING" = false ]; then
        echo ""
        echo "  Aborted. Choose a different path."
        exit 0
    fi
fi

success "Vault will be created at: $VAULT_ROOT"

# =============================================================================
# CONFIG FILE MODE — Skip interactive questions if --config provided
# =============================================================================

if [ -n "$CONFIG_FILE" ]; then
    if [ ! -f "$CONFIG_FILE" ]; then
        echo ""
        echo -e "  ${RED}Config file not found: $CONFIG_FILE${NC}"
        exit 1
    fi

    echo ""
    echo -e "  ${GREEN}Loading config from: ${BOLD}$CONFIG_FILE${NC}"
    echo ""

    # --- Read JSON using python3 (available on macOS and most Linux) ---
    _json_val() {
        python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
keys = '$1'.split('.')
val = data
for k in keys:
    if val is None: break
    val = val.get(k)
if val is None:
    print('')
elif isinstance(val, list):
    print('\n'.join(str(v) for v in val))
else:
    print(str(val))
" 2>/dev/null || echo ""
    }

    # --- Load all values from config ---
    USER_NAME=$(_json_val "user.name")
    USER_TIMEZONE=$(_json_val "user.timezone")
    USER_LOCATION=$(_json_val "user.location")
    USER_HOURS=$(_json_val "user.hours")
    USER_ROLE=$(_json_val "user.role")
    USER_STACK=$(_json_val "user.stack")
    USER_COMMS=$(_json_val "user.comms")
    USER_ALWAYS_KNOW=$(_json_val "user.always_know")
    USER_ROLES_RAW=$(_json_val "user.roles")

    AGENT_NAME=$(_json_val "agent.name")
    AGENT_EMOJI=$(_json_val "agent.emoji")
    AGENT_PERSONALITY=$(_json_val "agent.personality")
    AGENT_TONE=$(_json_val "agent.tone")
    AGENT_NEVER=$(_json_val "agent.never")

    YEAR_THEMES=$(_json_val "system.year_themes")
    YEAR_MISOGI=$(_json_val "system.year_misogi")
    WORK_PRINCIPLE=$(_json_val "system.work_principle")

    PROJECT_NAME=$(_json_val "project.name")
    PROJECT_WHAT=$(_json_val "project.what")
    PROJECT_DONE_WHEN=$(_json_val "project.done_when")

    # --- Defaults for empty values ---
    [ -z "$USER_NAME" ] && { echo -e "  ${RED}Error: user.name is required in config.${NC}"; exit 1; }
    [ -z "$USER_TIMEZONE" ] && USER_TIMEZONE="America/New_York"
    [ -z "$USER_HOURS" ] && USER_HOURS="9am–6pm weekdays"
    [ -z "$USER_COMMS" ] && USER_COMMS="Direct and concise, no fluff"
    [ -z "$AGENT_NAME" ] && AGENT_NAME="Sage"
    [ -z "$AGENT_EMOJI" ] && AGENT_EMOJI="🧠"
    [ -z "$AGENT_PERSONALITY" ] && AGENT_PERSONALITY="Direct and sharp, no fluff, honest about uncertainty"
    [ -z "$AGENT_TONE" ] && AGENT_TONE="Casual, like a smart friend who happens to be an expert"
    [ -z "$AGENT_NEVER" ] && AGENT_NEVER="Never flatter. Never add commitments without asking. Never be vague."
    [ -z "$WORK_PRINCIPLE" ] && WORK_PRINCIPLE="Fewer things, done completely"

    # --- Format roles ---
    USER_ROLES_LIST=""
    while IFS= read -r role; do
        [ -n "$role" ] && USER_ROLES_LIST="${USER_ROLES_LIST}- ${role}
"
    done <<< "$USER_ROLES_RAW"
    [ -z "$USER_ROLES_LIST" ] && USER_ROLES_LIST="- (fill in your roles)
"

    # --- Project ---
    ADD_PROJECT=false
    if [ -n "$PROJECT_NAME" ]; then
        ADD_PROJECT=true
        PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
    fi

    # --- Show summary ---
    echo -e "  ${CYAN}Name:${NC}       $USER_NAME"
    echo -e "  ${CYAN}Agent:${NC}      $AGENT_NAME $AGENT_EMOJI"
    echo -e "  ${CYAN}Timezone:${NC}   $USER_TIMEZONE"
    echo -e "  ${CYAN}Themes:${NC}     $YEAR_THEMES"
    echo -e "  ${CYAN}Misogi:${NC}     $YEAR_MISOGI"
    [ "$ADD_PROJECT" = true ] && echo -e "  ${CYAN}Project:${NC}    $PROJECT_NAME"
    echo ""

    success "Config loaded. Building your vault..."

    # Skip to vault creation (jump past interactive sections)
else
# =============================================================================
# INTERACTIVE MODE — Ask questions
# =============================================================================

# =============================================================================
# SECTION 2 — ABOUT YOU
# =============================================================================

section "② About you"

echo ""
echo -e "  This fills your ${CYAN}USER.md${NC} — what the agent knows about you."
echo ""

ask "Your name" "" USER_NAME
ask "Your timezone" "America/New_York" USER_TIMEZONE
ask "Your location (city, country)" "" USER_LOCATION
ask "Your working hours" "9am–6pm weekdays" USER_HOURS
ask "What do you do? (one line, e.g. 'Indie founder, building B2B SaaS')" "" USER_ROLE

echo ""
label "Your tech stack / main tools (e.g. TypeScript, Postgres, Notion)"
hint "Leave blank if not relevant"
ask "" "" USER_STACK

echo ""
label "How do you prefer to communicate?"
hint "e.g. 'Concise. No hand-holding. Skip the preamble.'"
ask "" "Direct and concise, no fluff" USER_COMMS

echo ""
label "Anything the agent should always know about you?"
hint "e.g. 'I have ADHD, keep tasks small' / 'I'm learning Spanish' / 'Never schedule before 9am'"
ask "" "" USER_ALWAYS_KNOW

# =============================================================================
# SECTION 3 — YOUR ROLES
# =============================================================================

section "③ Your life roles"

echo ""
echo -e "  Roles are the most important input in the whole system."
echo -e "  The agent filters every new commitment through these."
echo -e "  Think: what are the hats you wear in life?"
echo ""
hint "Examples: Founder, Father, Partner, Builder, Friend, Athlete"
hint "Aim for 4–7. Too many means no real priorities."

ask_multiline "List your current roles (one per line)" "" USER_ROLES_RAW

# Format roles as a markdown list
USER_ROLES_LIST=""
while IFS= read -r role; do
    [ -n "$role" ] && USER_ROLES_LIST="${USER_ROLES_LIST}- ${role}
"
done <<< "$USER_ROLES_RAW"

if [ -z "$USER_ROLES_LIST" ]; then
    USER_ROLES_LIST="- (fill in your roles)
"
fi

# =============================================================================
# SECTION 4 — YOUR AGENT
# =============================================================================

section "④ Your AI agent"

echo ""
echo -e "  This shapes ${CYAN}SOUL.md${NC} and ${CYAN}IDENTITY.md${NC} — the agent's personality."
echo -e "  You can always edit these later."
echo ""

ask "What should your agent be called?" "Sage" AGENT_NAME
ask "Pick an emoji for your agent" "🧠" AGENT_EMOJI

echo ""
label "Describe the agent's personality in one sentence"
hint "e.g. 'Direct, sharp, a little dry — gets to the point fast'"
hint "e.g. 'Warm and organized, like a great chief of staff'"
ask "" "Direct and sharp, no fluff, honest about uncertainty" AGENT_PERSONALITY

echo ""
label "What tone should the agent use with you?"
hint "e.g. 'Casual, like a smart colleague' / 'Professional but warm' / 'Deadpan and efficient'"
ask "" "Casual, like a smart friend who happens to be an expert" AGENT_TONE

echo ""
label "What should the agent NEVER do?"
hint "e.g. 'Never flatter me' / 'Never add tasks without asking' / 'Never use bullet points for everything'"
ask "" "Never flatter. Never add commitments without asking. Never be vague." AGENT_NEVER

# =============================================================================
# SECTION 5 — YOUR CORE SYSTEM
# =============================================================================

section "⑤ Your core system"

echo ""
echo -e "  ${CYAN}08-CoreSystem${NC} is the foundation. A few quick ones."
echo ""

label "What are your 3 words / themes for $year?"
hint "e.g. 'Focus, Health, Depth' — what defines this year for you"
ask "" "" YEAR_THEMES

label "What is the ONE big thing that must happen in $year?"
hint "Your Misogi — a challenge with real chance of failure"
ask "" "" YEAR_MISOGI

label "Your main principle for how you work"
hint "e.g. 'One thing at a time' / 'Ship before perfect' / 'Energy over time'"
ask "" "Fewer things, done completely" WORK_PRINCIPLE

# =============================================================================
# SECTION 6 — CURRENT PROJECT
# =============================================================================

section "⑥ Your current main project"

echo ""
echo -e "  We'll create your first project in ${CYAN}01-Projects/${NC}."
echo ""
hint "You can skip this and add projects manually later"

ask_yn "Add a current project now?" "y" ADD_PROJECT

if [ "$ADD_PROJECT" = true ]; then
    ask "Project name (e.g. 'Launch marketing site')" "" PROJECT_NAME
    ask "One sentence: what is this project?" "" PROJECT_WHAT
    ask "How will you know it's done?" "" PROJECT_DONE_WHEN
    # kebab-case the project name
    PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
fi

# =============================================================================
# SECTION 7 — CRON JOBS
# =============================================================================

section "⑦ Scheduled automation (cron)"

echo ""
echo -e "  Cron jobs wake the agent on a schedule — daily briefings,"
echo -e "  inbox sweeps, weekly review drafts."
echo ""
echo -e "  Two types of jobs:"
echo -e "  ${GREEN}✓${NC} vault-health  — pure bash, no AI, works without claude CLI"
echo -e "  ${YELLOW}⚡${NC} briefing/review — require claude CLI installed and authenticated"
echo ""
warn "AI jobs will silently fail if claude CLI is not set up. Check logs at 06-Agent/cron/logs/"
hint "You can activate these later with: brain cron"
echo ""

ask_yn "Activate cron jobs now?" "n" ACTIVATE_CRON

if [ "$ACTIVATE_CRON" = true ]; then
    ask "Daily briefing time (24h format, e.g. 07:30)" "07:30" CRON_BRIEFING
    CRON_BRIEF_HOUR="${CRON_BRIEFING%%:*}"
    CRON_BRIEF_MIN="${CRON_BRIEFING##*:}"
    ask "Daily closing time (24h format, e.g. 18:00)" "18:00" CRON_CLOSING
    CRON_CLOSE_HOUR="${CRON_CLOSING%%:*}"
    CRON_CLOSE_MIN="${CRON_CLOSING##*:}"
fi

# =============================================================================
# SECTION 8 — GIT
# =============================================================================

section "⑧ Version control"

echo ""
echo -e "  Your vault is your memory. Git means you can't lose it."
echo ""
hint "Strongly recommended. You can always add a private remote later."

ask_yn "Initialize vault as a git repository?" "y" INIT_GIT

# =============================================================================
# PATH FORK — Calm vs Eager
# =============================================================================

ONBOARDING_PATH="calm"
BRAIN_DUMP_PROJECTS=""
INITIAL_CONTACTS=""
DETECTED_TOOLS=""

echo ""
echo -e "  Before I build everything —"
echo ""
echo -e "  ${BOLD}1)${NC} Show me how it works first, I'll add more as I go"
echo -e "  ${BOLD}2)${NC} Let's get more of my world in here now"
echo ""
echo -ne "  → "
read -r PATH_CHOICE

if [[ "$PATH_CHOICE" == "2" ]]; then
    ONBOARDING_PATH="eager"
    echo ""
    echo -e "Perfect. Let's get your world in here."
    echo -e "${DIM}Just answer naturally — I'll sort everything.${NC}"

    ask_multiline "What are you currently working on?" "List as many as come to mind." BRAIN_DUMP_PROJECTS

    echo ""
    echo -e "${BOLD}Who are the 2-3 people most important to your work right now?${NC}"
    echo -e "${DIM}First names or full names — whatever comes naturally.${NC}"
    ask_multiline "" "" INITIAL_CONTACTS

    echo ""
    ask "Any tools you use daily that you'd want connected?" "" DETECTED_TOOLS
fi

# =============================================================================
# CONFIRMATION
# =============================================================================

section "⑨ Review & confirm"

echo ""
echo -e "  ${BOLD}Here's what will be created:${NC}"
echo ""
echo -e "  ${CYAN}Vault:${NC}        $VAULT_ROOT"
echo -e "  ${CYAN}Your name:${NC}    $USER_NAME"
echo -e "  ${CYAN}Timezone:${NC}     $USER_TIMEZONE"
echo -e "  ${CYAN}Agent name:${NC}   $AGENT_NAME $AGENT_EMOJI"
echo -e "  ${CYAN}Year themes:${NC}  $YEAR_THEMES"
echo -e "  ${CYAN}Misogi:${NC}       $YEAR_MISOGI"
if [ "$ADD_PROJECT" = true ]; then
    echo -e "  ${CYAN}Project:${NC}      $PROJECT_NAME"
fi
echo -e "  ${CYAN}Cron jobs:${NC}    $([ "$ACTIVATE_CRON" = true ] && echo 'yes, activating now' || echo 'no, install manually later')"
echo -e "  ${CYAN}Git:${NC}          $([ "$INIT_GIT" = true ] && echo 'yes' || echo 'no')"
echo ""
echo -e "  ${BOLD}Your roles:${NC}"
while IFS= read -r role; do
    [ -n "$role" ] && echo -e "    ${GREEN}✓${NC} $role"
done <<< "$USER_ROLES_RAW"
echo ""

if [ "$DRY_RUN" = true ]; then
    warn "DRY RUN — no files will be created. Exiting."
    exit 0
fi

ask_yn "Create vault now?" "y" CONFIRMED
if [ "$CONFIRMED" = false ]; then
    echo ""
    echo "  Cancelled. Run again when ready."
    exit 0
fi

fi  # End of interactive vs config-file mode

# --- Set defaults for config-file mode (cron + git) ---
# In config mode, skip cron activation and init git by default
if [ -n "$CONFIG_FILE" ]; then
    [ -z "$ACTIVATE_CRON" ] && ACTIVATE_CRON=false
    [ -z "$INIT_GIT" ] && INIT_GIT=true
fi

# =============================================================================
# BUILD THE VAULT
# =============================================================================

section "Building your vault..."
echo ""

# --- CLAUDE.md ---
mkf "$VAULT_ROOT/CLAUDE.md" "# ${USER_NAME}'s Brain Vault

This is ${USER_NAME}'s personal knowledge and agent vault.

## Agent
- Name: ${AGENT_NAME} ${AGENT_EMOJI}
- Operating instructions: \`06-Agent/workspace/AGENTS.md\`
- Identity and tone: \`06-Agent/workspace/SOUL.md\`
- User profile: \`06-Agent/workspace/USER.md\`

## Session Start
Follow the Session Start Protocol in \`06-Agent/workspace/AGENTS.md\`
before responding to anything.

## Vault Map
| Folder | Purpose |
|--------|---------|
| \`00-Inbox/\` | Capture — everything lands here first |
| \`01-Projects/\` | Active work with a finish line |
| \`02-Areas/\` | Ongoing responsibilities |
| \`03-Resources/\` | Knowledge base — evergreen reference |
| \`04-Archive/\` | Completed or abandoned work |
| \`05-Meta/\` | How this vault works |
| \`06-Agent/\` | AI agent runtime, memory, automation |
| \`07-Systems/\` | CRM, finances, planning |
| \`08-CoreSystem/\` | ${USER_NAME}'s personal operating system |"
success "CLAUDE.md"

# --- 00-Inbox ---
mkd "$VAULT_ROOT/00-Inbox/unsorted"
mkd "$VAULT_ROOT/00-Inbox/meetings"
mkd "$VAULT_ROOT/00-Inbox/emails"
mkd "$VAULT_ROOT/00-Inbox/captures"
mkf "$VAULT_ROOT/00-Inbox/README.md" "# 00-Inbox

Everything new lands here first. Never file directly into Projects or Areas.
Your agent processes and routes items during inbox sweeps.

- [[quick-notes]] — one-line captures
- [[links]] — URLs to process
- [[unsorted/]] — drop files here if you don't know where they go
- meetings/ — meeting transcripts and summaries (from MCP or manual)
- emails/ — email summaries (from MCP or manual)
- captures/ — anything else that lands here
"
mkf "$VAULT_ROOT/00-Inbox/quick-notes.md" "# Quick Notes

Capture anything here. Your agent will process and file it during inbox sweeps.

---
"
mkf "$VAULT_ROOT/00-Inbox/links.md" "# Links to Process

| Date | URL | Context | → Destination |
|------|-----|---------|---------------|
"
[ "$VAULT_TIER" = "1" ] && stamp_template \
    "$TEMPLATES_DIR/learn/00-inbox.md" \
    "$VAULT_ROOT/00-Inbox/LEARN.md"
# Write first capture if provided
if [ -n "$FIRST_CAPTURE" ]; then
    mkf "$VAULT_ROOT/00-Inbox/first-capture.md" "# First Capture — $today

$FIRST_CAPTURE

---
*Captured during onboarding. Agent to process on first session.*
"
    success "First capture saved to inbox"
fi

# Write brain dump from eager path
if [ "$ONBOARDING_PATH" = "eager" ]; then
    BRAIN_DUMP_CONTENT=""
    if [ -n "$BRAIN_DUMP_PROJECTS" ]; then
        BRAIN_DUMP_CONTENT="## Projects mentioned
$BRAIN_DUMP_PROJECTS
"
    fi
    if [ -n "$INITIAL_CONTACTS" ]; then
        BRAIN_DUMP_CONTENT="${BRAIN_DUMP_CONTENT}
## Key people
$INITIAL_CONTACTS
"
    fi
    if [ -n "$DETECTED_TOOLS" ]; then
        BRAIN_DUMP_CONTENT="${BRAIN_DUMP_CONTENT}
## Tools used
$DETECTED_TOOLS
"
    fi
    if [ -n "$BRAIN_DUMP_CONTENT" ]; then
        mkf "$VAULT_ROOT/00-Inbox/brain-dump.md" "# Brain Dump — $today

*Captured during onboarding (eager path). Agent to process on first session:
create projects, add contacts to CRM, log tools in observations.*

$BRAIN_DUMP_CONTENT"
        success "Brain dump saved to inbox"
    fi
fi

success "00-Inbox/"

# --- 01-Projects ---
mkd "$VAULT_ROOT/01-Projects"
mkf "$VAULT_ROOT/01-Projects/README.md" "# 01-Projects

Active work with a clear finish line.
Each project lives in its own subfolder with a README, notes, and assets.

Rule: if it has no finish line, it belongs in 02-Areas instead.

Use [[_template]] to start a new project.
"
mkf "$VAULT_ROOT/01-Projects/_template.md" "---
tags: [project]
status: active
started: YYYY-MM-DD
area: [[]]
---

# Project Name

## What & Why

## Done When

## Related
- Area: [[02-Areas/]]
- Resources: [[03-Resources/]]
- People: [[07-Systems/CRM/contacts/]]

## Next Action
- [ ]

## Notes
"

if [ "$ADD_PROJECT" = true ] && [ -n "$PROJECT_NAME" ]; then
    mkd "$VAULT_ROOT/01-Projects/$PROJECT_SLUG/assets"
    mkf "$VAULT_ROOT/01-Projects/$PROJECT_SLUG/README.md" "---
tags: [project]
status: active
started: $today
---

# $PROJECT_NAME

## What & Why
$PROJECT_WHAT

## Done When
$PROJECT_DONE_WHEN

## Related
- Area: [[]]
- People: [[]]

## Next Action
- [ ]

## Notes
"
    mkf "$VAULT_ROOT/01-Projects/$PROJECT_SLUG/notes.md" "# Notes — $PROJECT_NAME

"
    success "01-Projects/$PROJECT_SLUG/README.md"
    hint "Find it at: $VAULT_ROOT/01-Projects/$PROJECT_SLUG/"
elif [ "$ADD_PROJECT" = true ] && [ -z "$PROJECT_NAME" ]; then
    warn "Project name was blank — skipped. Add manually to 01-Projects/"
    success "01-Projects/"
else
    success "01-Projects/"
fi
[ "$VAULT_TIER" = "1" ] && stamp_template \
    "$TEMPLATES_DIR/learn/01-projects.md" \
    "$VAULT_ROOT/01-Projects/LEARN.md"

if [ "$MINIMAL" = false ]; then
# --- 02-Areas ---
for area in health finances career home; do
    mkd "$VAULT_ROOT/02-Areas/$area"
    area_title="$(echo "$area" | tr '[:lower:]' '[:upper:]' | cut -c1)$(echo "$area" | cut -c2-)"
    mkf "$VAULT_ROOT/02-Areas/$area/index.md" "---
tags: [area]
area: $area
---

# $area_title

## Active Projects
- [[01-Projects/]]

## Goals
- [[$year-$quarter]]
"

    mkf "$VAULT_ROOT/02-Areas/$area/STATE.md" "---
area: $area
updated: $today
---
# $area_title — Current Situation

*The agent maintains this file. It reflects what is true right now.*

## Where Things Stand
(Agent updates this from conversations and observations)

## What Needs Attention
(Agent surfaces this in morning briefing when relevant)
"

    mkf "$VAULT_ROOT/02-Areas/$area/GOALS.md" "---
area: $area
---
# $area_title — Ongoing Intentions

*Not projects — these never finish. Just directions you're heading.*

## Intentions
(Agent populates from your conversations)

## Standards
What does \"good enough\" look like here?
"

    mkf "$VAULT_ROOT/02-Areas/$area/RULES.md" "---
area: $area
---
# $area_title — How I Think About This

*Agent reads this before anything related to $area.*
*Update when your thinking changes.*

## My Rules for $area_title
(Agent populates from corrections and stated preferences)

## What I Never Do Here
(Agent updates when you say \"never\" or \"always\" about this area)
"
done
success "02-Areas/"
[ "$VAULT_TIER" = "1" ] && stamp_template \
    "$TEMPLATES_DIR/learn/02-areas.md" \
    "$VAULT_ROOT/02-Areas/LEARN.md"
fi

if [ "$MINIMAL" = false ]; then
# --- 03-Resources ---
for topic in programming business people reading; do
    mkd "$VAULT_ROOT/03-Resources/$topic"
done
mkf "$VAULT_ROOT/03-Resources/_index.md" "# Resources Index

Evergreen reference. Link here from projects and daily notes.

## Topics
- [[programming/]]
- [[business/]]
- [[people/]]
- [[reading/]]
"
success "03-Resources/"
[ "$VAULT_TIER" = "1" ] && stamp_template \
    "$TEMPLATES_DIR/learn/03-resources.md" \
    "$VAULT_ROOT/03-Resources/LEARN.md"
fi

if [ "$MINIMAL" = false ]; then
# --- 04-Archive ---
mkd "$VAULT_ROOT/04-Archive/projects"
mkd "$VAULT_ROOT/04-Archive/areas"
mkf "$VAULT_ROOT/04-Archive/README.md" "# Archive

Never delete — archive instead.
Agent never moves files here without ${USER_NAME}'s confirmation.
"
success "04-Archive/"
fi

# --- 05-Meta ---
mkd "$VAULT_ROOT/05-Meta/review"
mkf "$VAULT_ROOT/05-Meta/README.md" "# Vault README

${USER_NAME}'s personal knowledge system.
Built on PARA + AI agent + planning system.

## The Golden Rule
New information goes to \`00-Inbox\` first. Always.

## Key Files
- Agent instructions: \`06-Agent/workspace/AGENTS.md\`
- Conventions: \`05-Meta/conventions.md\`
- User profile: \`06-Agent/workspace/USER.md\`
- Core system: \`08-CoreSystem/\`
"
mkf "$VAULT_ROOT/05-Meta/conventions.md" "# Vault Conventions

## File Naming
- Projects: kebab-case → \`project-name\`
- Daily: \`YYYY-MM-DD.md\`
- Weekly: \`YYYY-WNN.md\`
- Quarterly: \`YYYY-QN.md\`
- Interactions: \`YYYY-MM-DD-person-name.md\`

## Backlink Conventions
| Linking to | Format | Example |
|-----------|--------|---------|
| Person | Full name | \`[[John Smith]]\` |
| Project | Folder name | \`[[project-name]]\` |
| Resource | Title case | \`[[Auth Patterns]]\` |
| Daily | Date | \`[[2026-03-05]]\` |
| Weekly | Week | \`[[2026-W10]]\` |
| Quarterly | Quarter | \`[[2026-Q1]]\` |

## Tags
project · area · resource · crm · contact · planning · daily · weekly

## Filing Rules
1. New → 00-Inbox always
2. Active work with end state → 01-Projects
3. Ongoing → 02-Areas
4. Reference → 03-Resources
5. Done → 04-Archive
"
success "05-Meta/"

# --- 06-Agent workspace ---
mkf "$VAULT_ROOT/06-Agent/README.md" "# 06-Agent

${AGENT_NAME}'s runtime — memory, automation, and operating instructions.

| Path | Purpose |
|------|---------|
| workspace/ | Agent identity, user profile, long-term memory |
| subagents/ | Specialized agents (inbox, CRM, researcher, writer) |
| cron/ | Scheduled jobs, prompts, logs |
| brain.sh | CLI — run 'brain help' for commands |

Never put personal notes here. This folder belongs to ${AGENT_NAME}.
"
mkd "$VAULT_ROOT/06-Agent/workspace/memory"
mkd "$VAULT_ROOT/06-Agent/state"
mkd "$VAULT_ROOT/06-Agent/workspace/skills/research"
mkd "$VAULT_ROOT/06-Agent/workspace/skills/writing"
mkd "$VAULT_ROOT/06-Agent/workspace/skills/coding"

stamp_template \
    "$TEMPLATES_DIR/agent/AGENTS.md" \
    "$VAULT_ROOT/06-Agent/workspace/AGENTS.md"

mkf "$VAULT_ROOT/06-Agent/workspace/SOUL.md" "# SOUL.md — ${AGENT_NAME}'s Identity

## Who You Are
${AGENT_NAME} ${AGENT_EMOJI} — ${USER_NAME}'s personal AI agent.
${AGENT_PERSONALITY}

## Tone
${AGENT_TONE}

## Values
- ${USER_NAME}'s time and attention are finite — don't waste them
- Clarity over completeness
- Suggest, don't decide — final calls belong to ${USER_NAME}
- Be honest about uncertainty rather than confident and wrong

## Never
${AGENT_NEVER}

## Remember
You are a fresh instance each session.
Continuity lives in the workspace files — read them first, always.
"

mkf "$VAULT_ROOT/06-Agent/workspace/IDENTITY.md" "# Identity

## Name
${AGENT_NAME}

## Emoji
${AGENT_EMOJI}

## One-liner
${USER_NAME}'s personal AI agent — handles knowledge, memory, and daily operations.
"

mkf "$VAULT_ROOT/06-Agent/workspace/USER.md" "# USER.md — ${USER_NAME}'s Profile

## Basic Info
- Name: ${USER_NAME}
- Role: ${USER_ROLE}
- Timezone: ${USER_TIMEZONE}
- Location: ${USER_LOCATION}
- Working hours: ${USER_HOURS}

## Communication
${USER_COMMS}

$([ -n "$USER_STACK" ] && echo "## Stack / Tools
${USER_STACK}
")
$([ -n "$USER_ALWAYS_KNOW" ] && echo "## Always Remember
${USER_ALWAYS_KNOW}
")
## Knowledge System
- Vault root: $VAULT_ROOT
- Inbox: 00-Inbox/
- Knowledge base: 03-Resources/
- CRM: 07-Systems/CRM/
- Daily notes: 07-Systems/goals/daily/
- Conventions: 05-Meta/conventions.md

## Core System
- Roles: [[08-CoreSystem/roles]]
- Principles: [[08-CoreSystem/principles]]
- Process: [[08-CoreSystem/my-process]]
Read these before suggesting priorities or plans.

## Roles
${USER_ROLES_LIST}
"

mkf "$VAULT_ROOT/06-Agent/workspace/TOOLS.md" "# TOOLS.md — Tool Notes

Notes on how ${USER_NAME} wants tools used.

## File System
- Confirm before writing outside vault root
- Use relative paths from vault root

## Search
Present findings, don't make decisions about what matters.

## Code
$([ -n "$USER_STACK" ] && echo "Stack: ${USER_STACK}")
Always show what you're about to run. Confirm before executing.
"

stamp_template \
    "$TEMPLATES_DIR/agent/BOOTSTRAP.md" \
    "$VAULT_ROOT/06-Agent/workspace/BOOTSTRAP.md"

stamp_template \
    "$TEMPLATES_DIR/agent/corrections.md" \
    "$VAULT_ROOT/06-Agent/workspace/corrections.md"

mkf "$VAULT_ROOT/06-Agent/workspace/memory.md" "# Long-Term Memory

Durable facts about ${USER_NAME} that should persist across sessions.

## Established Preferences
- Communication: ${USER_COMMS}
$([ -n "$USER_ALWAYS_KNOW" ] && echo "- Always: ${USER_ALWAYS_KNOW}")

## Standing Decisions
(${AGENT_NAME} appends here when ${USER_NAME} makes durable decisions)

## Key Context
- Current focus: $year themes — ${YEAR_THEMES}
- Year goal: ${YEAR_MISOGI}
- Work principle: ${WORK_PRINCIPLE}
"

mkf "$VAULT_ROOT/06-Agent/workspace/memory/$today.md" "# ${AGENT_NAME} Memory — $today

## Vault Created
${USER_NAME}'s Brain vault was initialized today via onboarding wizard.

## Setup Context
- Vault: $VAULT_ROOT
- Roles established: $(echo "$USER_ROLES_RAW" | tr '\n' ', ' | sed 's/,$//')
- Year themes: ${YEAR_THEMES}
$([ "$ADD_PROJECT" = true ] && echo "- First project: ${PROJECT_NAME}")

## Sessions
(${AGENT_NAME} writes session observations here)
"
mkf "$VAULT_ROOT/06-Agent/workspace/vault-health.md" "# Vault Health Report
*Generated: $today · Score: —/100 (run vault-health.sh to generate)*

Run \`bash 06-Agent/cron/jobs/vault-health.sh\` to generate your first health report.
"

mkf "$VAULT_ROOT/06-Agent/workspace/pending-actions.md" "# Pending Actions & Patterns
*Generated: $today · 0 items detected*

Run \`bash 06-Agent/cron/jobs/pattern-check.sh\` to scan for pending actions.
"

mkf "$VAULT_ROOT/06-Agent/workspace/observations.md" "---
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
(Topics approaching the proposal threshold)
"

mkf "$VAULT_ROOT/06-Agent/state/handoff.md" "---
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
(What the agent should know going in — primed context, follow-ups promised, mood/energy signals)
"

mkf "$VAULT_ROOT/06-Agent/state/created.md" "---
created: $today
---
Vault created on $today via onboard.sh.
"

success "06-Agent/workspace/"
[ "$VAULT_TIER" = "1" ] && stamp_template \
    "$TEMPLATES_DIR/learn/06-agent.md" \
    "$VAULT_ROOT/06-Agent/LEARN.md"

# --- Subagents ---
# Core subagents (always created)
mkd "$VAULT_ROOT/06-Agent/subagents/inbox-processor"
stamp_template "$TEMPLATES_DIR/agent/subagents/inbox-processor/AGENT.md" \
    "$VAULT_ROOT/06-Agent/subagents/inbox-processor/AGENT.md"

mkd "$VAULT_ROOT/06-Agent/subagents/crm-manager"
stamp_template "$TEMPLATES_DIR/agent/subagents/crm-manager/AGENT.md" \
    "$VAULT_ROOT/06-Agent/subagents/crm-manager/AGENT.md"
cp "$TEMPLATES_DIR/agent/subagents/crm-manager/briefing.md" \
    "$VAULT_ROOT/06-Agent/subagents/crm-manager/briefing.md"
cp "$TEMPLATES_DIR/agent/subagents/crm-manager/processing-log.md" \
    "$VAULT_ROOT/06-Agent/subagents/crm-manager/processing-log.md"

mkd "$VAULT_ROOT/06-Agent/subagents/calendar-agent"
stamp_template "$TEMPLATES_DIR/agent/subagents/calendar-agent/AGENT.md" \
    "$VAULT_ROOT/06-Agent/subagents/calendar-agent/AGENT.md"
cp "$TEMPLATES_DIR/agent/subagents/calendar-agent/briefing.md" \
    "$VAULT_ROOT/06-Agent/subagents/calendar-agent/briefing.md"
cp "$TEMPLATES_DIR/agent/subagents/calendar-agent/processing-log.md" \
    "$VAULT_ROOT/06-Agent/subagents/calendar-agent/processing-log.md"

if [ "$MINIMAL" = false ]; then
mkd "$VAULT_ROOT/06-Agent/subagents/researcher"
stamp_template "$TEMPLATES_DIR/agent/subagents/researcher/AGENT.md" \
    "$VAULT_ROOT/06-Agent/subagents/researcher/AGENT.md"

mkd "$VAULT_ROOT/06-Agent/subagents/writer"
stamp_template "$TEMPLATES_DIR/agent/subagents/writer/AGENT.md" \
    "$VAULT_ROOT/06-Agent/subagents/writer/AGENT.md"
fi
success "06-Agent/subagents/"

if [ "$MINIMAL" = false ]; then
# --- Skills ---
mkf "$VAULT_ROOT/06-Agent/workspace/skills/research/SKILL.md" "# Research Skill

## Purpose
Find information on a topic and file to 03-Resources.

## Process
1. Clarify scope
2. Gather and synthesize
3. File to 03-Resources/{topic}/concept-name.md
4. Add backlinks to related notes and projects

## Output Format
- Title case name
- 2-3 sentence summary at top
- Structured notes in ${USER_NAME}'s own words
- Sources at bottom
"

mkf "$VAULT_ROOT/06-Agent/workspace/skills/writing/SKILL.md" "# Writing Skill

## Style for ${USER_NAME}
- Tone: ${AGENT_TONE}
- ${USER_COMMS}

## Rules
Always present draft before writing to file.
"

mkf "$VAULT_ROOT/06-Agent/workspace/skills/coding/SKILL.md" "# Coding Skill

$([ -n "$USER_STACK" ] && echo "## Stack
${USER_STACK}
")
## Rules
- Show what you're about to run
- Confirm before executing anything
- Always show diff before editing existing files
"
fi

# --- Cron ---
mkd "$VAULT_ROOT/06-Agent/cron/launchd"
mkd "$VAULT_ROOT/06-Agent/cron/jobs"
mkd "$VAULT_ROOT/06-Agent/cron/prompts"
mkd "$VAULT_ROOT/06-Agent/cron/logs"

if [ "$MINIMAL" = false ]; then
mkf "$VAULT_ROOT/06-Agent/cron/README.md" "# Scheduled Jobs

## Pure bash (no LLM needed)
| Job | Schedule | Output |
|-----|----------|--------|
| daily-briefing | ${CRON_BRIEFING:-07:30} daily | Morning section in today's daily note |
| rebuild-context | 07:15 daily | 06-Agent/workspace/CONTEXT-PACK.md |
| crm-scan | 21:00 nightly | CRM briefing (contact detection, last-contact updates) |
| pattern-check | 21:30 nightly | 06-Agent/workspace/pending-actions.md |
| vault-health | Sunday 20:00 | 06-Agent/workspace/vault-health.md |
| daily-backup | 22:00 daily | Git commit of vault changes |

## LLM-powered (requires Claude CLI)
| Job | Schedule | Output |
|-----|----------|--------|
| daily-closing | ${CRON_CLOSING:-18:00} weekdays | End-of-day summary to agent memory |
| inbox-sweep | 10:00 weekdays | Inbox routing suggestions |
| weekly-review | Friday 17:00 | Draft weekly review |

## CLI
Run any job manually: \\\`bash 06-Agent/brain.sh <command>\\\`

## Activate
  bash $VAULT_ROOT/06-Agent/cron/install-jobs.sh

## Logs
Each job appends to logs/YYYY-MM-DD-jobname.log
"
fi

# Cron prompts
mkf "$VAULT_ROOT/06-Agent/cron/prompts/daily-briefing.md" "You are ${AGENT_NAME}, running the daily briefing for ${USER_NAME}.

Today is \$(date +%Y-%m-%d).

1. Read 07-Systems/goals/weekly/ for this week's plan
2. Read 07-Systems/CRM/pipeline/active.md for follow-ups due today
3. Check 01-Projects/ for actions due today
4. Read 06-Agent/workspace/memory.md for standing context

Write ONLY to the '## 🤖 Morning Briefing' section of today's daily note
at 07-Systems/goals/daily/\$(date +%Y-%m-%d).md

Write:
- Top 3 priorities for today
- CRM follow-ups due
- Inbox item count
- Any overdue actions

Do not touch any other section. Do not ask questions. Just write.
"

mkf "$VAULT_ROOT/06-Agent/cron/prompts/daily-closing.md" "You are ${AGENT_NAME}, running the daily closing for ${USER_NAME}.

Today is \$(date +%Y-%m-%d).

1. Read today's daily note: 07-Systems/goals/daily/\$(date +%Y-%m-%d).md
2. Read this week's plan in 07-Systems/goals/weekly/

Write to 06-Agent/workspace/memory/\$(date +%Y-%m-%d).md
Under '## End of Day':
- What happened (from the log section)
- Decisions made
- Open loops
- Tomorrow's top priority

Do not modify ${USER_NAME}'s daily note. Do not ask questions. Just write.
"

mkf "$VAULT_ROOT/06-Agent/cron/prompts/inbox-sweep.md" "You are running the inbox sweep for ${USER_NAME}.

Read all files in 00-Inbox/ and 00-Inbox/unsorted/.
Read 05-Meta/conventions.md for filing rules.

For each item, suggest destination.
Write summary to 06-Agent/workspace/memory/\$(date +%Y-%m-%d).md
under '## Inbox Sweep':
- Each item + suggested destination
- [NEEDS DECISION] for anything unclear

Do not move any files. Suggest only.
"

mkf "$VAULT_ROOT/06-Agent/cron/prompts/weekly-review.md" "You are ${AGENT_NAME}, running the weekly review draft for ${USER_NAME}.

Week: \$(date +%Y-W%V)

1. Read agent memory logs from this week
2. Read ${USER_NAME}'s daily notes from this week in 07-Systems/goals/daily/
3. Check 01-Projects/ for status changes
4. Check 07-Systems/CRM/pipeline/active.md

Fill in the '## Friday Review' section of 07-Systems/goals/weekly/\$(date +%Y-W%V).md:
- What went well
- What didn't
- Open loops carrying to next week
- Suggested focus for next week

Draft it. ${USER_NAME} will refine. Do not ask questions.
"

mkf "$VAULT_ROOT/06-Agent/cron/prompts/quarterly-checkin.md" "You are ${AGENT_NAME}, running the quarterly planning prompt for ${USER_NAME}.

1. Read 08-CoreSystem/roles.md and 08-CoreSystem/principles.md
2. Read last quarter's plan in 07-Systems/goals/quarterly/
3. Read 07-Systems/goals/yearly/$year.md

Create this quarter's plan in 07-Systems/goals/quarterly/
using the quarterly template. Pre-fill based on yearly goals and roles.
Mark sections clearly for ${USER_NAME} to complete.
"

# LLM config
mkd "$VAULT_ROOT/06-Agent/config"
mkf "$VAULT_ROOT/06-Agent/config/llm.conf" "# Brain Vault — LLM provider config
# All cron job scripts source this file.
#
# To switch model:        LLM_MODEL=claude-opus-4-6
# To add flags:           LLM_EXTRA_FLAGS=--dangerously-skip-permissions
# To switch provider:     LLM_CMD=<other-cli> and adjust LLM_EXTRA_FLAGS

LLM_CMD=claude
LLM_MODEL=
LLM_EXTRA_FLAGS=

run_llm() {
  local system=\"\$1\" task=\"\$2\"
  local cmd_args=(--system-prompt \"\$system\" -p \"\$task\")
  [ -n \"\$LLM_MODEL\" ] && cmd_args+=(--model \"\$LLM_MODEL\")
  if [ -n \"\$LLM_EXTRA_FLAGS\" ]; then
    read -ra _extra <<< \"\$LLM_EXTRA_FLAGS\"
    cmd_args+=(\"\${_extra[@]}\")
  fi
  \$LLM_CMD \"\${cmd_args[@]}\"
}
"

# Job scripts
# daily-briefing: data-driven, no LLM needed for basic stats
cp "$TEMPLATES_DIR/cron/jobs/daily-briefing.sh" "$VAULT_ROOT/06-Agent/cron/jobs/daily-briefing.sh"
success "06-Agent/cron/jobs/daily-briefing.sh (from template)"

# CRM scan: nightly contact detection and briefing update
cp "$TEMPLATES_DIR/cron/jobs/crm-scan.sh" "$VAULT_ROOT/06-Agent/cron/jobs/crm-scan.sh"
success "06-Agent/cron/jobs/crm-scan.sh (from template)"

# Vault health: scores vault hygiene (stale projects, inbox, streak, contacts)
cp "$TEMPLATES_DIR/cron/jobs/vault-health.sh" "$VAULT_ROOT/06-Agent/cron/jobs/vault-health.sh"
success "06-Agent/cron/jobs/vault-health.sh (from template)"

# Pattern check: detects recurring carries, stale actions, open loops
cp "$TEMPLATES_DIR/cron/jobs/pattern-check.sh" "$VAULT_ROOT/06-Agent/cron/jobs/pattern-check.sh"
success "06-Agent/cron/jobs/pattern-check.sh (from template)"

if [ "$MINIMAL" = false ]; then
mkf "$VAULT_ROOT/06-Agent/cron/jobs/daily-closing.sh" "#!/bin/bash
VAULT=\"$VAULT_ROOT\"
AGENT=\"\$VAULT/06-Agent\"
DATE=\$(date +%Y-%m-%d)
LOG=\"\$AGENT/cron/logs/\$DATE-daily-closing.log\"
source \"\$AGENT/config/llm.conf\"

SYSTEM=\$(cat \"\$AGENT/workspace/AGENTS.md\")
TASK=\$(cat \"\$AGENT/cron/prompts/daily-closing.md\")

echo \"[\$(date)] daily-closing start\" >> \"\$LOG\"
run_llm \"\$SYSTEM\" \"\$TASK\" >> \"\$LOG\" 2>&1
echo \"[\$(date)] done\" >> \"\$LOG\"
"

mkf "$VAULT_ROOT/06-Agent/cron/jobs/inbox-sweep.sh" "#!/bin/bash
VAULT=\"$VAULT_ROOT\"
AGENT=\"\$VAULT/06-Agent\"
DATE=\$(date +%Y-%m-%d)
LOG=\"\$AGENT/cron/logs/\$DATE-inbox-sweep.log\"
source \"\$AGENT/config/llm.conf\"

SYSTEM=\$(cat \"\$AGENT/subagents/inbox-processor/AGENT.md\")
TASK=\$(cat \"\$AGENT/cron/prompts/inbox-sweep.md\")

echo \"[\$(date)] inbox-sweep start\" >> \"\$LOG\"
run_llm \"\$SYSTEM\" \"\$TASK\" >> \"\$LOG\" 2>&1
echo \"[\$(date)] done\" >> \"\$LOG\"
"

mkf "$VAULT_ROOT/06-Agent/cron/jobs/weekly-review.sh" "#!/bin/bash
VAULT=\"$VAULT_ROOT\"
AGENT=\"\$VAULT/06-Agent\"
DATE=\$(date +%Y-%m-%d)
LOG=\"\$AGENT/cron/logs/\$DATE-weekly-review.log\"
source \"\$AGENT/config/llm.conf\"

SYSTEM=\$(cat \"\$AGENT/workspace/AGENTS.md\")
TASK=\$(cat \"\$AGENT/cron/prompts/weekly-review.md\")

echo \"[\$(date)] weekly-review start\" >> \"\$LOG\"
run_llm \"\$SYSTEM\" \"\$TASK\" >> \"\$LOG\" 2>&1
echo \"[\$(date)] done\" >> \"\$LOG\"
"
fi

# rebuild-context.sh — generates CONTEXT-PACK.md (no LLM needed, pure bash)
mkf "$VAULT_ROOT/06-Agent/cron/jobs/rebuild-context.sh" '#!/bin/bash

# =============================================================================
# rebuild-context.sh — Generates CONTEXT-PACK.md
# =============================================================================
# Assembles a single file from vault sources so any LLM session can load
# full context in one read instead of seven.
#
# Output: 06-Agent/workspace/CONTEXT-PACK.md
# Runs via cron 2x/day (6am, noon) or manually: brain context
# This is a read-only derived cache. Delete it → rebuilt next cycle.
# =============================================================================

set -e

if [ -z "$VAULT_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    VAULT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

OUTPUT="$VAULT_ROOT/06-Agent/workspace/CONTEXT-PACK.md"
NOW=$(date +"%Y-%m-%dT%H:%M:%S")
TODAY=$(date +"%Y-%m-%d")
YESTERDAY=$(date -v-1d +"%Y-%m-%d" 2>/dev/null || date -d "yesterday" +"%Y-%m-%d" 2>/dev/null || echo "")

strip_frontmatter() {
    local path="$1"
    if [ -f "$path" ]; then
        awk '\''BEGIN{fm=0} /^---$/{fm++; next} fm>=2||fm==0{print}'\'' "$path"
    fi
}

count_files() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -maxdepth 1 -type f -not -name ".*" -not -name "_*" | wc -l | tr -d " "
    else
        echo "0"
    fi
}

# --- Collect data ---
SOUL=$(strip_frontmatter "$VAULT_ROOT/06-Agent/workspace/SOUL.md")
USER_PROFILE=$(strip_frontmatter "$VAULT_ROOT/06-Agent/workspace/USER.md")
MEMORY=$(strip_frontmatter "$VAULT_ROOT/06-Agent/workspace/memory.md")

TODAY_MEMORY=""
[ -f "$VAULT_ROOT/06-Agent/workspace/memory/$TODAY.md" ] && TODAY_MEMORY=$(cat "$VAULT_ROOT/06-Agent/workspace/memory/$TODAY.md")

YESTERDAY_MEMORY=""
[ -n "$YESTERDAY" ] && [ -f "$VAULT_ROOT/06-Agent/workspace/memory/$YESTERDAY.md" ] && YESTERDAY_MEMORY=$(cat "$VAULT_ROOT/06-Agent/workspace/memory/$YESTERDAY.md")

# --- Active Projects ---
PROJECTS=""
if [ -d "$VAULT_ROOT/01-Projects" ]; then
    for proj_dir in "$VAULT_ROOT/01-Projects"/*/; do
        [ -d "$proj_dir" ] || continue
        proj_name=$(basename "$proj_dir")
        [ "$proj_name" = "_template.md" ] && continue
        readme="$proj_dir/README.md"
        if [ -f "$readme" ]; then
            status=$(grep -m1 "^status:" "$readme" 2>/dev/null | sed "s/status: *//" | tr -d " ")
            [ "$status" != "active" ] && continue
            area=$(grep -m1 "^area:" "$readme" 2>/dev/null | sed "s/area: *//")
            # Last modified — Linux first, macOS fallback
            last_mod_date=$(find "$proj_dir" -maxdepth 2 -name "*.md" -type f -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | awk "{ts=int(\$1); \"date -d @\"ts\" +%Y-%m-%d\" | getline d; print d}")
            if [ -z "$last_mod_date" ]; then
                last_mod_date=$(find "$proj_dir" -maxdepth 2 -name "*.md" -type f -exec stat -f "%m" {} \; 2>/dev/null | sort -rn | head -1 | xargs -I{} date -r {} +"%Y-%m-%d" 2>/dev/null || echo "unknown")
            fi
            open_tasks=$(grep -c "^\- \[ \]" "$readme" 2>/dev/null; true)
            closed_tasks=$(grep -c "^\- \[x\]" "$readme" 2>/dev/null; true)
            PROJECTS="${PROJECTS}- **${proj_name}** — ${area:-no area} | last active: ${last_mod_date} | open: ${open_tasks} / done: ${closed_tasks}
"
        fi
    done
fi

INBOX_COUNT=$(count_files "$VAULT_ROOT/00-Inbox")

# --- Corrections ---
CORRECTIONS=""
if [ -f "$VAULT_ROOT/06-Agent/workspace/corrections.md" ]; then
    active=$(awk "/^## Active Observations/,/^## /{print}" "$VAULT_ROOT/06-Agent/workspace/corrections.md" | grep "^|" | grep -v "^| Pattern" | grep -v "^|-" | grep -v "| *|" || true)
    [ -n "$active" ] && CORRECTIONS="$active"
fi

PENDING_COUNT=0
[ -f "$VAULT_ROOT/06-Agent/state/pending-actions.md" ] && PENDING_COUNT=$(grep -c "^\- \[ \]" "$VAULT_ROOT/06-Agent/state/pending-actions.md" 2>/dev/null || echo "0")

# --- Write output ---
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

## Active Projects

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
'

chmod +x "$VAULT_ROOT/06-Agent/cron/jobs/"*.sh

# launchd plists
BRIEF_H="${CRON_BRIEF_HOUR:-07}"
BRIEF_M="${CRON_BRIEF_MIN:-30}"
CLOSE_H="${CRON_CLOSE_HOUR:-18}"
CLOSE_M="${CRON_CLOSE_MIN:-00}"

mkf "$VAULT_ROOT/06-Agent/cron/launchd/com.brain.daily-briefing.plist" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
    <key>Label</key><string>com.brain.daily-briefing</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$VAULT_ROOT/06-Agent/cron/jobs/daily-briefing.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key><integer>$BRIEF_H</integer>
        <key>Minute</key><integer>$BRIEF_M</integer>
    </dict>
    <key>StandardOutPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/daily-briefing.log</string>
    <key>StandardErrorPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/daily-briefing-error.log</string>
    <key>RunAtLoad</key><false/>
</dict></plist>"

if [ "$MINIMAL" = false ]; then
mkf "$VAULT_ROOT/06-Agent/cron/launchd/com.brain.daily-closing.plist" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
    <key>Label</key><string>com.brain.daily-closing</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$VAULT_ROOT/06-Agent/cron/jobs/daily-closing.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key><integer>$CLOSE_H</integer>
        <key>Minute</key><integer>$CLOSE_M</integer>
    </dict>
    <key>StandardOutPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/daily-closing.log</string>
    <key>StandardErrorPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/daily-closing-error.log</string>
    <key>RunAtLoad</key><false/>
</dict></plist>"

mkf "$VAULT_ROOT/06-Agent/cron/launchd/com.brain.weekly-review.plist" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
    <key>Label</key><string>com.brain.weekly-review</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$VAULT_ROOT/06-Agent/cron/jobs/weekly-review.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key><integer>5</integer>
        <key>Hour</key><integer>17</integer>
        <key>Minute</key><integer>0</integer>
    </dict>
    <key>StandardOutPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/weekly-review.log</string>
    <key>StandardErrorPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/weekly-review-error.log</string>
    <key>RunAtLoad</key><false/>
</dict></plist>"
fi

mkf "$VAULT_ROOT/06-Agent/cron/jobs/daily-backup.sh" "#!/bin/bash
VAULT=\"$VAULT_ROOT\"
LOG=\"\$VAULT/06-Agent/cron/logs/\$(date +%Y-%m-%d)-daily-backup.log\"

echo \"[\$(date)] daily-backup start\" >> \"\$LOG\"
cd \"\$VAULT\" && git add -A
if git diff --cached --quiet; then
  echo \"[\$(date)] nothing to commit\" >> \"\$LOG\"
else
  git commit -m \"daily backup \$(date +%Y-%m-%d)\" >> \"\$LOG\" 2>&1
  echo \"[\$(date)] committed\" >> \"\$LOG\"
fi
echo \"[\$(date)] done\" >> \"\$LOG\"
"

chmod +x "$VAULT_ROOT/06-Agent/cron/jobs/daily-backup.sh"

mkf "$VAULT_ROOT/06-Agent/cron/launchd/com.brain.daily-backup.plist" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
    <key>Label</key><string>com.brain.daily-backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$VAULT_ROOT/06-Agent/cron/jobs/daily-backup.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key><integer>23</integer>
        <key>Minute</key><integer>0</integer>
    </dict>
    <key>StandardOutPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/daily-backup.log</string>
    <key>StandardErrorPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/daily-backup-error.log</string>
    <key>RunAtLoad</key><false/>
</dict></plist>"

if [ "$MINIMAL" = false ]; then
mkf "$VAULT_ROOT/06-Agent/cron/jobs/weekly-tag.sh" "#!/bin/bash
VAULT=\"$VAULT_ROOT\"
LOG=\"\$VAULT/06-Agent/cron/logs/\$(date +%Y-%m-%d)-weekly-tag.log\"
TAG=\$(date +%Y-W%V)

echo \"[\$(date)] weekly-tag start — \$TAG\" >> \"\$LOG\"
cd \"\$VAULT\"
if git rev-parse \"\$TAG\" >/dev/null 2>&1; then
  echo \"[\$(date)] tag \$TAG already exists, skipping\" >> \"\$LOG\"
else
  git tag \"\$TAG\" >> \"\$LOG\" 2>&1
  echo \"[\$(date)] tagged \$TAG\" >> \"\$LOG\"
fi
echo \"[\$(date)] done\" >> \"\$LOG\"
"

chmod +x "$VAULT_ROOT/06-Agent/cron/jobs/weekly-tag.sh"

mkf "$VAULT_ROOT/06-Agent/cron/launchd/com.brain.weekly-tag.plist" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
    <key>Label</key><string>com.brain.weekly-tag</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$VAULT_ROOT/06-Agent/cron/jobs/weekly-tag.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key><integer>6</integer>
        <key>Hour</key><integer>1</integer>
        <key>Minute</key><integer>0</integer>
    </dict>
    <key>StandardOutPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/weekly-tag.log</string>
    <key>StandardErrorPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/weekly-tag-error.log</string>
    <key>RunAtLoad</key><false/>
</dict></plist>"

# rebuild-context plist — runs at 6am and noon
mkf "$VAULT_ROOT/06-Agent/cron/launchd/com.brain.rebuild-context.plist" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
    <key>Label</key><string>com.brain.rebuild-context</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$VAULT_ROOT/06-Agent/cron/jobs/rebuild-context.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Hour</key><integer>6</integer>
            <key>Minute</key><integer>0</integer>
        </dict>
        <dict>
            <key>Hour</key><integer>12</integer>
            <key>Minute</key><integer>0</integer>
        </dict>
    </array>
    <key>StandardOutPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/rebuild-context.log</string>
    <key>StandardErrorPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/rebuild-context-error.log</string>
    <key>RunAtLoad</key><false/>
</dict></plist>"
fi

if [ "$MINIMAL" = false ]; then
mkf "$VAULT_ROOT/05-Meta/vault-health.sh" "#!/bin/bash
# vault-health.sh — Vault lint and health check
# Output: 05-Meta/vault-health.md
# Usage: bash vault-health.sh [--vault /path/to/vault]

VAULT=\"$VAULT_ROOT\"
while [ \$# -gt 0 ]; do
  case \"\$1\" in --vault) VAULT=\"\$2\"; shift 2 ;; *) shift ;; esac
done

REPORT=\"\$VAULT/05-Meta/vault-health.md\"
TODAY=\$(date +%Y-%m-%d)
THRESHOLD=\${INBOX_THRESHOLD:-20}
ISSUES=0

{
echo \"# Vault Health — \$TODAY\"
echo \"\"
echo \"| Check | Status | Detail |\"
echo \"|-------|--------|--------|\"

# 1. Stale projects (not modified in 30+ days)
stale=\$(find \"\$VAULT/01-Projects\" -maxdepth 2 -name \"README.md\" 2>/dev/null | while IFS= read -r f; do
  mtime=\$(stat -f %m \"\$f\" 2>/dev/null || stat -c %Y \"\$f\" 2>/dev/null || echo 0)
  age=\$(( (\$(date +%s) - mtime) / 86400 ))
  [ \"\$age\" -gt 30 ] && echo x
done | wc -l | tr -d ' ')
if [ \"\$stale\" -gt 0 ]; then
  echo \"| STALE PROJECT | ⚠ \$stale | not touched in 30+ days |\"
  ISSUES=\$((ISSUES + stale))
else
  echo \"| Stale projects | ✓ | all active |\"
fi

# 2. Inbox overflow
inbox=\$(find \"\$VAULT/00-Inbox\" -type f -name \"*.md\" 2>/dev/null | wc -l | tr -d ' ')
if [ \"\$inbox\" -gt \"\$THRESHOLD\" ]; then
  echo \"| INBOX OVERFLOW | ⚠ \$inbox | threshold: \$THRESHOLD |\"
  ISSUES=\$((ISSUES + 1))
else
  echo \"| Inbox count | ✓ | \$inbox items |\"
fi

# 3. Recent daily notes missing energy: frontmatter
missing=\$(find \"\$VAULT/07-Systems/goals/daily\" -name \"*.md\" ! -name \"_template.md\" 2>/dev/null | sort -r | head -7 | while IFS= read -r f; do
  grep -qi \"^energy:\" \"\$f\" 2>/dev/null || echo x
done | wc -l | tr -d ' ')
if [ \"\$missing\" -gt 0 ]; then
  echo \"| MISSING ENERGY | ⚠ \$missing | recent daily notes missing energy: field |\"
  ISSUES=\$((ISSUES + 1))
else
  echo \"| Energy frontmatter | ✓ | recent notes complete |\"
fi

# 4. CRM contacts with overdue next-action-date
overdue=\$(find \"\$VAULT/07-Systems/CRM/contacts\" -name \"*.md\" 2>/dev/null | while IFS= read -r f; do
  nad=\$(grep -m1 \"^next-action-date:\" \"\$f\" 2>/dev/null | awk '{print \$2}')
  [ -n \"\$nad\" ] && [[ \"\$nad\" < \"\$TODAY\" ]] && echo x
done | wc -l | tr -d ' ')
if [ \"\$overdue\" -gt 0 ]; then
  echo \"| CRM OVERDUE | ⚠ \$overdue | contacts need follow-up |\"
  ISSUES=\$((ISSUES + overdue))
else
  echo \"| CRM follow-ups | ✓ | none overdue |\"
fi

# 5. Broken backlinks: [[link]] where target.md does not exist
broken=\$(find \"\$VAULT\" -name \"*.md\" -not -path \"*/.obsidian/*\" 2>/dev/null | head -100 | while IFS= read -r f; do
  grep -oh '\\[\\[[^]|#]*\\]\\]' \"\$f\" 2>/dev/null | sed 's/\\[\\[//;s/\\]\\]//' | grep -v '^http' | while IFS= read -r link; do
    base=\$(basename \"\$link\")
    find \"\$VAULT\" -name \"\${base}.md\" 2>/dev/null | grep -q . || echo x
  done
done | wc -l | tr -d ' ')
if [ \"\$broken\" -gt 0 ]; then
  echo \"| BROKEN LINK | ⚠ \$broken | run manually to inspect |\"
  ISSUES=\$((ISSUES + broken))
else
  echo \"| Backlinks | ✓ | no broken links found |\"
fi

echo \"\"
if [ \"\$ISSUES\" -gt 0 ]; then
  echo \"> **\$ISSUES issue(s) found.** Review the table above.\"
else
  echo \"> **Vault is healthy.** No issues found.\"
fi
echo \"\"
echo \"_Last run: \$(date)_\"
} > \"\$REPORT\"

cat \"\$REPORT\"
[ \"\$ISSUES\" -gt 0 ] && exit 1 || exit 0
"

mkf "$VAULT_ROOT/06-Agent/cron/jobs/vault-lint.sh" "#!/bin/bash
VAULT=\"$VAULT_ROOT\"
AGENT=\"\$VAULT/06-Agent\"
bash \"\$VAULT/05-Meta/vault-health.sh\" >> \"\$AGENT/cron/logs/vault-lint.log\" 2>&1
"

mkf "$VAULT_ROOT/06-Agent/cron/launchd/com.brain.vault-lint.plist" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
    <key>Label</key><string>com.brain.vault-lint</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$VAULT_ROOT/06-Agent/cron/jobs/vault-lint.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key><integer>5</integer>
        <key>Hour</key><integer>16</integer>
        <key>Minute</key><integer>0</integer>
    </dict>
    <key>StandardOutPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/vault-lint.log</string>
    <key>StandardErrorPath</key><string>$VAULT_ROOT/06-Agent/cron/logs/vault-lint-error.log</string>
    <key>RunAtLoad</key><false/>
</dict></plist>"
fi

mkf "$VAULT_ROOT/06-Agent/cron/install-jobs.sh" "#!/bin/bash
# Install all launchd jobs
PLIST_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)/launchd\"
LAUNCH_AGENTS=\"\$HOME/Library/LaunchAgents\"

echo \"Installing Brain vault jobs for ${USER_NAME}...\"
for plist in \"\$PLIST_DIR\"/*.plist; do
    filename=\$(basename \"\$plist\")
    label=\${filename%.plist}
    launchctl bootout gui/\$(id -u) \"\$LAUNCH_AGENTS/\$filename\" 2>/dev/null || true
    cp \"\$plist\" \"\$LAUNCH_AGENTS/\$filename\"
    launchctl bootstrap gui/\$(id -u) \"\$LAUNCH_AGENTS/\$filename\"
    echo \"  ✓ \$label\"
done
echo \"Done.\"
"
chmod +x "$VAULT_ROOT/06-Agent/cron/install-jobs.sh"

mkd "$VAULT_ROOT/06-Agent/sessions"

mkf "$VAULT_ROOT/06-Agent/brain.sh" "#!/bin/bash
# Brain CLI — quick access to vault operations
# Usage: brain <command>
#   inbox      Run inbox sweep
#   briefing   Run daily briefing manually
#   health     Run vault health check (score + hygiene report)
#   patterns   Run pattern detection (carries, stale actions, open loops)
#   crm-scan   Run CRM contact detection and briefing update
#   context    Rebuild CONTEXT-PACK.md
#   backup     Commit vault changes to git
#   cron       Install/refresh all scheduled jobs

VAULT=\"$VAULT_ROOT\"
AGENT=\"\$VAULT/06-Agent\"
CRON=\"\$AGENT/cron/jobs\"
cmd=\"\${1:-help}\"

case \"\$cmd\" in
  inbox)
    bash \"\$CRON/inbox-sweep.sh\"
    ;;
  briefing)
    bash \"\$CRON/daily-briefing.sh\"
    ;;
  health)
    bash \"\$CRON/vault-health.sh\"
    ;;
  patterns)
    bash \"\$CRON/pattern-check.sh\"
    ;;
  crm-scan)
    bash \"\$CRON/crm-scan.sh\"
    ;;
  context)
    bash \"\$CRON/rebuild-context.sh\"
    ;;
  backup)
    bash \"\$CRON/daily-backup.sh\"
    ;;
  cron)
    bash \"\$AGENT/cron/install-jobs.sh\"
    ;;
  help|*)
    echo \"\"
    echo \"  brain <command>\"
    echo \"\"
    echo \"  inbox      Run inbox sweep\"
    echo \"  briefing   Run daily briefing manually\"
    echo \"  health     Run vault health check\"
    echo \"  patterns   Run pattern detection (carries, loops, stale actions)\"
    echo \"  crm-scan   Run CRM contact scan and briefing update\"
    echo \"  context    Rebuild CONTEXT-PACK.md\"
    echo \"  backup     Commit vault changes to git\"
    echo \"  cron       Install/refresh all scheduled jobs\"
    echo \"\"
    ;;
esac
"
chmod +x "$VAULT_ROOT/06-Agent/brain.sh"

success "06-Agent/cron/ + sessions/"

if [ "$MINIMAL" = false ]; then
# --- 07-Systems ---
mkf "$VAULT_ROOT/07-Systems/README.md" "# 07-Systems

Operational systems — the recurring infrastructure of your life.

| Path | Purpose |
|------|---------|
| CRM/ | People, relationships, follow-ups |
| finances/ | Accounts, monthly snapshots |
| goals/ | Daily, weekly, quarterly, yearly planning |
"

# --- 07-Systems CRM (Relationship Manager) ---
mkd "$VAULT_ROOT/07-Systems/CRM/contacts"
mkd "$VAULT_ROOT/07-Systems/CRM/pipeline"
mkd "$VAULT_ROOT/07-Systems/CRM/interactions"

stamp_template "$TEMPLATES_DIR/crm/_index.md" \
    "$VAULT_ROOT/07-Systems/CRM/_index.md"
cp "$TEMPLATES_DIR/crm/_template-contact.md" \
    "$VAULT_ROOT/07-Systems/CRM/_template-contact.md"
cp "$TEMPLATES_DIR/crm/pipeline/leads.md" \
    "$VAULT_ROOT/07-Systems/CRM/pipeline/leads.md"
cp "$TEMPLATES_DIR/crm/pipeline/active.md" \
    "$VAULT_ROOT/07-Systems/CRM/pipeline/active.md"
cp "$TEMPLATES_DIR/crm/pipeline/closed.md" \
    "$VAULT_ROOT/07-Systems/CRM/pipeline/closed.md"

# --- 07-Systems Finances ---
mkd "$VAULT_ROOT/07-Systems/finances"
mkf "$VAULT_ROOT/07-Systems/finances/_index.md" "# Finances

## Current Snapshot
Net Worth:
Monthly Fixed:
Monthly Variable Budget:

## Accounts → [[accounts]]
## This Month → [[$month]]
"
mkf "$VAULT_ROOT/07-Systems/finances/accounts.md" "# Accounts

| Account | Type | Institution |
|---------|------|-------------|
"
mkf "$VAULT_ROOT/07-Systems/finances/$month.md" "---
tags: [finances, monthly]
month: $month
---

# Finances — $(date +%B\ %Y)

## Income

## Fixed

## Variable

## Notes
"
fi

# --- 07-Systems Goals ---
mkd "$VAULT_ROOT/07-Systems/goals/daily"

if [ "$MINIMAL" = false ]; then
mkd "$VAULT_ROOT/07-Systems/goals/yearly"
mkd "$VAULT_ROOT/07-Systems/goals/quarterly"
mkd "$VAULT_ROOT/07-Systems/goals/weekly"
mkd "$VAULT_ROOT/07-Systems/goals/templates"

mkf "$VAULT_ROOT/07-Systems/goals/_index.md" "# Goals

## Current Focus
${YEAR_THEMES}

## Active Plans
- [[$year]] · [[$year-$quarter]] · [[$week]]
"

mkf "$VAULT_ROOT/07-Systems/goals/yearly/$year.md" "---
tags: [planning, yearly]
year: $year
---

# $year

## Themes
${YEAR_THEMES}

## Misogi
${YEAR_MISOGI}

## Big Rocks
- [ ]
- [ ]
- [ ]

## Roles Check
$(echo "$USER_ROLES_RAW" | while IFS= read -r role; do [ -n "$role" ] && echo "- $role: am I living this?"; done)

## Quarters
[[$year-Q1]] · [[$year-Q2]] · [[$year-Q3]] · [[$year-Q4]]
"

mkf "$VAULT_ROOT/07-Systems/goals/quarterly/$year-$quarter.md" "---
tags: [planning, quarterly]
quarter: $year-$quarter
parent: [[$year]]
---

# $year $quarter

## Focus
What does winning this quarter look like?

## Big Rocks
- [ ]
- [ ]
- [ ]

## Projects
$([ "$ADD_PROJECT" = true ] && echo "- [ ] [[$PROJECT_SLUG]]" || echo "- [ ] [[]]")

## Areas
$(for area in health finances career; do echo "- [[02-Areas/$area]] — "; done)

## Weekly Reviews
(links added as weeks complete)
"

mkf "$VAULT_ROOT/07-Systems/goals/weekly/$week.md" "---
tags: [planning, weekly]
week: $week
parent: [[$year-$quarter]]
---

# $week

## Focus
*One sentence: what does a successful week look like?*

## Big 3
*Strategic priorities — these move the needle on quarterly goals*
- [ ]
- [ ]
- [ ]

## Tasks
*Independent stuff that needs to get done this week (errands, maintenance, life)*
- [ ]

## Daily Logs
$(_e=$(date +%s); _w=$(date +%u); _m=$(( _e - (_w-1)*86400 )); for i in 0 1 2 3 4; do t=$(( _m + i*86400 )); d=$(date -r $t +%Y-%m-%d 2>/dev/null || date -d "@$t" +%Y-%m-%d 2>/dev/null || echo ""); [ -n "$d" ] && echo "[[${d}]]"; done | tr '\n' ' ')

## Quarterly Alignment
*How does this week connect to [[$year-$quarter]] Big Rocks?*


## Friday Review
*(Filled during Friday planning conversation with ${AGENT_NAME})*

**Big 3 status:**

**What went well?**

**What didn't?**

**Carries forward:**

**Independent tasks completed:**
"

# Weekly note template (for auto-creation by daily-briefing.sh)
stamp_template "$TEMPLATES_DIR/goals/weekly-template.md" "$VAULT_ROOT/07-Systems/goals/weekly/_template.md"

fi

# Daily note template (also used by daily-briefing.sh)
stamp_template "$TEMPLATES_DIR/goals/daily-template.md" "$VAULT_ROOT/07-Systems/goals/daily/_template.md"

# Fallback: create inline if template stamp failed
if [ ! -f "$VAULT_ROOT/07-Systems/goals/daily/_template.md" ]; then
mkf "$VAULT_ROOT/07-Systems/goals/daily/_template.md" "---
tags: [daily]
date: YYYY-MM-DD
week: [[YYYY-WNN]]
---

# YYYY-MM-DD

## 🤖 Morning Briefing
*(${AGENT_NAME} writes this — do not edit)*


---

## 🌅 Morning Pages
*(yours)*


---

## 🎯 Intentions
*(set during morning conversation with ${AGENT_NAME} — based on weekly priorities)*
- [ ]
- [ ]
- [ ]

---

## 📝 Log
*(shared)*


---

## 💡 Notes & Ideas
*(yours)*


---

## 🤖 End of Day
*(${AGENT_NAME} writes this — do not edit)*


---

## 🌙 Reflection
*(yours)*

Energy: /10
Grateful for:
"
fi

# Today's daily note
mkf "$VAULT_ROOT/07-Systems/goals/daily/$today.md" "---
tags: [daily]
date: $today
week: [[$week]]
---

# $today

## 🤖 Morning Briefing
*(${AGENT_NAME} writes this — do not edit)*


---

## 🌅 Morning Pages
*(yours — first entry in your new vault 🎉)*


---

## 🎯 Intentions
*(set during morning conversation with ${AGENT_NAME} — based on weekly priorities)*
- [ ]
- [ ]
- [ ]

---

## 📝 Log
*(shared)*
- Vault created! 🧠

---

## 💡 Notes & Ideas
*(yours)*


---

## 🤖 End of Day
*(${AGENT_NAME} writes this — do not edit)*


---

## 🌙 Reflection
*(yours)*

Energy: /10
Grateful for:
"
success "07-Systems/"

# --- 08-CoreSystem ---
if [ "$MINIMAL" = false ]; then
mkf "$VAULT_ROOT/08-CoreSystem/README.md" "# ${USER_NAME}'s Core System

The foundation. Everything in this vault serves what's defined here.
${AGENT_NAME} reads these before making suggestions about time or priorities.

## Files
- [[roles]] — life roles everything must map to
- [[principles]] — how you want to live and work
- [[my-process]] — how you actually work
- [[misogi-and-adventures]] — the big challenge + small ones
- [[relationship-values]] — how you show up with people
- [[home-values]] — what home stands for

## Review
Roles + Principles: quarterly | Misogi: yearly | Process: when something breaks
"
fi

mkf "$VAULT_ROOT/08-CoreSystem/roles.md" "# ${USER_NAME}'s Roles

Last reviewed: $today

Everything in the vault should serve at least one of these.
${AGENT_NAME} checks this before adding new commitments.

## Current Roles
${USER_ROLES_LIST}
## What Each Role Needs
(fill in what it means to be doing each role well)
"

mkf "$VAULT_ROOT/08-CoreSystem/principles.md" "# Principles

How ${USER_NAME} wants to organize life and make decisions.

## On Work
${WORK_PRINCIPLE}

## On Relationships

## On Health

## On Learning

## On Money
"

if [ "$MINIMAL" = false ]; then
mkf "$VAULT_ROOT/08-CoreSystem/my-process.md" "# My Process

How ${USER_NAME} works. How decisions get made. The operating rhythm.

## Daily Rhythm

## Weekly Rhythm

## How I Make Decisions

## What Gives Me Energy

## What Drains Me
"

mkf "$VAULT_ROOT/08-CoreSystem/misogi-and-adventures.md" "# Misogi & Mini Adventures

## $year Misogi
${YEAR_MISOGI}

## Mini Adventures
- [ ]
- [ ]
- [ ]

## Past Misogis
"

mkf "$VAULT_ROOT/08-CoreSystem/relationship-values.md" "# Relationship Values

How ${USER_NAME} wants to show up with people.

## Partner / Family

## Friends

## Colleagues
"

mkf "$VAULT_ROOT/08-CoreSystem/home-values.md" "# Home Values

What home feels like and stands for.

## Atmosphere

## Routines

## Hospitality
"
fi
success "08-CoreSystem/"
[ "$VAULT_TIER" = "1" ] && stamp_template \
    "$TEMPLATES_DIR/learn/08-coresystem.md" \
    "$VAULT_ROOT/08-CoreSystem/LEARN.md"

# --- Git init ---
if [ "$INIT_GIT" = true ]; then
    cd "$VAULT_ROOT"
    git init -q

    mkf "$VAULT_ROOT/.gitignore" "# Logs
06-Agent/cron/logs/

# Sessions (can be large)
06-Agent/sessions/

# macOS
.DS_Store

# Obsidian workspace (optional — remove if you want to sync workspace)
.obsidian/workspace.json
.obsidian/workspace-mobile.json
"

    git add -A
    git commit -q -m "Initial vault — ${USER_NAME}'s Brain"
    success "Git repository initialized"
fi

# --- Activate cron ---
if [ "$ACTIVATE_CRON" = true ]; then
    LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
    mkdir -p "$LAUNCH_AGENTS"
    PLIST_DIR="$VAULT_ROOT/06-Agent/cron/launchd"
    ACTIVATED=0
    FAILED=0
    for plist in "$PLIST_DIR"/*.plist; do
        fname=$(basename "$plist")
        cp "$plist" "$LAUNCH_AGENTS/$fname"
        if launchctl bootstrap gui/$(id -u) "$LAUNCH_AGENTS/$fname" 2>/dev/null; then
            ACTIVATED=$((ACTIVATED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done
    [ "$ACTIVATED" -gt 0 ] && success "Cron jobs activated ($ACTIVATED jobs)"
    [ "$FAILED" -gt 0 ] && warn "$FAILED job(s) failed to load — run 'brain cron' after setup to retry"
fi

# --- Symlink brain CLI ---
echo ""
echo -ne "  ${BOLD}Symlink 'brain' to /usr/local/bin?${NC} ${DIM}Type 'brain inbox' from anywhere [y/N]${NC}: "
read -r BRAIN_LINK
if [[ "$BRAIN_LINK" =~ ^[Yy]$ ]]; then
    if ln -sf "$VAULT_ROOT/06-Agent/brain.sh" /usr/local/bin/brain 2>/dev/null; then
        success "'brain' command available — try: brain help"
    else
        warn "Could not write to /usr/local/bin — try:"
        warn "  sudo ln -sf $VAULT_ROOT/06-Agent/brain.sh /usr/local/bin/brain"
    fi
fi

# =============================================================================
# DONE
# =============================================================================

echo ""
echo ""
divider
echo ""
echo -e "  ${BOLD}${GREEN}🧠 ${USER_NAME}'s vault is ready.${NC}"
echo ""
echo -e "  ${BOLD}Location:${NC} $VAULT_ROOT"
echo ""

TOTAL=$(find "$VAULT_ROOT" -type f | wc -l | tr -d ' ')
echo -e "  ${DIM}$TOTAL files created${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo ""
echo -e "  ${CYAN}1.${NC} Open ${BOLD}$VAULT_ROOT${NC} in Obsidian as a new vault"
echo -e "     Settings → Daily Notes → Template:"
echo -e "     ${DIM}07-Systems/goals/daily/_template.md${NC}"
echo -e "     New file location: ${DIM}07-Systems/goals/daily/${NC}"
echo ""
echo -e "  ${CYAN}2.${NC} Open vault in ${BOLD}Claude Cowork${NC} or ${BOLD}Claude Code${NC}"
echo -e "     It will read CLAUDE.md automatically"
echo -e "     ${AGENT_NAME} will run the BOOTSTRAP ritual on first session"
echo ""
if [ "$ACTIVATE_CRON" = false ]; then
    echo -e "  ${CYAN}3.${NC} When ready for scheduled jobs:"
    echo -e "     ${DIM}bash $VAULT_ROOT/06-Agent/cron/install-jobs.sh${NC}"
    echo ""
fi
if [ "$INIT_GIT" = true ]; then
    echo -e "  ${CYAN}4.${NC} Add a private remote to back up your vault:"
    echo -e "     ${DIM}cd $VAULT_ROOT && git remote add origin <your-private-repo>${NC}"
    echo ""
fi
echo -e "  ${DIM}Your daily note for today is ready:${NC}"
echo -e "  ${DIM}07-Systems/goals/daily/$today.md${NC}"
echo ""
divider
echo ""

# Export vault root for start.sh to read
echo "$VAULT_ROOT" > /tmp/brain_vault_root
