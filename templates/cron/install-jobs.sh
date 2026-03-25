#!/bin/bash
# =============================================================================
# install-jobs.sh — Install launchd jobs for the Brain vault (macOS)
# =============================================================================
# Resolves the vault's absolute path automatically, replaces {{VAULT_PATH}}
# in plist templates, copies to ~/Library/LaunchAgents, and loads them.
#
# Usage: bash install-jobs.sh
#   Run from anywhere — the script finds the vault from its own location.
#
# To uninstall: bash install-jobs.sh --uninstall
# =============================================================================

set -e

# --- Resolve vault path (3 levels up from this script) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLIST_DIR="$SCRIPT_DIR/launchd"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

# --- Validate ---
if [ ! -d "$PLIST_DIR" ]; then
    echo "ERROR: No launchd/ directory found at $PLIST_DIR"
    exit 1
fi

if [ ! -d "$VAULT/06-Agent" ]; then
    echo "ERROR: This doesn't look like a Brain vault: $VAULT"
    exit 1
fi

# --- Ensure logs directory exists ---
mkdir -p "$VAULT/06-Agent/cron/logs"

# --- Uninstall mode ---
if [ "$1" = "--uninstall" ]; then
    echo "Uninstalling Brain vault jobs..."
    for plist in "$PLIST_DIR"/*.plist; do
        [ -f "$plist" ] || continue
        filename=$(basename "$plist")
        label=${filename%.plist}
        launchctl unload "$LAUNCH_AGENTS/$filename" 2>/dev/null || true
        rm -f "$LAUNCH_AGENTS/$filename"
        echo "  ✗ $label removed"
    done
    echo "Done. All Brain jobs uninstalled."
    exit 0
fi

# --- Install ---
echo "Installing Brain vault jobs..."
echo "  Vault path: $VAULT"
echo ""

for plist in "$PLIST_DIR"/*.plist; do
    [ -f "$plist" ] || continue
    filename=$(basename "$plist")
    label=${filename%.plist}

    # Unload existing job if present
    launchctl unload "$LAUNCH_AGENTS/$filename" 2>/dev/null || true

    # Copy plist and replace {{VAULT_PATH}} with actual absolute path
    sed "s|{{VAULT_PATH}}|${VAULT}|g" "$plist" > "$LAUNCH_AGENTS/$filename"

    # Load the job
    launchctl load "$LAUNCH_AGENTS/$filename"
    echo "  ✓ $label"
done

echo ""
echo "Done. Jobs installed with vault path: $VAULT"
echo "Verify with: launchctl list | grep brain"
