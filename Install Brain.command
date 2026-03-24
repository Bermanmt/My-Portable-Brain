#!/bin/bash

# =============================================================================
# Portable Brain — macOS Installer
# =============================================================================
# Double-click this file to set up your Brain vault.
# It opens Terminal and walks you through the setup.
#
# If macOS blocks this file:
#   Right-click → Open → click "Open" in the dialog
#   Or run in Terminal: bash "Install Brain.command"
# =============================================================================

# Move to the directory where this script lives (the repo folder)
cd "$(dirname "$0")"

# Make all scripts executable (zip downloads strip permissions)
chmod +x start.sh 2>/dev/null
chmod +x lib/*.sh 2>/dev/null
chmod +x templates/cron/jobs/*.sh 2>/dev/null

# Clear screen and run the setup
clear
bash start.sh

# Keep Terminal open after completion so user can read the output
echo ""
echo "  You can close this window now."
echo ""
read -n 1 -s -r -p "  Press any key to close..."
