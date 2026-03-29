#Requires -Version 7.0
<#
.SYNOPSIS
    Bootstrap Agent — One-time installer for Windows PowerShell 7.

.DESCRIPTION
    Handles Windows execution policy, registers the bootstrap alias in your
    PowerShell profile, and validates the installation.

    Run this once from the bootstrap-agent tool directory:
        cd "C:\Users\Prince\Tools\bootstrap-agent"
        .\Install.ps1

    After install, 'bootstrap' is available from any PowerShell 7 terminal.

.NOTES
    Must be run from the bootstrap-agent directory.
    Requires PowerShell 7.0 or later.
    Does NOT require Administrator privileges (sets CurrentUser policy only).
#>

[CmdletBinding()]
param(
    [switch]$Uninstall
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# ── Colours ───────────────────────────────────────────────────────────────────
$ESC = [char]27
function hi($t)   { "$($ESC)[36m$t$($ESC)[0m" }
function ok($t)   { "$($ESC)[32m$t$($ESC)[0m" }
function warn($t) { "$($ESC)[33m$t$($ESC)[0m" }
function err($t)  { "$($ESC)[31m$t$($ESC)[0m" }
function dim($t)  { "$($ESC)[90m$t$($ESC)[0m" }
function bold($t) { "$($ESC)[1m$t$($ESC)[0m" }

function Write-Done { param($t) Write-Host "  $(ok "✓")  $t" }
function Write-Warn { param($t) Write-Host "  $(warn "⚠")  $t" }
function Write-Fail { param($t) Write-Host "  $(err "✗")  $t"; exit 1 }
function Write-Info { param($t) Write-Host "  $(dim "·")  $(dim $t)" }
function Write-Rule { Write-Host "  $($ESC)[90m$("─" * 58)$($ESC)[0m" }

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  $($ESC)[36m$($ESC)[1mBootstrap Agent$($ESC)[0m  $($ESC)[90mInstaller$($ESC)[0m"
Write-Host "  $($ESC)[90mWindows PowerShell 7 setup$($ESC)[0m"
Write-Host ""
Write-Rule
Write-Host ""

# ── Locate the main script ────────────────────────────────────────────────────
$scriptDir  = $PSScriptRoot
$mainScript = Join-Path $scriptDir "bootstrap-agent.ps1"

if (-not (Test-Path $mainScript)) {
    Write-Fail "bootstrap-agent.ps1 not found in: $scriptDir"
    Write-Info "Run Install.ps1 from inside the bootstrap-agent directory."
    exit 1
}

Write-Done "Tool directory: $scriptDir"

# ── Uninstall path ────────────────────────────────────────────────────────────
if ($Uninstall) {
    Write-Host ""
    Write-Host "  $(bold "Uninstalling…")"
    Write-Host ""

    $profilePath = $PROFILE.CurrentUserCurrentHost
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw -Encoding UTF8
        if ($content -match "bootstrap-agent") {
            # Remove only the bootstrap alias block
            $cleaned = $content -replace "(?ms)#\s*Bootstrap Agent.*?Set-Alias bootstrap.*?\n", ""
            $cleaned = $cleaned -replace "(?ms)\n# Bootstrap Agent[^\n]*\nSet-Alias bootstrap[^\n]*\n", ""
            # Simpler targeted removal
            $lines   = Get-Content $profilePath -Encoding UTF8
            $filtered = $lines | Where-Object { $_ -notmatch "Bootstrap Agent|Set-Alias bootstrap.*bootstrap-agent" }
            Set-Content $profilePath -Value $filtered -Encoding UTF8
            Write-Done "Alias removed from profile: $profilePath"
        } else {
            Write-Info "No Bootstrap Agent alias found in profile."
        }
    }
    Write-Host ""
    Write-Done "Uninstall complete. Restart your terminal to apply."
    Write-Host ""
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1 — CHECK POWERSHELL VERSION
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "  $(bold "Step 1 — PowerShell version")"
Write-Host ""

$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 7) {
    Write-Fail "PowerShell $psVersion detected. Bootstrap Agent requires PowerShell 7.0+."
    Write-Info "Download from: https://aka.ms/powershell"
    exit 1
}
Write-Done "PowerShell $psVersion — compatible"
Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2 — EXECUTION POLICY
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "  $(bold "Step 2 — Execution policy")"
Write-Host ""

# Windows has several policy scopes. We need to understand the effective policy.
# Scopes in priority order (highest to lowest):
#   MachinePolicy → UserPolicy → Process → CurrentUser → LocalMachine
#
# Strategy:
#   - Never touch MachinePolicy or UserPolicy (require Group Policy / domain admin)
#   - Never touch LocalMachine (requires Administrator elevation)
#   - Set CurrentUser to RemoteSigned — the minimum needed to run local scripts
#   - If Process policy overrides everything, set that too for this session
#   - If Group Policy has locked it to Restricted, we cannot override — explain clearly

$effectivePolicy  = Get-ExecutionPolicy                          # effective (highest priority wins)
$currentUserPolicy = Get-ExecutionPolicy -Scope CurrentUser
$localMachinePolicy = Get-ExecutionPolicy -Scope LocalMachine
$machinePolicy    = Get-ExecutionPolicy -Scope MachinePolicy -ErrorAction SilentlyContinue
$userPolicy       = Get-ExecutionPolicy -Scope UserPolicy -ErrorAction SilentlyContinue
$processPolicy    = Get-ExecutionPolicy -Scope Process -ErrorAction SilentlyContinue

Write-Info "MachinePolicy : $(if ($machinePolicy)  { $machinePolicy }  else { 'Undefined' })"
Write-Info "UserPolicy    : $(if ($userPolicy)     { $userPolicy }     else { 'Undefined' })"
Write-Info "LocalMachine  : $localMachinePolicy"
Write-Info "CurrentUser   : $(if ($currentUserPolicy) { $currentUserPolicy } else { 'Undefined' })"
Write-Info "Process       : $(if ($processPolicy)  { $processPolicy }  else { 'Undefined' })"
Write-Info "Effective     : $effectivePolicy"
Write-Host ""

# Check for Group Policy lock (MachinePolicy or UserPolicy set to Restricted/AllSigned)
$gpLocked = ($machinePolicy -in @("Restricted","AllSigned")) -or
            ($userPolicy    -in @("Restricted","AllSigned"))

if ($gpLocked) {
    Write-Warn "Group Policy has restricted script execution on this machine."
    Write-Host ""
    Write-Host "  $(warn "Cannot override Group Policy without domain administrator access.")"
    Write-Host ""
    Write-Host "  $(bold "Workaround options:")"
    Write-Host ""
    Write-Host "  $(dim "A")  Run the script directly each time with -ExecutionPolicy bypass:"
    Write-Host "     $(dim "pwsh -ExecutionPolicy Bypass -File `"$mainScript`"")"
    Write-Host ""
    Write-Host "  $(dim "B")  Create a .bat launcher in the same directory:"
    Write-Host "     $(dim "bootstrap.bat (see Install.ps1 output below)")"
    Write-Host ""

    # Create a .bat launcher that bypasses execution policy per-invocation
    $batContent = @"
@echo off
:: Bootstrap Agent launcher — bypasses execution policy for this invocation only
:: This is safe: -ExecutionPolicy Bypass applies only to this process, not the system
pwsh.exe -ExecutionPolicy Bypass -NoLogo -File "%~dp0bootstrap-agent.ps1" %*
"@
    $batPath = Join-Path $scriptDir "bootstrap.bat"
    Set-Content -Path $batPath -Value $batContent -Encoding ASCII
    Write-Done "Created bootstrap.bat — add $scriptDir to your PATH to use it"
    Write-Host ""
    Write-Info "Add to PATH: System Properties → Environment Variables → Path → New → $scriptDir"
    Write-Host ""
    exit 0
}

# Safe policies that allow local scripts
$safePolicies = @("RemoteSigned","Unrestricted","Bypass")

if ($effectivePolicy -notin $safePolicies) {
    Write-Warn "Current effective policy '$effectivePolicy' blocks local scripts."
    Write-Host ""
    Write-Host "  Setting CurrentUser policy to RemoteSigned..."
    Write-Host "  $(dim "RemoteSigned = local scripts run freely; downloaded scripts must be signed.")"
    Write-Host "  $(dim "This is the recommended policy for developers on Windows.")"
    Write-Host ""

    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Done "Execution policy set: CurrentUser = RemoteSigned"
    } catch {
        Write-Warn "Could not set CurrentUser policy: $_"
        Write-Host ""
        Write-Host "  $(bold "Fallback: setting Process scope for this session only.")"
        try {
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            Write-Done "Execution policy set: Process = Bypass (this session only)"
            Write-Warn "This does not persist. Re-run Install.ps1 as Administrator to set permanently."
        } catch {
            Write-Fail "Could not set execution policy: $_"
        }
    }
} else {
    Write-Done "Execution policy '$effectivePolicy' — scripts can run"
}

# Also unblock the script file itself if it was downloaded from the internet
# (Windows marks downloaded files with an alternate data stream: Zone.Identifier)
try {
    $mainScriptItem = Get-Item $mainScript -ErrorAction SilentlyContinue
    if ($mainScriptItem) {
        Unblock-File -Path $mainScript -ErrorAction SilentlyContinue
        Write-Done "Script unblocked (cleared Zone.Identifier if present)"
    }
} catch {
    # Non-fatal — some environments don't support this
    Write-Info "Note: could not run Unblock-File — may not be needed on this system"
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3 — POWERSHELL PROFILE + ALIAS
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "  $(bold "Step 3 — PowerShell profile and alias")"
Write-Host ""

# PowerShell 7 uses a different profile path from Windows PowerShell 5.1
# $PROFILE.CurrentUserCurrentHost = profile for PS7 only (recommended)
# $PROFILE.CurrentUserAllHosts    = profile for all PowerShell versions (broader)
# We use CurrentUserCurrentHost so the alias only loads in PS7 — no interference with PS5.

$profilePath = $PROFILE.CurrentUserCurrentHost
Write-Info "Profile path: $profilePath"

# Create profile directory and file if they don't exist
$profileDir = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Write-Done "Created profile directory"
}

if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    Write-Done "Created profile file: $profilePath"
}

# Check if alias is already registered
$profileContent = Get-Content $profilePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue

# We register a function (not just an alias) so msingi/bootstrap can pass args cleanly
$launcherFn = @"
function msingi {
    # Msingi launcher — spawns independent window or runs inline for dry-run/help
    param([switch]`$DryRun, [string]`$Path = "")
    `$script = "$mainScript"
    `$argStr = @()
    if (`$DryRun) { `$argStr += "-DryRun" }
    if (`$Path)   { `$argStr += "-Path `"`$Path`"" }
    & "`$script" @argStr
}
Set-Alias -Name bootstrap -Value msingi -Scope Global -ErrorAction SilentlyContinue
"@

if ($profileContent -and ($profileContent -match "function msingi" -or $profileContent -match "bootstrap-agent")) {
    Write-Done "Msingi launcher already in profile"
    Write-Info "To update: edit $profilePath"
} else {
    $block = @"


# Msingi v3.7.0 — added by Install.ps1 on $(Get-Date -Format "yyyy-MM-dd")
$launcherFn
"@
    Add-Content -Path $profilePath -Value $block -Encoding UTF8
    Write-Done "Launcher function registered in profile"
    Write-Info "Commands available: msingi  |  bootstrap  |  msingi -DryRun  |  msingi -Path C:\projectspp"
}

# Register for current session immediately
Invoke-Expression $launcherFn
Write-Done "Launcher active in current session"
Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4 — VALIDATE DATA FILES
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "  $(bold "Step 4 — Validate data files")"
Write-Host ""

$dataFiles = @("agents.json","skills.json")
$allGood   = $true

foreach ($f in $dataFiles) {
    $fp = Join-Path $scriptDir $f
    if (-not (Test-Path $fp)) {
        Write-Warn "$f not found — Bootstrap Agent will fail without it"
        $allGood = $false
    } else {
        try {
            $null = Get-Content $fp -Raw | ConvertFrom-Json
            Write-Done "$f — valid JSON"
        } catch {
            Write-Warn "$f — invalid JSON: $_"
            $allGood = $false
        }
    }
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5 — OPTIONAL PATH REGISTRATION
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "  $(bold "Step 5 — PATH registration")"
Write-Host ""

$currentPath = [System.Environment]::GetEnvironmentVariable("PATH","User")
if ($currentPath -and $currentPath.Split(";") -contains $scriptDir) {
    Write-Done "Tool directory already in user PATH"
} else {
    Write-Host "  $(hi "?") Add $scriptDir to your user PATH? $(dim "(y/N)") " -NoNewline
    $addPath = Read-Host
    if ($addPath -match "^[yY]") {
        $newPath = if ($currentPath) { "$currentPath;$scriptDir" } else { $scriptDir }
        [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        $env:PATH = "$env:PATH;$scriptDir"
        Write-Done "Added to user PATH — effective in new terminals"
        Write-Info "This enables 'bootstrap' from cmd.exe and other shells via bootstrap.bat"
    } else {
        Write-Info "Skipped — alias is sufficient for PowerShell 7 terminals"
    }
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════════════════════
Write-Rule
Write-Host ""

if ($allGood) {
    Write-Host "  $($ESC)[32m$($ESC)[1m✓ Installation complete$($ESC)[0m"
} else {
    Write-Host "  $(warn "⚠ Installation complete with warnings — review above")"
}

Write-Host ""
Write-Host "  $(hi "How to use:")"
Write-Host "  $(dim "  Type any of these in PowerShell 7:")"
Write-Host ""
Write-Host "      msingi                    $(dim "# launches in its own window")"
Write-Host "      bootstrap                 $(dim "# alias — same as msingi")"
Write-Host "      msingi -DryRun            $(dim "# preview without writing")"
Write-Host "      msingi -Update            $(dim "# update to latest release")"
Write-Host "      msingi -Check             $(dim "# context health check on current project")"
Write-Host "      msingi -Path C:\Projects\my-app"
Write-Host ""
Write-Host "  $(hi "Msingi opens in its own clean terminal window automatically.")"
Write-Host "  $(dim "  If Windows Terminal (wt.exe) is installed, it opens in a new tab.")"
Write-Host "  $(dim "  Otherwise it opens in a new pwsh conhost window.")"
Write-Host ""
Write-Host "  $(hi "To uninstall:")"
Write-Host "  $(dim "  .\Install.ps1 -Uninstall")"
Write-Host ""
Write-Host "  $(hi "If execution policy blocks the script in future:")"
Write-Host "  $(dim "  pwsh -ExecutionPolicy Bypass -File `"$mainScript`"")"
Write-Host ""
