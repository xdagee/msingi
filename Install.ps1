#Requires -Version 7.0
<#
.SYNOPSIS
    Msingi Installer — Foundation for agentic excellence.

.DESCRIPTION
    Handles Windows execution policy, registers the msingi launcher in your
    PowerShell profile, and validates the installation environment.

    Run this once from the msingi tool directory:
        cd "D:\path\to\msingi"
        .\install.ps1

.NOTES
    Must be run from the msingi directory.
    Requires PowerShell 7.0 or later.
    Preserves CRLF line endings and single-column formatting.

    Version: 3.8.0
#>

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$Force,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Styling Primitives ────────────────────────────────────────────────────────
$ESC = [char]27
$Ansi = [PSCustomObject]@{
    Cyan   = "$($ESC)[36m"
    Green  = "$($ESC)[32m"
    Yellow = "$($ESC)[33m"
    Red    = "$($ESC)[31m"
    Dim    = "$($ESC)[90m"
    Bold   = "$($ESC)[1m"
    Reset  = "$($ESC)[0m"
}

function hi($t)   { "$($script:Ansi.Cyan)$t$($script:Ansi.Reset)" }
function ok($t)   { "$($script:Ansi.Green)$t$($script:Ansi.Reset)" }
function warn($t) { "$($script:Ansi.Yellow)$t$($script:Ansi.Reset)" }
function err($t)  { "$($script:Ansi.Red)$t$($script:Ansi.Reset)" }
function dim($t)  { "$($script:Ansi.Dim)$t$($script:Ansi.Reset)" }
function bold($t) { "$($script:Ansi.Bold)$t$($script:Ansi.Reset)" }

function Write-Done { param($t) Write-Host "  $(ok "✓")  $t" }
function Write-Warn { param($t) Write-Host "  $(warn "⚠")  $t" }
function Write-Fail { param($t) if (-not $DryRun) { Write-Host "  $(err "✗")  $t"; exit 1 } else { Write-Host "  $(err "✗")  $t [DryRun]" } }
function Write-Info { param($t) Write-Host "  $(dim "·")  $(dim $t)" }
function Write-Rule { Write-Host "  $($script:Ansi.Dim)$("─" * 58)$($script:Ansi.Reset)" }

function Write-Step {
    param([int]$Index, [string]$Title)
    Write-Host "  $(bold "Step $Index — $Title")"
    Write-Host ""
}

# ── Core Logic ────────────────────────────────────────────────────────────────

function Get-MsingiVersion { "3.8.0" }

function Show-Banner {
    Write-Host ""
    Write-Host "  $($script:Ansi.Cyan)$($script:Ansi.Bold)Msingi$($script:Ansi.Reset)  $($script:Ansi.Dim)Installer$($script:Ansi.Reset)"
    Write-Host "  $($script:Ansi.Dim)Foundation for agentic excellence (v$(Get-MsingiVersion))$($script:Ansi.Reset)"
    Write-Host ""
    Write-Rule
    Write-Host ""
}

function Test-Prerequisites {
    $scriptDir = $PSScriptRoot
    $mainFile  = Join-Path $scriptDir "msingi.ps1"

    if (-not (Test-Path $mainFile)) {
        Write-Fail "msingi.ps1 not found in $scriptDir"
        Write-Info "Please run install.ps1 from the msingi root directory."
    }

    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 7) {
        Write-Fail "PowerShell $psVersion detected. Msingi requires PowerShell 7.0+."
        Write-Info "Get PS7: https://aka.ms/powershell"
    }

    return @{ Dir = $scriptDir; Script = $mainFile; Version = $psVersion }
}

function Sync-ExecutionPolicy {
    $eff = Get-ExecutionPolicy
    Write-Info "Current effective policy: $eff"

    $safe = @("RemoteSigned", "Unrestricted", "Bypass")
    if ($eff -notin $safe) {
        if ($DryRun) { Write-Done "Would set CurrentUser policy to RemoteSigned"; return }
        
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Done "Execution policy updated: CurrentUser = RemoteSigned"
        } catch {
            Write-Warn "Failed to set CurrentUser policy. Background: $_"
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            Write-Done "Session policy updated: Process = Bypass"
        }
    } else {
        Write-Done "Execution policy '$eff' is compatible"
    }

    # Unblock script
    Unblock-File -Path (Join-Path $PSScriptRoot "msingi.ps1") -ErrorAction SilentlyContinue
}

function Manage-ProfileRegistration {
    param($ScriptPath)
    
    $profile = $PROFILE.CurrentUserCurrentHost
    $dir     = Split-Path $profile -Parent
    
    if (-not (Test-Path $dir)) { 
        if (-not $DryRun) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Write-Done "Created profile directory"
    }
    
    if (-not (Test-Path $profile)) {
        if (-not $DryRun) { New-Item -ItemType File -Path $profile -Force | Out-Null }
        Write-Done "Created profile file"
    }

    $content = if (Test-Path $profile) { Get-Content $profile -Raw -Encoding UTF8 } else { "" }
    
    # Escape path for use in single-quoted string
    $safePath = $ScriptPath -replace "'", "''"
    
    $launcher = @"
function msingi {
    # Msingi launcher — Foundation for agentic excellence
    param(
        [switch]`$DryRun,
        [switch]`$Update,
        [switch]`$Check,
        [string]`$Path = ""
    )
    `$script = '$safePath'
    `$args = @()
    if (`$DryRun) { `$args += "-DryRun" }
    if (`$Update) { `$args += "-Update" }
    if (`$Check)  { `$args += "-Check"  }
    if (`$Path)   { `$args += "-Path"; `$args += `$Path }
    & `$script @args
}
Set-Alias -Name bootstrap -Value msingi -Scope Global -ErrorAction SilentlyContinue
"@

    if ($content -match "function msingi") {
        if ($Force) {
            # Update existing registration
            $newContent = $content -replace "(?ms)function msingi \{.*?Set-Alias -Name bootstrap.*?\n", $launcher
            if (-not $DryRun) { Set-Content $profile -Value $newContent -Encoding UTF8 }
            Write-Done "Updated msingi launcher in profile"
        } else {
            Write-Done "Msingi launcher already registered"
            Write-Info "To force update: .\install.ps1 -Force"
        }
    } else {
        $block = "`n`n# Msingi v$(Get-MsingiVersion) — Foundation`n$launcher"
        if (-not $DryRun) { Add-Content $profile -Value $block -Encoding UTF8 }
        Write-Done "Launcher registered in profile"
    }

    # Activate in current session
    if (-not $DryRun) { Invoke-Expression $launcher }
}

function Remove-Registration {
    $profile = $PROFILE.CurrentUserCurrentHost
    if (-not (Test-Path $profile)) { Write-Info "No profile found."; return }

    $lines = Get-Content $profile -Encoding UTF8
    $filtered = $lines | Where-Object { $_ -notmatch "msingi|bootstrap" }
    
    if (-not $DryRun) { Set-Content $profile -Value $filtered -Encoding UTF8 }
    Write-Done "Msingi registration removed from profile"
}

# ── Execution ─────────────────────────────────────────────────────────────────

Show-Banner
$env = Test-Prerequisites
Write-Done "Environment validated: $($env.Dir)"

if ($Uninstall) {
    Write-Host ""
    Write-Step 0 "Removal"
    Remove-Registration
    Write-Host ""
    Write-Done "Msingi uninstalled. Restart terminal to clean up aliases."
    exit 0
}

Write-Host ""
Write-Step 1 "Execution Policy"
Sync-ExecutionPolicy

Write-Host ""
Write-Step 2 "Launcher Setup"
Manage-ProfileRegistration -ScriptPath $env.Script

Write-Host ""
Write-Step 3 "Data Validation"
$allValid = $true
foreach ($f in @("agents.json", "skills.json")) {
    $p = Join-Path $env.Dir $f
    if (-not (Test-Path $p)) {
        Write-Warn "Missing essential data file: $f"
        $allValid = $false
    } else {
        try {
            $null = Get-Content $p -Raw | ConvertFrom-Json
            Write-Done "$f is valid"
        } catch {
            Write-Warn "Corrupt JSON in ${f}: $($_.Exception.Message)"
            $allValid = $false
        }
    }
}

Write-Host ""
Write-Rule
Write-Host ""

if ($allValid) {
    Write-Host "  $(ok "✓") $(bold "Installation Complete")"
    Write-Host ""
    Write-Info "Try typing 'msingi' or 'bootstrap' to start."
} else {
    Write-Host "  $(warn "⚠") $(bold "Installation Finished with Warnings")"
}
Write-Host ""
