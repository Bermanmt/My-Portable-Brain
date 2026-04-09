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
#   bash start.sh --quiet          → suppress UI (for skill/automation use)
#   bash start.sh --config f.json  → non-interactive mode with JSON config
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
SIMPLE_MODE=false
QUIET_MODE=false
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true ;;
        --vault)     PRESET_VAULT="$2"; shift ;;
        --tier)      PRESET_TIER="$2"; shift ;;
        --minimal)   PRESET_TIER="3" ;;
        --simple)    SIMPLE_MODE=true ;;
        --quiet)     QUIET_MODE=true ;;
        --config)    CONFIG_FILE="$2"; shift ;;
    esac
    shift
done

# Simple mode: auto-select Tier 2, pass --simple to onboard.sh
if [ "$SIMPLE_MODE" = true ]; then
    PRESET_TIER="2"
fi

# --- Helpers ---
divider() { echo -e "${DIM}$(printf '─%.0s' {1..60})${NC}"; }
section() { echo ""; echo -e "${BOLD}${BLUE}$1${NC}"; divider; }
success() { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()    { echo -e "${YELLOW}  ⚠ $1${NC}"; }
info()    { echo -e "${CYAN}  → $1${NC}"; }

# =============================================================================
# WELCOME (skip in quiet mode)
# =============================================================================

if [ "$QUIET_MODE" = false ]; then
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
    echo -e "  ${DIM}v0.3 — github.com/Bermanmt/My-Portable-Brain${NC}"
    echo ""
    divider
    echo ""
fi

# =============================================================================
# DEPENDENCY CHECK
# =============================================================================

MISSING=false

check_dep() {
    local cmd="$1"
    local label="$2"
    local required="$3"
    if command -v "$cmd" &>/dev/null; then
        [ "$QUIET_MODE" = false ] && success "$label"
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}  ✗ $label — required, not found${NC}"
            MISSING=true
        else
            [ "$QUIET_MODE" = false ] && warn "$label — optional (some features unavailable)"
        fi
    fi
}

[ "$QUIET_MODE" = false ] && section "Checking dependencies" && echo ""

check_dep "bash"    "bash 3.2+"    "required"
check_dep "git"     "git"          "optional"
check_dep "claude"  "Claude CLI"   "optional"

if [ "$MISSING" = true ]; then
    echo -e "${RED}  Required dependencies missing. Please install and re-run.${NC}"
    exit 1
fi

if [ "$QUIET_MODE" = false ] && [ "$SIMPLE_MODE" != true ] && ! command -v "claude" &>/dev/null; then
    echo ""
    echo -e "  ${DIM}Claude CLI not found. Vault will be created but automated jobs${NC}"
    echo -e "  ${DIM}won't run. Install later: https://claude.ai/code${NC}"
    echo ""
fi

# =============================================================================
# TIER SELECTION
# =============================================================================

if [ "$SIMPLE_MODE" = true ] || [ "$QUIET_MODE" = true ]; then
    TIER="${PRESET_TIER:-2}"
else
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
    echo -e "  ${BOLD}Tier 3 — Minimal${NC}"
    echo -e "  ${DIM}Core vault only. Essential files + one cron job.${NC}"
    echo -e "  ${DIM}Best if you want to try the system first.${NC}"
    echo ""

    if [ -n "$PRESET_TIER" ]; then
        TIER="$PRESET_TIER"
        info "Using tier $TIER (from --tier flag)"
    else
        echo -ne "  ${BOLD}Which tier?${NC} ${DIM}[1/2/3, default: 2]${NC}: "
        read -r input
        TIER="${input:-2}"
    fi

    if [ "$TIER" != "1" ] && [ "$TIER" != "2" ] && [ "$TIER" != "3" ]; then
        warn "Invalid selection — defaulting to Tier 2."
        TIER="2"
    fi

    echo ""
    success "Tier $TIER — $([ "$TIER" = "1" ] && echo 'Lean' || [ "$TIER" = "2" ] && echo 'Full' || echo 'Minimal')"
fi

# =============================================================================
# RUN ONBOARDING
# =============================================================================

[ "$QUIET_MODE" = false ] && section "Personalizing your vault" && echo ""

ONBOARD_FLAGS=""
[ "$DRY_RUN" = true ]       && ONBOARD_FLAGS="$ONBOARD_FLAGS --dry-run"
[ -n "$PRESET_VAULT" ]      && ONBOARD_FLAGS="$ONBOARD_FLAGS --vault $PRESET_VAULT"
[ "$SIMPLE_MODE" = true ]   && ONBOARD_FLAGS="$ONBOARD_FLAGS --simple"
[ -n "$CONFIG_FILE" ]       && ONBOARD_FLAGS="$ONBOARD_FLAGS --config $CONFIG_FILE"

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
# POST-SETUP: Delete BOOTSTRAP.md (prevents re-triggering onboarding)
# =============================================================================

if [ -f "$SCRIPT_DIR/BOOTSTRAP.md" ]; then
    rm -f "$SCRIPT_DIR/BOOTSTRAP.md"
fi

# Also delete from vault root if different from script dir
if [ -f "$VAULT_ROOT/BOOTSTRAP.md" ]; then
    rm -f "$VAULT_ROOT/BOOTSTRAP.md"
fi

# =============================================================================
# POST-SETUP: Clean up repo files (in-place installation)
# =============================================================================
# When --vault . is used, the vault is created in the same folder as the repo.
# Clean up installer/repo files that are no longer needed.

if [ "$(cd "$VAULT_ROOT" && pwd)" = "$(cd "$SCRIPT_DIR" && pwd)" ] && [ -d "$VAULT_ROOT/06-Agent" ]; then
    [ "$QUIET_MODE" = false ] && echo "" && info "Cleaning up installer files..."

    # Remove installer scripts
    rm -f "$SCRIPT_DIR/start.sh" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/install.sh" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/Install Brain.command" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/Install Windows Brain.bat" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/Install Brain.ps1" 2>/dev/null || true

    # Remove repo docs and artifacts
    rm -f "$SCRIPT_DIR/onboard-wizard.html" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/CHANGELOG.md" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/CONTRIBUTING.md" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/NEXT-STEPS.md" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/README.md" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/.DS_Store" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/.gitignore" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/brain-config.json" 2>/dev/null || true

    # Remove repo directories
    rm -rf "$SCRIPT_DIR/lib" 2>/dev/null || true
    rm -rf "$SCRIPT_DIR/templates" 2>/dev/null || true
    rm -rf "$SCRIPT_DIR/docs" 2>/dev/null || true
    rm -rf "$SCRIPT_DIR/site" 2>/dev/null || true

    # Remove repo git history (vault gets its own git init)
    rm -rf "$SCRIPT_DIR/.git" 2>/dev/null || true

    # Keep: LICENSE, .claude/skills/setup-brain/

    [ "$QUIET_MODE" = false ] && success "Installer files removed. This folder is now your vault."
fi

# =============================================================================
# FIRST MISSION (skip in quiet mode)
# =============================================================================

if [ "$QUIET_MODE" = false ]; then
    echo ""
    divider
    echo ""
    echo -e "  ${BOLD}${GREEN}🧠 Your vault is ready.${NC}"
    echo ""
    echo -e "  ${BOLD}Location:${NC}  $VAULT_ROOT"
    if [ "$SIMPLE_MODE" != true ]; then
        echo -e "  ${BOLD}Tier:${NC}      $TIER — $([ "$TIER" = "1" ] && echo 'Lean' || [ "$TIER" = "2" ] && echo 'Full' || echo 'Minimal')"
    fi
    echo ""
    divider
    echo ""
    echo -e "  ${BOLD}What to do next:${NC}"
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
    if [ "$SIMPLE_MODE" != true ] && command -v "claude" &>/dev/null; then
        echo -e "  ${CYAN}Step 4${NC}  (Optional) Activate scheduled briefings:"
        echo -e "          ${DIM}bash $VAULT_ROOT/06-Agent/cron/install-jobs.sh${NC}"
        echo ""
    fi
    divider
    echo ""
    echo -e "  ${DIM}Why this system works: docs/philosophy.md${NC}"
    echo -e "  ${DIM}How to connect Claude:  docs/agent-setup.md${NC}"
    echo ""
fi
