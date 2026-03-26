@echo off
:: =============================================================================
:: Portable Brain — Windows Installer
:: =============================================================================
:: Double-click this file to set up your Brain vault.
:: It runs the PowerShell installer which handles the rest.
:: =============================================================================

powershell -ExecutionPolicy Bypass -File "%~dp0Install Brain.ps1"
