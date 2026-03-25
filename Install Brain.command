#!/bin/bash

# =============================================================================
# Portable Brain — macOS Installer
# =============================================================================
# Double-click this file to set up your Brain vault.
#
# If macOS blocks this file:
#   System Settings → Privacy & Security → click "Open Anyway"
# =============================================================================

# Move to the directory where this script lives (the repo folder)
cd "$(dirname "$0")"

# Make all scripts executable (zip downloads strip permissions)
chmod +x start.sh 2>/dev/null
chmod +x lib/*.sh 2>/dev/null
chmod +x templates/cron/jobs/*.sh 2>/dev/null

# Run the setup in simple mode (fewer questions, smart defaults)
clear
bash start.sh --simple

# Keep Terminal open so user can read the output
echo ""
echo "  You can close this window now."
echo ""
read -n 1 -s -r -p "  Press any key to close..."
