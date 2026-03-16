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

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --vault) NEXT_IS_VAULT=true ;;
        *) [ "$NEXT_IS_VAULT" = true ] && PRESET_VAULT="$arg" && NEXT_IS_VAULT=false ;;
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

# =============================================================================
# WELCOME
# =============================================================================

clear
echo ""
echo -e "${BOLD}${MAGENTA}"
cat << 'EOF'
  ██████╗ ██████╗  █████╗ ██╗███╗   ██╗
  ██╔══██╗██╔══██╗██╔══██╗██║████╗  ██║
  ██████╔╝██████╔╝███████║██║██╔██╗ ██║
  ██╔══██╗██╔══██╗██╔══██║██║██║╚██╗██║
  ██████╔╝██║  ██║██║  ██║██║██║ ╚████║
  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

  V A U L T   O N B O A R D I N G
EOF
echo -e "${NC}"
echo -e "${DIM}  Personal knowledge system + AI agent setup${NC}"
echo -e "${DIM}  Takes about 5 minutes. Your answers shape the vault.${NC}"
echo ""
divider
echo ""
echo -e "  This wizard will:"
echo -e "  ${GREEN}✓${NC} Ask you ~15 questions about yourself and how you work"
echo -e "  ${GREEN}✓${NC} Generate a full vault with your answers baked in"
echo -e "  ${GREEN}✓${NC} Create your agent's personality and memory files"
echo -e "  ${GREEN}✓${NC} Set up your planning structure for today, this week, this quarter"
echo -e "  ${GREEN}✓${NC} Wire up CRM, finances, and your core system"
echo ""
if [ "$DRY_RUN" = true ]; then
    warn "DRY RUN mode — no files will be created"
    echo ""
fi
echo -ne "  Press ${BOLD}Enter${NC} to begin, or ${BOLD}Ctrl+C${NC} to exit: "
read -r

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
warn "Requires the 'claude' CLI to be installed and authenticated."
hint "You can activate these later with: bash 06-Agent/cron/install-jobs.sh"
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
mkf "$VAULT_ROOT/00-Inbox/quick-notes.md" "# Quick Notes

Capture anything here. One line per idea. Sort during weekly review.

---
"
mkf "$VAULT_ROOT/00-Inbox/links.md" "# Links to Process

| Date | URL | Context | → Destination |
|------|-----|---------|---------------|
"
[ "${VAULT_TIER:-2}" = "1" ] && stamp_template \
    "$TEMPLATES_DIR/learn/00-inbox.md" \
    "$VAULT_ROOT/00-Inbox/LEARN.md"
success "00-Inbox/"

# --- 01-Projects ---
mkd "$VAULT_ROOT/01-Projects"
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
    success "01-Projects/$PROJECT_SLUG/"
else
    success "01-Projects/"
fi
[ "${VAULT_TIER:-2}" = "1" ] && stamp_template \
    "$TEMPLATES_DIR/learn/01-projects.md" \
    "$VAULT_ROOT/01-Projects/LEARN.md"

# --- 02-Areas ---
for area in health finances career home; do
    mkd "$VAULT_ROOT/02-Areas/$area"
    area_title="$(echo "$area" | tr '[:lower:]' '[:upper:]' | cut -c1)$(echo "$area" | cut -c2-)"
    mkf "$VAULT_ROOT/02-Areas/$area/index.md" "---
tags: [area]
area: $area
---

# $area_title

## Standard
What does \"good enough\" look like here?

## Active Projects
- [[01-Projects/]]

## Goals
- [[$year-$quarter]]
"
done
success "02-Areas/"
[ "${VAULT_TIER:-2}" = "1" ] && stamp_template \
    "$TEMPLATES_DIR/learn/02-areas.md" \
    "$VAULT_ROOT/02-Areas/LEARN.md"

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
[ "${VAULT_TIER:-2}" = "1" ] && stamp_template \
    "$TEMPLATES_DIR/learn/03-resources.md" \
    "$VAULT_ROOT/03-Resources/LEARN.md"

# --- 04-Archive ---
mkd "$VAULT_ROOT/04-Archive/projects"
mkd "$VAULT_ROOT/04-Archive/areas"
mkf "$VAULT_ROOT/04-Archive/README.md" "# Archive

Never delete — archive instead.
Agent never moves files here without ${USER_NAME}'s confirmation.
"
success "04-Archive/"

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
mkd "$VAULT_ROOT/06-Agent/workspace/memory"
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
success "06-Agent/workspace/"
[ "${VAULT_TIER:-2}" = "1" ] && stamp_template \
    "$TEMPLATES_DIR/learn/06-agent.md" \
    "$VAULT_ROOT/06-Agent/LEARN.md"

# --- Subagents ---
mkd "$VAULT_ROOT/06-Agent/subagents/inbox-processor"
mkf "$VAULT_ROOT/06-Agent/subagents/inbox-processor/AGENT.md" "# Inbox Processor

## Purpose
Process 00-Inbox and suggest filing destinations for ${USER_NAME}.

## Access
- Read/write: 00-Inbox/
- Read: 05-Meta/conventions.md, 01-Projects/, 02-Areas/, 03-Resources/

## Process
1. Read all files in 00-Inbox/
2. Suggest destination per item based on conventions.md
3. Present suggestions before moving anything
4. Mark items needing ${USER_NAME}'s decision as [NEEDS DECISION]

## Output
List of items, destinations, and decisions needed.
"

mkd "$VAULT_ROOT/06-Agent/subagents/crm-manager"
mkf "$VAULT_ROOT/06-Agent/subagents/crm-manager/AGENT.md" "# CRM Manager

## Purpose
Manage contacts, log interactions, track follow-ups for ${USER_NAME}.

## Access
- Read/write: 07-Systems/CRM/ only
- Read: 05-Meta/conventions.md

## Cannot
- Contact anyone
- Modify files outside 07-Systems/CRM/
- Make decisions about relationships

## Output
Summary of changes made and backlinks created.
"

mkd "$VAULT_ROOT/06-Agent/subagents/researcher"
mkf "$VAULT_ROOT/06-Agent/subagents/researcher/AGENT.md" "# Researcher

## Purpose
Research topics and file findings to 03-Resources.

## Access
- Read/write: 03-Resources/
- Read: 00-Inbox/, 05-Meta/conventions.md

## Process
Follow workspace/skills/research/SKILL.md

## Output
Path of file created + backlinks added.
"

mkd "$VAULT_ROOT/06-Agent/subagents/writer"
mkf "$VAULT_ROOT/06-Agent/subagents/writer/AGENT.md" "# Writer

## Purpose
Draft documents, emails, summaries on request.

## Access
- Read: files passed by orchestrator
- Write: only to path explicitly specified

## Style
Follow workspace/skills/writing/SKILL.md
Always present draft before writing to file.
"
success "06-Agent/subagents/"

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

# --- Cron ---
mkd "$VAULT_ROOT/06-Agent/cron/launchd"
mkd "$VAULT_ROOT/06-Agent/cron/jobs"
mkd "$VAULT_ROOT/06-Agent/cron/prompts"
mkd "$VAULT_ROOT/06-Agent/cron/logs"

mkf "$VAULT_ROOT/06-Agent/cron/README.md" "# Scheduled Jobs

| Job | Schedule | Output |
|-----|----------|--------|
| daily-briefing | ${CRON_BRIEFING:-07:30} daily | Morning section in today's daily note |
| daily-closing | ${CRON_CLOSING:-18:00} weekdays | End-of-day to agent memory |
| inbox-sweep | 10:00 weekdays | Inbox-processor subagent |
| weekly-review | Friday 17:00 | Draft weekly review |
| quarterly-checkin | 1st of quarter | Quarterly planning prompt |

## Activate
  bash $VAULT_ROOT/06-Agent/cron/install-jobs.sh

## Logs
Each job appends to logs/YYYY-MM-DD-jobname.log
"

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
mkf "$VAULT_ROOT/06-Agent/cron/jobs/daily-briefing.sh" "#!/bin/bash
VAULT=\"$VAULT_ROOT\"
AGENT=\"\$VAULT/06-Agent\"
DATE=\$(date +%Y-%m-%d)
DAILY=\"\$VAULT/07-Systems/goals/daily/\$DATE.md\"
TEMPLATE=\"\$VAULT/07-Systems/goals/daily/_template.md\"
LOG=\"\$AGENT/cron/logs/\$DATE-daily-briefing.log\"
source \"\$AGENT/config/llm.conf\"

[ ! -f \"\$DAILY\" ] && cp \"\$TEMPLATE\" \"\$DAILY\" && sed \"s/YYYY-MM-DD/\$DATE/g\" \"\$DAILY\" > \"\$DAILY.tmp\" && mv \"\$DAILY.tmp\" \"\$DAILY\"

SYSTEM=\$(cat \"\$AGENT/workspace/AGENTS.md\"; echo; cat \"\$AGENT/workspace/SOUL.md\"; echo; cat \"\$AGENT/workspace/USER.md\")
TASK=\$(cat \"\$AGENT/cron/prompts/daily-briefing.md\")

echo \"[\$(date)] daily-briefing start\" >> \"\$LOG\"
run_llm \"\$SYSTEM\" \"\$TASK\" >> \"\$LOG\" 2>&1
echo \"[\$(date)] done\" >> \"\$LOG\"
"

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

chmod +x "$VAULT_ROOT/06-Agent/cron/jobs/daily-backup.sh" "$VAULT_ROOT/06-Agent/cron/jobs/weekly-tag.sh"

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
success "06-Agent/cron/ + sessions/"

# --- 07-Systems CRM ---
mkd "$VAULT_ROOT/07-Systems/CRM/contacts"
mkd "$VAULT_ROOT/07-Systems/CRM/pipeline"
mkd "$VAULT_ROOT/07-Systems/CRM/interactions"

mkf "$VAULT_ROOT/07-Systems/CRM/_index.md" "# CRM

## Pipeline
- [[pipeline/leads]] · [[pipeline/active]] · [[pipeline/closed]]

## Follow-ups Due
(${AGENT_NAME} updates this during morning briefing)
"
mkf "$VAULT_ROOT/07-Systems/CRM/_template-contact.md" "---
tags: [crm, contact]
status: active
last-contact:
next-action:
next-action-date:
---

# Full Name

**Role:**
**Company:** [[]]
**Met via:** [[]]

## Context

## Interaction Log

## Open Loops
- [ ]
"
mkf "$VAULT_ROOT/07-Systems/CRM/pipeline/leads.md" "# Leads

| Contact | Source | Added | Next Action |
|---------|--------|-------|-------------|
"
mkf "$VAULT_ROOT/07-Systems/CRM/pipeline/active.md" "# Active

| Contact | Last Contact | Next Action | Due |
|---------|-------------|-------------|-----|
"
mkf "$VAULT_ROOT/07-Systems/CRM/pipeline/closed.md" "# Closed

| Contact | Outcome | Date |
|---------|---------|------|
"

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

# --- 07-Systems Goals ---
mkd "$VAULT_ROOT/07-Systems/goals/yearly"
mkd "$VAULT_ROOT/07-Systems/goals/quarterly"
mkd "$VAULT_ROOT/07-Systems/goals/weekly"
mkd "$VAULT_ROOT/07-Systems/goals/daily"
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

## Big 3
- [ ]
- [ ]
- [ ]

## Daily Logs
$(_e=$(date +%s); _w=$(date +%u); _m=$(( _e - (_w-1)*86400 )); for i in 0 1 2 3 4; do t=$(( _m + i*86400 )); d=$(date -r $t +%Y-%m-%d 2>/dev/null || date -d "@$t" +%Y-%m-%d 2>/dev/null || echo ""); [ -n "$d" ] && echo "[[${d}]]"; done | tr '\n' ' ')

## Friday Review
**What went well?**

**What didn't?**

**Carries forward:**
"

# Daily note template
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
*(yours)*
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
*(yours)*
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
success "08-CoreSystem/"
[ "${VAULT_TIER:-2}" = "1" ] && stamp_template \
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
    PLIST_DIR="$VAULT_ROOT/06-Agent/cron/launchd"
    ACTIVATED=0
    for plist in "$PLIST_DIR"/*.plist; do
        fname=$(basename "$plist")
        cp "$plist" "$LAUNCH_AGENTS/$fname"
        launchctl bootstrap gui/$(id -u) "$LAUNCH_AGENTS/$fname" 2>/dev/null && ACTIVATED=$((ACTIVATED + 1)) || true
    done
    success "Cron jobs activated ($ACTIVATED jobs)"
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
