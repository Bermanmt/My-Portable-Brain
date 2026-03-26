# =============================================================================
# Portable Brain — Windows Installer
# =============================================================================
# Right-click this file → "Run with PowerShell" to set up your Brain vault.
#
# This script finds or installs Git Bash, then runs the setup through it.
# Your vault will be created at ~/Brain (inside your user folder).
#
# If Windows blocks this script:
#   Open PowerShell as Administrator and run:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
# =============================================================================

$ErrorActionPreference = "Stop"

# --- Colors ---
function Write-Accent { param($msg) Write-Host $msg -ForegroundColor Magenta }
function Write-Ok     { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn   { param($msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Err    { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red }

Clear-Host
Write-Host ""
Write-Accent "  🧠 Portable Brain — Windows Setup"
Write-Host ""

# --- Find Git Bash ---
$gitBashPaths = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)

$bashExe = $null
foreach ($path in $gitBashPaths) {
    if (Test-Path $path) {
        $bashExe = $path
        break
    }
}

# Also check if bash is on PATH (WSL or Git Bash)
if (-not $bashExe) {
    $bashOnPath = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashOnPath) {
        $bashExe = $bashOnPath.Source
    }
}

if (-not $bashExe) {
    Write-Host ""
    Write-Err "Bash not found on this computer."
    Write-Host ""
    Write-Host "  Portable Brain needs bash to run. You have two options:" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Option 1 — Install Git for Windows (recommended):" -ForegroundColor White
    Write-Host "    https://git-scm.com/download/win" -ForegroundColor Cyan
    Write-Host "    (includes Git Bash — that's all we need)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Option 2 — Enable WSL (Windows Subsystem for Linux):" -ForegroundColor White
    Write-Host "    Open PowerShell as Admin and run: wsl --install" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  After installing either one, run this script again." -ForegroundColor Gray
    Write-Host ""

    # Offer to open the Git download page
    $answer = Read-Host "  Open the Git download page now? [Y/n]"
    if ($answer -ne "n" -and $answer -ne "N") {
        Start-Process "https://git-scm.com/download/win"
    }

    Write-Host ""
    Read-Host "  Press Enter to close"
    exit 1
}

Write-Ok "Found bash: $bashExe"

# --- Navigate to script directory ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# --- Run the setup through bash ---
Write-Host ""
Write-Host "  Starting setup..." -ForegroundColor Gray
Write-Host ""

# Convert Windows path to unix path for bash
$unixDir = $scriptDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
# Lowercase drive letter for Git Bash
$unixDir = '/' + $unixDir.Substring(1, 1).ToLower() + $unixDir.Substring(2)

& $bashExe -c "cd '$unixDir' && chmod +x start.sh lib/*.sh templates/cron/jobs/*.sh 2>/dev/null; bash start.sh --simple"

# --- Done ---
Write-Host ""
Write-Host "  You can close this window now." -ForegroundColor Gray
Write-Host ""
Read-Host "  Press Enter to close"
