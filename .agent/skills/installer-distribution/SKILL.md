---
name: installer-distribution
description: Use when modifying install.ps1, managing PowerShell profile registration, or planning cross-platform distribution.
---

# Installer & Distribution Skill

Maintain the Msingi installer and plan cross-platform distribution channels.

## Role

You are the **Distribution Engineer**. Your goal is to ensure Msingi installs reliably on every supported platform with zero manual configuration.

## Context

`install.ps1` handles Windows installation — execution policy, PowerShell profile registration, data file validation, and the `msingi`/`bootstrap` alias. macOS/Linux uses a simple `ln -s` to PATH. The Go rewrite will unify distribution via goreleaser.

## Instructions

1. **install.ps1 Maintenance**:
   - Mandatory: Version string in `Get-MsingiVersion` (line 65) must match `msingi.ps1` `$VERSION`.
   - Pattern: All profile modifications must be idempotent — re-running install must not duplicate entries.
   - Mandatory: Support `-Uninstall`, `-Force`, and `-DryRun` flags.
   - Mandatory: Validate `agents.json` and `skills.json` during installation.

2. **Profile Registration**:
   - Location: `$PROFILE.CurrentUserCurrentHost`.
   - Pattern: Register a `msingi` function (not just an alias) that forwards all parameters.
   - Alias: `Set-Alias -Name bootstrap -Value msingi` for backward compatibility.
   - Safety: Never overwrite existing profile content — append with a versioned comment block.

3. **Execution Policy**:
   - Mandatory: Set `RemoteSigned` at `CurrentUser` scope — never `Unrestricted` or `Bypass` at machine scope.
   - Fallback: If `CurrentUser` fails, set `Bypass` at `Process` scope for the current session only.
   - Mandatory: Run `Unblock-File` on `msingi.ps1` after policy change.

4. **macOS/Linux Installation**:
   - Pattern: Symlink to `/usr/local/bin/msingi` or `~/.local/bin/msingi`.
   - Mandatory: Verify Bash version ≥ 4.0 before symlinking (macOS ships Bash 3).
   - Instruction: Recommend `brew install bash` on macOS if version is insufficient.

5. **Future Distribution Channels**:
   - Windows: Scoop manifest (`msingi.json`), Winget manifest.
   - macOS: Homebrew tap formula.
   - Linux: Direct binary download from GitHub Releases.
   - All: goreleaser-driven automated release pipeline.

6. **Version Synchronization**:
   - Mandatory: The installer version must always match the main script version.
   - Locations: `install.ps1:Get-MsingiVersion`, `msingi.ps1:$VERSION`, `msingi.sh:VERSION`, `README.md`.
