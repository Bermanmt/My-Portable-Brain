#!/bin/bash

# =============================================================================
# Portable Brain — Linux / macOS Installer
# =============================================================================
# Run this script to set up your Brain vault.
#
# Usage:
#   bash install.sh            → guided setup (simple mode)
#   bash install.sh --full     → full setup with all options
#
# Or if you downloaded the zip:
#   chmod +x install.sh && ./install.sh
# =============================================================================

cd "$(dirname "$0")"

# Make all scripts executable (zip downloads may strip permissions)
chmod +x start.sh 2>/dev/null
chmod +x lib/*.sh 2>/dev/null
chmod +x templates/cron/jobs/*.sh 2>/dev/null

# Check for --full flag
MODE="--simple"
for arg in "$@"; do
    case "$arg" in
        --full) MODE="" ;;
    esac
done

clear
bash start.sh $MODE
