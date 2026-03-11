#!/bin/bash

# =============================================================================
# My Portable Brain — Start
# =============================================================================
# The only file you need to run. Everything else is called from here.
#
# Usage:
#   bash start.sh                  → interactive setup
#   bash start.sh --dry-run        → preview without creating files
#   bash start.sh --tier 1         → skip tier selection
#   bash start.sh --vault ~/Brain  → skip path question
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Parse flags ---
DRY_RUN=false
PRESET_VAULT=""
PRESET_TIER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true ;;
        --vault)     PRESET_VAULT="$2"; shift ;;
        --tier)      PRESET_TIER="$2"; shift ;;
    esac
    shift
done

# --- Helpers ---
divider() { echo -e "${DIM}$(printf '─%.0s' {1..60})${NC}"; }
section() { echo ""; echo -e "${BOLD}${BLUE}$1${NC}"; divider; }
success() { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()    { echo -e "${YELLOW}  ⚠ $1${NC}"; }
info()    { echo -e "${CYAN}  → $1${NC}"; }

# =============================================================================
# WELCOME
# =============================================================================

clear
echo ""
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  ╔══════════════════════════════════════════╗
  ║         🧠  My Portable Brain            ║
  ║    A knowledge system that learns you    ║
  ╚══════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo -e "  ${DIM}v0.1 — github.com/yourusername/portable-brain${NC}"
echo ""
divider
echo ""

# =============================================================================
# DEPENDENCY CHECK
# =============================================================================

section "Checking dependencies"
echo ""

MISSING=false

check_dep() {
    local cmd="$1"
    local label="$2"
    local required="$3"
    if command -v "$cmd" &>/dev/null; then
        success "$label"
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}  ✗ $label — required, not found${NC}"
            MISSING=true
        else
            warn "$label — optional (some features unavailable)"
        fi
    fi
}

check_dep "bash"    "bash 3.2+"    "required"
check_dep "git"     "git"          "optional"
check_dep "claude"  "Claude CLI"   "optional"

echo ""
if [ "$MISSING" = true ]; then
    echo -e "${RED}  Required dependencies missing. Please install and re-run.${NC}"
    echo ""
    exit 1
fi

if ! command -v "claude" &>/dev/null; then
    echo -e "  ${DIM}Claude CLI not found. Vault will be created but automated jobs${NC}"
    echo -e "  ${DIM}won't run. Install later: https://claude.ai/code${NC}"
    echo ""
fi

# =============================================================================
# TIER SELECTION
# =============================================================================

section "Choose your setup"
echo ""
echo -e "  ${BOLD}Tier 1 — Lean${NC}"
echo -e "  ${DIM}Minimal structure. Every folder explains itself.${NC}"
echo -e "  ${DIM}Best if you're new to PARA or want to start simple.${NC}"
echo ""
echo -e "  ${BOLD}Tier 2 — Full${NC}"
echo -e "  ${DIM}Complete vault with all systems pre-built.${NC}"
echo -e "  ${DIM}Best if you're ready to use everything from day one.${NC}"
echo ""

if [ -n "$PRESET_TIER" ]; then
    TIER="$PRESET_TIER"
    info "Using tier $TIER (from --tier flag)"
else
    echo -ne "  ${BOLD}Which tier?${NC} ${DIM}[1/2, default: 2]${NC}: "
    read -r input
    TIER="${input:-2}"
fi

if [ "$TIER" != "1" ] && [ "$TIER" != "2" ]; then
    warn "Invalid selection — defaulting to Tier 2."
    TIER="2"
fi

echo ""
success "Tier $TIER — $([ "$TIER" = "1" ] && echo 'Lean' || echo 'Full')"

# =============================================================================
# RUN ONBOARDING
# =============================================================================

section "Personalizing your vault"
echo ""

ONBOARD_FLAGS=""
[ "$DRY_RUN" = true ]    && ONBOARD_FLAGS="$ONBOARD_FLAGS --dry-run"
[ -n "$PRESET_VAULT" ]   && ONBOARD_FLAGS="$ONBOARD_FLAGS --vault $PRESET_VAULT"

# Export tier so onboard.sh and build scripts can read it
export BRAIN_TIER="$TIER"

if [ ! -f "$SCRIPT_DIR/lib/onboard.sh" ]; then
    echo -e "${RED}  Error: lib/onboard.sh not found${NC}"
    echo -e "  Run start.sh from the portable-brain directory."
    exit 1
fi

bash "$SCRIPT_DIR/lib/onboard.sh" $ONBOARD_FLAGS

[ "$DRY_RUN" = true ] && exit 0

# Read vault root written by onboard.sh
if [ -f "/tmp/brain_vault_root" ]; then
    VAULT_ROOT=$(cat /tmp/brain_vault_root)
fi

if [ -z "$VAULT_ROOT" ]; then
    echo -e "${RED}  Could not determine vault location. Setup may have failed.${NC}"
    exit 1
fi

# =============================================================================
# FIRST MISSION
# =============================================================================

echo ""
divider
echo ""
echo -e "  ${BOLD}${GREEN}🧠 Your vault is ready.${NC}"
echo ""
echo -e "  ${BOLD}Location:${NC}  $VAULT_ROOT"
echo -e "  ${BOLD}Tier:${NC}      $TIER — $([ "$TIER" = "1" ] && echo 'Lean' || echo 'Full')"
echo ""
divider
echo ""
echo -e "  ${BOLD}Do this right now — before closing this window:${NC}"
echo ""
echo -e "  ${CYAN}Step 1${NC}  Open ${BOLD}$VAULT_ROOT${NC} in Obsidian"
echo -e "          File → Open Vault → select that folder"
echo ""
echo -e "  ${CYAN}Step 2${NC}  Drop 3 things on your mind into:"
echo -e "          ${DIM}00-Inbox/quick-notes.md${NC}"
echo -e "          ${DIM}Don't organize them. Just write.${NC}"
echo ""
echo -e "  ${CYAN}Step 3${NC}  Open the vault in Claude Code or Claude Cowork"
echo -e "          It reads CLAUDE.md automatically."
echo -e "          Your agent will introduce itself and guide you from there."
echo ""
if command -v "claude" &>/dev/null; then
    echo -e "  ${CYAN}Step 4${NC}  (Optional) Activate scheduled briefings:"
    echo -e "          ${DIM}bash $VAULT_ROOT/06-Agent/cron/install-jobs.sh${NC}"
    echo ""
fi
divider
echo ""
echo -e "  ${DIM}Why this system works: docs/philosophy.md${NC}"
echo -e "  ${DIM}How to connect Claude:  docs/agent-setup.md${NC}"
echo ""
