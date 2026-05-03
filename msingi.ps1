#Requires -Version 7.0
<#
.SYNOPSIS
    Msingi v3.8.1 — Self-configuring multi-agent project scaffold tool.

.DESCRIPTION
    Interactive PowerShell 7 TUI that scaffolds production-ready projects with
    full context engineering structure for multi-agent development workflows.

    v3 additions over v2:
      - Hybrid type composition — combine two project types (e.g. API Service + CLI Tool)
      - Smart intake — 5 targeted clarifying questions before scaffold generation
        (audience, auth, sensitive data, deployment target, scale profile)
      - Intake answers woven into CONTEXT.md, SECURITY.md, and TASKS.md

    Project types: Web Application, API Service, ML/AI System, CLI Tool,
                   Full-Stack Platform, Android App (Kotlin + Jetpack Compose)

    Each type generates:
      - Type-specific architecture guidance in CONTEXT.md
      - Non-functional requirements (performance, availability, security)
      - SECURITY.md  — threat model starters relevant to the project type
      - QUALITY.md   — production quality gates and definition of done
      - ENVIRONMENTS.md — dev / staging / production strategy
      - OBSERVABILITY.md — logging, metrics, alerting specification
      - Stronger ADR format with constraints and review cadence
      - SESSION.md with explicit ESCALATE path for production blockers
      - Android: GRADLE.md skill spec + libs.versions.toml starter

    Data files (edit freely — no script changes needed):
      agents.json  — agent registry
      skills.json  — skill inference patterns

.PARAMETER Path
    Target project directory. Greenfield: new subfolder named after project.
    Brownfield: existing directory to scan and overlay.

.PARAMETER DryRun
    Preview all files that would be created without writing anything.

.EXAMPLE
    bootstrap
    bootstrap -Path C:\Projects\my-app
    bootstrap -DryRun

.NOTES
    Add to PowerShell $PROFILE for global invocation:
    Set-Alias bootstrap "C:\Users\Prince\Tools\msingi\msingi.ps1"
#>

[CmdletBinding()]
param(
    [string]$Path   = "",
    [switch]$DryRun,
    [switch]$Update,
    [switch]$Check
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# ── Quick commands: -Update and -Check run before the full TUI loads ──────────
# Resolved after constants/colours are defined below — see MAIN section.

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════
$VERSION    = "3.10.0"
$SCRIPT_DIR = $PSScriptRoot
$MAX_SKILLS = 12   # type-scoped pool means all matches are relevant

# ═══════════════════════════════════════════════════════════════════════════════
# ANSI + COLOUR ENGINE  (v3 — extended palette)
# ═══════════════════════════════════════════════════════════════════════════════
$ESC = [char]27
function ansi($code) { "$ESC[${code}m" }

$C = @{
    Reset      = ansi 0
    Bold       = ansi 1
    Dim        = ansi 2
    Italic     = ansi 3
    Underline  = ansi 4
    # Foreground
    Cyan       = ansi 36
    BrCyan     = ansi 96
    Green      = ansi 32
    BrGreen    = ansi 92
    Yellow     = ansi 33
    BrYellow   = ansi 93
    Red        = ansi 31
    BrRed      = ansi 91
    Magenta    = ansi 35
    BrMagenta  = ansi 95
    Blue       = ansi 34
    BrBlue     = ansi 94
    Gray       = ansi 90
    White      = ansi 97
    Black      = ansi 30
    # Background
    BgCyan     = ansi 46
    BgGreen    = ansi 42
    BgYellow   = ansi 43
    BgRed      = ansi 41
    BgBlue     = ansi 44
    BgMagenta  = ansi 45
    BgGray     = ansi 100
    BgDark     = ansi 40
    BgWhite    = ansi 107
    # Cursor / erase
    CursorOff  = "$ESC[?25l"
    CursorOn   = "$ESC[?25h"
    ClearLine  = "$ESC[2K"
    ClearEOS   = "$ESC[J"
}

function ansi-fg([int]$r, [int]$g, [int]$b) { "$ESC[38;2;${r};${g};${b}m" }
function ansi-bg([int]$r, [int]$g, [int]$b) { "$ESC[48;2;${r};${g};${b}m" }
function cursor-up([int]$n)   { "$ESC[${n}A" }
function cursor-down([int]$n) { "$ESC[${n}B" }
function cursor-col([int]$n)  { "$ESC[${n}G" }
function cursor-pos([int]$row,[int]$col) { "$ESC[${row};${col}H" }

# Semantic colour functions
function c($color, $text)  { "$($C[$color])$text$($C.Reset)" }
function dim($t)            { c Gray      $t }
function hi($t)             { c BrCyan    $t }
function ok($t)             { c BrGreen   $t }
function warn($t)           { c BrYellow  $t }
function err($t)            { c BrRed     $t }
function accent($t)         { c BrMagenta $t }
function muted($t)          { c Gray      $t }
function bold($t)           { "$($C.Bold)$t$($C.Reset)" }
function italic($t)         { "$($C.Italic)$t$($C.Reset)" }
function ul($t)             { "$($C.Underline)$t$($C.Reset)" }

# True-colour theme accents
$BRAND   = ansi-fg 0   210 200   # teal brand colour
$BRAND_B = "$($C.Bold)$(ansi-fg 0 210 200)"
$STEP_DIM    = ansi-fg 80 80 90
$STEP_DONE   = ansi-fg 80 200 120
$STEP_ACTIVE = ansi-fg 0  210 200
$HEADER_BG   = ansi-bg 18 18 28
$FOOTER_BG   = ansi-bg 18 18 28

# ═══════════════════════════════════════════════════════════════════════════════
# SUCCESS INFRASTRUCTURE (Success Criteria Implementation)
# ═══════════════════════════════════════════════════════════════════════════════

# 1. Terminal Capability Detection
$TERM_CAPS = @{
    Unicode = $true
    Color   = $true
    Width   = 80
}

function Test-Terminal {
    # Detect Unicode support
    if ($IsWindows) {
        $TERM_CAPS.Unicode = $OutputEncoding.EncodingName -match "utf-8" -or [Console]::OutputEncoding.EncodingName -match "utf-8"
    } else {
        $TERM_CAPS.Unicode = $env:LANG -match "UTF-8"
    }

    # Detect Color support
    if ($env:NO_COLOR -or $env:TERM -eq "dumb") {
        $TERM_CAPS.Color = $false
    } elseif ($env:CI) {
        $TERM_CAPS.Color = $true # Most CI systems support color
    }
    
    $TERM_CAPS.Width = try { [Console]::WindowWidth } catch { 80 }
    if ($TERM_CAPS.Width -lt 20) { $TERM_CAPS.Width = 80 }
}

# 2. Data Integrity Validation
function Validate-Data {
    param([string]$File)
    if (-not (Test-Path $File)) {
        throw "Critical: Configuration file not found: $File"
    }
    try {
        $data = Get-Content $File -Raw | ConvertFrom-Json -ErrorAction Stop
        if (-not $data.schema_version) {
            throw "Invalid Schema: $File is missing schema_version. Please update your data files."
        }
    } catch {
        throw "Syntax Error: $File contains invalid JSON logic. Please check for trailing commas or missing brackets."
    }
}

# 3. State Persistence
$STATE_FILE = Join-Path $HOME ".msingi_state.json"
function Save-State {
    param($StateObj)
    $StateObj | ConvertTo-Json | Set-Content $STATE_FILE
}

function Load-State {
    if (Test-Path $STATE_FILE) {
        return Get-Content $STATE_FILE -Raw | ConvertFrom-Json
    }
    return $null
}

# ═══════════════════════════════════════════════════════════════════════════════
# TERMINAL GEOMETRY
# ═══════════════════════════════════════════════════════════════════════════════
function Get-TermWidth  { $TERM_CAPS.Width }
function Get-TermHeight { try { [Console]::WindowHeight } catch { 24 } }

# Sidebar width (steps panel)
$SIDEBAR_W = 22
# Inner content indent (inside main panel)
$CONTENT_INDENT = "    "

# ═══════════════════════════════════════════════════════════════════════════════
# LAYOUT HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

# Pad or truncate a plain string to exactly $w visible characters
function Pad([string]$s, [int]$w, [string]$align = "left") {
    if ($s.Length -ge $w) { return $s.Substring(0, $w) }
    $pad = $w - $s.Length
    if ($align -eq "right") { return (' ' * $pad) + $s }
    if ($align -eq "center") {
        $l = [Math]::Floor($pad / 2); $r = $pad - $l
        return (' ' * $l) + $s + (' ' * $r)
    }
    return $s + (' ' * $pad)
}

function Write-Rule {
    $w = [Math]::Min((Get-TermWidth) - 4, 72)
    Write-Host "  $($C.Gray)$("─" * $w)$($C.Reset)"
}
function Write-Blank { Write-Host "" }

# ── Header bar ────────────────────────────────────────────────────────────────
function Write-Header {
    param([string]$Mode = "", [string]$StepLabel = "")
    $tw   = Get-TermWidth
    $fill = $tw - 2

    # Msingi brand — teal ⬡ mark + name in bold
    $logo  = " ⬡ "
    $name  = "Msingi"
    $ver   = "  v$VERSION"

    # Right side: mode pill + step counter + platform tag
    $right = ""
    if ($Mode)      { $right += " $Mode " }
    if ($StepLabel) { $right += "  $StepLabel " }
    $right += "  PS7 "

    $mid = $fill - ($logo + $name + $ver).Length - $right.Length
    if ($mid -lt 0) { $mid = 0 }

    $leftPart  = "$HEADER_BG$(ansi-fg 0 210 200)$($C.Bold)$logo$name$($C.Reset)$HEADER_BG$(ansi-fg 120 120 140)$ver$($C.Reset)"
    $rightPart = "$HEADER_BG$(ansi-fg 80 80 100)$(' ' * $mid)$right$($C.Reset)"
    Write-Host "$leftPart$rightPart"
}

# ── Footer bar ────────────────────────────────────────────────────────────────
function Write-Footer {
    param([string]$Hints = "↑↓ move  Space toggle  Enter confirm  Esc back")
    $tw   = Get-TermWidth
    $fill = $tw - 2
    $bar  = " $Hints"
    $pad  = [Math]::Max(0, $fill - $bar.Length)
    Write-Host "$FOOTER_BG$($C.Gray)$bar$(' ' * $pad)$($C.Reset)"
}

# ── Step sidebar (inline, printed once per screen) ───────────────────────────
# Steps: array of [label, state]  state: "done"|"active"|"pending"
function Write-StepSidebar {
    param([object[]]$Steps)
    Write-Host ""
    foreach ($s in $Steps) {
        $label = $s.label
        $state = $s.state
        if ($state -eq "done") {
            Write-Host "  $STEP_DONE✓  $($C.Gray)$label$($C.Reset)"
        } elseif ($state -eq "active") {
            Write-Host "  $STEP_ACTIVE▶  $($C.Bold)$STEP_ACTIVE$label$($C.Reset)"
        } else {
            Write-Host "  $STEP_DIM·  $($C.Gray)$label$($C.Reset)"
        }
    }
    Write-Host ""
}

# ── Section divider inside main content ──────────────────────────────────────
function Write-Section {
    param([string]$Title, [string]$Sub = "")
    $tw   = [Math]::Min((Get-TermWidth) - 4, 72)
    $line = "─" * [Math]::Max(0, $tw - $Title.Length - 3)
    Write-Host ""
    Write-Host "  $($C.Bold)$STEP_ACTIVE$Title$($C.Reset)  $($C.Gray)$line$($C.Reset)"
    if ($Sub) { Write-Host "  $($C.Gray)$Sub$($C.Reset)" }
    Write-Host ""
}

# ── Boxed success / summary panel ────────────────────────────────────────────
function Write-Box {
    param([string]$Title, [string]$Sub = "", [string[]]$Lines = @(), [string]$Color = "BrCyan")
    $tw = [Math]::Min((Get-TermWidth) - 4, 68)
    $inner = $tw - 2
    Write-Host ""
    Write-Host "  $($C.Gray)╔$("═" * $inner)╗$($C.Reset)"
    # Title row
    $titlePad = [Math]::Max(0, $inner - $Title.Length - 2)
    Write-Host "  $($C.Gray)║$($C.Reset)  $($C[$Color])$($C.Bold)$Title$($C.Reset)$(' ' * $titlePad) $($C.Gray)║$($C.Reset)"
    if ($Sub) {
        $subPad = [Math]::Max(0, $inner - $Sub.Length - 2)
        Write-Host "  $($C.Gray)║$($C.Reset)  $($C.Gray)$Sub$($C.Reset)$(' ' * $subPad) $($C.Gray)║$($C.Reset)"
    }
    if ($Lines.Count -gt 0) {
        Write-Host "  $($C.Gray)╠$("─" * $inner)╣$($C.Reset)"
        foreach ($ln in $Lines) {
            $lnPad = [Math]::Max(0, $inner - $ln.Length - 2)
            Write-Host "  $($C.Gray)║$($C.Reset)  $($C.Gray)$ln$($C.Reset)$(' ' * $lnPad) $($C.Gray)║$($C.Reset)"
        }
    }
    Write-Host "  $($C.Gray)╚$("═" * $inner)╝$($C.Reset)"
    Write-Host ""
}

# ── Inline key-value table (for review / profile panels) ─────────────────────
function Write-KVTable {
    param([object[]]$Rows, [int]$KeyWidth = 18)
    foreach ($row in $Rows) {
        $k   = Pad $row.Key $KeyWidth
        $v   = $row.Value
        $col = if ($row.Color) { $row.Color } else { "White" }
        Write-Host "  $($C.Gray)$k$($C.Reset)  $($C[$col])$v$($C.Reset)"
    }
}

# ── Tag pill (inline coloured label) ─────────────────────────────────────────
function pill($label, $color = "BrCyan") {
    "$($C[$color])$($C.Bold) $label $($C.Reset)"
}

# ── Spinner (blocking, shows during a work block) ─────────────────────────────
function Invoke-WithSpinner {
    param([string]$Message, [scriptblock]$Work)
    $frames  = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    $i       = 0
    Write-Host "$($C.CursorOff)" -NoNewline
    # Run work in a job so we can spin while waiting
    $job = Start-Job -ScriptBlock $Work
    while ($job.State -eq "Running") {
        $f = $frames[$i % $frames.Count]
        Write-Host "`r  $($C.BrCyan)$f$($C.Reset)  $($C.Gray)$Message$($C.Reset)   " -NoNewline
        Start-Sleep -Milliseconds 80
        $i++
    }
    $result = Receive-Job $job -Wait -AutoRemoveJob 2>$null
    Write-Host "`r  $(ok "✓")  $Message$($C.Gray)           $($C.Reset)"
    Write-Host "$($C.CursorOn)" -NoNewline
    return $result
}

# ── Standard output helpers ───────────────────────────────────────────────────
function Write-Step {
    param($n, $t)
    Write-Host "  $($C.Gray)[$n]$($C.Reset)  $($C.Bold)$STEP_ACTIVE$t$($C.Reset)"
}
function Write-Done { param($t) Write-Host "  $(ok "✓")  $t" }
function Write-Warn { param($t) Write-Host "  $(warn "⚠")  $t" }
function Write-Fail { param($t) Write-Host "  $(err "✗")  $t" }
function Write-Info { param($t) Write-Host "  $($C.Gray)·  $t$($C.Reset)" }
function Write-Flag { param($t) Write-Host "  $(accent "⚑")  $(accent $t)" }

# ── Banner / screen header ─────────────────────────────────────────────────────
function Write-Banner {
    param([string]$Mode = "", [string]$StepLabel = "")
    Clear-Host
    Write-Header -Mode $Mode -StepLabel $StepLabel
    Write-Host ""
}

# ── Animated splash screen ────────────────────────────────────────────────────
# Shown once at startup. Typewriter-types the tagline, then fades to screen 1.
function Write-Splash {
    Clear-Host
    $tw = Get-TermWidth
    $th = Get-TermHeight

    # Vertical centering: push content to roughly 1/3 from top
    $topPad = [Math]::Max(2, [int]($th / 3) - 4)
    Write-Host ("`n" * $topPad) -NoNewline

    # Large ASCII logomark — the ⬡ hex symbol scaled up with Unicode box chars
    $logoLines = @(
        "     ╭───────────────────────────╮",
        "     │                           │",
        "     │   ⬡  M S I N G I          │",
        "     │                           │",
        "     ╰───────────────────────────╯"
    )
    foreach ($ln in $logoLines) {
        $pad = [Math]::Max(0, [int](($tw - $ln.Length) / 2))
        Write-Host "$(ansi-fg 0 210 200)$($C.Bold)$(' ' * $pad)$ln$($C.Reset)"
    }

    Write-Host ""

    # Tagline — typewriter effect
    $tagline = "Context engineering infrastructure for AI agent sessions."
    $pad = [Math]::Max(0, [int](($tw - $tagline.Length) / 2))
    $prefix = " " * $pad
    Write-Host "$prefix$(ansi-fg 120 120 140)" -NoNewline
    foreach ($ch in $tagline.ToCharArray()) {
        Write-Host $ch -NoNewline
        Start-Sleep -Milliseconds 18
    }
    Write-Host "$($C.Reset)"

    Write-Host ""

    # Subtitle
    $sub = "Built in Accra. Designed for everywhere."
    $padSub = [Math]::Max(0, [int](($tw - $sub.Length) / 2))
    Write-Host "$(' ' * $padSub)$(ansi-fg 60 60 80)$sub$($C.Reset)"
    Write-Host ""

    # Pause briefly, then fade to step 1
    Start-Sleep -Milliseconds 700
}

# ── Two-column screen layout helper ──────────────────────────────────────────
# Renders the sidebar (left) and a section header (right) simultaneously
# using cursor positioning. Returns the content area top row.
function Write-TwoColumn {
    param(
        [int]$StepIndex,
        [string]$Mode        = "",
        [string]$SectionTitle = "",
        [string]$SectionSub   = "",
        [string[]]$Summary    = @()   # live project summary lines for sidebar bottom
    )

    Clear-Host
    Write-Header -Mode $Mode -StepLabel "$($StepIndex + 1)/7"

    $tw       = Get-TermWidth
    $leftW    = 26    # sidebar column width
    $rightW   = [Math]::Max(40, $tw - $leftW - 2)

    $stepDefs = @("Mode","Type","Details","Intake","Agents","Skills","Review")

    # ── Draw sidebar (left column) ──────────────────────────────────────────
    # Row 3 = first step line (row 1 = header, row 2 = blank)
    $row = 3
    [Console]::SetCursorPosition(0, $row)
    Write-Host ""  # blank line

    $row = 4
    foreach ($i in 0..($stepDefs.Count - 1)) {
        [Console]::SetCursorPosition(0, $row)
        $label = $stepDefs[$i]
        if ($i -lt $StepIndex) {
            Write-Host "  $STEP_DONE✓  $($C.Gray)$($label.PadRight(16))$($C.Reset)"
        } elseif ($i -eq $StepIndex) {
            Write-Host "  $STEP_ACTIVE▶  $($C.Bold)$STEP_ACTIVE$($label.PadRight(16))$($C.Reset)"
        } else {
            Write-Host "  $STEP_DIM·  $($C.Gray)$($label.PadRight(16))$($C.Reset)"
        }
        $row++
    }

    # ── Draw vertical divider ────────────────────────────────────────────────
    $dividerRow = 3
    for ($r = $dividerRow; $r -lt ($dividerRow + $stepDefs.Count + 2); $r++) {
        [Console]::SetCursorPosition($leftW - 1, $r)
        Write-Host "$(ansi-fg 40 40 55)│$($C.Reset)" -NoNewline
    }

    # ── Summary panel at bottom of sidebar ──────────────────────────────────
    if ($Summary.Count -gt 0) {
        $sumRow = 4 + $stepDefs.Count + 1
        [Console]::SetCursorPosition(0, $sumRow)
        Write-Host "  $(ansi-fg 40 40 55)─────────────────────$($C.Reset)"
        foreach ($s in $Summary) {
            $sumRow++
            [Console]::SetCursorPosition(0, $sumRow)
            Write-Host "  $(ansi-fg 80 80 100)$($s.Substring(0, [Math]::Min($s.Length, $leftW - 3)))$($C.Reset)"
        }
    }
}

# ── Move cursor to right-column
function Read-Choice {
    param([string[]]$Items, [int]$Selected = 0, [string]$Prompt = "Select",
          [string]$FooterHint = "↑↓ navigate  Tab next  Shift+Tab prev  Enter confirm  Esc back")

    # Strip ANSI sequences to get visible character length
    function Strip-Ansi-C([string]$s) {
        return [regex]::Replace($s, "\e\[[0-9;]*[mABCDEFGHJKLMnsuhr]", "")
    }

    # Physical terminal lines a single row occupies (accounts for line wrap)
    function Row-Height-C([string]$label) {
        $tw      = try { [Console]::WindowWidth } catch { 80 }
        $prefix  = 7    # "  ▶  " or "     " = 5 visible chars + 2 padding
        $visible = (Strip-Ansi-C $label).Length + $prefix + 3
        return [Math]::Max(1, [Math]::Ceiling($visible / $tw))
    }

    function Menu-Height-C([string[]]$items) {
        $h = 0; foreach ($item in $items) { $h += Row-Height-C $item }; return $h
    }

    Write-Host ""
    Write-Host "  $STEP_ACTIVE›$($C.Reset)  $($C.Bold)$Prompt$($C.Reset)  $($C.Gray)↑↓ navigate  Enter confirm  Tab next  Shift+Tab prev  → next  ← prev  G goto$($C.Reset)"
    Write-Host ""

    $cur = [Math]::Clamp($Selected, 0, $Items.Count - 1)
    Write-Host $C.CursorOff -NoNewline

    function Draw-Choice([string[]]$items, [int]$c) {
        foreach ($i in 0..($items.Count - 1)) {
            if ($i -eq $c) {
                Write-Host "  $STEP_ACTIVE▶$($C.Reset)  $($C.Bold)$STEP_ACTIVE$($items[$i])$($C.Reset)   "
            } else {
                Write-Host "     $($C.Gray)$($items[$i])$($C.Reset)   "
            }
        }
    }

    Draw-Choice $Items $cur

    $result = $cur
    $confirmed = $false
    while ($true) {
        $key   = [Console]::ReadKey($true)
        $moved = $false

        if ($key.Key -eq [ConsoleKey]::Enter)  { $result = $cur; $confirmed = $true; break }
        if ($key.Key -eq [ConsoleKey]::Escape -or $key.Key -eq [ConsoleKey]::B) { $result = -1; break }
        if ($key.Key -eq [ConsoleKey]::G) { $result = -4; break }
        if ($key.Key -eq [ConsoleKey]::Tab) {
            if ($key.Modifiers -band [ConsoleModifiers]::Shift) {
                $result = -3; break
            } else {
                if ($confirmed) {
                    $result = -2; break
                } else {
                    Write-Host "  $($C.Yellow)→ Press Enter to confirm first, then Tab to advance$($C.Reset)" -NoNewline
                    Write-Host "`r" -NoNewline
                    Write-Host (" " * 60) -NoNewline
                    Write-Host "`r" -NoNewline
                }
            }
        }
        if ($key.Key -eq [ConsoleKey]::RightArrow) {
            if ($confirmed) {
                $result = -2; break
            } else {
                Write-Host "  $($C.Yellow)→ Press Enter to confirm first, then → to advance$($C.Reset)" -NoNewline
                Write-Host "`r" -NoNewline
                Write-Host (" " * 60) -NoNewline
                Write-Host "`r" -NoNewline
            }
        }
        if ($key.Key -eq [ConsoleKey]::LeftArrow) {
            $result = -3; break
        }

        if ($key.Key -eq [ConsoleKey]::UpArrow) {
            $newCur = [Math]::Max(0, $cur - 1)
            if ($newCur -ne $cur) { $cur = $newCur; $moved = $true }
        }
        if ($key.Key -eq [ConsoleKey]::DownArrow) {
            $newCur = [Math]::Min($Items.Count - 1, $cur + 1)
            if ($newCur -ne $cur) { $cur = $newCur; $moved = $true }
        }

        if ($moved) {
            $confirmed = $false
            $physLines = Menu-Height-C $Items
            Write-Host (cursor-up $physLines) -NoNewline
            Draw-Choice $Items $cur
        }
    }

    Write-Host $C.CursorOn -NoNewline
    Write-Host ""
    return $result
}

function Read-Checkboxes {
    param([string[]]$Items, [bool[]]$Checked, [string]$Prompt = "Select",
          [string]$FooterHint = "↑↓ navigate  Space toggle  Tab next  Shift+Tab prev  Enter confirm  Esc back")

    # Strip ANSI escape sequences from a string to get its visible length
    function Strip-Ansi([string]$s) {
        return [regex]::Replace($s, "\e\[[0-9;]*[mABCDEFGHJKLMnsuhr]", "")
    }

    # Calculate how many physical terminal lines a rendered row occupies.
    # Row format is: "  ▶  ●  <label>   " — prefix is 9 visible chars.
    function Row-Height([string]$label) {
        $tw        = try { [Console]::WindowWidth } catch { 80 }
        $prefix    = 9   # "  ▶  ●  " visible chars
        $visible   = (Strip-Ansi $label).Length + $prefix + 3  # trailing spaces
        return [Math]::Max(1, [Math]::Ceiling($visible / $tw))
    }

    # Total physical lines occupied by the full menu
    function Menu-Height([string[]]$items) {
        $h = 0
        foreach ($item in $items) { $h += Row-Height $item }
        return $h
    }

    Write-Host ""
    Write-Host "  $STEP_ACTIVE›$($C.Reset)  $($C.Bold)$Prompt$($C.Reset)  $($C.Gray)↑↓ navigate  Space toggle  Enter confirm  Tab next  Shift+Tab prev  → next  ← prev  G goto$($C.Reset)"
    Write-Host ""

    # Start cursor on the first pre-checked item (or 0)
    $firstChecked = 0
    for ($fi = 0; $fi -lt $Checked.Count; $fi++) {
        if ($Checked[$fi]) { $firstChecked = $fi; break }
    }
    $cur = $firstChecked

    Write-Host $C.CursorOff -NoNewline

    function Draw-Checks([string[]]$items, [bool[]]$checked, [int]$c) {
        foreach ($i in 0..($items.Count - 1)) {
            $box   = if ($checked[$i]) { "$($C.BrGreen)●$($C.Reset)" } else { "$($C.Gray)○$($C.Reset)" }
            $arrow = if ($i -eq $c)    { "$STEP_ACTIVE▶$($C.Reset)" } else { "  " }
            $label = if ($i -eq $c) {
                if ($checked[$i]) { "$($C.Bold)$($C.BrGreen)$($items[$i])$($C.Reset)" }
                else              { "$($C.Bold)$STEP_ACTIVE$($items[$i])$($C.Reset)" }
            } else {
                if ($checked[$i]) { "$($C.BrGreen)$($items[$i])$($C.Reset)" }
                else              { "$($C.Gray)$($items[$i])$($C.Reset)" }
            }
            Write-Host "  $arrow  $box  $label   "
        }
    }

    Draw-Checks $Items $Checked $cur

    $navResult = 0
    $confirmed = $false
    while ($true) {
        $key    = [Console]::ReadKey($true)
        $moved  = $false
        $toggled = $false

        if ($key.Key -eq [ConsoleKey]::Enter)    { $navResult = 0; $confirmed = $true; break }
        if ($key.Key -eq [ConsoleKey]::Escape -or $key.Key -eq [ConsoleKey]::B) { $navResult = -1; break }
        if ($key.Key -eq [ConsoleKey]::G) { $navResult = -4; break }
        if ($key.Key -eq [ConsoleKey]::Tab) {
            if ($key.Modifiers -band [ConsoleModifiers]::Shift) {
                $navResult = -3; break
            } else {
                if ($confirmed) {
                    $navResult = -2; break
                } else {
                    Write-Host "  $($C.Yellow)→ Press Enter to confirm first, then Tab to advance$($C.Reset)" -NoNewline
                    Write-Host "`r" -NoNewline
                    Write-Host (" " * 70) -NoNewline
                    Write-Host "`r" -NoNewline
                }
            }
        }
        if ($key.Key -eq [ConsoleKey]::RightArrow) {
            if ($confirmed) {
                $navResult = -2; break
            } else {
                Write-Host "  $($C.Yellow)→ Press Enter to confirm first, then → to advance$($C.Reset)" -NoNewline
                Write-Host "`r" -NoNewline
                Write-Host (" " * 70) -NoNewline
                Write-Host "`r" -NoNewline
            }
        }
        if ($key.Key -eq [ConsoleKey]::LeftArrow) {
            $navResult = -3; break
        }

        if ($key.Key -eq [ConsoleKey]::Spacebar) {
            $Checked[$cur] = -not $Checked[$cur]
            $toggled = $true
            $confirmed = $false
        }

        if ($key.Key -eq [ConsoleKey]::UpArrow) {
            $newCur = [Math]::Max(0, $cur - 1)
            if ($newCur -ne $cur) { $cur = $newCur; $moved = $true }
        }
        if ($key.Key -eq [ConsoleKey]::DownArrow) {
            $newCur = [Math]::Min($Items.Count - 1, $cur + 1)
            if ($newCur -ne $cur) { $cur = $newCur; $moved = $true }
        }

        # Only redraw when something actually changed
        if ($moved -or $toggled) {
            $physLines = Menu-Height $Items
            Write-Host (cursor-up $physLines) -NoNewline
            Draw-Checks $Items $Checked $cur
        }
    }

    Write-Host $C.CursorOn -NoNewline
    Write-Host ""
    if ($navResult -ne 0) { return $navResult }
    return $Checked
}

function Read-Line {
    param([string]$Prompt, [string]$Default = "", [string]$Hint = "")

    Write-Host ""
    if ($Hint) {
        Write-Host "  $STEP_ACTIVE›$($C.Reset)  $($C.Bold)$Prompt$($C.Reset)  $($C.Gray)$Hint$($C.Reset)"
    } else {
        Write-Host "  $STEP_ACTIVE›$($C.Reset)  $($C.Bold)$Prompt$($C.Reset)  $($C.Gray)Enter confirm  Esc back$($C.Reset)"
    }
    
    $displayDefault = if ($Default) { "  [$Default]" } else { "" }
    Write-Host "  $(dim "(leave empty to keep current value)")"
    Write-Host "  $displayDefault  " -NoNewline
    
    $inputStr = ""
    
    while ($true) {
        $key = [Console]::ReadKey($true)
        
        # Back navigation
        if ($key.Key -eq [ConsoleKey]::Escape) {
            Write-Host "`r" -NoNewline
            Write-Host (" " * ([Console]::WindowWidth - 1)) -NoNewline
            Write-Host "`r" -NoNewline
            return $null
        }
        
        # Confirm
        if ($key.Key -eq [ConsoleKey]::Enter) {
            Write-Host ""
            if (-not $inputStr -and $Default) { return $Default }
            return $inputStr.Trim()
        }
        
        # Backspace
        if ($key.Key -eq [ConsoleKey]::Backspace) {
            if ($inputStr.Length -gt 0) {
                $inputStr = $inputStr.Substring(0, $inputStr.Length - 1)
                Write-Host "`b `b" -NoNewline
            }
            continue
        }
        
        # Tab completion (accept default)
        if ($key.Key -eq [ConsoleKey]::Tab -and -not $inputStr) {
            $inputStr = $Default
            Write-Host $inputStr -NoNewline
            continue
        }
        
        # Printable characters
        if ($key.KeyChar -ge 32 -and $key.KeyChar -le 126) {
            $inputStr += $key.KeyChar
            Write-Host $key.KeyChar -NoNewline
        }
    }
}

function Read-Confirm {
    param([string]$Prompt, [bool]$Default = $false)
    
    $defaultStr = if ($Default) { "Y/n" } else { "y/N" }
    Write-Host ""
    Write-Host "  $STEP_ACTIVE›$($C.Reset)  $($C.Bold)$Prompt$($C.Reset)  $($C.Gray)($defaultStr)  Enter confirm  Esc back$($C.Reset)"
    
    while ($true) {
        $key = [Console]::ReadKey($true)
        
        if ($key.Key -eq [ConsoleKey]::Enter) {
            return $Default
        }
        if ($key.Key -eq [ConsoleKey]::Escape -or $key.Key -eq [ConsoleKey]::B) {
            return $null
        }
        
        if ($key.KeyChar -eq 'y' -or $key.KeyChar -eq 'Y') {
            Write-Host "  $(ok "Yes")"
            return $true
        }
        if ($key.KeyChar -eq 'n' -or $key.KeyChar -eq 'N') {
            Write-Host "  $(dim "No")"
            return $false
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# DATA LOADERS
# ═══════════════════════════════════════════════════════════════════════════════
function Load-Agents {
    $p = Join-Path $SCRIPT_DIR "agents.json"
    if (-not (Test-Path $p)) { Write-Fail "agents.json not found: $p"; exit 1 }
    $data = Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json
    return $data.agents
}

function Load-SkillPatterns {
    $p = Join-Path $SCRIPT_DIR "skills.json"
    if (-not (Test-Path $p)) { Write-Fail "skills.json not found: $p"; exit 1 }
    $data = Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json
    return $data.skills
}


# ═══════════════════════════════════════════════════════════════════════════════
# PROJECT TYPE REGISTRY
# Each type carries: id, label, description, architecture, nfr, securityThreats,
#                    qualityGates, observabilityFocus, androidGradle flag
# ═══════════════════════════════════════════════════════════════════════════════
$PROJECT_TYPES = @(
    @{
        id          = "web-app"
        label       = "Web Application"
        description = "Server-rendered or SPA — user-facing, auth, database, deployment"
        architecture = @"
### Pattern
MVC or layered architecture. Separate concerns: routing, business logic, data access.
Never put business logic in controllers or templates.

### Service boundaries
- Presentation layer: templates/components, no direct DB access
- Application layer: use-case orchestration, input validation
- Domain layer: business rules, pure functions, no framework dependencies
- Infrastructure layer: DB, cache, external APIs, file storage

### State management
Server-side session or JWT — define in SECURITY.md. Never store sensitive state client-side.

### API contracts
Define request/response shapes before implementation. Version all public endpoints.
Breaking changes require a new version — never silently change existing contracts.
"@
        nfr = @"
## Non-Functional Requirements

### Performance
- Page load (LCP): < 2.5 s on 4G connection
- Time to first byte (TTFB): < 500 ms
- API response (p95): < 300 ms for read operations, < 1 s for writes
- Database queries: no query > 100 ms in production; add indexes before shipping

### Availability
- Target uptime: 99.9% (< 8.7 h downtime/year)
- Graceful degradation: define which features degrade vs which hard-fail
- Health endpoint: `/health` must return 200 with DB + cache connectivity status

### Scalability
- Define expected concurrent users at launch and at 10x growth
- Stateless application layer — horizontal scaling must be possible without rework
- Cache strategy required for any read path > 50 ms or hit more than 100/min

### Security
- See SECURITY.md for full threat model
- All inputs validated server-side — never trust client
- HTTPS enforced; HSTS header required
- Content-Security-Policy header defined before launch

### Reliability
- All external API calls must have timeout + retry logic with exponential backoff
- Database connection pooling configured — not default settings
- Background jobs must be idempotent — safe to re-run on failure
"@
        securityThreats = @"
## Threat Model — Web Application

### Authentication surface
- Brute force / credential stuffing: rate-limit login endpoints; lockout after N failures
- Session fixation: regenerate session ID on login
- JWT secret exposure: rotate regularly; store in secrets manager, not .env committed to git
- Password storage: bcrypt/argon2 with appropriate cost factor — never MD5/SHA1

### Input handling
- SQL injection: parameterised queries always — no string concatenation in queries
- XSS: escape all user output; set Content-Security-Policy
- CSRF: token per form; SameSite cookie attribute
- Path traversal: validate and sanitise all file path inputs

### Data exposure
- PII in logs: audit all log statements — never log passwords, tokens, or full PII
- API over-fetching: return only fields the client needs; no raw DB object serialisation
- Error messages: production errors must not expose stack traces or internal paths

### Infrastructure
- Dependency vulnerabilities: run dependency audit in CI (``npm audit`, ``composer audit`, or equivalent) — block on HIGH
- Secrets in code: pre-commit hook or CI scan for committed secrets
- CORS misconfiguration: whitelist specific origins — never ``Access-Control-Allow-Origin: *` in production
"@
        qualityGates = @"
## Production Quality Gates — Web Application

An agent must not mark any feature complete without these gates passing.

### Code quality
- [ ] No linter errors or warnings (zero tolerance in CI)
- [ ] No ``console.log` / debug statements in production code
- [ ] All functions < 50 lines; cyclomatic complexity < 10
- [ ] No commented-out code committed

### Testing
- [ ] Unit test coverage ≥ 80% on business logic layer
- [ ] Integration tests cover all API endpoints (happy path + auth failure + validation failure)
- [ ] No test stubs or skipped tests without documented reason
- [ ] All tests pass in CI — no local-only passes

### Security
- [ ] Dependency audit passes with no HIGH or CRITICAL vulnerabilities
- [ ] OWASP Top 10 checklist reviewed for each new feature
- [ ] No secrets, tokens, or PII in source code or logs (confirmed by scan)
- [ ] Authentication and authorisation tested explicitly — not assumed

### Performance
- [ ] No N+1 queries (reviewed via query log or ORM debug mode)
- [ ] All new DB queries have EXPLAIN output reviewed
- [ ] Lighthouse score ≥ 85 for Performance, Accessibility, Best Practices

### Operability
- [ ] All new endpoints emit structured log events (request, response code, duration)
- [ ] Errors emit to observability stack with stack trace and request context
- [ ] Health endpoint reflects new dependencies
- [ ] Environment variables documented in ENVIRONMENTS.md
- [ ] README updated with any new setup steps

### Definition of done
A feature is production-ready when all boxes above are checked, a peer review
(human or second agent) has verified the implementation against the skill spec,
and the deployment has been validated in staging before production promotion.
"@
        entropyControl = "- **Component purity:** UI components must not contain business logic or make direct API calls. Delegate to hooks or services."
        observabilityFocus = @"
## Observability Requirements — Web Application

### Structured logging
Every request must emit a structured log event containing:
``timestamp`, ``level`, ``request_id`, ``method`, ``path`, ``status_code`,
``duration_ms`, ``user_id` (if authenticated), ``error` (if applicable).

Log levels: ERROR for exceptions, WARN for degraded behaviour,
INFO for significant business events, DEBUG for development only (never in production).

Never log: passwords, tokens, full credit card numbers, raw PII.
Log: anonymised user IDs, event types, durations, error codes.

### Metrics (expose or emit)
- Request rate (rpm) per endpoint
- Error rate (%) per endpoint — alert if > 1% sustained for 5 min
- p50 / p95 / p99 response time per endpoint
- Active sessions / DAU (business metric)
- DB connection pool utilisation — alert if > 80%

### Health checks
``GET /health` — returns JSON: `{ status, db, cache, timestamp }`
``GET /ready` — returns 200 only when fully initialised (used by load balancer)

### Alerting thresholds (define before launch)
- Error rate > 1% for 5 min → page on-call
- p95 response time > 2 s for 5 min → alert
- Health check failure → immediate page
- Disk / memory > 85% → alert
"@
        androidGradle = $false
    },
    @{
        id          = "api-service"
        label       = "API Service"
        description = "Headless backend consumed by other systems — contracts are everything"
        architecture = @"
### Pattern
Layered service architecture. Each layer has a single direction of dependency.

### Layers
- Transport layer: HTTP handlers, request parsing, response serialisation — no business logic
- Application layer: use-case orchestration, input validation, auth enforcement
- Domain layer: business rules, entities, value objects — no framework or DB imports
- Infrastructure layer: repositories, external API clients, queue producers

### Contract discipline
Every endpoint must have a documented request schema and response schema.
Version all endpoints from day one: `/api/v1/`. Adding fields is non-breaking.
Removing or renaming fields requires a new version — never in-place.

### Error contract
All errors return a consistent envelope:
`{ error: { code: string, message: string, details?: object } }`
HTTP status codes must be semantically correct — 4xx for client errors, 5xx for server.
"@
        nfr = @"
## Non-Functional Requirements

### Performance
- API response (p95): < 200 ms for read, < 500 ms for write
- Throughput: define expected requests/second at launch and 10x
- No synchronous operations blocking the event loop > 50 ms

### Availability
- Target uptime: 99.95% for internal services, 99.99% for customer-facing APIs
- Circuit breaker required on all downstream service calls
- Graceful shutdown: drain in-flight requests before terminating

### Contract stability
- Semantic versioning for all breaking changes
- Deprecation period: minimum 30 days notice before removing endpoints
- Changelog entry required for every release

### Security
- See SECURITY.md — authentication on every non-public endpoint
- Rate limiting per API key and per IP
- Input validation at the transport layer — never trust caller

### Reliability
- All external calls: timeout + retry (exponential backoff, max 3 attempts)
- Idempotency keys on any mutation endpoint that could be retried
- Dead letter queue for any async message consumer
"@
        securityThreats = @"
## Threat Model — API Service

### Authentication
- Missing auth checks: every route must explicitly declare its auth requirement
- Token leakage: short expiry (15 min access tokens); refresh token rotation
- Privilege escalation: authorisation checked at the use-case layer, not just transport

### Input
- Injection (SQL, NoSQL, command): parameterised queries everywhere — zero exceptions
- Schema validation: reject requests that don't match schema before any processing
- Oversized payloads: body size limits enforced at transport layer

### Rate and abuse
- API key stuffing: rate limit per key, per IP, and globally
- Enumeration: consistent response times on auth failures (timing attack prevention)
- Replay attacks: nonce or timestamp validation on sensitive operations

### Infrastructure
- Internal service authentication: services authenticate to each other — no implicit trust
- Secret rotation: API keys and DB credentials must be rotatable without downtime
- Dependency audit: block deploys on HIGH/CRITICAL CVEs in CI
"@
        qualityGates = @"
## Production Quality Gates — API Service

### Contract
- [ ] OpenAPI / schema spec exists and matches implementation (validated in CI)
- [ ] All endpoints versioned under `/api/vN/`
- [ ] All error responses conform to standard error envelope
- [ ] Breaking changes documented in CHANGELOG.md before merging

### Testing
- [ ] Unit tests on all domain logic (≥ 85% coverage)
- [ ] Contract tests for every endpoint (request validation + response shape)
- [ ] Integration tests cover: happy path, auth failure, validation failure, downstream timeout
- [ ] Load test performed before production — baseline latency and error rate documented

### Security
- [ ] Every endpoint has explicit auth requirement declared
- [ ] Rate limiting configured and tested
- [ ] No HIGH/CRITICAL CVEs in dependency audit
- [ ] Secrets confirmed absent from source (automated scan in CI)

### Operability
- [ ] Structured logs on every request/response
- [ ] Distributed tracing propagated (trace ID in request/response headers)
- [ ] Health + readiness endpoints implemented
- [ ] Graceful shutdown implemented and tested
- [ ] All env vars documented in ENVIRONMENTS.md

### Definition of done
Implementation matches OpenAPI spec. Contract tests pass. Load test baseline
documented. Deployed and validated in staging. No open HIGH security findings.
"@
        entropyControl = "- **Strict boundaries:** All request handlers must go through the middleware chain for auth/validation. No direct database access from controllers."
        observabilityFocus = @"
## Observability Requirements — API Service

### Structured logging
Every request: ``request_id`, ``method`, ``path`, ``status`, ``duration_ms`,
``caller_service` (for service-to-service), ``user_id` or ``api_key_hash`.

### Distributed tracing
Propagate ``X-Request-ID` and ``X-Trace-ID` headers on all inbound and outbound calls.
Log both IDs on every event. Never generate a new trace ID mid-chain.

### Metrics
- Request rate, error rate, p95 latency per endpoint
- Downstream call duration and error rate per dependency
- Queue depth and consumer lag (if using message queue)

### Alerting
- Error rate > 0.5% for 3 min → alert
- p95 latency > 500 ms for 5 min → alert
- Any 5xx spike > 10 in 60 s → page
- Circuit breaker open → immediate alert
"@
        androidGradle = $false
    },
    @{
        id          = "ml-ai"
        label       = "ML / AI System"
        description = "Model pipeline, data flows, reproducibility, inference serving"
        architecture = @"
### Pattern
Pipeline architecture. Each stage is independently testable and replaceable.

### Stages
- Data ingestion: collect, validate schema, store raw — never transform raw data in place
- Preprocessing: deterministic transforms, logged inputs and outputs
- Training / fine-tuning: reproducible — seed, config, and data version locked per run
- Evaluation: held-out test set, metrics logged to experiment tracker
- Serving: inference API with input validation, output confidence scores, fallback

### Reproducibility contract
Every training run must log: data version, preprocessing config, model config,
random seed, framework versions, hardware spec. A run is not valid without these.

### Data contracts
Define schema for every pipeline boundary: raw input, preprocessed features,
model input tensor shape, model output shape. Validate at each boundary — never assume.
"@
        nfr = @"
## Non-Functional Requirements

### Performance
- Inference latency (p95): define acceptable threshold for the use case
- Throughput: define requests/second the serving layer must sustain
- Preprocessing pipeline: define acceptable wall-clock time per batch

### Reliability
- Inference fallback: define behaviour when model is unavailable (cached result, default, error)
- Data pipeline: failed runs must not corrupt existing processed data
- Model rollback: previous model version must be deployable in < 15 min

### Reproducibility
- Any experiment must be re-runnable from config alone
- Model artifacts versioned and stored with metadata (not just weights)
- Dataset versions pinned — preprocessing must not silently change training data

### Scalability
- Inference serving: horizontal scaling must work without model reload overhead
- Batch jobs: define max acceptable queue depth before scaling triggers

### Data quality
- Input validation at inference time — reject malformed inputs with structured error
- Data drift monitoring: define metrics and alert thresholds
- Label quality checks before any training run
"@
        securityThreats = @"
## Threat Model — ML / AI System

### Data
- Training data poisoning: validate data provenance; log data source and version per run
- PII in training data: audit datasets before use; pseudonymise where required
- Data exfiltration: restrict access to raw datasets; audit trail on access

### Model
- Model theft via API: rate limit inference endpoint; monitor for systematic extraction patterns
- Adversarial inputs: define input validation rules; test with adversarial examples pre-launch
- Prompt injection (LLM systems): sanitise all user-supplied input before passing to model

### Infrastructure
- Model artifact tampering: checksum verification before loading weights
- Dependency vulnerabilities: ML dependencies (PyTorch, TF, HuggingFace) have frequent CVEs — audit in CI
- GPU/compute abuse: authentication required on all inference endpoints; cost alerting configured

### Output
- Sensitive content in outputs: define content policy and filtering before production
- Model hallucination in high-stakes contexts: human review gates defined where applicable
"@
        qualityGates = @"
## Production Quality Gates — ML / AI System

### Reproducibility
- [ ] Any training run reproducible from config file alone (verified by re-run)
- [ ] Data version pinned and logged for every model in production
- [ ] Framework and dependency versions locked (requirements.txt / pyproject.toml pinned)

### Model quality
- [ ] Evaluation metrics defined and baselined before first production deployment
- [ ] Test set is held-out and never seen during training or hyperparameter search
- [ ] Model performance regression test in CI — deploy blocked if metrics drop > threshold
- [ ] Bias and fairness evaluation completed for models making decisions about people

### Serving
- [ ] Input validation rejects malformed requests with structured error
- [ ] Inference latency SLA documented and tested under expected load
- [ ] Fallback behaviour implemented and tested
- [ ] Model rollback procedure documented and tested

### Data pipeline
- [ ] Schema validation at every pipeline boundary
- [ ] Failed runs do not modify existing processed data
- [ ] Data access audit trail in place

### Definition of done
Model meets baseline metrics on held-out test set. Serving latency SLA validated
under load. Fallback and rollback tested. Data pipeline schema-validated end-to-end.
No HIGH security findings. Deployed and monitored in staging for 48 h before production.
"@
        entropyControl = "- **Idempotency & Isolation:** Data transformations must be repeatable. Model inferences must be isolated from state mutation."
        observabilityFocus = @"
## Observability Requirements — ML / AI System

### Training runs
Every run must emit: run ID, data version, config hash, start time, end time,
final metrics (loss, accuracy, F1 or equivalent), hardware utilisation.
Use an experiment tracker (MLflow, W&B, or equivalent) — not ad-hoc logging.

### Inference serving
Per-request: ``request_id`, ``model_version`, ``input_shape`, ``inference_duration_ms`,
``output_confidence` (where applicable), ``fallback_triggered` (bool).

### Data pipeline
Per batch: ``pipeline_version`, ``input_record_count`, ``output_record_count`,
``validation_failures`, ``duration_s`. Alert if validation failure rate > 1%.

### Model monitoring (production)
- Prediction distribution drift: alert if output distribution shifts > threshold
- Input feature drift: compare live input distribution to training distribution weekly
- Error rate on labelled feedback: track where available

### Alerting
- Inference p95 > SLA threshold for 5 min → alert
- Fallback triggered > 1% of requests → alert
- Data pipeline failure → page
- Model metrics regression in CI → block deploy
"@
        androidGradle = $false
    },
    @{
        id          = "cli-tool"
        label       = "CLI Tool"
        description = "Developer tooling — distribution, cross-platform, UX, reliability"
        architecture = @"
### Pattern
Command-router + handler architecture. Each command is an isolated handler.

### Structure
- Entry point: argument parsing, help generation — no logic
- Command handlers: one file per command, pure functions where possible
- Core library: reusable logic with no CLI dependencies (testable in isolation)
- Output layer: all stdout/stderr formatting in one place — never scattered

### Contract
Commands must: accept `--help`, return exit code 0 on success / non-zero on error,
emit structured output on `--json` flag where applicable, never crash on bad input.

### Cross-platform
Test on Windows (PowerShell), macOS (zsh), and Linux (bash).
Never hardcode path separators. Use the platform's path APIs.
"@
        nfr = @"
## Non-Functional Requirements

### Performance
- Cold start: < 500 ms from invocation to first output
- Command execution: define acceptable wall-clock time per command category
- No blocking I/O on the main thread without a progress indicator

### Reliability
- Never corrupt user data on failure — write to temp then move
- Exit codes: 0 success, 1 general error, 2 misuse, 126 permission denied, 127 not found
- Ctrl-C handled gracefully — no dangling processes or corrupted state

### Distribution
- Single binary or minimal install (define install method before building)
- Auto-update mechanism or clear version check with upgrade path
- Backward compatibility: flags and output format stable across minor versions

### UX
- `--help` on every command and subcommand
- Errors go to stderr; data goes to stdout
- Colour output gated behind TTY check — never colour in piped output
- `--dry-run` on any destructive operation
"@
        securityThreats = @"
## Threat Model — CLI Tool

### Input
- Shell injection: never pass user input to shell commands via string interpolation
- Path traversal: validate all path arguments; resolve and confirm within expected boundaries
- Malicious config files: validate config file schema before using values

### Credentials
- Secrets in command history: never accept secrets as positional args — use env vars or prompts
- Credential storage: use OS keychain (Credential Manager / Keychain / Secret Service) not plaintext files
- Token scope: request minimum required permissions for any OAuth/API token

### Distribution
- Supply chain: verify checksums of downloaded dependencies in CI
- Binary signing: sign release artifacts; verify on install where platform supports
- Update mechanism: verify update package integrity before applying
"@
        qualityGates = @"
## Production Quality Gates — CLI Tool

### Correctness
- [ ] Every command tested: happy path, bad input, missing permissions, missing dependencies
- [ ] Exit codes correct and documented
- [ ] `--help` output accurate and complete for every command

### Cross-platform
- [ ] Tested on Windows, macOS, Linux in CI
- [ ] No hardcoded path separators or OS-specific assumptions
- [ ] TTY detection correct — colour disabled in piped output

### Reliability
- [ ] No data corruption on Ctrl-C or unexpected exit (verified with chaos test)
- [ ] All writes atomic (temp file + move)
- [ ] Graceful error messages — no raw stack traces to end users

### Distribution
- [ ] Install method documented and tested on clean machine
- [ ] Version check / upgrade path documented
- [ ] Release artifact signed and checksum published

### Definition of done
All commands pass cross-platform CI. No raw stack traces reachable by user.
Install tested on clean machine. Help text reviewed for accuracy.
"@
        entropyControl = "- **Headless first:** All logic must be executable without a TUI/UI. Separate the engine from the interface."
        observabilityFocus = @"
## Observability Requirements — CLI Tool

### Logging
Debug logs behind `--verbose` / `--debug` flag — never emitted by default.
Errors to stderr with enough context to diagnose without a stack trace.
Structured log file (opt-in) for enterprise users: `--log-file path`.

### Telemetry (opt-in only)
If telemetry is collected: explicit opt-in required, documented clearly,
no PII, no file contents, only: command name, duration, exit code, OS, version.
Opt-out must work without network access.

### Version reporting
`--version` emits: tool version, runtime version, OS, architecture.
Useful for support and bug reports.
"@
        androidGradle = $false
    },
    @{
        id          = "fullstack"
        label       = "Full-Stack Platform"
        description = "Web frontend + API backend + optional ML — monorepo or multi-repo"
        architecture = @"
### Pattern
Layered full-stack with clear interface contracts between tiers.

### Tiers
- Frontend: component-based, talks only to API (never directly to DB)
- API layer: business logic, auth, validation — the single source of truth for rules
- Data layer: DB, cache, file storage — accessed only through repositories
- Optional ML layer: inference API consumed by the application layer — not directly by frontend

### Monorepo vs multi-repo decision
Decide before first commit and record in memory/decisions/.
Monorepo: shared tooling, atomic cross-tier changes, one CI pipeline.
Multi-repo: independent deployments, stronger team boundaries, more DevOps complexity.

### Shared contracts
API contract (OpenAPI or GraphQL schema) is the boundary between frontend and backend.
Frontend and backend teams (or agents) must not share implementation code — only contracts.
Schema changes require coordination and versioning — never silent.

### Deployment topology
Define environments before building: local, staging, production.
Each environment must be independently deployable.
Feature flags preferred over long-lived feature branches.
"@
        nfr = @"
## Non-Functional Requirements

### Performance
- Frontend: LCP < 2.5 s, TTI < 3.5 s on 4G
- API: p95 < 300 ms reads, < 800 ms writes
- Search / complex queries: < 1 s with caching; define cache TTL per query type

### Availability
- Target: 99.9% uptime across the platform
- Degraded mode: frontend must function (read-only or cached) if API is temporarily unavailable
- DB failover: < 30 s automatic failover; no manual intervention required

### Scalability
- Stateless API and frontend servers — horizontal scaling without rework
- DB read replicas for read-heavy paths
- CDN for all static assets — no static files served by application server

### Security
- See SECURITY.md — authentication touches both frontend and API
- CORS policy explicitly defined — frontend origin whitelisted, not wildcard
- All secrets in secrets manager — no .env files in production

### Data
- Backup: automated daily backups with tested restore procedure
- Retention: define data retention policy before launch — especially for PII
- GDPR / data compliance: define applicable regulations before collecting user data
"@
        securityThreats = @"
## Threat Model — Full-Stack Platform

### Frontend
- XSS: escape all user-generated content; strict Content-Security-Policy
- Dependency hijacking: lock frontend dependencies; audit regularly
- Sensitive data in browser storage: never store tokens or PII in localStorage

### API
- Auth bypass: every protected route tested for auth enforcement
- Mass assignment: whitelist accepted fields — never bind request body directly to model
- IDOR: authorisation checked at object level — not just route level

### Data
- SQL / NoSQL injection: parameterised queries everywhere
- PII exposure in logs: audit all log statements across frontend and backend
- Database credentials: rotatable without downtime; never in source code

### Infrastructure
- CORS misconfiguration: tested explicitly — not assumed
- Secret sprawl: single secrets manager; no secrets in CI environment variables as plain text
- Dependency vulnerabilities: automated audit in CI for both frontend and backend; block on HIGH/CRITICAL
"@
        qualityGates = @"
## Production Quality Gates — Full-Stack Platform

### Frontend
- [ ] Lighthouse ≥ 85 (Performance, Accessibility, Best Practices, SEO)
- [ ] No console errors in production build
- [ ] All user-facing flows tested (E2E with Cypress / Playwright)
- [ ] WCAG 2.1 AA accessibility validated on core flows

### API
- [ ] OpenAPI spec exists, validated against implementation in CI
- [ ] All endpoints: auth tested, validation tested, error shape correct
- [ ] No N+1 queries; query log reviewed for new endpoints
- [ ] p95 latency within SLA under load test

### Data
- [ ] DB migrations tested: up and down
- [ ] Backup restore tested before production launch
- [ ] Data retention policy implemented and verified

### Security
- [ ] OWASP Top 10 reviewed for both frontend and API
- [ ] No HIGH/CRITICAL CVEs across all dependency trees
- [ ] CSP, HSTS, X-Frame-Options, X-Content-Type-Options headers set

### Operability
- [ ] Centralised logging across all tiers with correlation IDs
- [ ] Alerting configured for: error rate, latency, health check failures
- [ ] Runbook exists for: deploy, rollback, DB failover, incident response

### Definition of done
All tier gates pass. E2E tests green. Load test baseline documented.
Staging validated for 24 h. Security scan clean. Runbook reviewed.
"@
        entropyControl = "- **Separation of concerns:** Strict boundary between frontend components and backend services. Share only API contracts/types."
        observabilityFocus = @"
## Observability Requirements — Full-Stack Platform

### Correlation
Every request that originates on the frontend must carry a ``X-Request-ID` through
to the API and all downstream services. Log this ID at every tier. Essential for
tracing a user action from browser to database.

### Frontend
- Real User Monitoring (RUM): Core Web Vitals, JS errors, route timing
- Client-side errors: capture with source maps; group by error message
- User flows: track conversion funnel metrics for core business flows

### API
- Structured request logs: method, path, status, duration, user ID, request ID
- Slow query log: any query > 100 ms logged with query text and explain plan
- External call log: every outbound HTTP call logged with duration and status

### Infrastructure
- Database: connection pool saturation, replication lag, long-running queries
- Cache: hit rate, eviction rate, memory utilisation
- CDN: cache hit rate, origin error rate

### Alerting
- Any tier error rate > 1% for 5 min → alert
- API p95 > SLA for 5 min → alert
- Health check failure at any tier → page
- DB replication lag > 30 s → alert
"@
        androidGradle = $false
    },
    @{
        id          = "android"
        label       = "Android App"
        description = "Kotlin + Jetpack Compose · Clean Architecture · Hilt · KSP · Coroutines/Flow"
        architecture = @"
### Pattern
Clean Architecture with strict layer boundaries. No framework leakage into domain.

### Layers (inner to outer — dependency rule: outer depends on inner, never reversed)
- **Domain layer** (``domain/`): entities, use cases, repository interfaces, value objects
  - Pure Kotlin — zero Android framework imports. No Context, no ViewModel here.
  - Use cases are single-responsibility: one public ``invoke()` or ``execute()` function.

- **Data layer** (``data/`): repository implementations, data sources (local + remote)
  - Room DAOs for local, Retrofit services for remote
  - Data models (DTOs) mapped to domain entities — never pass DTOs to domain or UI
  - Repository decides: cache first, network first, or merged strategy

- **Presentation layer** (``presentation/`): ViewModels, Compose screens, UI state
  - ViewModel exposes ``StateFlow<UiState>` — one sealed class per screen
  - Screen composables observe state; no business logic in composables
  - Navigation: single-activity, Compose Navigation with typed routes

### Dependency injection
Hilt throughout. Module per layer: ``DomainModule`, ``DataModule`, ``NetworkModule`.
Never instantiate dependencies manually. Never pass Application context down into domain.

### Async
Coroutines + Flow everywhere. ``viewModelScope` in ViewModels.
``Dispatchers.IO` for data operations; ``Dispatchers.Main` for UI updates (via ``flowOn`).
No ``GlobalScope`. No ``runBlocking` outside tests.

### State management
Single source of truth: Room + StateFlow. UI state derived from repository Flow.
Never duplicate state between ViewModel and composable.
"@
        nfr = @"
## Non-Functional Requirements

### Performance
- App startup (cold start): < 2 s on mid-range device (e.g. 2021 Pixel 4a equivalent)
- Frame rate: 60 fps sustained; no jank on scroll or animation (no dropped frames > 1%)
- ANR (Application Not Responding): zero ANRs in production — all I/O off main thread
- APK size: define size budget before building; use R8 shrinking on release

### Availability and reliability
- Crash-free sessions: ≥ 99.5% (target 99.9% post-stabilisation)
- Offline mode: define which features work offline and which degrade gracefully
- Data sync conflict resolution: define strategy before implementing sync

### Compatibility
- ``minSdk`: 26 (Android 8.0) — covers > 95% of active devices as of 2025
- ``targetSdk`: latest stable (35 as of bootstrap date)
- Test on: small screen (5"), large screen (6.7"), foldable if applicable
- Accessibility: TalkBack support required for all interactive elements

### Security
- See SECURITY.md — mobile threat model differs from web
- ProGuard/R8 enabled on all release builds — rules maintained in GRADLE.md
- Certificate pinning required for sensitive API endpoints

### Battery and resources
- No wake locks held longer than necessary
- Background work via WorkManager only — no foreground services without user awareness
- Network requests batched where possible — no polling; use push or WorkManager
"@
        securityThreats = @"
## Threat Model — Android Application

### Local storage
- Sensitive data in SharedPreferences: never store tokens, keys, or PII in SharedPreferences
  Use EncryptedSharedPreferences or Android Keystore for sensitive values
- SQLite exposure: database file accessible on rooted devices — encrypt sensitive DBs
- Log exposure: never log tokens, passwords, or PII — logs readable by other apps on some devices

### Network
- Certificate pinning bypass: implement pinning with OkHttp CertificatePinner; test with proxy
- Plaintext traffic: ``android:usesCleartextTraffic="false"` in manifest for production
- Man-in-the-middle: validate server certificate chain; do not accept self-signed in production

### Application
- Exported components: audit all Activities, Services, Receivers in manifest —
  exported components must validate caller; unexported by default
- Deep link injection: validate and sanitise all deep link parameters before use
- WebView: disable JavaScript if not needed; never load untrusted URLs; ``setAllowFileAccess(false)`

### Build
- Debug build exposure: ``debuggable false` enforced in release build type
- API keys in source: never hardcode API keys — use BuildConfig fields from secrets manager
- Obfuscation: R8 minification enabled for release; keep rules audited (see GRADLE.md)
"@
        qualityGates = @"
## Production Quality Gates — Android Application

### Build
- [ ] Release build compiles with R8 minification enabled — no crashes introduced by obfuscation
- [ ] ``debuggable false` in release build type (verified in build.gradle.kts)
- [ ] No hardcoded API keys or secrets in source or BuildConfig committed to git
- [ ] ``minSdk` and ``targetSdk` correct per CONTEXT.md; lint passes with no errors

### Code quality
- [ ] All Kotlin lint checks pass — no suppressed warnings without documented reason
- [ ] Detekt or ktlint configured and passing in CI
- [ ] No coroutine antipatterns: no ``runBlocking` in production code, no ``GlobalScope`
- [ ] No business logic in Composables or Activities — domain logic in domain layer only

### Testing
- [ ] Unit tests on all use cases (≥ 85% domain layer coverage)
- [ ] ViewModel tests with fake repositories — no real network or DB in unit tests
- [ ] UI tests (Compose testing) for critical user flows
- [ ] Robolectric or instrumented tests for DB migrations

### Performance
- [ ] Cold start time measured on reference device and within SLA
- [ ] No ANRs reproducible in QA testing — StrictMode enabled in debug builds
- [ ] No memory leaks (LeakCanary clean in debug build before release)
- [ ] R8 APK size within defined size budget

### Play Store compliance
- [ ] Target SDK is current year's requirement (Google updates annually — check before release)
- [ ] Permissions declared are the minimum required — each justified in code comment
- [ ] Privacy policy URL set in Play Console before any data collection
- [ ] Content rating completed in Play Console

### Definition of done
Release build passes all lint and tests. LeakCanary clean. Cold start within SLA.
No HIGH security findings. Tested on physical device (not only emulator).
Internal test track validated before production promotion.
"@
        entropyControl = "- **Thread safety:** Never perform blocking I/O on the main thread. Always inject dispatchers."
        observabilityFocus = @"
## Observability Requirements — Android Application

### Crash reporting
Firebase Crashlytics (or equivalent) integrated before first production release.
Every crash must include: device model, OS version, app version, user journey
(last 5 screen visits), non-PII custom keys relevant to the crash context.

### Performance monitoring
Firebase Performance Monitoring or equivalent:
- App start time (cold, warm, hot)
- Screen rendering time per screen
- Network request duration and failure rate per endpoint

### Analytics (define before collecting)
Event tracking schema defined in a separate ``ANALYTICS.md` or skills spec.
Every event: ``event_name`, ``screen_name`, ``timestamp`, anonymised ``user_id`.
No PII in analytics events. Legal basis for collection documented.

### Error logging
Non-fatal errors logged to crash reporter with context.
Never log PII. Log: error code, feature area, anonymised user state.

### Alerting
- Crash-free session rate drops below threshold → alert in Firebase
- ANR rate > 0.1% → investigate immediately
- Force close rate increase → Play Console alert configured
"@
        androidGradle = $true
    },
    @{
        id          = "desktop-windows"
        label       = "Desktop App (Windows)"
        description = "Native Windows application — WinUI 3 / WPF · MVVM · MSIX · Windows App SDK"
        architecture = @"
### Pattern
MVVM (Model-View-ViewModel) with strict separation between XAML UI and business logic.

### Layers
- **View**: XAML files and code-behind (UI only)
- **ViewModel**: Observes models, provides data for binding, handles UI commands
- **Model**: Domain logic, data entities, services
- **Infrastructure**: Native Windows APIs, local File IO, Windows Registry, SQLite

### Windows App SDK / WinUI 3
Prefer WinUI 3 for new applications. Use Community Toolkit for MVVM and common UI patterns.
Dependency Injection via `Microsoft.Extensions.DependencyInjection`.

### State management
Local state in ViewModels with `INotifyPropertyChanged`. Persistent state in local SQLite or JSON settings.
"@
        nfr = @"
## Non-Functional Requirements

### Performance
- Cold start: < 1.5 s to first interactive window
- UI responsiveness: 60 fps; no blocking calls on the UI thread
- Memory footprint: define baseline for idle state and peak usage

### Reliability
- Graceful handling of Windows Sleep/Hibernate transitions
- Atomic file writes for user data and settings
- Error reporting via Windows Event Log or integrated telemetry

### Compatibility
- Windows 10 version 1809 (build 17763) as minimum (check project requirements)
- Support for x64 and ARM64 architectures
- High DPI awareness and per-monitor scaling support

### Security
- Use Windows Credential Manager for sensitive user tokens—never plain text files
- DLL hijacking prevention: secure dependency loading
- Application signing for all distribution packages
"@
        securityThreats = @"
## Threat Model — Windows Desktop App

### Input and Files
- Path traversal: validate all file path inputs; resolve relative to app data folders
- Untrusted file formats: sanitise and validate any data loaded from user-supplied files
- Command injection: never pass unvalidated user input to `Process.Start` or shell commands

### Credentials
- Insecure storage: secrets stored in `.config` or `.xml` are easily extracted
- Memory scrapers: clear sensitive data from memory as soon as possible after use

### Distribution
- DLL Hijacking: avoid loading DLLs from search paths that include user-writable folders
- Package tampering: verify MSIX package integrity before installation or update
- Manifest spoofing: audit `AppxManifest.xml` for excessive capabilities/permissions
"@
        qualityGates = @"
## Production Quality Gates — Windows Desktop App

### Build and Package
- [ ] Compiles for both x64 and ARM64 architectures
- [ ] MSIX package created and validated with Windows App Certification Kit
- [ ] Application and installer signed with a valid code-signing certificate

### Code Quality
- [ ] No blocking synchronous I/O on the UI thread
- [ ] No hardcoded file paths — use `Environment.SpecialFolder`
- [ ] Linter/Analyser (e.g. StyleCop, Roslyn) passes with no warnings

### Testing
- [ ] Unit tests for all ViewModels and Domain logic (≥ 80% coverage)
- [ ] UI Automation tests for critical user flows (WinAppDriver or equivalent)
- [ ] Installer 'Upgrade' and 'Uninstall' paths verified for data persistence

### Definition of Done
Signed MSIX package ready for distribution. App Certification Kit passes.
Unit and UI tests green. No blocking I/O on main thread.
"@
        entropyControl = "- **Process separation:** Keep UI rendering on the main thread, but push all heavy computation to background workers."
        observabilityFocus = @"
## Observability Requirements — Windows Desktop App

### Logging
Centralised logging using a library like Serilog.
- **File logs**: stored in `%LocalAppData%\<AppName>\Logs`; auto-rotate and prune
- **Event Log**: log critical system-level errors to Windows Event Viewer

### Telemetry (Opt-in)
Non-PII telemetry covering:
- Application version, OS version, and Architecture (x64/ARM64)
- Feature usage frequency and session duration
- Crash stacks and exception types (automated minidump collection for native crashes)

### Versioning
`--version` (or 'About' box) must report: App Version, SDK Version, Runtime Version.
"@
        androidGradle = $false
    }
)

# ═══════════════════════════════════════════════════════════════════════════════
# PROJECT SCANNER
# ═══════════════════════════════════════════════════════════════════════════════
function Invoke-ProjectScan {
    param([string]$ScanPath, [bool]$Deep = $false)

    $depth = if ($Deep) { 5 } else { 2 }
    Write-Host ""
    Write-Host "  $(hi "Scanning") $ScanPath $(dim "(depth: $depth)")"
    Write-Host ""

    $result = @{
        Name        = Split-Path $ScanPath -Leaf
        Description = ""
        Stack       = @()
        Milestone   = "v1.0 release"
    }

    # README → description
    $readme = Get-ChildItem $ScanPath -Filter "README*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($readme) {
        $lines = Get-Content $readme.FullName -TotalCount 40 -Encoding UTF8 -ErrorAction SilentlyContinue
        $desc  = $lines | Where-Object { $_ -notmatch "^#" -and $_.Trim() -ne "" } | Select-Object -First 3
        if ($desc) { $result.Description = ($desc -join " ").Trim() }
        Write-Done "README — description extracted"
    }

    $stackHints = [System.Collections.Generic.List[string]]::new()

    # package.json
    if (Test-Path "$ScanPath\package.json") {
        try {
            $pkg = Get-Content "$ScanPath\package.json" -Raw | ConvertFrom-Json
            if ($pkg.dependencies)    { $pkg.dependencies.PSObject.Properties.Name    | Select-Object -First 8 | ForEach-Object { $stackHints.Add($_) } }
            if ($pkg.devDependencies) { $pkg.devDependencies.PSObject.Properties.Name | Select-Object -First 4 | ForEach-Object { $stackHints.Add($_) } }
        } catch {}
        Write-Done "package.json"
    }

    # composer.json
    if (Test-Path "$ScanPath\composer.json") {
        try {
            $comp = Get-Content "$ScanPath\composer.json" -Raw | ConvertFrom-Json
            if ($comp.require) { $comp.require.PSObject.Properties.Name | Select-Object -First 8 | ForEach-Object { $stackHints.Add($_) } }
        } catch {}
        $stackHints.Add("PHP"); Write-Done "composer.json"
    }

    # Python
    foreach ($rf in @("requirements.txt","pyproject.toml","Pipfile")) {
        if (Test-Path "$ScanPath\$rf") {
            Get-Content "$ScanPath\$rf" -TotalCount 20 -Encoding UTF8 -ErrorAction SilentlyContinue |
                Where-Object { $_ -match "^\w" -and $_ -notmatch "^\[" } |
                ForEach-Object { ($_ -split "[>=<!\[ ]")[0].Trim() } |
                Where-Object { $_ -and $_.Length -gt 1 } | Select-Object -First 8 |
                ForEach-Object { $stackHints.Add($_) }
            $stackHints.Add("Python"); Write-Done $rf
        }
    }

    # Android
    if ((Test-Path "$ScanPath\app\build.gradle.kts") -or (Test-Path "$ScanPath\app\build.gradle")) {
        $stackHints.Add("Kotlin"); $stackHints.Add("Android"); Write-Done "Android Gradle project detected"
    }

    # Ruby / Go / Rust
    if (Test-Path "$ScanPath\Gemfile")    { $stackHints.Add("Ruby");  Write-Done "Gemfile" }
    if (Test-Path "$ScanPath\go.mod")     { $stackHints.Add("Go");    Write-Done "go.mod" }
    if (Test-Path "$ScanPath\Cargo.toml") { $stackHints.Add("Rust");  Write-Done "Cargo.toml" }

    # File extensions
    $extMap = @{
        ".kt"=>"Kotlin"; ".kts"=>"Kotlin"; ".ts"=>"TypeScript"; ".tsx"=>"TypeScript/React"
        ".jsx"=>"React"; ".py"=>"Python";   ".php"=>"PHP";        ".rb"=>"Ruby"
        ".go"=>"Go";     ".rs"=>"Rust";     ".cs"=>"C#";          ".java"=>"Java"
        ".swift"=>"Swift"; ".vue"=>"Vue";   ".svelte"=>"Svelte"
    }
    Get-ChildItem $ScanPath -File -Recurse -Depth $depth -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "node_modules|\.git|vendor|__pycache__|\.next|build|\.gradle" } |
        Group-Object Extension | Sort-Object Count -Descending | Select-Object -First 8 |
        ForEach-Object { if ($extMap[$_.Name]) { $stackHints.Add($extMap[$_.Name]) } }

    # Config fingerprints
    @{
        "tailwind.config*" = "Tailwind CSS"; "vite.config*" = "Vite"
        "next.config*"     = "Next.js";      "nuxt.config*" = "Nuxt"
        "artisan"          = "Laravel";       "manage.py"    = "Django"
        "libs.versions.toml" = "Gradle Version Catalog"
    }.GetEnumerator() | ForEach-Object {
        if (Get-ChildItem $ScanPath -Filter $_.Key -File -Recurse -Depth 2 -ErrorAction SilentlyContinue) {
            $stackHints.Add($_.Value)
        }
    }

    $clean = $stackHints | Where-Object { $_ -and $_.Length -gt 1 } |
             ForEach-Object { $_.Trim() } | Select-Object -Unique | Select-Object -First 12
    $result.Stack = @($clean)

    Write-Done "Stack inferred: $(if ($result.Stack) { $result.Stack -join ', ' } else { 'none detected' })"
    Write-Host ""
    return $result
}

# ═══════════════════════════════════════════════════════════════════════════════
# SKILL INFERENCE
# ═══════════════════════════════════════════════════════════════════════════════
function Invoke-SkillInference {
    # Two-pass: type-scoped candidates first, then trigger matching within that set.
    # Baseline skills are always added regardless of type or trigger.
    # Returns: list of skills with TriggerMatches and Confidence properties added
    param([string]$Haystack, [string]$TypeId, $Patterns)

    # Category weights for confidence calculation
    $categoryWeights = @{
        "auth" = 1.5
        "data" = 1.2
        "api" = 1.0
        "infra" = 0.9
        "testing" = 0.9
        "messaging" = 0.9
        "ui" = 0.8
        "ml" = 0.8
        "android" = 0.8
    }

    # Pass 1 — scope candidates to this project type (if types field present)
    $candidates = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $Patterns) {
        $typesField = $p.types
        if (-not $typesField -or $typesField.Count -eq 0 -or $typesField -contains $TypeId) {
            $candidates.Add($p)
        }
    }

    # Pass 2 — trigger match within scoped candidates (with trigger tracking)
    $matched = [System.Collections.Generic.List[object]]::new()
    $haystackLower = $Haystack.ToLower()
    foreach ($p in $candidates) {
        if ($p.trigger) {
            $triggerMatches = @()
            $regex = [regex]::new($p.trigger, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            $matches = $regex.Matches($Haystack)
            foreach ($m in $matches) {
                $triggerMatches += $m.Value
            }
            if ($triggerMatches.Count -gt 0) {
                $p | Add-Member -NotePropertyName TriggerMatches -NotePropertyValue $triggerMatches -Force
                
                # Calculate confidence: trigger_count * category_weight * position_bonus
                $catWeight = if ($categoryWeights[$p.category]) { $categoryWeights[$p.category] } else { 0.8 }
                $firstPos = $matches[0].Index
                $descLen = if ($Haystack.Length -gt 0) { $Haystack.Length } else { 1 }
                $posBonus = 1.0 + (0.1 * (1 - ($firstPos / $descLen)))
                $confidence = [Math]::Min(5, [Math]::Round($triggerMatches.Count * $catWeight * $posBonus))
                $p | Add-Member -NotePropertyName Confidence -NotePropertyValue $confidence -Force
                
                $matched.Add($p)
            }
        }
    }

    # Pass 3 — add baseline skills (scoped to type) not already matched (no triggers)
    foreach ($p in $candidates) {
        if ($p.baseline -and -not ($matched | Where-Object { $_.id -eq $p.id })) {
            $p | Add-Member -NotePropertyName TriggerMatches -NotePropertyValue @() -Force
            $p | Add-Member -NotePropertyName Confidence -NotePropertyValue 1 -Force
            $matched.Add($p)
        }
    }

    $seen = @{}; $result = [System.Collections.Generic.List[object]]::new()
    foreach ($s in $matched) {
        if (-not $seen[$s.id]) {
            $seen[$s.id] = $true; $result.Add($s)
            if ($result.Count -ge $MAX_SKILLS) { break }
        }
    }
    return @($result)
}

# ═══════════════════════════════════════════════════════════════════════════════
# SKILLS REVIEW SCREEN
# ═══════════════════════════════════════════════════════════════════════════════
function Invoke-SkillsReview {
    param($InferredSkills)

    $checked = @()

    if ($InferredSkills.Count -eq 0) {
        Write-Info "No skills inferred from description/stack."
        Write-Host ""
        $addAny = Read-Confirm "Add skills manually?" $false
        if (-not $addAny) { return @() }
    } else {
        # Build labels with confidence and triggers
        $labels = @($InferredSkills | ForEach-Object {
            $conf = if ($_.Confidence) { $_.Confidence } else { 1 }
            # Confidence dots: ● for filled, ○ for empty
            $dots = ""
            for ($i = 1; $i -le 5; $i++) {
                if ($i -le $conf) { $dots += "●" } else { $dots += "○" }
            }
            $cat = if ($_.category) { $_.category } else { "?" }
            
            # Triggers if available
            $triggerInfo = ""
            if ($_.TriggerMatches -and $_.TriggerMatches.Count -gt 0) {
                $triggerInfo = " ← inferred: ""$($_.TriggerMatches -join '"", ""')"""
            }
            
            "$($_.name)  $(dim "$dots $cat")$triggerInfo"
        })
        $checked = @($InferredSkills | ForEach-Object { $true })
        $checked = Read-Checkboxes -Items $labels -Checked $checked -Prompt "Inferred skills (● = confidence)"
        if ($null -eq $checked -or ($checked -is [int])) { return $checked }
    }

    $selected = [System.Collections.Generic.List[object]]::new()
    if ($checked -is [array]) {
        for ($i = 0; $i -lt $InferredSkills.Count; $i++) {
            if ($checked[$i]) { $selected.Add($InferredSkills[$i]) }
        }
    }

    Write-Host ""
    $addMore = Read-Confirm "Add a custom skill?" $false
    while ($addMore) {
        $cName = Read-Line "Skill name" "" "(e.g. PDF Export)"
        $cCat  = Read-Line "Category"   "api" "(auth|data|api|ui|ml|infra|messaging|testing|android)"
        if ($cName) {
            $cId = $cName.ToLower() -replace "\s+","-" -replace "[^a-z0-9\-]",""
            $selected.Add([PSCustomObject]@{ id=$cId; name=$cName; category=$cCat; baseline=$false; trigger="" })
            Write-Done "Added: $cName"
        }
        $addMore = Read-Confirm "Add another?" $false
    }
    return $selected.ToArray()
}

# ═══════════════════════════════════════════════════════════════════════════════
# FILE BUILDERS — SHARED
# ═══════════════════════════════════════════════════════════════════════════════
function Get-Date-Short { return (Get-Date).ToString("yyyy-MM-dd") }

function Build-AgentConfig {
    param($Agent, $Project)
    $n = $Project.Name; $d = $Project.Description
    $s = if ($Project.Stack) { $Project.Stack -join ", " } else { "See CONTEXT.md" }
    $m = $Project.Milestone; $url = $Agent.docsUrl; $id = $Agent.scratchpad

    if ($Agent.file -eq "opencode.json") {
        return (@{
            project             = $n; description = $d
            stack               = if ($Project.Stack) { @($Project.Stack) } else { @() }
            milestone           = $m; context_files = @("CONTEXT.md","TASKS.md")
            session_file        = "scratchpads/$id/SESSION.md"
            notes_file          = "scratchpads/$id/NOTES.md"
            scratchpad          = "scratchpads/$id/"; memory = "memory/decisions/"; docs = $url
            retrieval_rules     = @(
                "At session start: read CONTEXT.md, TASKS.md, QUALITY.md, SESSION.md, and NOTES.md",
                "Read SECURITY.md and ENVIRONMENTS.md before any feature touching auth, data, or config",
                "Read src/ files only when directly required — never load entire directories",
                "Pull memory/decisions/ only when relevant to a current decision"
            )
            compaction_protocol = @(
                "Prepend a new delta block to SESSION.md — never rewrite or replace previous blocks (context collapse risk)",
                "Record specific deltas: file names, line numbers, exact states — not polished summaries",
                "Promote architectural decisions to memory/decisions/ before stopping",
                "If a production blocker is unresolved: set Status: ESCALATE in SESSION.md",
                "Brevity bias warning: the urge to write a clean summary drops the specific details the next session needs most — exact errors, partial states, line numbers. Write raw state transfer.",
                "Context anxiety warning: if summarising instead of implementing, skipping verification, or rushing to wrap up — stop. Write SESSION.md delta, set Status: Partial. A clean partial beats silently degraded output."
            )
            rules               = @(
                "Every feature must pass QUALITY.md gates before being marked complete",
                "Security decisions must be recorded in memory/decisions/ with CRITICAL severity",
                "Write observations to NOTES.md; never write unverified assumptions as facts",
                "Do not modify memory/decisions/ — append only",
                "Flag out-of-scope or high-risk actions in SESSION.md for human review"
            )
        } | ConvertTo-Json -Depth 5)
    }

    $heading = ($Agent.file -replace "\.md$","").ToUpper()

    return @"
# $heading
> Pointer file — canonical context lives in CONTEXT.md

## Role
Production engineer on **$n** — $($Project.TypeLabel).
$d

## Stack
$s

## Current Milestone
$m

## Core Context
> Context engineering principle: dynamic state before static context.
> Read this section at the start of every session.

1. ``scratchpads/$id/SESSION.md`` — where did I leave off? Resolve any ESCALATE before proceeding
2. ``TASKS.md`` — what is the current work for this milestone?
3. ``WORKSTREAMS.md`` — which workstream am I in? What is my scope? Any phase gates to check?
4. ``scratchpads/$id/NOTES.md`` — what do I persistently know across sessions?
5. ``CONTEXT.md`` — architecture and NFRs (skim if unchanged)

## Where to look next
> Progressive disclosure: fetch these documents only when relevant to your current task.

- **Design & Architecture**: Check ``docs/`` for architectural diagrams, API contracts, or data models
- **Execution Plans**: Check ``.plans/`` for active and historical ExecPlans (see PLANS.md for protocol)
- **Domain Logic**: Check ``DOMAIN.md`` before features touching business rules
- **Production Rules**: Check ``QUALITY.md``, ``SECURITY.md``, ``ENVIRONMENTS.md``, and ``OBSERVABILITY.md`` before implementation
- **Exploration**: Check ``DISCOVERY.md`` before starting significant new features

## Context budget rules
Context window is finite. Curate it — do not fill it indiscriminately. Target a
60-80% utilization rate for optimal reasoning performance; exceeding 80% severely
degrades your ability to follow complex logic.

**What to always include (small, high-signal):**
- SESSION.md handoff — the compressed state of the last session
- The specific SKILL.md for the current task
- The specific gotchas.md for the current task

**What to include selectively (fetch on demand, not at session start):**
- CONTEXT.md sections — only the architecture/NFR blocks relevant to today's task
- src/ files — only the specific files being modified
- memory/decisions/ — only when a current decision relates to a prior one
- skills/*/outputs/ — only when you need to know the result of a prior skill execution

**What to compress before including:**
- If gotchas.md has grown beyond 20 entries: summarise the resolved ones into a single paragraph before reading — do not load all entries raw
- If NOTES.md exceeds 300 lines: summarise the oldest 2/3 into a compact facts block, then append

**What never to load wholesale:**
- The entire src/ directory
- All skill specs at once
- All memory/decisions/ entries
- All gotchas from all skills

## How to use skills
Each skill is a **folder** in ``skills/<id>/``:
- ``SKILL.md`` — the contract — includes **When to use** trigger to help you identify the right skill
- ``gotchas.md`` — accumulated failure patterns — **always read before implementing**
- ``scripts/`` — helper scripts to run or compose (do not rebuild what is already here)
- ``assets/`` — templates, config, and reference files
- ``outputs/`` — structured results from prior skill executions (compressed context for future sessions)

When starting a task: identify the right skill by its **When to use** trigger, read its SKILL.md,
then read gotchas.md — starting with the highest-confidence entries (``●●●●●`` and ``●●●●○``).
After completing a skill: complete the gotcha delta checklist in the verification section.
This is not optional — it is the primary mechanism by which Msingi context self-improves
across sessions (ACE principle: execution feedback updating bullet metadata).

## Retrieval rules
- Read ``src/`` files only when directly required — never load entire directories
- Use file listing or grep to understand structure before opening files
- Pull ``memory/decisions/`` only when a current decision relates to a prior one
- Never preload speculatively — retrieve just-in-time
- Use scripts in ``skills/<id>/scripts/`` instead of rebuilding boilerplate
- Check ``skills/<id>/outputs/`` for prior results before re-running expensive operations

## Production rules
- Every feature must pass all gates in ``QUALITY.md`` before being marked complete
- Never mark a task done without verifying against the relevant skill spec in ``skills/``
- Security decisions (auth, secrets, data exposure) logged in ``memory/decisions/`` as CRITICAL
- Performance-affecting changes: benchmark before and after — log results in NOTES.md
- All inputs validated at the boundary — never trust caller
- No speculative implementation: if the spec is ambiguous, flag in SESSION.md — do not guess
- When you hit a failure: update ``gotchas.md`` in the relevant skill folder before continuing

## Execution Plans (PLANS.md)
When writing complex features, refactoring significant components, or embarking on multi-hour tasks:
- **Always use an ExecPlan** (as described in PLANS.md) from design to implementation
- ExecPlans are living documents — update their Progress, Decision Log, and Discovery sections at every stopping point
- Never proceed with a complex task without a concrete, approved ExecPlan in place

## Doc Gardening Protocol
Codebases drift. You are responsible for ensuring the context layer remains accurate.
- Periodically check whether CONTEXT.md, DOMAIN.md, and the active skill's gotchas.md still match the codebase
- If you notice documentation that is stale, inaccurate, or missing key decisions: autonomously update it
- Stale context is a bug. Fix it just like you would fix broken code.

## Agentic loop protocol
Every action must follow this cycle. No exceptions.

1. **Goal** — State the goal and success criteria before acting
2. **Act** — Take a single, concrete action (edit a file, run a command, search)
3. **Evaluate** — Check the result against QUALITY.md gates and acceptance criteria
4. **Adapt** — If the action failed, try an alternative approach. Log both attempts:
   ``[attempt 1] approach X → failed: reason`` / ``[attempt 2] approach Y → succeeded``
5. **Escalate** — After 3 failed attempts at the same sub-goal, set Status: ESCALATE.
   Do not loop indefinitely — the cost of retrying exceeds the cost of asking for help.
6. **Verify** — On success, confirm the result satisfies the original goal before moving on.
   A passing test is not a passing feature — check against the user's stated intent.

**Discipline checklist — confirm each step before moving on:**
- State the goal and success criteria before every action
- Evaluate the result of every action against QUALITY.md gates
- Vary your approach on retry — change at least one variable each attempt
- Verify the final result against acceptance criteria before marking done


## On-demand hooks
Invoke these slash commands for specific high-risk sessions:

``/careful`` — blocks destructive operations (rm -rf, DROP TABLE, force-push, delete in prod).
Invoke before any session that touches production data, schemas, or deployed infrastructure.

``/freeze`` — blocks file writes outside a specified directory.
Invoke when debugging: "I want to add logs but must not change unrelated files."

*(Add more hooks to ``skills/`` as you discover patterns worth enforcing)*

## Memory and execution logs
- Append to ``scratchpads/$id/NOTES.md`` — cross-session observations that survive compaction
- For skills that run repeatedly (automation, standup, deploy): keep a log in ``skills/<id>/assets/run.log``
  Format each entry: ``[date] [outcome] [summary]`` — the model reads its own history and improves
- Store per-skill config in ``skills/<id>/assets/config.json`` — ask the user for values on first run

## Compaction protocol
When approaching context limits mid-session:
1. Write a new delta block to ``scratchpads/$id/SESSION.md`` (prepend at top)
2. Record: decisions made, files modified, exact state of each touched file, next action
3. Promote architectural decisions to ``memory/decisions/`` before stopping
4. If a production blocker is unresolved: set **Status: ESCALATE** — human must review before next session

**Brevity bias warning (ACE, arXiv 2510.04618):**
When writing the SESSION.md delta, resist the tendency to produce a concise summary.
LLMs under context pressure generate "helpful" summaries that drop the specific
details — exact error messages, line numbers, dependency versions, partial states —
that the next session most needs. Write specific deltas, not polished summaries:
"auth.ts:47 — token expiry check inverted, FIXED" beats "fixed auth bug."
The SESSION.md delta log is not documentation. It is raw state transfer.

## Context anxiety — recognise and resist it

> Research finding (Anthropic Engineering, 2026): agents begin changing behaviour as they
> *approach* their perceived context limit — shortcutting work, summarising instead of
> implementing, or wrapping up tasks earlier than the spec requires. This happens before
> the actual context limit is hit, and produces silently degraded output.

**Signs you are experiencing context pressure:**
- You are summarising what you *would* do rather than doing it
- You are marking tasks done without verifying against acceptance criteria
- You are skipping steps in the verification checklist "for brevity"
- You are writing stub implementations instead of real ones
- You feel an urge to wrap up the session sooner than the work requires

**What to do instead:**
Stop. Do not produce degraded output.
Write ``scratchpads/$id/SESSION.md`` with your exact current state.
Set **Status: Partial** and a precise **Next action** that the next session can pick up from.
A clean handoff that the next session completes correctly is worth more than a rushed completion
that produces incorrect work silently.

## Escalation
Set ``Status: ESCALATE`` in SESSION.md when:
- A security decision requires human approval before proceeding
- An architectural ambiguity could lead to significant rework if guessed wrong
- A quality gate cannot be met without changing requirements
- An external dependency is broken or unavailable

Do not proceed past an ESCALATE. The next session begins by resolving it.

## Agent directives

<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the calls,
make all of the independent calls in parallel. When reading multiple files, read them
all simultaneously. When searching across files, run searches in parallel.
If some tool calls depend on previous results, execute them sequentially.
</use_parallel_tool_calls>

<investigate_before_answering>
Read the referenced file before answering questions about it. Investigate and read
relevant files BEFORE answering questions about the codebase. Ground every claim
in observed file content or command output. Give hallucination-free answers.
</investigate_before_answering>

<default_to_action>
Implement changes rather than only suggesting them. If the user's intent is unclear,
infer the most useful likely action and proceed, using tools to discover missing details
instead of guessing. Try to infer whether a tool call (e.g., file edit or read) is
intended, and act accordingly.
</default_to_action>

<post_retrieval_filtering>
After retrieving files or search results, filter out irrelevant sections before
consuming the context into your active reasoning space. Do not blindly load
large blocks of code if only a single function is relevant.
</post_retrieval_filtering>

<probe_based_evaluation>
Before acting on complex domain rules or architecture, probe your retrieved
context by explicitly stating your assumptions and verifying they match the
documentation. If there's a mismatch, re-read the static context layer.
</probe_based_evaluation>

<reversibility_check>
Take local, reversible actions freely (editing files, running tests, reading code).
For actions that are hard to reverse (force-push, database drops, deleting branches),
affect shared systems, or could be destructive — confirm with the user before proceeding.
When encountering obstacles, choose reversible approaches over destructive shortcuts.
</reversibility_check>

<scope_discipline>
Only make changes that are directly requested or clearly necessary. Keep solutions
simple and focused. A bug fix does not need surrounding code cleaned up. A simple
feature does not need extra configurability. Design for the current task, not
hypothetical future requirements. The right amount of complexity is the minimum
needed for the current task.
</scope_discipline>

## Scope
- Read:  ``CONTEXT.md``, ``TASKS.md``, ``WORKSTREAMS.md``, ``DOMAIN.md``, ``QUALITY.md``, ``SECURITY.md``, ``ENVIRONMENTS.md``, ``OBSERVABILITY.md``, ``DISCOVERY.md``, ``src/`` (on demand), ``skills/*/SKILL.md``, ``skills/*/gotchas.md``
- Write: ``src/``, ``scratchpads/$id/``, ``skills/*/gotchas.md`` (append only), ``skills/*/assets/``, ``skills/*/outputs/``, ``DISCOVERY.md`` (append only), ``WORKSTREAMS.md`` (status updates only), ``DOMAIN.md`` (append only)
- Append only: ``agents/``, ``memory/decisions/`` — preserve existing entries

## Reference
$url
"@
}

function Build-ContextMd {
    param($Project, $Agents, $Skills, $Type)

    $stackLines = if ($Project.Stack -and $Project.Stack.Count -gt 0) {
        ($Project.Stack | ForEach-Object { "- $_" }) -join "`n"
    } else { "- To be defined" }

    $agentLines = ($Agents | ForEach-Object { "- $($_.name) ($($_.file))" }) -join "`n"
    $docsLines  = ($Agents | ForEach-Object { "- [$($_.name)]($($_.docsUrl))" }) -join "`n"
    $skillLines = if ($Skills -and $Skills.Count -gt 0) {
        ($Skills | ForEach-Object { "- [$($_.name)](skills/$($_.id)/SKILL.md) · $($_.category) · UNIMPLEMENTED" }) -join "`n"
    } else { "- To be defined" }

    $status = if ($Project.Mode -eq "brownfield") { "Active — brownfield overlay applied" } else { "Active — greenfield" }

    $hybridLine  = if ($Project.SecondaryTypeId) {
        "`n**Hybrid secondary:** $($Project.SecondaryTypeLabel)"
    } else { "" }

    # Intake summary
    $audienceMap   = @{ public="Public users"; internal="Internal / team"; b2b="B2B clients"; mobile="Mobile app users" }
    $deployMap     = @{ cloud="Cloud (managed)"; "on-prem"="On-premises"; edge="Edge / CDN"; "mobile-store"="Mobile store"; desktop="Desktop install" }
    $scaleMap      = @{ personal="Personal / side project"; "small-team"="Small team (<500 users)"; growth="Growth (500–50k users)"; enterprise="Enterprise (50k+ users)" }
    $audienceLabel = if ($Project.Audience  -and $audienceMap[$Project.Audience])  { $audienceMap[$Project.Audience]  } else { "Not specified" }
    $deployLabel   = if ($Project.DeploymentTarget -and $deployMap[$Project.DeploymentTarget]) { $deployMap[$Project.DeploymentTarget] } else { "Not specified" }
    $scaleLabel    = if ($Project.ScaleProfile -and $scaleMap[$Project.ScaleProfile]) { $scaleMap[$Project.ScaleProfile] } else { "Not specified" }
    $authLabel     = if ($Project.NeedsAuth) { "Required" } else { "Not required" }
    $dataLabel     = if ($Project.HandlesSensitiveData) {
        $tags = if ($Project.PSObject.Properties["SensitiveDataTags"]) { $Project.SensitiveDataTags } else { "Yes" }
        "Yes — $tags"
    } else { "None" }

    return @"
# CONTEXT.md — Static-Context Cache Layer
> This file represents the static baseline of the project. Cache this
> understanding and only re-read when architecture or fundamental NFRs change.

## Project
**Name:** $($Project.Name)
**Type:** $($Project.TypeLabel)$hybridLine
**Status:** $status
**Bootstrapped:** $(Get-Date-Short)

## Purpose
$($Project.Description)

## Project profile
| Dimension | Value |
|---|---|
| Audience | $audienceLabel |
| Authentication | $authLabel |
| Sensitive data | $dataLabel |
| Deployment target | $deployLabel |
| Scale profile | $scaleLabel |

## Tech Stack
$stackLines

## Architecture
$($Type.architecture)

$($Type.nfr)

## Operational context
- **DISCOVERY.md** — exploration log; variant approaches, experiments, hypotheses before committing to direction
- **WORKSTREAMS.md** — parallel agent coordination; scope boundaries, phases, merge checkpoints
- **DOMAIN.md** — business domain context; rules, concepts, vocabulary, what good looks like
- **SECURITY.md** — threat model and security requirements for this project type
- **QUALITY.md** — production quality gates; agents must verify before marking work complete
- **ENVIRONMENTS.md** — environment strategy (dev / staging / production)
- **OBSERVABILITY.md** — logging, metrics, alerting specification

## Active Agents
$agentLines

## Agent Documentation
$docsLines

## Required Skills
$skillLines

## Current Milestone
$($Project.Milestone)

## Process rules
- memory/decisions/ is append-only — never edit existing entries
- Agent configs are pointers, not primary context — update CONTEXT.md first
- All architectural decisions logged in memory/decisions/ before implementation
- SESSION.md filled at every session end — including on context limit hits
- ESCALATE status in SESSION.md means: human must review before next session proceeds

---
*Canonical context. All agent files and decisions derive from this. Update here first.*
"@
}

function Build-TasksMd {
    param($Project, $Skills)
    $date = Get-Date-Short

    $skillBacklog = if ($Skills -and $Skills.Count -gt 0) {
        "- [ ] Review skill specs in skills/ — define interfaces before any implementation`n" +
        "- [ ] Implement skills in priority order per skills/README.md`n" +
        "- [ ] Verify each skill against its acceptance criteria before marking done"
    } else { "" }

    $brownfieldNote = if ($Project.Mode -eq "brownfield") {
        "`n- [ ] Verify inferred CONTEXT.md is accurate — confirm description, stack, architecture`n" +
        "- [ ] Audit existing src/ against generated skill specs`n" +
        "- [ ] Identify gaps between current state and production quality gates (QUALITY.md)"
    } else { "" }

    # Intake-driven task additions
    $intakeTasks = ""
    if ($Project.NeedsAuth) {
        $intakeTasks += "`n- [ ] Design and document auth flow before any implementation (login, logout, token lifecycle)"
    }
    if ($Project.HandlesSensitiveData) {
        $tags = if ($Project.PSObject.Properties["SensitiveDataTags"]) { $Project.SensitiveDataTags } else { "sensitive data" }
        $intakeTasks += "`n- [ ] Complete sensitive data inventory ($tags) — map all fields before coding"
        $intakeTasks += "`n- [ ] Define data retention and deletion policy — log decision to memory/decisions/"
    }
    if ($Project.ScaleProfile -eq "growth" -or $Project.ScaleProfile -eq "enterprise") {
        $intakeTasks += "`n- [ ] Define SLO targets (uptime, latency p95) and configure alerting before launch"
        $intakeTasks += "`n- [ ] Load test at 2x expected peak before promotion to production"
    }
    if ($Project.ScaleProfile -eq "enterprise") {
        $intakeTasks += "`n- [ ] Compliance requirements identified and documented in memory/decisions/"
        $intakeTasks += "`n- [ ] Penetration test scheduled before first external release"
    }
    if ($Project.DeploymentTarget -eq "mobile-store") {
        $intakeTasks += "`n- [ ] App store listing and review requirements documented before feature freeze"
        $intakeTasks += "`n- [ ] Release signing and keystore management documented in SECURITY.md"
    }
    if ($Project.DeploymentTarget -eq "on-prem") {
        $intakeTasks += "`n- [ ] Deployment runbook written before handoff — install, upgrade, rollback"
        $intakeTasks += "`n- [ ] Network and firewall requirements documented in ENVIRONMENTS.md"
    }
    if ($Project.Audience -eq "public") {
        $intakeTasks += "`n- [ ] Abuse prevention strategy defined (rate limiting, CAPTCHA, anomaly detection)"
    }
    if ($Project.SecondaryTypeId) {
        $intakeTasks += "`n- [ ] Hybrid type integration points identified — document boundary between $($Project.TypeLabel) and $($Project.SecondaryTypeLabel) concerns"
    }

    return @"
# TASKS.md — Active Work

## Milestone: $($Project.Milestone)

### In Progress
- [ ] Review all generated context files — correct anything that doesn't match the project
- [ ] Verify SECURITY.md threat model is complete for this project
- [ ] Set up dev environment per ENVIRONMENTS.md$brownfieldNote

### Backlog — Foundation
- [ ] Confirm architecture decisions in CONTEXT.md; log any changes to memory/decisions/
- [ ] Define data models and API contracts before implementation
- [ ] Implement stack-specific lint configs (ESLint, Ruff, etc.) to enforce quality locally
- [ ] Set up CI pipeline with lint, test, and security audit gates
- [ ] Configure observability stack per OBSERVABILITY.md$intakeTasks

### Backlog — Skills
$skillBacklog

### Backlog — Launch readiness
- [ ] All QUALITY.md gates passing
- [ ] Load test performed and baseline documented
- [ ] Runbook written: deploy, rollback, incident response
- [ ] Staging validated before production promotion

### Done
- [x] Project bootstrapped ($date)

---
*Update after every agent session. A task is not done until QUALITY.md gates pass.*
*ESCALATE items in SESSION.md take priority over all backlog work.*
"@
}

function Build-PlansMd {
    return @"
# PLANS.md — Execution Plan Specification

> **What is this?** An Execution Plan (ExecPlan) is a living design document that a coding agent or human follows to deliver a complex feature. Use this template for any multi-hour task, significant refactor, or risky implementation.

## How to use ExecPlans

When authoring an ExecPlan, start from the skeleton below. As you research and implement, keep all sections up to date. Add or split entries in the Progress list at every stopping point to affirmatively state the progress made and next steps. 

ExecPlans are living documents — it should always be possible to restart from *only* the ExecPlan and no other work.

## Core Requirements

1. **Self-contained**: Assume the reader is a novice with no prior context. Define terms, repeat assumptions, and embed required knowledge rather than linking out.
2. **Behavior-focused**: Describe observable outcomes ("navigating to /health returns HTTP 200"), not just code changes ("added HealthCheck struct").
3. **Idempotent and safe**: Write steps so they can be run multiple times safely. Provide rollback paths for risky operations.
4. **Validation-first**: Include instructions to run tests, start the system, and observe it doing something useful. Validation is not optional.

---

# Skeleton of a Good ExecPlan

*Copy this skeleton to a new file (e.g., `docs/plans/feature-name.md`) when starting a complex task.*

## Purpose / Big Picture
Explain in a few sentences what someone gains after this change and how they can see it working. State the user-visible behavior you will enable.

## Progress
Use a list with checkboxes to summarize granular steps. Every stopping point must be documented here.
- [ ] (YYYY-MM-DD HH:MM) Example step 1.
- [ ] Example step 2.

## Surprises & Discoveries
Document unexpected behaviors, bugs, optimizations, or insights discovered during implementation. Provide concise evidence.
- **Observation:** ...
  **Evidence:** ...

## Decision Log
Record every decision made while working on the plan.
- **Decision:** ...
  **Rationale:** ...
  **Date/Author:** ...

## Context and Orientation
Describe the current state relevant to this task as if the reader knows nothing. Name the key files and modules by full path. Define any non-obvious term you will use.

## Plan of Work
Describe the sequence of edits and additions. For each edit, name the file and location and what to insert or change. Keep it concrete and minimal.

## Concrete Steps & Validation
State the exact commands to run and where to run them. When a command generates output, show a short expected transcript so the reader can compare. Describe how to start the system and what to observe.

## Outcomes & Retrospective
*(Fill this out at completion)* Summarize outcomes, gaps, and lessons learned. Compare the result against the original purpose.
"@
}

function Build-PlanTemplateMd {
    return @"
# ExecPlan: [Feature Name]

## Purpose / Big Picture
[Explain what someone gains after this change and how they can see it working.]

## Progress
- [ ] (YYYY-MM-DD HH:MM) [Step 1]
- [ ] [Step 2]

## Surprises & Discoveries
- **Observation:** ...
  **Evidence:** ...

## Decision Log
- **Decision:** ...
  **Rationale:** ...
  **Date/Author:** ...

## Context and Orientation
[Describe the current state relevant to this task. Name the key files and modules by full path.]

## Plan of Work
[Describe the sequence of edits and additions.]

## Concrete Steps & Validation
[State the exact commands to run, expected output transcripts, and validation steps.]

## Outcomes & Retrospective
[Summarize outcomes and lessons learned at completion.]
"@
}

function Build-ChangelogMd {
    param($Project)
    $date   = Get-Date-Short
    $action = if ($Project.Mode -eq "brownfield") { "Brownfield overlay applied" } else { "Project initialised" }

    return @"
# CHANGELOG.md — Context Evolution Log

Records when and why canonical context (CONTEXT.md, architecture, constraints) changed.
This is not a code changelog — it tracks context drift and correction.

---

## $date — Bootstrap

- $action`: $($Project.Name)
- Project type: $($Project.TypeLabel)
- Milestone set: $($Project.Milestone)
- CONTEXT.md, TASKS.md, STRUCTURE.md, QUALITY.md, SECURITY.md, ENVIRONMENTS.md, OBSERVABILITY.md created
- Agent configs generated with production rules and escalation protocol

---

<!-- Template for future entries:

## YYYY-MM-DD — [reason for update]

- Changed: [what changed in CONTEXT.md or project structure]
- Why: [what happened that made the old context wrong or incomplete]
- Agent that surfaced it: [which agent or session revealed the drift]
- Impact: [which decisions or implementations are affected]

-->
"@
}

function Build-DiscoveryMd {
    param($Project)
    $date = Get-Date-Short

    return @"
# DISCOVERY.md — Exploration & Experiments Log

**Project:** $($Project.Name)
**Type:** $($Project.TypeLabel)

> Pattern 3 of AI-native development: the bottleneck shifts from *delivery* to *discovery*.
> When generation is cheap, the valuable work is evaluating variants — not executing one.
> This file tracks approaches explored, prototypes attempted, and decisions about direction.
> It is distinct from memory/decisions/ (which records confirmed architectural choices).

---

## What belongs here

- Alternative approaches considered but not yet decided
- Prototype results: what was tried, what it revealed, why it was abandoned or adopted
- Experiments: hypothesis, method, outcome
- Variant comparisons: A vs B analysis before committing

## What does not belong here

- Confirmed architectural decisions → memory/decisions/
- Implementation tasks → TASKS.md
- Context drift corrections → CHANGELOG.md

---

## How to use

**Before starting a significant feature:**
Add an entry describing the approach you are about to try and your hypothesis.

**After attempting something:**
Record the outcome — even if it failed. Failures are the most valuable entries.

**When comparing approaches:**
Document both. Record which you chose and why. Link to the ADR in memory/decisions/ if a decision was confirmed.

---

## Exploration log

### $date — Project initialisation

**Question:** What is the right scaffold structure for $($Project.Name)?
**Approach:** Msingi v$VERSION — $($Project.TypeLabel) scaffold with context engineering.
**Hypothesis:** A canonical CONTEXT.md + skill specs + decision log will prevent context drift across agent sessions.
**Status:** In progress — evaluate after 3 sessions.
**Next:** After first milestone, assess whether skill specs reduced implementation loops.

---

<!-- Entry template:

### YYYY-MM-DD — [short title]

**Question:** [What are you trying to find out?]
**Approach:** [What you tried — be specific enough to reproduce]
**Hypothesis:** [What you expected and why]
**Outcome:** [What actually happened]
**Learned:** [What this tells you — even null results are useful]
**Status:** EXPLORING | ABANDONED | ADOPTED | SUPERSEDED
**Link:** [ADR in memory/decisions/ if this led to a confirmed decision]

-->
"@
}

function Build-WorkstreamsMd {
    param($Project, $Agents, $Skills)
    $date     = Get-Date-Short
    $typeNote = if ($Project.SecondaryTypeId) {
        "$($Project.TypeLabel) + $($Project.SecondaryTypeLabel)"
    } else { $Project.TypeLabel }

    # Generate one workstream stub per agent — seeded with suggested scope
    $wsDefs = ""
    $scopeSuggestions = @{
        "claude-code"  = "auth, API layer, business logic"
        "gemini-cli"   = "data layer, migrations, schema"
        "codex"        = "tests, CI config, tooling scripts"
        "opencode"     = "frontend, UI components, styles"
        "aider"        = "refactoring, code quality, documentation"
        "deepagents"   = "research tasks, long-horizon planning, multi-step workflows"
        # legacy entries kept for users who still have these in agents.json
        "qwen-code"    = "infrastructure, deployment config"
        "antigravity"  = "documentation, code review, refactoring"
    }

    $i = 1
    foreach ($a in $Agents) {
        $scope = if ($scopeSuggestions[$a.id]) { $scopeSuggestions[$a.id] } else { "define scope before starting" }
        $wsDefs += @"

### WS-$i — $($a.name)
**Agent:** $($a.name) (``$($a.file)``)
**Status:** IDLE
**Scope:** $scope
**Owns:** *(define: which src/ subdirectories or files this workstream exclusively writes)*
**Depends on:** *(list any WS- numbers that must complete a phase before this starts)*

**Current task:**
*(describe the specific task currently in progress, or leave blank if IDLE)*

**Merge checkpoint:** *(define: what must be true before merging this workstream's output)*
- [ ] Tests pass for owned scope
- [ ] No writes outside owned scope
- [ ] QUALITY.md gates relevant to this scope verified
- [ ] SESSION.md complete with current state

**Last active:** —
**Notes:**

---
"@
        $i++
    }

    return @"
# WORKSTREAMS.md — Parallel Agent Coordination

**Project:** $($Project.Name)
**Type:** $typeNote
**Created:** $date

> Karpathy principle: the skill is now how to manage a small org of agents.
> Carve the codebase into parallel non-conflicting workstreams.
> Each workstream owns a defined scope. Agents do not write outside their scope.
> Human reviews at merge checkpoints — not after every commit.

---

## Why workstreams matter

Without scope boundaries, parallel agents create conflicts:
- Two agents modify the same file simultaneously → merge chaos
- Agent A makes assumptions about Agent B's output → silent incompatibility
- No checkpoint → problems discovered late when they are expensive to fix

Workstreams prevent this. Each agent has exclusive write access to its scope.
Read access is unrestricted — agents can read anything.

---

## Coordination rules

1. **Scope is exclusive write, unrestricted read.**
   An agent may read any file. It may only write to files within its assigned scope.

2. **Declare conflicts before starting.**
   If two workstreams need to write the same file, resolve ownership before starting.
   One agent owns the file; the other proposes changes via a PR or a spec update.

3. **Phase gates before parallel work.**
   Some work must be sequential. Define phases below.
   Example: auth schema (WS-1) must be confirmed before API layer (WS-2) starts.

4. **Merge checkpoints are mandatory.**
   A workstream does not merge until all its checkpoint criteria pass.
   The human reviews at merge — agents do not self-approve merges.

5. **SESSION.md is per-agent, WORKSTREAMS.md is shared.**
   Update this file when workstream status changes.
   It is the single view of parallel progress.

---

## Phases (define before starting parallel work)

| Phase | Workstreams | Gate to advance |
|-------|-------------|-----------------|
| 1 — Foundation | *(e.g. WS-1: schema + auth)* | Schema confirmed, auth contract signed off |
| 2 — Core build | *(e.g. WS-2, WS-3 in parallel)* | Phase 1 merged and green |
| 3 — Integration | *(all workstreams)* | All scopes merged, integration tests pass |

*(Edit phases to match your actual delivery plan. Delete rows that do not apply.)*

---

## Workstreams
$wsDefs
---

## Conflict log

| Date | File | WS-A | WS-B | Resolution |
|------|------|------|------|------------|
| *(add when a conflict is discovered and resolved)* | | | | |

---

## Merge history

| Date | Workstream | What merged | Reviewer |
|------|------------|-------------|----------|
| $date | — | Initial scaffold | Msingi v$VERSION |

---

*Update this file at every merge checkpoint and whenever scope changes.*
*Scope changes require human approval — agents do not reassign scope unilaterally.*
"@
}

function Build-DomainMd {
    param($Project, $Type)
    $date  = Get-Date-Short
    $short = if ($Project.Description.Length -gt 200) { $Project.Description.Substring(0,200) + "..." } else { $Project.Description }

    # Type-specific domain prompts — questions that push agents toward real understanding
    $domainPrompts = @{
        "web-app"    = "What are the core user journeys? What does a user do from landing to value? What is the most common failure path? What does 'success' look like from the user's perspective?"
        "api-service"= "Who are the API consumers and what do they expect? What is the contract — the guarantees this API makes? What are the latency and reliability requirements per endpoint? What happens when a consumer misuses the API?"
        "ml-ai"      = "What is the ground truth for this problem — how is correctness defined? What does the training data distribution look like? Where is the model most likely to fail silently? What is the cost of a false positive vs false negative?"
        "cli-tool"   = "Who runs this tool and in what context? What is the most common invocation? What does the user do when the tool fails or produces unexpected output? What does the tool need to know about the environment it runs in?"
        "fullstack"  = "What is the primary user action this system enables? Where is the boundary between frontend and backend concerns? What data flows from user action to persistent state? What is the system's most critical path under load?"
        "android"    = "What does the user do in the first 30 seconds? What happens when the app is backgrounded mid-task? What are the device constraints (minimum SDK, offline support, battery budget)? What does the Play Store reviewer check?"
    }
    $prompt = if ($domainPrompts[$Project.TypeId]) { $domainPrompts[$Project.TypeId] } else { "What is the core problem this system solves? Who is the primary user and what do they need?" }

    return @"
# DOMAIN.md — Business Domain Context

**Project:** $($Project.Name)
**Type:** $($Project.TypeLabel)
**Created:** $date

> This file teaches agents the *domain* — not the tech stack, not the task list.
> Execution docs (CONTEXT.md, TASKS.md, SKILL.md) tell agents what to build.
> This file tells agents *why it matters*, *who it's for*, and *what good looks like*.
> A well-written DOMAIN.md reduces misguided implementations and spec ambiguity.
> Grow it over time as the project reveals domain complexity.

---

## What this file is for

When an agent understands the domain, it:
- Asks better clarifying questions before implementing
- Catches requirements that contradict domain reality
- Makes better trade-off decisions without asking every time
- Writes code that names things the way the domain names them

When an agent lacks domain understanding, it:
- Implements technically correct code that solves the wrong problem
- Uses generic naming that makes the codebase harder to reason about
- Misses edge cases that are obvious to anyone who knows the domain

---

## Project in plain language

$short

**What this system does for its users:**
*(One paragraph. Write it the way you'd explain it to a smart person outside tech.
Focus on the outcome for the user — not the features, not the stack.)*


---

## Core domain concepts

*(Define the entities, processes, and rules that govern this domain.
These become the vocabulary the codebase should use.*
*Start with 3–5 concepts. Add more as the project reveals complexity.)*

| Concept | What it means in this domain | Notes |
|---------|------------------------------|-------|
| *(e.g. User)* | *(how this project defines "user" — not the generic meaning)* | |
| *(e.g. Order)* | *(domain-specific definition)* | |
| *(add as discovered)* | | |

---

## Business rules

*(Non-negotiable constraints from the domain — not technical decisions.
Example: "A user can have at most one active subscription at any time."
These are facts about the domain that must be preserved by any implementation.)*

- *(add as discovered — each rule on its own line)*

---

## What good looks like

*(Describe success from the perspective of the user or the business.
Agents use this to evaluate whether their implementation is actually solving the problem.)*

A successful session in this system means:

-

---

## Questions that reveal domain depth

*(Seeded for this project type — answer these over time.
Each answer makes agents more capable in future sessions.)*

$prompt

---

## Domain-specific gotchas

*(Edge cases, misconceptions, or business rules that an agent would not infer from
the tech spec alone. These are the domain equivalent of gotchas.md in skill specs.)*

- *(add as discovered)*

---

## Glossary

*(Terms used in this domain that have specific meanings different from their everyday usage,
or terms used internally that an outside agent might not recognise.)*

| Term | Definition |
|------|------------|
| *(add as discovered)* | |

---

## Multi-agent evaluation pattern

> This section documents the generator-evaluator pattern for teams using Msingi
> with multi-agent workflows. It is based on Anthropic's harness design research
> (March 2026) and applies to this project wherever complex features are built.

### The core insight

When an agent evaluates its own work, it reliably skews positive — even when the
output is obviously mediocre to a human observer. Separating the agent doing the work
(generator) from the agent judging the work (evaluator) is a strong lever for quality.

### How to apply this to $($Project.Name)

**For any feature that maps to a SKILL.md in this project:**

1. **Before coding** — the implementing agent proposes a sprint contract
   (saved to ``skills/<id>/assets/sprint-contract.md``) that maps each acceptance
   criterion to a specific, testable verification step.

2. **After coding** — a second agent (or a fresh session of the same agent,
   ideally with no memory of writing the code) reads the sprint contract and
   verifies each criterion against the running implementation. It does not trust
   the implementing agent's self-report.

3. **The evaluator's stance** — the evaluator agent should be prompted to be
   skeptical. Its job is to find what is broken, not to confirm what works.
   Prompt it explicitly: "Assume this implementation has bugs. Your job is to
   find them."

4. **Calibrating the evaluator** — the evaluator's first few assessments may
   be too lenient. Read its findings. Where its judgment diverges from yours,
   update its prompt. This calibration loop — read logs, find divergences,
   update prompt — is the actual work. It takes several rounds.

### Grading criteria for $($Project.Name)

*(Define 4–6 criteria that capture what "good" means for this specific project.
These give both the generator and evaluator something concrete to grade against.
"Is this good?" is ungradable. "Does this implement the contract behaviour
at all defined failure paths?" is gradable.)*

| Criterion | Weight | What it measures | What fails here |
|-----------|--------|-----------------|-----------------|
| Contract compliance | High | Does the implementation match the sprint contract exactly? | Stubbed features, missing error paths, wrong response shapes |
| Edge case coverage | High | Are failure paths tested, not just happy paths? | Only the happy path works; errors produce 500s or wrong behaviour |
| *(add project-specific)* | | | |
| *(add project-specific)* | | | |

### Context anxiety and the evaluator

Research finding: agents begin shortcutting and wrapping up work prematurely
as they approach their perceived context limit. This is called context anxiety.
The evaluator is particularly valuable here: it catches the shortcuts the
generator took under context pressure that the generator would never self-report.

If the evaluator consistently finds the same class of issue (stubs, missing
validation, missing error handling), this is a signal that the generator is
operating under context pressure. The fix is shorter sprints, not better prompting.

---

*Created: $date — Msingi v$VERSION*
*Grow this file over time. A 500-word DOMAIN.md after 10 sessions is worth more*
*than a perfect DOMAIN.md written at bootstrap that no one maintains.*
"@
}

function Build-StructureMd {
    param($Project, $Agents, $Skills)

    $agentLines   = ($Agents | ForEach-Object { "│   ├── $($_.file.PadRight(24)) ← $($_.name)" }) -join "`n"
    $scratchLines = ($Agents | ForEach-Object { "│   ├── $($_.scratchpad.PadRight(24))/ ← $($_.name)" }) -join "`n"
    $skillLines   = if ($Skills -and $Skills.Count -gt 0) {
        ($Skills | ForEach-Object { "│   ├── $($_.id).md" }) -join "`n"
    } else { "│   └── (skills inferred at bootstrap)" }

    $cols       = ($Agents | ForEach-Object { $_.name }) -join " | "
    $divider    = ($Agents | ForEach-Object { "------" }) -join "|"
    $read       = ($Agents | ForEach-Object { "read" }) -join " | "
    $rw         = ($Agents | ForEach-Object { "read/write" }) -join " | "
    $onDemand   = ($Agents | ForEach-Object { "on-demand r/w" }) -join " | "
    $verify     = ($Agents | ForEach-Object { "read + verify" }) -join " | "
    $readOnly   = ($Agents | ForEach-Object { "read" }) -join " | "
    $appendOnly = ($Agents | ForEach-Object { "append only" }) -join " | "

    return @"
# STRUCTURE.md — Directory Map and Agent Scope

Defines project layout and agent authorisation boundaries.
Update this file when structure changes significantly.

---

## Directory Layout

``````
$($Project.Name)/
├── CONTEXT.md              ← canonical truth: architecture, NFRs, stack (human maintains)
├── TASKS.md                ← active work and milestone (human + agents)
├── DISCOVERY.md            ← exploration log: variants tried, hypotheses, experiments
├── WORKSTREAMS.md          ← parallel agent coordination: scope, phases, merge checkpoints
├── DOMAIN.md               ← business domain context: rules, concepts, what good looks like
├── CHANGELOG.md            ← context evolution log (human maintains)
├── STRUCTURE.md            ← this file (human maintains)
├── QUALITY.md              ← production quality gates (human maintains)
├── SECURITY.md             ← threat model and security requirements (human maintains)
├── ENVIRONMENTS.md         ← environment strategy (human maintains)
├── OBSERVABILITY.md        ← logging, metrics, alerting spec (human maintains)
├── README.md
├── agents/
$agentLines
├── skills/                 ← skill specs (contracts, not implementations)
$skillLines
│   └── README.md
├── memory/
│   ├── decisions/          ← ADRs — append only, never edit existing
│   └── bootstrap-record.json
├── scratchpads/
$scratchLines
│       ├── SESSION.md      ← end-of-session handoff; ESCALATE status if blocked
│       └── NOTES.md        ← persistent working memory
└── src/                    ← source code (agents write here)
``````

---

## Agent Scope Matrix

| Area | $cols |
|------|$divider|
| CONTEXT.md | $read |
| TASKS.md | $rw |
| DISCOVERY.md | $rw |
| WORKSTREAMS.md | $rw |
| DOMAIN.md | $rw |
| QUALITY.md | $read |
| SECURITY.md | $read |
| ENVIRONMENTS.md | $read |
| OBSERVABILITY.md | $read |
| agents/ | $read |
| skills/ | $verify |
| src/ | $onDemand |
| scratchpads/own/ | $rw |
| scratchpads/other/ | $readOnly |
| memory/decisions/ | $appendOnly |

---

## Protocol rules

**Retrieval:** src/ is on-demand only. Inspect structure before opening files.
Never load directories wholesale — retrieve just-in-time.

**Quality:** No feature is complete until QUALITY.md gates pass.
Agents self-verify — not humans covering for agents.

**Compaction:** SESSION.md filled at every session end, including on context limit hits.

**Escalation:** ``Status: ESCALATE` in SESSION.md means the next session must
resolve the escalation before doing any other work. Do not continue past an ESCALATE.

**Decisions:** memory/decisions/ is append-only. Never edit or delete existing ADRs.
New information that supersedes an old decision creates a new entry referencing the old one.

---

## Status
Last reviewed: $(Get-Date-Short)
"@
}

function Build-SecurityMd {
    param($Project, $Type)

    # Build intake-driven additional threat blocks
    $intakeThreatBlocks = ""

    # Auth block
    if ($Project.NeedsAuth) {
        $intakeThreatBlocks += @"

## Authentication requirements (from project intake)
This project requires authentication. The following controls are mandatory:
- Implement credential stuffing protection (rate limiting + lockout on repeated failures)
- Enforce MFA for admin or privileged roles
- Session tokens must be rotated on privilege escalation
- Password reset flows must use time-limited, single-use tokens
- OAuth/OIDC flows: validate ``state`` parameter to prevent CSRF; verify ``aud`` claim on JWTs
"@
    }

    # Sensitive data block
    if ($Project.HandlesSensitiveData) {
        $tags = if ($Project.PSObject.Properties["SensitiveDataTags"]) { $Project.SensitiveDataTags } else { "sensitive data" }
        $intakeThreatBlocks += @"

## Sensitive data requirements (from project intake)
This project handles: **$tags**

Mandatory controls:
- Encrypt all sensitive fields at rest (AES-256 minimum) and in transit (TLS 1.2+)
- Implement field-level access control — agents must not read sensitive fields outside their scope
- Audit log all access to sensitive records: who, when, what operation
- Data retention policy must be defined before launch — log to memory/decisions/
- Never include sensitive values in logs, error messages, or analytics events
"@
        if ($tags -match "PII") {
            $intakeThreatBlocks += @"
- GDPR/CCPA compliance: right-to-erasure and data export must be implementable
- Map all PII fields in a data inventory before implementation begins
"@
        }
        if ($tags -match "payment") {
            $intakeThreatBlocks += @"
- PCI-DSS scope must be minimised — use a tokenisation provider (Stripe, Adyen) rather than storing card data
- Never log full card numbers, CVVs, or full PANs under any circumstances
"@
        }
        if ($tags -match "health") {
            $intakeThreatBlocks += @"
- HIPAA/health data regulations apply — confirm applicable jurisdiction before implementation
- Implement break-glass access logging for emergency health record access
"@
        }
    }

    # Scale-specific threat block
    if ($Project.ScaleProfile -eq "growth" -or $Project.ScaleProfile -eq "enterprise") {
        $intakeThreatBlocks += @"

## Scale-specific security requirements (from project intake)
Scale profile: **$($Project.ScaleProfile)**

At this scale, additional controls are required:
- DDoS mitigation must be in place before public launch (WAF, rate limiting, CDN-level protection)
- Security incident response runbook must be written before go-live
- Penetration test required before first external-facing release
- Dependency vulnerability scanning must run in CI on every merge
"@
    }

    # Deployment-specific block
    if ($Project.DeploymentTarget -eq "on-prem") {
        $intakeThreatBlocks += @"

## On-premises deployment requirements (from project intake)
- Network segmentation: application tier must not be directly reachable from the internet
- Internal PKI or certificate pinning for service-to-service communication
- Patch management policy must be documented before deployment
"@
    }
    if ($Project.DeploymentTarget -eq "edge") {
        $intakeThreatBlocks += @"

## Edge deployment requirements (from project intake)
- No secrets in edge function code — use platform secret stores (e.g. Cloudflare Secrets)
- Cache poisoning: validate all cache keys; never cache responses containing user-specific data
- Request signing for origin-to-edge communication
"@
    }

    return @"
# SECURITY.md — Threat Model and Security Requirements

**Project:** $($Project.Name)
**Type:** $($Project.TypeLabel)$(if ($Project.SecondaryTypeId) { " + $($Project.SecondaryTypeLabel)" })
**Review date:** $(Get-Date-Short)
**Next review:** $((Get-Date).AddMonths(3).ToString("yyyy-MM-dd")) (or after any significant feature addition)

> This document defines the security posture agents must implement.
> Every agent reads this before working on authentication, data handling, or configuration.
> Security decisions are logged in memory/decisions/ with Severity: CRITICAL.

---

$($Type.securityThreats)
$intakeThreatBlocks

---

## Security process for agents

### Before implementing any auth or data feature
1. Read the relevant section of this threat model
2. Check memory/decisions/ for prior security decisions on this topic
3. If the threat model doesn't cover your case: log the gap in SESSION.md as ESCALATE

### When you find a security issue
1. Stop work on the current task
2. Log the finding in memory/decisions/ with Severity: CRITICAL
3. Set Status: ESCALATE in SESSION.md — do not attempt to fix unilaterally

### Secrets and credentials
- Never hardcode credentials, tokens, API keys, or connection strings in source
- Never log credential values — log only key names and redacted shapes
- Use environment variables or a secrets manager — see ENVIRONMENTS.md
- If you need a secret to test locally: document it in ENVIRONMENTS.md, not in code

---

## Review checklist (complete before any release)
- [ ] All items in the threat model above have been addressed or explicitly accepted
- [ ] Dependency audit run — no HIGH or CRITICAL CVEs unaddressed
- [ ] Secrets scan run — no credentials in source or history
- [ ] Authentication and authorisation tested explicitly for each protected resource
- [ ] Error messages reviewed — no stack traces or internal paths exposed to users
$(if ($Project.HandlesSensitiveData) { "- [ ] Sensitive data inventory complete and reviewed" })
$(if ($Project.HandlesSensitiveData) { "- [ ] Encryption at rest verified for all sensitive fields" })
$(if ($Project.NeedsAuth) { "- [ ] Auth flows tested: login, logout, token expiry, session rotation, MFA (if applicable)" })
$(if ($Project.ScaleProfile -eq "growth" -or $Project.ScaleProfile -eq "enterprise") { "- [ ] Penetration test scheduled or completed" })
$(if ($Project.ScaleProfile -eq "growth" -or $Project.ScaleProfile -eq "enterprise") { "- [ ] Incident response runbook written and reviewed" })
"@
}

function Build-QualityMd {
    param($Project, $Type)

    return @"
# QUALITY.md — Production Quality Gates

**Project:** $($Project.Name)
**Type:** $($Project.TypeLabel)

> These are not suggestions. A feature is not complete until every applicable
> gate below is checked. Agents self-verify — do not mark done and move on.
> Gates that cannot be met without changing requirements trigger an ESCALATE.

---

$($Type.qualityGates)

---

## Gate verification process

When an agent completes a feature:
1. Read through every gate in the relevant section above
2. For each gate: confirm it passes, or document why it does not apply
3. Write verification results to scratchpads/[agent]/NOTES.md
4. If any gate fails: either fix it (preferred) or log the exception in memory/decisions/
   with Severity: HIGH and the rationale for accepting the exception
5. Only then mark the task done in TASKS.md

## Exceptions
Any accepted quality exception must be logged in memory/decisions/ with:
- Which gate was not met
- Why it was accepted
- What the remediation plan is and by when
- Severity: HIGH minimum (CRITICAL if security-related)

## Entropy Control (Golden Principles)
Codebases naturally degrade over time. Agents must actively fight entropy by enforcing these golden principles when modifying existing code:
- **Centralize shared utilities:** If you see the same logic in two places, extract it to a shared module.
- **Prune dead code:** If you replace a function or deprecate a feature, delete the old code immediately. Do not leave it commented out.
- **Refactor as you go:** If you touch a file that violates current style or architecture standards, upgrade it to the new standard as part of your PR.
$($Type.entropyControl)
"@
}

function Build-EnvironmentsMd {
    param($Project)

    $androidNote = if ($Project.TypeId -eq "android") { @"

## Android-specific environments

### Debug build type
- ``debuggable true`
- StrictMode enabled — catches threading and resource violations
- LeakCanary included
- Logging verbose — all levels emitted
- API base URL points to dev server

### Release build type
- ``debuggable false` (enforced — CI validates this)
- R8 minification and obfuscation enabled
- ProGuard rules applied (see GRADLE.md)
- Logging: only ERROR and WARN
- API base URL injected via BuildConfig from CI secrets

### Internal test track (Play Console)
- Release build signed with upload key
- Connected to staging API
- Firebase Crashlytics enabled with test flag
- Used for QA validation before production promotion

### Production track (Play Console)
- Staged rollout: 10% → 50% → 100%
- Crashlytics monitoring active
- Rollback: publish previous APK to production track
"@ } else { "" }

    return @"
# ENVIRONMENTS.md — Environment Strategy

**Project:** $($Project.Name)

> Defines each environment's purpose, configuration approach, and promotion gates.
> Agents read this before touching any configuration, secrets, or deployment logic.
> Never hardcode environment-specific values in source — use the approach defined here.

---

## Environments

### Development (local)
**Purpose:** Individual developer / agent work. Fast iteration. Debugging enabled.
**Data:** Local or shared dev database. Never real user data.
**Config source:** `.env.local` (gitignored). See `.env.example` for required keys.
**Expectations:** May be broken. No uptime SLA. Verbose logging acceptable.

### Staging
**Purpose:** Pre-production validation. Mirrors production configuration.
**Data:** Anonymised copy of production data OR synthetic data. Never real PII.
**Config source:** Secrets manager or CI/CD environment variables.
**Promotion gate:** All QUALITY.md gates pass. Security scan clean. Load test baseline documented.
**Expectations:** Should always be deployable. Treat staging failures as production risks.

### Production
**Purpose:** Live system serving real users.
**Data:** Real user data — handle with care. PII subject to retention policy.
**Config source:** Secrets manager only. No .env files on production servers.
**Promotion gate:** Staging validated. Rollback plan confirmed. On-call notified.
**Expectations:** 99.9%+ uptime. Changes via deployment pipeline only — no manual edits.

---

## Configuration rules

1. **Never commit secrets.** `.env` files are gitignored. Use `.env.example` with placeholder values.
2. **Environment parity.** Staging config must mirror production — differences are risks.
3. **Secrets manager.** Production secrets live in a secrets manager (define which one before launch).
4. **Rotation.** All secrets must be rotatable without downtime — design for this from day one.
5. **Audit.** Every secret access logged — who accessed what and when.

---

## Required environment variables

Document all required variables here as the project grows.
Format: ``VARIABLE_NAME` — purpose — required in which environments.

| Variable | Purpose | Dev | Staging | Production |
|----------|---------|-----|---------|------------|
| ``APP_ENV` | Environment name | local | staging | production |
| ``DB_URL` | Database connection string | ✓ | ✓ | ✓ |
| ``SECRET_KEY` | Application secret / JWT signing | ✓ | ✓ | ✓ |
| *(add as project grows)* | | | | |

---

## Promotion checklist

### Dev → Staging
- [ ] All tests pass in CI
- [ ] No HIGH/CRITICAL security findings
- [ ] Environment variables documented above

### Staging → Production
- [ ] All QUALITY.md gates verified in staging
- [ ] Load test performed — baseline documented in memory/decisions/
- [ ] Rollback plan confirmed (how to revert and how long it takes)
- [ ] On-call / responsible person notified of deployment
- [ ] Post-deployment smoke test defined and ready to run
$androidNote
"@
}

function Build-ObservabilityMd {
    param($Project, $Type)

    return @"
# OBSERVABILITY.md — Logging, Metrics, and Alerting

**Project:** $($Project.Name)
**Type:** $($Project.TypeLabel)

> Defines what the system must emit and what must be monitored.
> Agents read this before implementing any logging, metrics, or health check logic.
> Observability is not optional — it is a production requirement.

---

$($Type.observabilityFocus)

---

## General logging rules (all project types)

### What to log
- Significant business events (user registered, order placed, model inference complete)
- All errors with full context: error code, message, relevant IDs, stack trace (server-side only)
- Performance measurements for critical paths: duration, resource consumed
- Security events: login attempt, permission denied, token issued/revoked

### What never to log
- Passwords, tokens, API keys, or any credential — even partially
- Full PII: names, emails, phone numbers, addresses in production logs
- Payment card data (PCI scope — log only masked values if required)
- Raw request bodies that may contain any of the above

### Log format
Structured JSON preferred. Every log entry must include:
``timestamp` (ISO 8601), ``level`, ``service`, ``request_id` (where applicable), ``message`.

---

## Application Legibility
The system must be transparent to both humans and agents during runtime.
- **Correlation IDs:** Every external request must generate or inherit a trace ID passed to all downstream services and logs.
- **Health endpoints:** The system must expose a ``/_health` or similar endpoint returning component status and version.
- **Readiness/Liveness:** For orchestrated deployments (e.g., Kubernetes), expose distinct liveness and readiness probes.

---

## Tooling decisions (fill in before first production deploy)

| Concern | Tool chosen | Rationale | ADR reference |
|---------|-------------|-----------|---------------|
| Log aggregation | *(define)* | | |
| Metrics / APM | *(define)* | | |
| Error tracking | *(define)* | | |
| Alerting | *(define)* | | |
| Uptime monitoring | *(define)* | | |

Log tooling decisions in memory/decisions/ with Severity: HIGH.

---

## Alert runbook stubs

For each alert below, create a runbook entry in memory/decisions/ before going live:
- What does this alert mean?
- What are the first 3 steps to diagnose?
- Who is responsible for responding?
- What is the escalation path if not resolved in 30 min?
"@
}

function Build-SessionMd {
    param($Agent)

    return @"
# SESSION.md — $($Agent.name) Handoff

> **Append-only delta log.** Each session adds a new block at the top.
> Never rewrite or compress existing entries — the paper ACE (arXiv 2510.04618)
> proves that LLM-mediated rewriting causes context collapse: knowledge is
> silently erased rather than preserved. A growing log costs tokens honestly;
> a "summary" costs tokens deceptively.
>
> The next session reads the most recent block first. Older blocks are still here
> and searchable — do not delete them.

---

<!-- ════════════════════════════════════════════════════════════════ -->
<!-- SESSION BLOCK — copy this template, fill it, prepend at top    -->
<!-- ════════════════════════════════════════════════════════════════ -->

## Session — [YYYY-MM-DD] — $($Agent.name)

**Status:** [ ] Complete  [ ] Partial  [ ] **ESCALATE**

> If ESCALATE: do not proceed until a human reviews. Describe blocker below.

### Escalation (fill only if ESCALATE)
**Blocker:**
**Why human review is required:**
**Proposed options:**

---

### Context cost
- Target utilization: [ ] Optimal (60-80%)  [ ] Over-budget (>80%)  [ ] Under-utilized (<60%)
- Files loaded at start:
- Avoidable re-reads:
- Compression ratio (tokens consumed vs produced): 
- Cost: [ ] Low (<5k tokens)  [ ] Medium (5–15k)  [ ] High (>15k)
- **Efficiency note:** *(one sentence — what drove cost? what to skip next time?)*
- **Leverage note:** *(one sentence — what was discovered beyond the task? high leverage = understanding, not just execution)*
- **Context drift check:** [ ] Is current execution still aligned with the milestone? (If no, ESCALATE)

---

### Delta — what changed this session

> ACE principle: record specific deltas, not summaries.
> Anchored iterative summarization: anchor the state transfer to the original milestone goal.
> "Updated auth.ts line 47 to fix token expiry" beats "worked on auth".
> These bullets are the raw material for gotchas.md and memory/decisions/.

**Accomplished:**
-

**Failed / did not work (include error messages):**
-

**Decisions made (architectural or structural):**
-

**src/ state (one line per touched area: complete / partial / broken):**
-

---

### Gotcha delta — update gotchas.md before closing
> For each gotcha with a matching trigger keyword that fired this session:
> find its entry in the relevant ``skills/<id>/gotchas.md``, raise confidence
> one level, update ``last_seen`` to today.
> For each new failure pattern: add a new G-NNN entry at low confidence.
> Do this before marking the session done. Skipping this is the main source
> of knowledge loss across sessions.

- [ ] Scanned trigger keywords in relevant gotchas.md files
- [ ] Raised confidence on triggered gotchas
- [ ] Added new G-NNN entries for novel failures
- [ ] No gotchas triggered this session

---

### Quality gates checked
-

### Open blockers (non-escalation)
-

### Next action
*(One sentence. The single most important thing the next session does first.)*


### Context drift check
[ ] No drift — CONTEXT.md is still accurate
[ ] CONTEXT.md needs update — reason:
[ ] CHANGELOG.md entry added
[ ] memory/decisions/ updated for any architectural decision

---
<!-- end of session block — do not delete this marker -->

"@
}

function Build-NotesMd {
    param($Agent)
    $date = Get-Date-Short

    return @"
# NOTES.md — $($Agent.name) Working Memory

> This file is loaded at every session start. Every line costs tokens.
> Verified facts only — confirm against src/ or CONTEXT.md before recording.
> Never write unverified assumptions here.

## Tiered memory protocol — grow-and-archive, never compress

> **ACE finding (arXiv 2510.04618, ICLR 2026):** LLM-mediated compression of
> accumulated knowledge causes context collapse — the model erases details it
> deems redundant, which are often the details that matter most. An 18k-token
> context collapsed to 122 tokens in one rewrite step, dropping accuracy below
> baseline. The fix is to never ask an LLM to compress its own memory.

**Active tier (this file):** verified observations from recent sessions.
**Archive tier (NOTES-archive.md):** older entries preserved verbatim.

When this file exceeds 300 lines:
1. Identify the oldest 100–150 lines (oldest dated entries)
2. **Move them verbatim to ``NOTES-archive.md``** under a dated heading — do NOT summarise, compress, or rewrite them
3. Delete those lines from this file
4. The active tier stays under 300 lines; the archive grows indefinitely
5. Load ``NOTES-archive.md`` only when a query specifically needs historical context

**Why verbatim?** Compression loses the specific details — exact error messages,
edge case values, dependency version numbers — that are most useful in future sessions.
Let the active tier shrink by *moving* entries, not by *summarising* them.
The model will filter relevance at read time; it does not need you to pre-filter.

---

## API and integration quirks
<!-- Endpoints that are flaky, rate limits, auth gotchas, SDK behaviour. -->
<!-- Each entry: what + why + workaround. Remove when fixed. -->


---

## Conventions in this codebase
<!-- Naming patterns, style decisions, structural patterns not in CONTEXT.md. -->
<!-- These are observations, not decisions — promote to memory/decisions/ if architectural. -->


---

## Performance observations
<!-- Query timings, bottlenecks found, optimisations applied with before/after. -->


---

## Security notes
<!-- Threat model gaps found, accepted risks, security decisions pending promotion. -->
<!-- Promote to memory/decisions/ with Severity: CRITICAL before session ends. -->


---

## Things that failed and why
<!-- Approaches tried that did not work. Each entry saves the next session from repeating it. -->
<!-- Format: [date] what was tried → why it failed → what to try instead -->


---

## Human preferences
<!-- Tone, format, level of detail, corrections noted in review. -->


---

## Open questions requiring human input
<!-- Flag here before escalating to SESSION.md. One line per question. -->


---

*Created: $date — $($Agent.name)*
*Target: under 300 lines active. Archive verbatim when over — never compress.*
"@
}

function Build-SkillSpec {
    param($Skill, $Project)

    $guidance = @{
        auth      = "Security is non-negotiable. All inputs validated server-side. Tokens short-lived. Never store plain-text credentials. Every auth decision logged in memory/decisions/ as CRITICAL."
        data      = "Data integrity is the contract. Validate before write. Handle null and empty states explicitly. Every query has a defined error path. No N+1 queries."
        api       = "APIs are contracts. Version explicitly. Consistent error envelope. Validate all inputs before processing. Log all failures with context and request ID."
        ui        = "Components are building blocks, not pages. Stateless where possible. Accept props/state, emit events. Document edge cases. Accessibility required — not optional."
        ml        = "Pipelines, not magic. Every step reproducible. Log inputs, outputs, failure modes. Validate data shapes at every boundary. No silent failures."
        infra     = "Invisible when working, catastrophic when not. Every config has a documented default. Fail loudly. Secrets never in source. Rotatable without downtime."
        messaging = "Messages can be lost, duplicated, or delayed. Design for idempotency. Log send and delivery. Fallback paths for all failure modes."
        testing   = "Tests are specifications. Write before implementation where possible. Cover happy path, error path, and edge cases. No flaky tests committed."
        android   = "Android has unique constraints: main thread is sacred (no I/O), lifecycle is complex (handle all states), and the user can kill the app at any time. Design defensively."
    }

    # Invocation trigger — phrased so Claude scans it to decide when to use this skill
    $triggers = @{
        auth      = "Use this skill when implementing login, logout, signup, token issuance, session management, OAuth flows, API key validation, or any access control logic."
        data      = "Use this skill when writing database queries, migrations, ORM models, caching logic, file storage, or any code that reads or writes persistent data."
        api       = "Use this skill when building REST endpoints, GraphQL resolvers, webhooks, rate limiting, request validation, or API versioning logic."
        ui        = "Use this skill when building UI components, forms, design system elements, responsive layouts, or any user-facing interface code."
        ml        = "Use this skill when implementing model inference, training pipelines, data preprocessing, feature engineering, or experiment tracking."
        infra     = "Use this skill when configuring deployments, CI/CD pipelines, Docker/K8s resources, secrets management, or infrastructure-as-code."
        messaging = "Use this skill when implementing queues, pub/sub, event buses, background jobs, or any async inter-service communication."
        testing   = "Use this skill when writing unit tests, integration tests, e2e tests, test fixtures, mocks, or any test infrastructure."
        android   = "Use this skill when building Android screens, ViewModels, Compose UI, Room queries, Hilt modules, or any Android-specific feature."
    }

    $hint    = if ($guidance[$Skill.category])  { $guidance[$Skill.category]  } else { "Define constraints before implementing." }
    $trigger = if ($triggers[$Skill.category])  { $triggers[$Skill.category]  } else { "Use this skill when implementing $($Skill.name) functionality." }
    $short   = if ($Project.Description.Length -gt 120) { $Project.Description.Substring(0,120) + "..." } else { $Project.Description }
    $date    = Get-Date-Short

    # Quick start summary per category — minimal token cost to reach productive state
    # Format: interface in one sentence + #1 gotcha. Load full spec only when needed.
    $quickStart = @{
        auth      = "**Interface:** takes credentials or token → returns auth result + session. **#1 gotcha:** JWTs are signed, not encrypted — never put sensitive data in the payload."
        data      = "**Interface:** takes query params → returns typed result or error. **#1 gotcha:** N+1 queries are the silent killer — profile before marking any data feature done."
        api       = "**Interface:** HTTP request in → validated response out, consistent error envelope. **#1 gotcha:** returning 200 with an error body breaks all downstream monitoring — use correct status codes."
        ui        = "**Interface:** accepts typed props → renders component, emits typed events. **#1 gotcha:** missing loading and error states will crash the UI — always handle all three states."
        ml        = "**Interface:** takes typed input tensor/dataframe → returns prediction + confidence. **#1 gotcha:** train/val data leakage — always split before shuffling, never after."
        infra     = "**Interface:** declarative config in → provisioned resource out. **#1 gotcha:** secrets in build args get baked into image layers — use runtime env vars or a secrets manager."
        messaging = "**Interface:** message in → processed + ack/nack out. **#1 gotcha:** consumers must be idempotent — the same message will be delivered more than once."
        testing   = "**Interface:** test subject in → assertion result out. **#1 gotcha:** tests that never assert pass silently — require a minimum assertion count in linter config."
        android   = "**Interface:** ViewModel state in → Compose UI out, user events up. **#1 gotcha:** any I/O on the main thread causes an ANR — all data work must run on Dispatchers.IO."
    }

    $qs = if ($quickStart[$Skill.category]) { $quickStart[$Skill.category] } else { "**Interface:** define before implementing. **#1 gotcha:** check ``gotchas.md`` before writing any code." }

    return @"
# $($Skill.name)

> **When to use:** $trigger

**ID:** $($Skill.id)  **Category:** $($Skill.category)  **Status:** UNIMPLEMENTED  **Created:** $date

---

## Quick start
> Read this section first. Load the rest of the spec only when you need the detail.
> This is the minimum context to begin implementing correctly.

$qs

**Before writing any code:** read ``gotchas.md`` in this folder.
Start with ``●●●●●`` and ``●●●●○`` entries — they are the most likely to apply.
**After implementing:** write a compact result record to ``outputs/``, update ``last_seen`` on any gotcha that triggered, and add new entries for anything unexpected.

---

> This is a contract, not an implementation plan.
> Status lifecycle: UNIMPLEMENTED → IN PROGRESS → NEEDS-REVIEW → IMPLEMENTED
> Any deviation from the Interface section must be logged in memory/decisions/.

---

## Skill folder contents

| File | Purpose |
|------|---------|
| ``SKILL.md`` | This file — the contract |
| ``gotchas.md`` | Failure patterns accumulated from real usage — read before implementing |
| ``scripts/`` | Helper scripts Claude can run or compose (add as needed) |
| ``assets/`` | Templates, reference data, sprint contracts (add as needed) |
| ``references/`` | API docs, type definitions, detailed specs (add as needed) |
| ``outputs/`` | Structured results from skill executions — compressed context for future sessions |

**Progressive disclosure:** Read ``SKILL.md`` first. Fetch other files only when you need the detail.
**Sprint contract:** Write your implementation plan to ``assets/sprint-contract.md`` before coding. This is the negotiated agreement between what the spec says and what you will actually build and test.

---

## Purpose

One sentence: what this skill does and why it exists in **$($Project.Name)**.

*Project context: "$short"*

---

## Interface

### Inputs
| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| — | — | — | — | Define before implementing |

### Outputs

**Success:**
``````
{ success: true, data: <define shape here> }
``````

**Error:**
``````
{ success: false, error: { code: string, message: string, details?: object } }
``````

### Side effects
<!-- DB writes, cache invalidations, events emitted, external API calls. Be explicit. -->

- *(none defined yet)*

---

## Constraints

$hint

### Hard limits
- Never swallow errors silently — propagate or log with full context
- Never trust input — validate at the boundary before any processing
- Never block the main thread / event loop for I/O

### Acceptance criteria
- [ ] Happy path: *(define the expected successful flow)*
- [ ] Auth failure: *(define behaviour when caller is not authorised)*
- [ ] Validation failure: *(define behaviour on bad input)*
- [ ] Downstream failure: *(define behaviour when external dependency fails)*
- [ ] Performance: *(define latency or throughput target)*

---

## Sprint contract

> Before writing a single line of implementation, the agent proposes a contract and records it here.
> This bridges the gap between the high-level spec above and what is actually testable.
> Inspired by the Anthropic harness design pattern: generator and evaluator negotiate
> what "done" looks like *before* any code is written, not after.

**Status:** [ ] Not started  [ ] Contract proposed  [ ] Contract confirmed  [ ] In progress  [ ] Done

### What will be built (proposed by implementing agent)

*(Describe the specific implementation — not the spec, but your plan for satisfying it.
Be concrete enough that a separate agent could verify it without asking you questions.)*


### How it will be verified (specific, testable)

*(Map each acceptance criterion above to a concrete test that can be run against the implementation.
"It works" is not a test. "GET /users/123 returns 200 with {id, name, email}" is a test.)*

| Criterion | Verification method | Expected outcome |
|-----------|--------------------|-----------------:|
| Happy path | *(specific request/action + expected response)* | |
| Auth failure | *(specific request + expected 401/403 response)* | |
| Validation failure | *(specific bad input + expected 422 response and error shape)* | |
| Downstream failure | *(mock or kill dependency + verify graceful degradation)* | |
| Performance | *(benchmark command + target metric)* | |

### Out of scope for this sprint

*(Be explicit. Anything not listed above is deferred. This prevents scope creep during QA.)*

-

### Contract confirmed by

*(Second agent or human reviewer signs off here before work begins.
If working solo, take a 5-minute break and re-read this as a skeptical reviewer.)*

**Reviewer:** *(agent ID or "human")*
**Date:**
**Notes:**

---


**Read ``gotchas.md`` for the full failure log.** Quick reference below:

- *(add the first gotcha the moment you hit a failure — do not wait)*
- *(format: what went wrong → why → how to avoid it)*

---

## Dependencies

| Dependency | Type | Version | Notes |
|------------|------|---------|-------|
| — | — | — | List before implementing |

---

## Security considerations
<!-- Specific to this skill. Reference SECURITY.md for project-wide model. -->

- *(none defined yet)*

---

## Implementation notes

- Read ``CONTEXT.md`` architecture section before writing any code
- Check ``memory/decisions/`` for prior decisions that affect this skill
- Check ``gotchas.md`` for known failure patterns before starting
- Write implementation to ``src/`` — this spec file stays unchanged
- Log deviations from this spec in ``memory/decisions/`` with Severity: HIGH
- If you need helper scripts: add them to ``scripts/`` and reference from here

---

## Verification checklist
*(Agent completes before marking IMPLEMENTED)*

- [ ] Interface matches spec — no undocumented parameters or return shapes
- [ ] All acceptance criteria passing — tested, not assumed
- [ ] Inputs validated at the boundary
- [ ] All error paths handled and tested
- [ ] Side effects documented and match spec
- [ ] Security considerations addressed
- [ ] QUALITY.md gates applicable to this skill all pass

### Gotcha delta — required, not optional
> ACE (arXiv 2510.04618): execution feedback updating context metadata is the
> primary mechanism by which context self-improves. Skipping this step is the
> main cause of knowledge loss across sessions. Do this before marking done.

- [ ] Scanned trigger keywords in ``gotchas.md`` against what happened this session
- [ ] For each gotcha whose trigger fired: raised confidence one level, updated ``last_seen`` to today
- [ ] For each novel failure not in ``gotchas.md``: added a new G-NNN entry at ``●●○○○ low`` confidence
- [ ] For each gotcha that explicitly did NOT apply: lowered confidence one level, added a note
- [ ] No gotchas triggered and no new failures — noted this below

**Gotcha update log** *(fill or write "none triggered")*:

---

*Spec created: $date — Msingi v$VERSION*
"@
}

function Build-SkillGotchas {
    param($Skill, $Project)
    $date = Get-Date-Short

    # ── Confidence scoring model (inspired by ECC instincts architecture) ──────
    # Each gotcha is a belief with evidence, not just a note.
    # Confidence levels:
    #   ●●●●● critical  — hit repeatedly, never contradicted, causes data loss or security issues
    #   ●●●●○ high      — hit 3+ times across projects, well-understood cause
    #   ●●●○○ medium    — seeded from known patterns, not yet confirmed in this project
    #   ●●○○○ low       — single observation, needs more evidence
    #   ●○○○○ weak      — theoretical, contradicted once, or very edge-case
    #
    # Agents: when you update a gotcha entry, also update its confidence and last_seen.
    # Raise confidence when it triggers again. Lower it if an approach worked despite the warning.
    # Mark RESOLVED when permanently fixed in the codebase (do not delete — keep as history).

    # Seed gotchas — structured with confidence metadata
    # Format per entry: id · title · confidence · triggers · what → why → prevention
    $seeds = @{
        auth = @"

### G-001 · JWTs are not encrypted — only signed
``confidence: ●●●●● critical``  ``triggers: jwt, token, payload, claims``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Sensitive data placed in JWT payload is exposed — base64 is not encryption.
**Why:** JWT signing proves authenticity but not secrecy. Any party can decode the payload.
**Prevention:** Never put PII, secrets, or sensitive business data in a JWT payload. Store a user ID only; fetch sensitive data server-side on each request.

### G-002 · OAuth state param not validated → CSRF
``confidence: ●●●●○ high``  ``triggers: oauth, callback, redirect, authorization_code``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** CSRF attack on the OAuth callback — attacker forces victim to link attacker's account.
**Why:** The ``state`` param exists to bind the request to the initiating session. Skipping the check removes this binding.
**Prevention:** Generate a cryptographically random ``state`` before redirect. Verify it matches exactly on callback. Reject any mismatch.

### G-003 · Password reset tokens reused after first use
``confidence: ●●●●○ high``  ``triggers: reset, password, token, forgot``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Reset link works multiple times — attacker who intercepts it can use it later.
**Why:** Token not invalidated on first use, or invalidated asynchronously with a race window.
**Prevention:** Mark token used *before* processing the reset. Make tokens single-use and expire in ≤15 minutes. Use constant-time comparison.

### G-004 · Raw Authorization header logged in error handlers
``confidence: ●●●●○ high``  ``triggers: log, error, authorization, header, bearer``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Bearer tokens appear in logs — accessible to anyone with log access.
**Why:** Error handlers log the full request headers without redacting credentials.
**Prevention:** Strip Authorization header from logs. Log only scheme + first 8 chars: ``Bearer sk-12345...``. Audit log pipeline for credential leakage before first deploy.
"@

        data = @"

### G-001 · N+1 query in data loops
``confidence: ●●●●● critical``  ``triggers: loop, forEach, map, list, collection, index``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** One query fires per iteration instead of one batch query for the whole set.
**Why:** ORM lazy-loading resolves associations inside a loop. Visible in query logs; often invisible until load.
**Prevention:** Enable query logging in dev. Profile every list endpoint before marking done. Use eager loading or a single JOIN. If count > 2× items, investigate immediately.

### G-002 · Migration runs on wrong database
``confidence: ●●●●○ high``  ``triggers: migrate, migration, schema, database, env``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Migration runs against production because APP_ENV was not set or was wrong.
**Why:** Migration tool defaults to a configured database, ignoring which environment is active.
**Prevention:** Assert APP_ENV at the top of every migration script. Print the target database name and require explicit confirmation before running against staging or production.

### G-003 · ORM silently returns null on not-found
``confidence: ●●●●○ high``  ``triggers: findOne, findById, get, fetch, lookup``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Code assumes a row exists; ORM returns null; downstream code throws a cryptic null-reference error.
**Why:** Many ORMs return null for missing records rather than throwing. The error surfaces far from the query.
**Prevention:** Always handle null explicitly at the point of query. Use ``findOrFail`` where available. Never chain property access on an ORM result without a null check.

### G-004 · Soft-delete not filtered in joins
``confidence: ●●●●○ high``  ``triggers: join, relation, association, soft, deleted_at, paranoid``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Soft-deleted records appear in query results via joined relations.
**Why:** The soft-delete filter applies to the primary model but not to eagerly-loaded relations.
**Prevention:** Apply ``deleted_at IS NULL`` (or equivalent scope) to every relation in every join. Audit all list queries when adding soft-delete to an existing model.
"@

        api = @"

### G-005 · Offline-first sync races cause data loss
`confidence: ●●●●○ high`  `triggers: offline, sync, conflict, local-first, merge`  `last_seen: seeded`  `status: ACTIVE`
`helpful: 0`  `harmful: 0`
**What:** User makes changes offline, then syncs. Race between local and remote causes one set of changes to be silently dropped.
**Why:** No conflict resolution strategy. Last-write-wins or no strategy at all.
**Prevention:** Implement explicit conflict resolution UI. Use CRDTs or operational transforms. Log and alert on conflicts instead of silently discarding.

### G-001 · 200 status with error body
``confidence: ●●●●● critical``  ``triggers: response, status, error, return, handler``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Client receives 200 OK with ``{"error": "..."}`` — monitoring tools log success; client code breaks.
**Why:** Error thrown inside a try/catch that returns a generic 200 response with the error message in the body.
**Prevention:** Use proper 4xx (client error) and 5xx (server error) status codes. Never return 200 for an error condition. Define a canonical error envelope and use it everywhere.

### G-002 · Content-Type not validated → silent empty body
``confidence: ●●●●○ high``  ``triggers: body, parse, request, json, content-type``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Client sends JSON as ``text/plain``; body parser ignores it; handler receives empty object.
**Why:** Body parser only processes bodies whose Content-Type matches its configuration.
**Prevention:** Validate Content-Type header before parsing. Return 415 Unsupported Media Type for unexpected types. Add a test that sends the wrong Content-Type.

### G-003 · Rate limit not scoped per user
``confidence: ●●●●○ high``  ``triggers: rate, limit, throttle, quota, counter``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** One user exhausts the rate limit for all users sharing an IP (e.g. office NAT).
**Why:** Rate limit keyed on IP only, not on authenticated identity.
**Prevention:** Scope rate limits by authenticated user ID when available, falling back to IP. Use separate counters for authenticated and anonymous traffic.

### G-004 · Inconsistent error envelope across endpoints
``confidence: ●●●●○ high``  ``triggers: error, message, response, envelope, format``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Some endpoints return ``{"error": "..."}``; others return ``{"message": "..."}``. Clients cannot handle errors generically.
**Why:** Different developers or different sessions wrote different handlers without a shared standard.
**Prevention:** Define the error envelope once in SKILL.md before writing any handler. Lint or test for envelope shape consistency. Fix before v1 — clients build around your error format.
"@

        ui = @"

### G-005 · API gateway forwards requests to all upstream services
`confidence: ●●●●○ high`  `triggers: gateway, proxy, bff, forward, route, upstream`  `last_seen: seeded`  `status: ACTIVE`
`helpful: 0`  `harmful: 0`
**What:** Gateway calls every backend service even when one would suffice — adds latency, masks failures.
**Why:** Incorrect route configuration or wildcard matching in gateway routing rules.
**Prevention:** Verify routing rules explicitly match the intended service. Test with malformed paths. Monitor per-upstream latency in gateway metrics.

### G-006 · BFF aggregates data but does not handle partial failures
`confidence: ●●●●○ high`  `triggers: bff, aggregate, compose, partial, fallback, circuit`  `last_seen: seeded`  `status: ACTIVE`
`helpful: 0`  `harmful: 0`
**What:** One upstream service fails and the entire BFF response fails, even though some data could still be returned.
**Why:** No circuit breaker or partial response strategy implemented in the aggregation layer.
**Prevention:** Implement circuit breakers per upstream. Return partial data with nulls or defaults for failed services. Surface failure info in response metadata.

### G-001 · Inline object/function prop causes re-renders on every parent render
``confidence: ●●●●○ high``  ``triggers: props, render, component, function, object, memo``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Child component re-renders on every parent render even when its data has not changed.
**Why:** A new object or function literal is created on every render pass, so referential equality check always fails.
**Prevention:** Memoize callbacks with ``useCallback``. Memoize objects with ``useMemo``. Lift static values out of the render function entirely.

### G-002 · Validation only on submit — no inline feedback
``confidence: ●●●●○ high``  ``triggers: form, input, validate, submit, field``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** User fills out a long form, clicks Submit, and only then sees all validation errors.
**Why:** Validation logic runs only in the submit handler.
**Prevention:** Add field-level validation on blur. Show errors as the user moves between fields. Reserve submit-time validation for cross-field rules only.

### G-003 · Missing loading and error states
``confidence: ●●●●● critical``  ``triggers: fetch, load, async, await, data, component``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Component renders nothing while loading and throws an uncaught error when the fetch fails.
**Why:** Only the success state was implemented. Loading and error are treated as edge cases.
**Prevention:** Every async data-fetching component must handle three states: loading, error, success. Write the loading and error states first. They are not optional.

### G-004 · Hardcoded pixel breakpoints
``confidence: ●●●○○ medium``  ``triggers: breakpoint, media, responsive, px, screen``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Layout breaks on non-standard screen sizes because breakpoints were hardcoded in pixels.
**Why:** Breakpoints chosen for the developer's screen, not from the design system.
**Prevention:** Use design system spacing and breakpoint tokens. Never hardcode a px value for a layout breakpoint. Test at 375px, 768px, 1024px, 1440px minimum.
"@

        ml = @"

### G-001 · Train/validation data leakage via pre-split shuffle
``confidence: ●●●●● critical``  ``triggers: shuffle, split, train, validation, test, dataset``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Model appears to generalise but is actually memorising leaked validation data.
**Why:** Dataset shuffled before train/val split — temporal or index-based structure bleeds across the split boundary.
**Prevention:** Always split first, then shuffle the training set only. For time-series data: split by time, not randomly. Verify split indices are disjoint before training.

### G-002 · Checkpoint saved without preprocessing config
``confidence: ●●●●○ high``  ``triggers: checkpoint, save, model, weights, serialize``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Cannot reproduce inference because preprocessing parameters (normalization stats, tokenizer config) are not saved with the model.
**Why:** Preprocessing is treated as separate from the model; only weights are checkpointed.
**Prevention:** Save preprocessing config alongside model weights in every checkpoint. Version the preprocessing pipeline. Test: delete everything except the checkpoint and verify inference still works.

### G-003 · Input shape mismatch at inference time
``confidence: ●●●●○ high``  ``triggers: inference, shape, input, preprocess, transform``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Model throws a shape error at inference because preprocessing was changed after training.
**Why:** Preprocessing code was modified without retraining the model. Mismatch discovered only at runtime.
**Prevention:** Pin preprocessing version in the model card. Treat the preprocessing pipeline as part of the model contract — changes require retraining.

### G-004 · PII in raw feature logs
``confidence: ●●●●○ high``  ``triggers: log, feature, input, raw, pii, personal``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Personal data (names, emails, IDs) appears in training logs and experiment tracking.
**Why:** Raw input features logged for debugging without a redaction step.
**Prevention:** Redact or hash identity fields before any logging. Define a list of PII fields in SECURITY.md before writing any logging code. Audit all experiment tracking dashboards.
"@

        infra = @"

### G-001 · Secret baked into image layer via build arg
``confidence: ●●●●● critical``  ``triggers: dockerfile, build, arg, secret, key, token``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Secret persists in every image layer and is visible in ``docker history`` — even if removed in a later layer.
**Why:** ``ARG`` and ``ENV`` values are embedded in the image manifest. Removing them in a later ``RUN`` step does not remove them from earlier layers.
**Prevention:** Never pass secrets as build args. Use Docker BuildKit secrets (``--secret``), runtime environment variables, or a secrets manager. Scan images for secrets before push.

### G-002 · Health endpoint returns 200 when dependencies are down
``confidence: ●●●●○ high``  ``triggers: health, ready, liveness, probe, endpoint``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Load balancer routes traffic to an instance whose database connection is dead, causing cascading failures.
**Why:** Health endpoint returns 200 unconditionally without testing dependencies.
**Prevention:** Health check must actually query the database, cache, and any critical external dependencies. Return 503 if any dependency fails. Test the failure path explicitly.

### G-003 · No resource limits on containers
``confidence: ●●●●○ high``  ``triggers: container, pod, kubernetes, memory, cpu, limits``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** One runaway process consumes all node memory, causing OOM kills of unrelated containers.
**Why:** Resource limits not set; scheduler has no information to enforce fairness.
**Prevention:** Always set CPU and memory requests and limits. Start with conservative values and tune from observability data. Never deploy to production without limits.

### G-004 · Rollback plan untested before production
``confidence: ●●●●○ high``  ``triggers: deploy, rollback, release, production, promote``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Rollback fails during an incident because the procedure was never tested and has unresolved dependencies.
**Why:** Rollback is treated as a theoretical option, not a required pre-deploy check.
**Prevention:** Test the rollback procedure on staging before every production deploy. Document rollback time. The rollback plan is a deployment gate, not an afterthought.
"@

        messaging = @"

### G-005 · Premature optimization hides real bottlenecks
`confidence: ●●●○○ medium`  `triggers: optim, profile, benchmark, perf, bottleneck`  `last_seen: seeded`  `status: ACTIVE`
`helpful: 0`  `harmful: 0`
**What:** Developer spends days optimizing code that is not in the hot path. Real bottleneck remains unaddressed.
**Why:** No profiling data. Assumptions about performance based on intuition rather than measurement.
**Prevention:** Profile in production or realistic staging. Use flame graphs. Optimize only after measurement shows the code is on the critical path.

### G-006 · CI pipeline runs full test suite on every branch
`confidence: ●●●○○ medium`  `triggers: ci, pipeline, test, branch, pr, workflow`  `last_seen: seeded`  `status: ACTIVE`
`helpful: 0`  `harmful: 0`
**What:** Every PR triggers a 30-minute test suite, discouraging fast iteration. Developers skip tests to ship faster.
**Why:** No test categorization. No parallelization. No selective test execution based on changed files.
**Prevention:** Split tests into unit, integration, e2e. Run unit tests on every commit. Run integration on main and release branches only. Parallelize aggressively.

### G-001 · Consumer not idempotent
``confidence: ●●●●● critical``  ``triggers: consume, process, message, handler, queue, event``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Processing the same message twice causes duplicate charges, duplicate records, or duplicate notifications.
**Why:** Message queues guarantee at-least-once delivery. Duplicate delivery is not a bug — it is a guarantee.
**Prevention:** Every consumer must be idempotent. Use idempotency keys (deduplicate on message ID). Test by manually replaying the same message twice and asserting identical state.

### G-002 · Dead-letter queue not monitored
``confidence: ●●●●○ high``  ``triggers: dlq, dead-letter, failed, queue, monitor, alert``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Failed messages accumulate silently in the DLQ. Business processes stall. Nobody notices until a user complains.
**Why:** DLQ is configured for reliability but no alert is set on its depth.
**Prevention:** Alert on DLQ depth > 0. Review DLQ messages daily. Every message in the DLQ represents a failed business transaction — treat it as an incident.

### G-003 · Schema changed without consumer migration
``confidence: ●●●●○ high``  ``triggers: schema, payload, message, version, change, field``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Old consumers crash processing new message format. New consumers crash processing old messages.
**Why:** Producer updated the schema without a migration plan or versioning strategy.
**Prevention:** Version message schemas. Use a schema registry. Deploy consumers that handle both old and new formats before updating producers. Never remove a field until all consumers have migrated.

### G-004 · Unbounded retry floods downstream
``confidence: ●●●●○ high``  ``triggers: retry, backoff, error, failure, downstream``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** One bad message triggers infinite retries that overwhelm the downstream service during recovery.
**Why:** Retry configured with no backoff, no jitter, and no maximum retry count.
**Prevention:** Use exponential backoff with jitter. Set a maximum retry count. After max retries, route to DLQ. Never retry at full speed — always add jitter to avoid thundering herd.
"@

        testing = @"

### G-001 · Test passes because it never asserts
``confidence: ●●●●● critical``  ``triggers: test, expect, assert, it, describe, spec``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Test always passes — including when the code is broken — because the assertion was never written.
**Why:** ``expect(result)`` without ``.toBe()``, ``.toEqual()``, or any matcher is a no-op. Test runner reports pass.
**Prevention:** Require minimum assertion count in linter config. Write the assertion *before* the implementation. Verify the test fails when you break the code it tests.

### G-002 · Test database state leaks between tests
``confidence: ●●●●○ high``  ``triggers: database, state, test, reset, isolation, transaction``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Test B fails because Test A left data in the database. Tests pass individually but fail in sequence.
**Why:** Database not reset between tests. Test order dependency created.
**Prevention:** Wrap each test in a transaction and roll it back after. Or truncate all tables in a beforeEach hook. Tests must be fully isolated — order-independent and parallelisable.

### G-003 · Time-sensitive tests using Date.now() directly
``confidence: ●●●●○ high``  ``triggers: time, date, timer, delay, setTimeout, flaky``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Test is flaky — passes when the machine is fast, fails under load because timing assumptions break.
**Why:** ``Date.now()`` or ``new Date()`` read wall-clock time which varies based on machine load.
**Prevention:** Inject a clock interface. Freeze time in test setup (sinon.useFakeTimers, jest.useFakeTimers). Never test timing with wall-clock time in a unit test.

### G-004 · Mocking the implementation instead of the interface
``confidence: ●●●●○ high``  ``triggers: mock, stub, spy, interface, boundary, integration``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Tests pass but real integration breaks because the mock models internal implementation details, not the external contract.
**Why:** Mock written to match current internal behaviour rather than the public interface.
**Prevention:** Mock at the boundary — the interface the caller depends on, not the internals. If the real dependency is cheap to run in tests, prefer integration tests over mocks.
"@

        android = @"

### G-001 · I/O on the main thread → ANR
``confidence: ●●●●● critical``  ``triggers: network, io, database, file, main, thread, coroutine``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** App freezes and Android shows "Application Not Responding" dialog. User force-quits.
**Why:** Network call, disk I/O, or database query running on the main thread blocks UI rendering for > 5 seconds.
**Prevention:** All I/O must use ``Dispatchers.IO``. Collect results on ``Dispatchers.Main`` via ``withContext`` or Flow. Enable StrictMode in debug builds — it will detect main-thread I/O before it ships.

### G-002 · Context reference in ViewModel → leak on config change
``confidence: ●●●●● critical``  ``triggers: viewmodel, context, activity, fragment, lifecycle``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** ViewModel holds a reference to Activity context. Activity is destroyed on rotation. ViewModel holds a leaked Activity reference. Memory leak and potential crash.
**Why:** ViewModel survives configuration changes; Activity does not. A ViewModel holding an Activity reference prevents garbage collection.
**Prevention:** Never store Activity, Fragment, View, or Context in a ViewModel. Use ApplicationContext if context is required. Use StateFlow / LiveData to push state to the UI layer.

### G-003 · Unstable lambda causes excessive Compose recomposition
``confidence: ●●●●○ high``  ``triggers: compose, recomposition, lambda, unstable, remember, performance``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Composable recomposes on every frame because a lambda or object passed as a parameter is considered unstable.
**Why:** Compose uses referential equality to skip recomposition. Lambdas capturing unstable types are never equal.
**Prevention:** Wrap lambdas in ``remember { }`` or hoist them to a stable scope. Annotate data classes with ``@Stable`` or ``@Immutable`` where appropriate. Use the Compose compiler metrics to measure recomposition counts.

### G-004 · ProGuard strips serialisation classes in release build
``confidence: ●●●●○ high``  ``triggers: proguard, release, serialize, json, gson, moshi, strip``  ``last_seen: seeded``  ``status: ACTIVE``
``helpful: 0``  ``harmful: 0``
**What:** Release build crashes with ``JsonDataException`` or returns null for all fields. Debug build works perfectly.
**Why:** ProGuard strips or renames data class fields and constructors used for JSON serialisation because it cannot trace the reflection-based access.
**Prevention:** Add ``@Keep`` to all serialised data classes, or add ``-keep`` rules in proguard-rules.pro before testing the release build. Test the release build in CI — never assume debug == release behaviour.
"@
    }

    $date      = Get-Date-Short
    $seedBlock = if ($seeds[$Skill.category]) {
        $seeds[$Skill.category]
    } else {
        "`n*(No seed gotchas for this category — add the first one when you hit a failure)*`n"
    }

    return @"
# Gotchas: $($Skill.name)

> Each entry is a **belief with evidence** — not just a note.
> Confidence reflects how often this gotcha was triggered and whether it was ever contradicted.
> Read high-confidence entries first. They are the most likely to apply to your current task.
> This file is append-only. Do not delete entries — mark resolved ones ``[RESOLVED: date]``.

---

## Confidence scale

``●●●●● critical`` — triggered repeatedly, causes data loss or security issues, never contradicted
``●●●●○ high``     — triggered 3+ times, well-understood cause and prevention
``●●●○○ medium``   — seeded from known patterns, not yet confirmed in this project
``●●○○○ low``      — single observation, needs more evidence before trusting fully
``●○○○○ weak``     — theoretical, contradicted once, or very edge-case

> **ACE principle (arXiv 2510.04618):** each entry is a bullet with metadata.
> The ``helpful`` and ``harmful`` counters track execution feedback automatically —
> raise ``helpful`` when the gotcha prevented a real mistake; raise ``harmful``
> when following the advice led to incorrect behaviour. These counters are the
> signal that drives confidence updates. High helpful + low harmful = raise confidence.
> Low helpful + high harmful = lower confidence, investigate, possibly resolve.

---

## How to update an entry (delta update protocol)

> Do this in the gotcha delta section of SESSION.md and SKILL.md verification checklist.
> Localised updates only — never rewrite the whole file.

When a gotcha **triggers** during your session:
1. Find its entry, update ``last_seen`` to today
2. Increment ``helpful`` counter by 1
3. Raise confidence one level (max ``●●●●●``)

When a gotcha **does NOT apply** despite matching trigger keywords:
1. Find its entry, add a note: ``[date] did not apply — [why]``
2. Increment ``harmful`` counter by 1
3. Lower confidence one level (min ``●○○○○``)

When a **new failure pattern** appears that has no gotcha entry:
1. Add a new entry at the bottom of "Project-specific gotchas"
2. Start at ``●●○○○ low`` — one observation is not enough for high confidence
3. Fill ``helpful: 1``, ``harmful: 0`` to initialise counters

When a gotcha is **permanently fixed** in the codebase:
1. Mark ``status: RESOLVED (date)`` — never delete — keep as history

**New entry format (with counters):**

``````markdown
### G-NNN · [short title]
``confidence: ●●○○○ low``  ``triggers: [keywords]``  ``last_seen: [date]``  ``status: ACTIVE``
``helpful: 1``  ``harmful: 0``
**What:** [what went wrong]
**Why:** [why it happened]
**Prevention:** [how to avoid it]
``````

---

## Seeded gotchas (from known failure patterns — medium confidence until confirmed in this project)
$seedBlock

---

## Project-specific gotchas

*(Add entries discovered during actual work on $($Project.Name).
These become the highest-value entries over time — they encode your specific project's failure history.)*

---

*File created: $date — Msingi v$VERSION*
*Confidence rises with evidence. Confidence decays when contradicted. Resolved entries stay as history.*
*Counters: helpful = times this prevented a real mistake. harmful = times following it led to wrong behaviour.*
"@
}

function Build-SkillsReadme {
    param($Skills, $Project)
    $date  = Get-Date-Short
    $short = if ($Project.Description.Length -gt 100) { $Project.Description.Substring(0,100) + "..." } else { $Project.Description }

    $byCategory = @{}
    foreach ($s in $Skills) {
        if (-not $byCategory[$s.category]) { $byCategory[$s.category] = @() }
        $byCategory[$s.category] += $s
    }

    $blocks = ""
    foreach ($cat in ($byCategory.Keys | Sort-Object)) {
        $capCat = (Get-Culture).TextInfo.ToTitleCase($cat)
        $blocks += "### $capCat`n"
        foreach ($s in $byCategory[$cat]) {
            $blocks += "- [``$($s.id)/SKILL.md``](./$($s.id)/SKILL.md) — $($s.name) · UNIMPLEMENTED`n"
        }
        $blocks += "`n"
    }

    return @"
# skills/ — Capability Library

**Project:** $($Project.Name)
**Type:** $($Project.TypeLabel)

Each skill is a **folder** — not just a file.
The folder contains a contract (``SKILL.md``), accumulated failure knowledge (``gotchas.md``),
and optionally: helper scripts (``scripts/``), templates (``assets/``), API references (``references/``).

> **Skills are not just documentation.** Add scripts Claude can run, templates it can copy,
> and data files it can read. The folder structure is a form of progressive disclosure —
> Claude reads ``SKILL.md`` first and fetches the rest on demand.
> Write compact structured results to ``outputs/`` after each execution — future sessions
> read from ``outputs/`` instead of re-running or re-loading full history.

---

## How agents use skills

1. Agent reads the task in TASKS.md — identifies the relevant skill by its **When to use** trigger
2. Agent reads ``SKILL.md`` — understands the interface and acceptance criteria
3. Agent reads ``gotchas.md`` — avoids known failure patterns before writing a line of code
4. Agent checks ``scripts/`` — uses existing helpers instead of rebuilding them
5. Agent implements in ``src/`` — spec stays unchanged
6. Agent updates ``gotchas.md`` if it hit a new failure — institutional memory grows
7. Agent logs deviations in ``memory/decisions/`` with Severity: HIGH

---

## Workflow

1. Pick the next UNIMPLEMENTED skill from TASKS.md
2. Set its Status to IN PROGRESS in ``SKILL.md``
3. Read QUALITY.md — know the gates before starting, not after
4. Implement and fill the verification checklist
5. Update Status → NEEDS-REVIEW → IMPLEMENTED (after human or peer review)

---

## Skills index ($($Skills.Count))

$blocks
---

## Growing a skill over time

- Add new gotchas to ``gotchas.md`` as you discover them (never delete — mark resolved)
- Add helper scripts to ``scripts/`` when you find yourself rebuilding the same boilerplate
- Add API reference extracts to ``references/`` when the external docs are slow to navigate
- Add output templates to ``assets/`` when the skill produces structured output
- Write execution records to ``outputs/`` — one compact JSON or markdown file per significant run
  Format: ``{ date, outcome, summary, key_values }`` — future sessions read these instead of re-running
- Write ``assets/sprint-contract.md`` before each implementation sprint — the negotiated plan
  that maps acceptance criteria to specific verifiable tests

---

*Generated by Msingi v$VERSION on $date*
*Inferred from: "$short"*
"@
}

function Build-DecisionsSeed {
    param($Project)
    $date = Get-Date-Short

    return @"
# 000-init.md — Project Initialisation

**Date:** $date
**Status:** CONFIRMED
**Severity:** HIGH
**Made by:** Human (bootstrap)
**Review date:** $((Get-Date).AddMonths(6).ToString("yyyy-MM-dd"))

---

## Decision
Initialise **$($Project.Name)** as a $($Project.TypeLabel) with a production-grade
context engineering structure for multi-agent development.

## Context
Project requires coordination across multiple AI agents across many sessions.
Without a canonical structure, each agent session risks:
- Context drift (agents working from outdated assumptions)
- Repeated decisions (same architectural choices made differently each session)
- Quality regression (no shared definition of done)
- Security gaps (no shared threat model)

## Architecture chosen
$($Project.TypeLabel) — see CONTEXT.md for full architecture and non-functional requirements.

## Consequences
- CONTEXT.md is the single source of truth — update it first, always
- All agents read QUALITY.md before marking work complete
- All agents read SECURITY.md before auth, data, or configuration work
- SESSION.md filled at every session end without exception
- ESCALATE status in SESSION.md means: human reviews before next session proceeds
- memory/decisions/ is append-only — never edit or delete existing ADRs
- src/ retrieved on demand only — never wholesale directory loads

## Alternatives considered
- Ad-hoc prompting per session: rejected — no continuity, repeated context loss
- Single shared system prompt: rejected — context rot at scale, no per-agent specialisation
- Canonical structure without quality gates: rejected — agents would self-certify without a standard

---

<!-- ADR template for future entries — copy this block, increment NNN:

# NNN-short-title.md

**Date:** YYYY-MM-DD
**Status:** PENDING | CONFIRMED | SUPERSEDED
**Severity:** LOW | MEDIUM | HIGH | CRITICAL
**Made by:** [agent name or human]
**Session:** [scratchpads/agent/SESSION.md reference]
**Review date:** YYYY-MM-DD
**Supersedes:** [NNN-prior-decision.md or "none"]
**Superseded by:** [leave blank until a future ADR replaces this one]

## Decision
[One clear sentence. State what was decided, not why.]

## Context
[Why this decision was needed. What problem it solves. What constraints applied.
Include: scale profile, deployment target, team size, any hard external constraints.]

## Spec reference
[Link to the relevant SKILL.md or CONTEXT.md section this decision affects.
Example: skills/user-authentication/SKILL.md — Interface section]

## Alternatives considered
| Option | Why rejected |
|--------|-------------|
| [Option A] | [honest trade-off — not just "worse"] |
| [Option B] | [honest trade-off] |

## Consequences
- Enables: [what becomes possible]
- Constrains: [what becomes harder or impossible]
- Defers: [what is explicitly not decided here]

## Review trigger
[Specific condition that would cause this to be revisited.
Example: "If daily active users exceed 10k" or "If we add a mobile client"]

---
Reminder: this file is append-only.
To supersede this decision: create a new ADR, fill in its "Supersedes" field,
then update this file's "Superseded by" field. Never edit the body of a confirmed ADR.

-->
"@
}

function Build-Gitignore {
    param($Project)
    $extras = ""
    $stack  = if ($Project.Stack) { $Project.Stack -join " " } else { "" }

    if ($stack -match "Python") {
        $extras += "`n# Python`n__pycache__/`n*.py[cod]`n.venv/`nvenv/`ndist/`nbuild/`n*.egg-info/`n.pytest_cache/"
    }
    if ($stack -match "Node|React|Next|Vue|Svelte|TypeScript") {
        $extras += "`n# Node`nnode_modules/`n.next/`ndist/`n.nuxt/`n.output/`n.cache/"
    }
    if ($stack -match "PHP|Laravel") {
        $extras += "`n# PHP`nvendor/`nstorage/logs/`n*.log"
    }
    if ($Project.TypeId -eq "android" -or $stack -match "Android|Kotlin") {
        $extras += "`n# Android`n*.iml`n.gradle/`nlocal.properties`nbuild/`ncaptures/`n.externalNativeBuild/`n.cxx/`n*.apk`n*.aab`n*.jks`n*.keystore"
    }

    return @"
# $($Project.Name) — .gitignore

# Context engineering — scratchpads are ephemeral working files
# Commit SESSION.md and NOTES.md only if your team wants shared session history
scratchpads/

# Agent-local config (personal settings, not committed)
# Team-shared configs (.claude/rules/, .claude/commands/, etc.) ARE committed
.claude/settings.local.json

# Secrets — never commit these
.env
.env.local
.env.staging
.env.production
*.env
secrets/
*.pem
*.key
*.p12

# OS
.DS_Store
Thumbs.db
desktop.ini

# IDE
.vscode/
.idea/
*.suo
*.swp
$extras
"@
}

function Build-ReadmeMd {
    param($Project, $Agents, $Skills)
    $date = Get-Date-Short

    $stackSection = if ($Project.Stack -and $Project.Stack.Count -gt 0) {
        "## Stack`n" + (($Project.Stack | ForEach-Object { "- $_" }) -join "`n") + "`n"
    } else { "" }

    $agentTree   = ($Agents | ForEach-Object { "│   ├── $($_.file)" }) -join "`n"
    $skillTree   = if ($Skills -and $Skills.Count -gt 0) {
        ($Skills | ForEach-Object { "│   ├── $($_.id).md" }) -join "`n"
    } else { "│   └── (inferred at bootstrap)" }
    $scratchTree = ($Agents | ForEach-Object { "│   ├── $($_.scratchpad)/" }) -join "`n"
    $agentList   = ($Agents | ForEach-Object { "- **$($_.name)** — reads ``agents/$($_.file)``" }) -join "`n"
    $skillList   = if ($Skills -and $Skills.Count -gt 0) {
        ($Skills | ForEach-Object { "- **$($_.name)** — ``skills/$($_.id).md`` · UNIMPLEMENTED" }) -join "`n"
    } else { "- See skills/ directory" }

    return @"
# $($Project.Name)

**Type:** $($Project.TypeLabel)

$($Project.Description)

$stackSection
## Project Structure

``````
$($Project.Name)/
├── CONTEXT.md              ← architecture, NFRs, stack — canonical truth
├── TASKS.md                ← active milestone and work
├── CHANGELOG.md            ← context evolution log
├── STRUCTURE.md            ← directory map and agent scope
├── QUALITY.md              ← production quality gates
├── SECURITY.md             ← threat model and security requirements
├── ENVIRONMENTS.md         ← dev / staging / production strategy
├── OBSERVABILITY.md        ← logging, metrics, alerting spec
├── README.md
├── agents/
$agentTree
├── skills/
$skillTree
│   └── README.md
├── memory/
│   ├── decisions/          ← ADRs — append only
│   │   └── 000-init.md
│   └── bootstrap-record.json
├── scratchpads/
$scratchTree
│       ├── SESSION.md      ← session handoff (ESCALATE flag if blocked)
│       └── NOTES.md        ← persistent working memory
└── src/
``````

## Active Agents
$agentList

## Required Skills ($($Skills.Count))
$skillList

## Context Engineering Protocol

| Layer | Files | Purpose |
|-------|-------|---------|
| Canonical | ``CONTEXT.md``, ``TASKS.md`` | Source of truth — architecture, NFRs, stack |
| Production ops | ``QUALITY.md``, ``SECURITY.md``, ``ENVIRONMENTS.md``, ``OBSERVABILITY.md`` | Non-negotiable production requirements |
| Evolution | ``CHANGELOG.md`` | Tracks context drift and correction |
| Skills | ``skills/*.md`` | Capability contracts — interface, constraints, acceptance criteria |
| Translation | ``agents/*`` | Per-agent config with retrieval rules, escalation, production rules |
| Working memory | ``scratchpads/*/NOTES.md`` | Persistent cross-session observations |
| Handoff | ``scratchpads/*/SESSION.md`` | End-of-session state + ESCALATE protocol |
| Decisions | ``memory/decisions/`` | Append-only ADR log |

## Key protocols

**Session start:** CONTEXT.md → TASKS.md → SESSION.md → NOTES.md → QUALITY.md → SECURITY.md

**Feature complete:** All QUALITY.md gates verified. Skill spec verification checklist filled.

**Escalation:** Status: ESCALATE in SESSION.md → human reviews → next session resolves before other work.

**Decisions:** memory/decisions/ is append-only. New context creates new entry. Never edit existing.

## Editing agents.json / skills.json
Add agents or skill patterns in the bootstrap tool data files — no script changes needed.

---
*Bootstrapped with Msingi v$VERSION on $date*
"@
}

# ═══════════════════════════════════════════════════════════════════════════════
# ANDROID-SPECIFIC BUILDERS
# ═══════════════════════════════════════════════════════════════════════════════
function Build-GradleMd {
    param($Project)
    $date = Get-Date-Short

    return @"
# GRADLE.md — Android Gradle Configuration Guide

**Project:** $($Project.Name)
**Created:** $date
**Status:** ACTIVE — agents must read this before touching any .gradle.kts file

> Gradle is the most common source of Android build failures and agent confusion.
> This document is the authoritative reference for all Gradle decisions in this project.
> Changes to Gradle configuration must be logged in memory/decisions/.

---

## Build system decisions (confirmed at bootstrap)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| DSL | Kotlin DSL (.kts) | Type-safe, IDE-supported, modern standard |
| Dependency management | Version Catalog (libs.versions.toml) | Central version control, no duplication |
| Annotation processing | KSP | KAPT is deprecated; KSP is faster and actively maintained |
| DI framework | Hilt | Google-supported, Compose-compatible, standard |
| Async | Coroutines + Flow | Official Kotlin async; integrates with Hilt and Compose |
| Minification | R8 (enabled on release) | Required for Play Store; reduces APK size |

**These decisions are locked. Changes require an ADR in memory/decisions/ with Severity: HIGH.**

---

## File structure

``````
project-root/
├── settings.gradle.kts         ← plugin management + module declarations
├── build.gradle.kts            ← root build file (project-level)
├── gradle/
│   ├── libs.versions.toml      ← version catalog (single source of version truth)
│   └── wrapper/
│       └── gradle-wrapper.properties
└── app/
    └── build.gradle.kts        ← app module build file
``````

---

## Version catalog: gradle/libs.versions.toml

``````toml
[versions]
# Core — these versions must be compatible with each other
kotlin              = "2.1.0"
agp                 = "8.7.3"          # Android Gradle Plugin
ksp                 = "2.1.0-1.0.29"   # Must match kotlin version prefix

# Compose — compiler version is tied to Kotlin version
compose-bom         = "2024.12.01"     # BOM manages all compose-* versions
compose-compiler    = "1.5.14"         # Check compatibility matrix before updating

# DI
hilt                = "2.54"

# Async
coroutines          = "1.10.1"

# Networking
retrofit            = "2.11.0"
okhttp              = "4.12.0"

# Local storage
room                = "2.6.1"

# Lifecycle / ViewModel
lifecycle           = "2.8.7"

# Navigation
navigation-compose  = "2.8.5"

# Image loading
coil                = "2.7.0"

# Testing
junit               = "4.13.2"
junit-ext           = "1.2.1"
espresso            = "3.6.1"
mockk               = "1.13.13"
turbine             = "1.2.0"          # Flow testing

[libraries]
# Kotlin
kotlin-stdlib           = { module = "org.jetbrains.kotlin:kotlin-stdlib", version.ref = "kotlin" }

# Compose (BOM manages versions — do not specify versions for compose-* libraries)
compose-bom             = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui              = { group = "androidx.compose.ui", name = "ui" }
compose-ui-graphics     = { group = "androidx.compose.ui", name = "ui-graphics" }
compose-ui-tooling      = { group = "androidx.compose.ui", name = "ui-tooling" }
compose-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
compose-material3       = { group = "androidx.compose.material3", name = "material3" }
compose-activity        = { module = "androidx.activity:activity-compose", version = "1.9.3" }

# Hilt
hilt-android            = { module = "com.google.dagger:hilt-android", version.ref = "hilt" }
hilt-compiler           = { module = "com.google.dagger:hilt-android-compiler", version.ref = "hilt" }
hilt-navigation-compose = { module = "androidx.hilt:hilt-navigation-compose", version = "1.2.0" }

# Coroutines
coroutines-android      = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-android", version.ref = "coroutines" }
coroutines-test         = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test", version.ref = "coroutines" }

# Room
room-runtime            = { module = "androidx.room:room-runtime", version.ref = "room" }
room-ktx                = { module = "androidx.room:room-ktx", version.ref = "room" }
room-compiler           = { module = "androidx.room:room-compiler", version.ref = "room" }  # via KSP

# Retrofit + OkHttp
retrofit-core           = { module = "com.squareup.retrofit2:retrofit", version.ref = "retrofit" }
retrofit-gson           = { module = "com.squareup.retrofit2:converter-gson", version.ref = "retrofit" }
okhttp-core             = { module = "com.squareup.okhttp3:okhttp", version.ref = "okhttp" }
okhttp-logging          = { module = "com.squareup.okhttp3:logging-interceptor", version.ref = "okhttp" }

# Lifecycle / ViewModel
lifecycle-viewmodel-compose = { module = "androidx.lifecycle:lifecycle-viewmodel-compose", version.ref = "lifecycle" }
lifecycle-runtime-ktx   = { module = "androidx.lifecycle:lifecycle-runtime-ktx", version.ref = "lifecycle" }

# Navigation
navigation-compose      = { module = "androidx.navigation:navigation-compose", version.ref = "navigation-compose" }

# Image loading
coil-compose            = { module = "io.coil-kt:coil-compose", version.ref = "coil" }

# Testing
junit                   = { module = "junit:junit", version.ref = "junit" }
junit-ext               = { module = "androidx.test.ext:junit", version.ref = "junit-ext" }
espresso-core           = { module = "androidx.test.espresso:espresso-core", version.ref = "espresso" }
mockk                   = { module = "io.mockk:mockk", version.ref = "mockk" }
turbine                 = { module = "app.cash.turbine:turbine", version.ref = "turbine" }
compose-ui-test-junit4  = { group = "androidx.compose.ui", name = "ui-test-junit4" }
compose-ui-test-manifest = { group = "androidx.compose.ui", name = "ui-test-manifest" }

[plugins]
android-application     = { id = "com.android.application",            version.ref = "agp" }
android-library         = { id = "com.android.library",                version.ref = "agp" }
kotlin-android          = { id = "org.jetbrains.kotlin.android",        version.ref = "kotlin" }
kotlin-compose          = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
ksp                     = { id = "com.google.devtools.ksp",             version.ref = "ksp" }
hilt                    = { id = "com.google.dagger.hilt.android",      version.ref = "hilt" }
``````

---

## settings.gradle.kts

``````kotlin
pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "$($Project.Name)"
include(":app")
// Add more modules here: include(":feature:auth"), include(":core:data")
``````

---

## Root build.gradle.kts

``````kotlin
// Top-level build file. Do not add dependencies here.
plugins {
    alias(libs.plugins.android.application)  apply false
    alias(libs.plugins.android.library)      apply false
    alias(libs.plugins.kotlin.android)       apply false
    alias(libs.plugins.kotlin.compose)       apply false
    alias(libs.plugins.ksp)                  apply false
    alias(libs.plugins.hilt)                 apply false
}
``````

---

## app/build.gradle.kts

``````kotlin
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

android {
    namespace = "com.example.$($Project.Name.ToLower() -replace '[^a-z0-9]', '')"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.$($Project.Name.ToLower() -replace '[^a-z0-9]', '')"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        debug {
            isDebuggable = true
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            isDebuggable = false          // NEVER change this to true for release
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Signing config: define signingConfigs block and reference here
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true   // Enable for BuildConfig.DEBUG, BuildConfig.APPLICATION_ID, etc.
    }
}

dependencies {
    // Compose BOM — manages all compose-* versions together
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.material3)
    implementation(libs.compose.activity)
    debugImplementation(libs.compose.ui.tooling)
    implementation(libs.compose.ui.tooling.preview)

    // Hilt — KSP for annotation processing
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)

    // Coroutines
    implementation(libs.coroutines.android)

    // Room — KSP for annotation processing
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)

    // Retrofit + OkHttp
    implementation(libs.retrofit.core)
    implementation(libs.retrofit.gson)
    implementation(libs.okhttp.core)
    debugImplementation(libs.okhttp.logging)  // Logging interceptor: debug only

    // Lifecycle
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.ktx)

    // Navigation
    implementation(libs.navigation.compose)

    // Image loading
    implementation(libs.coil.compose)

    // Testing
    testImplementation(libs.junit)
    testImplementation(libs.mockk)
    testImplementation(libs.coroutines.test)
    testImplementation(libs.turbine)
    androidTestImplementation(libs.junit.ext)
    androidTestImplementation(libs.espresso.core)
    androidTestImplementation(libs.compose.ui.test.junit4)
    debugImplementation(libs.compose.ui.test.manifest)
}
``````

---

## proguard-rules.pro (baseline)

``````proguard
# Keep application class
-keep class $($Project.Name.ToLower() -replace '[^a-z0-9]', '').** { *; }

# Hilt
-keep class dagger.hilt.** { *; }
-keepnames @dagger.hilt.android.lifecycle.HiltViewModel class * extends androidx.lifecycle.ViewModel

# Retrofit + Gson
-keepattributes Signature
-keepattributes *Annotation*
-keep class retrofit2.** { *; }
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
# Keep all data classes used as API models (adjust package)
-keep class $($Project.Name.ToLower() -replace '[^a-z0-9]', '').data.model.** { *; }

# Room
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
-keep @androidx.room.Dao class *

# Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# OkHttp
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
``````

---

## Critical rules for agents

### Before touching any .gradle.kts file
1. Read this entire document
2. Check memory/decisions/ for any Gradle-related prior decisions
3. Never add a dependency that duplicates a version catalog entry — use ``libs.*`` always

### Version updates
- **Never update Kotlin version without checking Compose compiler compatibility matrix:**
  https://developer.android.com/jetpack/androidx/releases/compose-kotlin
- **KSP version prefix must match Kotlin version:** ksp = ``{kotlin.version}-{ksp.patch}``
- **Update Compose BOM, not individual Compose library versions**
- Log all version updates in memory/decisions/ — version mismatches are hard to diagnose

### Adding a new library
1. Add version to ``[versions]`` in libs.versions.toml
2. Add library entry to ``[libraries]``
3. Add to build.gradle.kts using ``libs.*`` alias — never hardcode version strings
4. Add plugin to ``[plugins]`` if it's a Gradle plugin

### Annotation processors (KSP)
Use ``ksp()`` — never ``kapt()``. KAPT is deprecated.
KSP processors: Hilt compiler, Room compiler, any other annotation processor.

### Never do these
- ``implementation 'com.example:lib:1.0'`` — use version catalog
- ``kapt(...)`` — use ``ksp(...)``
- ``isDebuggable = true`` in release build type
- Hardcode API keys in build.gradle.kts — use BuildConfig with CI secrets

---

*GRADLE.md created: $date — Msingi v$VERSION*
*Review before every major Kotlin or AGP update.*
"@
}

function Build-LibsVersionsToml {
    param($Project)
    # Already embedded in GRADLE.md as documentation.
    # This generates the actual toml file.
    return @"
[versions]
kotlin              = "2.1.0"
agp                 = "8.7.3"
ksp                 = "2.1.0-1.0.29"
compose-bom         = "2024.12.01"
hilt                = "2.54"
coroutines          = "1.10.1"
retrofit            = "2.11.0"
okhttp              = "4.12.0"
room                = "2.6.1"
lifecycle           = "2.8.7"
navigation-compose  = "2.8.5"
coil                = "2.7.0"
junit               = "4.13.2"
junit-ext           = "1.2.1"
espresso            = "3.6.1"
mockk               = "1.13.13"
turbine             = "1.2.0"

[libraries]
kotlin-stdlib                   = { module = "org.jetbrains.kotlin:kotlin-stdlib",                       version.ref = "kotlin" }
compose-bom                     = { group = "androidx.compose",                    name = "compose-bom",                     version.ref = "compose-bom" }
compose-ui                      = { group = "androidx.compose.ui",                 name = "ui" }
compose-ui-graphics             = { group = "androidx.compose.ui",                 name = "ui-graphics" }
compose-ui-tooling              = { group = "androidx.compose.ui",                 name = "ui-tooling" }
compose-ui-tooling-preview      = { group = "androidx.compose.ui",                 name = "ui-tooling-preview" }
compose-material3               = { group = "androidx.compose.material3",           name = "material3" }
compose-activity                = { module = "androidx.activity:activity-compose",                       version = "1.9.3" }
compose-ui-test-junit4          = { group = "androidx.compose.ui",                 name = "ui-test-junit4" }
compose-ui-test-manifest        = { group = "androidx.compose.ui",                 name = "ui-test-manifest" }
hilt-android                    = { module = "com.google.dagger:hilt-android",                           version.ref = "hilt" }
hilt-compiler                   = { module = "com.google.dagger:hilt-android-compiler",                  version.ref = "hilt" }
hilt-navigation-compose         = { module = "androidx.hilt:hilt-navigation-compose",                    version = "1.2.0" }
coroutines-android              = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-android",          version.ref = "coroutines" }
coroutines-test                 = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test",             version.ref = "coroutines" }
room-runtime                    = { module = "androidx.room:room-runtime",                                version.ref = "room" }
room-ktx                        = { module = "androidx.room:room-ktx",                                   version.ref = "room" }
room-compiler                   = { module = "androidx.room:room-compiler",                               version.ref = "room" }
retrofit-core                   = { module = "com.squareup.retrofit2:retrofit",                           version.ref = "retrofit" }
retrofit-gson                   = { module = "com.squareup.retrofit2:converter-gson",                     version.ref = "retrofit" }
okhttp-core                     = { module = "com.squareup.okhttp3:okhttp",                               version.ref = "okhttp" }
okhttp-logging                  = { module = "com.squareup.okhttp3:logging-interceptor",                  version.ref = "okhttp" }
lifecycle-viewmodel-compose     = { module = "androidx.lifecycle:lifecycle-viewmodel-compose",             version.ref = "lifecycle" }
lifecycle-runtime-ktx           = { module = "androidx.lifecycle:lifecycle-runtime-ktx",                  version.ref = "lifecycle" }
navigation-compose              = { module = "androidx.navigation:navigation-compose",                     version.ref = "navigation-compose" }
coil-compose                    = { module = "io.coil-kt:coil-compose",                                   version.ref = "coil" }
junit                           = { module = "junit:junit",                                               version.ref = "junit" }
junit-ext                       = { module = "androidx.test.ext:junit",                                   version.ref = "junit-ext" }
espresso-core                   = { module = "androidx.test.espresso:espresso-core",                      version.ref = "espresso" }
mockk                           = { module = "io.mockk:mockk",                                            version.ref = "mockk" }
turbine                         = { module = "app.cash.turbine:turbine",                                   version.ref = "turbine" }

[plugins]
android-application             = { id = "com.android.application",                version.ref = "agp" }
android-library                 = { id = "com.android.library",                    version.ref = "agp" }
kotlin-android                  = { id = "org.jetbrains.kotlin.android",            version.ref = "kotlin" }
kotlin-compose                  = { id = "org.jetbrains.kotlin.plugin.compose",     version.ref = "kotlin" }
ksp                             = { id = "com.google.devtools.ksp",                 version.ref = "ksp" }
hilt                            = { id = "com.google.dagger.hilt.android",          version.ref = "hilt" }
"@
}

# ═══════════════════════════════════════════════════════════════════════════════
# NATIVE AGENT CONFIG BUILDERS
# ═══════════════════════════════════════════════════════════════════════════════

function Build-NativeAgentFiles {
    param($Agent, $Project, $Skills, $Type, [string]$Root)
    $nc = $Agent.nativeConfig
    if (-not $nc) { return }

    switch ($Agent.id) {
        "claude-code"  { Build-ClaudeNativeConfig  -Project $Project -Skills $Skills -Type $Type -Root $Root }
        "gemini-cli"   { Build-GeminiNativeConfig   -Project $Project -Root $Root }
        "opencode"     { Build-OpenCodeNativeConfig -Project $Project -Root $Root }
        "aider"        { Build-AiderNativeConfig    -Project $Project -Root $Root }
        "deepagents"   { Build-DeepAgentsNativeConfig -Project $Project -Root $Root }
        "antigravity"  { Build-AntigravityNativeConfig -Project $Project -Skills $Skills -Root $Root }
    }
}

function Build-ClaudeNativeConfig {
    param($Project, $Skills, $Type, [string]$Root)

    # .claude/settings.json — permissions and safety
    $settingsObj = @{
        permissions = @{
            allow = @(
                "Read(*)"
                "Write(src/**)"
                "Write(skills/**)"
                "Write(scratchpads/**)"
                "Write(memory/**)"
                "Write(TASKS.md)"
                "Write(DISCOVERY.md)"
                "Write(WORKSTREAMS.md)"
            )
            deny = @(
                "Write(.env*)"
                "Write(*.pem)"
                "Write(*.key)"
            )
        }
    }
    Emit ".claude\settings.json" ($settingsObj | ConvertTo-Json -Depth 4) $Root

    # .claude/rules/security.md — path-scoped, lazy-loaded when touching auth/security files
    $secRules = @"
---
paths:
  - "**/auth/**"
  - "**/security/**"
  - "**/crypto/**"
  - "**/*auth*"
  - "**/*token*"
  - "**/*session*"
  - "SECURITY.md"
---
# Security Rules

These rules activate when you touch authentication, security, or cryptography files.

## Mandatory checks
- Read SECURITY.md before any implementation in these paths
- All auth flows must validate tokens server-side — never trust client-only validation
- Secrets must come from environment variables — never hardcode credentials
- Log security decisions to memory/decisions/ with Severity: CRITICAL
- Rate-limit all authentication endpoints
- Sanitize and validate all external inputs before processing

## Before committing
- Confirm no secrets in diff (API keys, passwords, tokens, connection strings)
- Confirm no PII in log statements
- Confirm error messages do not leak internal structure
"@
    Emit ".claude\rules\security.md" $secRules $Root

    # .claude/rules/quality.md — path-scoped, lazy-loaded when touching source files
    $qualRules = @"
---
paths:
  - "**/src/**"
  - "**/lib/**"
  - "**/app/**"
  - "**/components/**"
  - "**/services/**"
---
# Quality Rules

These rules activate when you modify source code.

## Before marking any task complete
- Verify against every applicable gate in QUALITY.md
- Run tests — a passing build is not a passing feature
- Check the relevant skill spec in skills/ if implementing a skill
- Update gotchas.md if you hit a failure pattern

## Code standards
- Explicit return types on public functions and API boundaries
- Functions exceeding 50 lines should be evaluated for extraction
- No dead or commented-out code in committed files
- All external inputs validated at the boundary
"@
    Emit ".claude\rules\quality.md" $qualRules $Root

    # .claude/commands/implement.md — workflow command
    $implCmd = @"
# /project:implement — Skill Implementation Workflow

When the user invokes this command, follow this sequence:

1. **Identify the skill**: Ask which skill to implement, or infer from context
2. **Read the spec**: Load ``skills/<id>/SKILL.md`` — understand acceptance criteria
3. **Read gotchas**: Load ``skills/<id>/gotchas.md`` — start with highest-confidence entries
4. **Propose contract**: Map each acceptance criterion to a testable verification step
5. **Implement**: Write the code, following QUALITY.md gates
6. **Verify**: Run tests, check each acceptance criterion against your contract
7. **Update gotchas**: If you hit any failure patterns, append to gotchas.md
8. **Report**: Summarise what was done, what was verified, what remains
"@
    Emit ".claude\commands\implement.md" $implCmd $Root

    # .claude/commands/handoff.md — session handoff
    $handoffCmd = @"
# /project:handoff — Session Handoff

When the user invokes this command, perform a clean session handoff:

1. **Write SESSION.md delta**: Prepend a new block to ``scratchpads/claude-code/SESSION.md``
   - Record: decisions made, files modified, exact state of each touched file
   - Use specific deltas (file:line, exact errors) not polished summaries
2. **Promote decisions**: Move any architectural decisions to ``memory/decisions/``
3. **Set status**: Choose one of:
   - **Complete** — all acceptance criteria met, QUALITY.md gates passed
   - **Partial** — work is incomplete, next action clearly stated
   - **ESCALATE** — blocked on a decision that requires human review
4. **Update TASKS.md**: Mark completed items, note in-progress items
5. **Final check**: Confirm SESSION.md has enough detail for the next session to resume without re-reading source files
"@
    Emit ".claude\commands\handoff.md" $handoffCmd $Root

    # .claude/commands/review.md — code review against quality gates
    $reviewCmd = @"
# /project:review — Quality Gate Review

When the user invokes this command, review the current work against quality gates:

1. **Load QUALITY.md**: Read all applicable quality gates
2. **Identify changes**: Check git diff or recent modifications
3. **Gate check**: For each applicable gate:
   - Pass: note what was verified
   - Fail: note what needs fixing and suggest specific remediation
   - N/A: note why the gate does not apply
4. **Security scan**: Check for hardcoded secrets, unsanitised inputs, PII in logs
5. **Report**: Produce a structured pass/fail summary with actionable items
"@
    Emit ".claude\commands\review.md" $reviewCmd $Root

    Write-Done "Native config: .claude/ (settings, rules, commands)"
}

function Build-GeminiNativeConfig {
    param($Project, [string]$Root)

    # .gemini/settings.json — model and sandbox defaults
    $settingsObj = @{ sandbox = $true }
    Emit ".gemini\settings.json" ($settingsObj | ConvertTo-Json -Depth 3) $Root

    # .gemini/GEMINI.md — scoped context (loaded in addition to root GEMINI.md)
    $gemCtx = @"
# Gemini CLI — Project-Scoped Context

> This file is loaded automatically by Gemini CLI when working in this project.
> It supplements the root GEMINI.md with project-specific constraints.

## Security constraints
- Read SECURITY.md before any work touching auth, tokens, or credentials
- Never hardcode secrets — use environment variables
- Log security decisions to ``memory/decisions/`` with Severity: CRITICAL

## Quality constraints
- Verify against QUALITY.md gates before marking any task complete
- Run tests after every implementation change
- Update ``skills/<id>/gotchas.md`` when you encounter failure patterns

## Context management
- Read ``scratchpads/gemini-cli/SESSION.md`` at session start for handoff state
- Write SESSION.md delta before ending any session
- Use NOTES.md for cross-session observations
"@
    Emit ".gemini\GEMINI.md" $gemCtx $Root

    Write-Done "Native config: .gemini/ (settings, context)"
}

function Build-OpenCodeNativeConfig {
    param($Project, [string]$Root)

    # .opencode/agents/researcher.md — research-focused agent
    $researchAgent = @"
# Researcher Agent

You are a research-focused agent for $($Project.Name).
Your role is to investigate, understand, and document — not to implement.

## Behaviour
- Read CONTEXT.md and DOMAIN.md before investigating
- Document findings in DISCOVERY.md
- When comparing approaches, record both options with trade-offs
- Do not modify ``src/`` files — your scope is documentation and analysis
- Promote confirmed decisions to ``memory/decisions/``

## Outputs
- DISCOVERY.md entries with hypothesis, method, outcome
- ``memory/decisions/`` entries for confirmed architectural choices
"@
    Emit ".opencode\agents\researcher.md" $researchAgent $Root

    # .opencode/agents/implementer.md — implementation-focused agent
    $implAgent = @"
# Implementer Agent

You are an implementation-focused agent for $($Project.Name).
Your role is to write code that passes quality gates.

## Behaviour
- Read the relevant SKILL.md before implementing any feature
- Read gotchas.md before starting — avoid known failure patterns
- Verify against QUALITY.md gates before marking work complete
- Update gotchas.md if you hit any new failure patterns
- Write SESSION.md delta when stopping mid-task

## Scope
- Write: ``src/``, ``skills/*/outputs/``, ``scratchpads/opencode/``
- Read: CONTEXT.md, QUALITY.md, SECURITY.md, ``skills/*/SKILL.md``
- Append only: ``memory/decisions/``, DISCOVERY.md
"@
    Emit ".opencode\agents\implementer.md" $implAgent $Root

    Write-Done "Native config: .opencode/agents/ (researcher, implementer)"
}

function Build-AiderNativeConfig {
    param($Project, [string]$Root)

    # .aider.conf.yml — auto-load context files at session start
    $confYml = @"
# Aider project configuration — generated by Msingi v$VERSION
# Auto-loads context files so Aider starts with project knowledge

read:
  - agents/AIDER.md
  - CONTEXT.md
  - QUALITY.md
  - TASKS.md
"@
    Emit ".aider.conf.yml" $confYml $Root

    # .aiderignore — keep Aider's context clean
    $aiderIgnore = @"
# Msingi scaffold — exclude from Aider repo map
# Context files are loaded explicitly via .aider.conf.yml read: key
scratchpads/
memory/
skills/*/outputs/
skills/*/assets/
skills/*/references/
workstreams/

# Other agent config directories
.claude/
.gemini/
.opencode/
.deepagents/
.agent/

# Build artifacts and dependencies
node_modules/
dist/
build/
.next/
__pycache__/
.venv/
vendor/
.gradle/
"@
    Emit ".aiderignore" $aiderIgnore $Root

    Write-Done "Native config: .aider.conf.yml, .aiderignore"
}

function Build-DeepAgentsNativeConfig {
    param($Project, [string]$Root)

    # .deepagents/AGENTS.md — project-specific persistent context
    $daCtx = @"
# Deep Agents — Project Context

**Project:** $($Project.Name)
**Type:** $($Project.TypeLabel)

## Session protocol
1. Read ``scratchpads/deepagents/SESSION.md`` for handoff state
2. Read TASKS.md for current work
3. Read the relevant SKILL.md before implementing any feature
4. Verify against QUALITY.md gates before marking work complete

## Rules
- Security decisions logged in ``memory/decisions/`` with Severity: CRITICAL
- Update ``skills/<id>/gotchas.md`` when you encounter failure patterns
- Write SESSION.md delta before ending any session
- Set Status: ESCALATE when blocked on human-required decisions

## Scope
- Read: CONTEXT.md, QUALITY.md, SECURITY.md, ``skills/*/SKILL.md``
- Write: ``src/``, ``scratchpads/deepagents/``, ``skills/*/outputs/``
- Append only: ``memory/decisions/``, DISCOVERY.md, DOMAIN.md
"@
    Emit ".deepagents\AGENTS.md" $daCtx $Root

    Write-Done "Native config: .deepagents/ (AGENTS.md)"
}

function Build-AntigravityNativeConfig {
    param($Project, $Skills, [string]$Root)

    # .agent/rules/security.md
    $secRules = @"
# Security Rules

## When to apply
These rules apply when modifying any file related to authentication, authorization,
secrets management, cryptography, or data privacy.

## Mandatory checks
- Read SECURITY.md before any implementation touching auth or credentials
- Secrets must come from environment variables — never hardcode credentials
- All auth flows must validate tokens server-side
- Log security decisions to ``memory/decisions/`` with Severity: CRITICAL
- Rate-limit all authentication endpoints
- Sanitize and validate all external inputs at the boundary
- Error messages must not leak internal structure or stack traces
- No PII in application logs
"@
    Emit ".agent\rules\security.md" $secRules $Root

    # .agent/rules/quality.md
    $qualRules = @"
# Quality Rules

## When to apply
These rules apply when modifying source code or marking tasks complete.

## Before marking any task complete
- Verify against every applicable gate in QUALITY.md
- Run tests — a passing build is not a passing feature
- Check the relevant skill spec in ``skills/`` if implementing a skill
- Update gotchas.md if you hit a failure pattern

## Code standards
- Explicit return types on public functions and API boundaries
- Functions exceeding 50 lines should be evaluated for extraction
- No dead or commented-out code in committed files
- All external inputs validated at the boundary
- Write tests for new business logic before marking a task complete
"@
    Emit ".agent\rules\quality.md" $qualRules $Root

    # .agent/commands/implement.md
    $implCmd = @"
# /implement — Skill Implementation Workflow

1. **Identify the skill**: Ask which skill to implement, or infer from context
2. **Read the spec**: Load ``skills/<id>/SKILL.md`` — understand acceptance criteria
3. **Read gotchas**: Load ``skills/<id>/gotchas.md`` — highest-confidence entries first
4. **Propose contract**: Map each acceptance criterion to a testable verification step
5. **Implement**: Write the code, following QUALITY.md gates
6. **Verify**: Run tests, check each acceptance criterion
7. **Update gotchas**: Append to gotchas.md if you hit failure patterns
8. **Report**: Summarise what was done, what was verified, what remains
"@
    Emit ".agent\commands\implement.md" $implCmd $Root

    # .agent/commands/handoff.md
    $handoffCmd = @"
# /handoff — Session Handoff

1. **Write SESSION.md delta**: Prepend a new block to ``scratchpads/antigravity/SESSION.md``
   - Record: decisions made, files modified, exact state of each touched file
   - Use specific deltas (file:line, exact errors) not polished summaries
2. **Promote decisions**: Move architectural decisions to ``memory/decisions/``
3. **Set status**: Complete | Partial | ESCALATE
4. **Update TASKS.md**: Mark completed items, note in-progress items
5. **Confirm**: SESSION.md has enough detail for the next session to resume
"@
    Emit ".agent\commands\handoff.md" $handoffCmd $Root

    # .agent/workflows/review.md
    $reviewWf = @"
# Review Workflow

## Purpose
Review current work against quality gates and security requirements.

## Steps
1. Load QUALITY.md — read all applicable quality gates
2. Identify changes — check recent modifications
3. For each applicable gate: pass, fail (with remediation), or N/A (with reason)
4. Security scan — check for hardcoded secrets, unsanitised inputs, PII in logs
5. Produce a structured pass/fail summary
"@
    Emit ".agent\workflows\review.md" $reviewWf $Root

    Write-Done "Native config: .agent/ (rules, commands, workflows)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# WRITE HELPERS
# ═══════════════════════════════════════════════════════════════════════════════
function Write-ProjectFile {
    param([string]$FullPath, [string]$Content)
    $dir = Split-Path $FullPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $FullPath -Value $Content -Encoding UTF8 -NoNewline
}

function Emit {
    param([string]$RelPath, [string]$Content, [string]$Root)
    $full = Join-Path $Root ($RelPath -replace "/","\\")
    if (-not $DryRun) { Write-ProjectFile -FullPath $full -Content $Content }
    Write-Done $RelPath
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXECUTION PLAN SCREEN
# ═══════════════════════════════════════════════════════════════════════════════
function Show-ExecutionPlan {
    param($Project, $Agents, $Skills, [string]$WorkflowMode)

    Clear-Host
    Write-Host ""
    Write-Host "  $BRAND$($C.Bold)EXECUTION PLAN$($C.Reset)  $(dim "$WorkflowMode mode")$($C.Reset)"
    Write-Host ""
    Write-Rule

    $audienceMap = @{ public="Public users"; internal="Internal / team"; b2b="B2B clients"; mobile="Mobile app users" }
    $deployMap   = @{ cloud="Cloud (managed)"; "on-prem"="On-premises"; edge="Edge / CDN"; "mobile-store"="Mobile store"; desktop="Desktop install" }
    $scaleMap    = @{ personal="Personal"; "small-team"="Small team"; growth="Growth"; enterprise="Enterprise" }

    # ── Project Summary ─────────────────────────────────────────────────────────
    Write-Host "  $(hi "PROJECT")"
    $typeDisplay = if ($Project.SecondaryTypeId) {
        "$($Project.TypeLabel) + $($Project.SecondaryTypeLabel)"
    } else { $Project.TypeLabel }
    Write-Host "    $($Project.Name) $(dim "($typeDisplay)")"
    Write-Host "    Mode: $($Project.Mode) | Stack: $(if ($Project.Stack) { $Project.Stack -join ', ' } else { 'not specified' })"
    Write-Host ""

    # ── Intake ───────────────────────────────────────────────────────────────────
    Write-Host "  $(hi "INTAKE")"
    $aud = if ($audienceMap[$Project.Audience]) { $audienceMap[$Project.Audience] } else { "not set" }
    $dep = if ($deployMap[$Project.DeploymentTarget]) { $deployMap[$Project.DeploymentTarget] } else { "not set" }
    $scl = if ($scaleMap[$Project.ScaleProfile]) { $scaleMap[$Project.ScaleProfile] } else { "not set" }
    $auth = if ($Project.NeedsAuth) { ok "Required" } else { dim "None" }
    Write-Host "    Audience: $aud | Auth: $auth | Deploy: $dep"
    Write-Host "    Scale: $scl"
    Write-Host ""

    # ── Agents ───────────────────────────────────────────────────────────────────
    Write-Host "  $(hi "AGENTS") ($($Agents.Count))"
    $agentNames = ($Agents | ForEach-Object { $_.name }) -join ", "
    Write-Host "    $agentNames"
    Write-Host ""

    # ── Skills with explainability ─────────────────────────────────────────────
    Write-Host "  $(hi "SKILLS") ($($Skills.Count) inferred)"
    foreach ($s in $Skills) {
        $conf = if ($s.Confidence) { $s.Confidence } else { 1 }
        $dots = ""
        for ($i = 1; $i -le 5; $i++) {
            $dots += if ($i -le $conf) { "●" } else { "○" }
        }
        $cat = if ($s.category) { $s.category } else { "?" }
        $triggerInfo = ""
        if ($s.TriggerMatches -and $s.TriggerMatches.Count -gt 0) {
            $triggerInfo = " ← ""$($s.TriggerMatches -join '", "')"""
        }
        Write-Host "    $(dim $dots) $($s.name) $(dim "[$cat]")$triggerInfo"
    }
    Write-Host ""

    # ── Files to generate ───────────────────────────────────────────────────────
    Write-Host "  $(hi "FILES")"
    Write-Host "    CONTEXT.md, TASKS.md, DOMAIN.md, WORKSTREAMS.md"
    Write-Host "    SECURITY.md, QUALITY.md, OBSERVABILITY.md, ENVIRONMENTS.md"
    Write-Host "    agents/, skills/, scratchpads/, memory/, docs/, .plans/"
    # Native config directories per agent
    foreach ($a in $Agents) {
        $nc = $a.nativeConfig
        if ($nc -and $nc.configDir) {
            $supList = ($nc.supports | ForEach-Object { $_ }) -join ", "
            Write-Host "    $(dim "$($nc.configDir)/") ($supList)"
        } elseif ($nc -and $nc.supports) {
            $supList = ($nc.supports | ForEach-Object { $_ }) -join ", "
            Write-Host "    $(dim "$($a.name):") $supList"
        }
    }
    Write-Host ""

    Write-Rule
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# REVIEW SCREEN
# ═══════════════════════════════════════════════════════════════════════════════
function Show-Review {
    param($Project, $Agents, $Skills)

    $audienceMap = @{ public="Public users"; internal="Internal / team"; b2b="B2B clients"; mobile="Mobile app users" }
    $deployMap   = @{ cloud="Cloud (managed)"; "on-prem"="On-premises"; edge="Edge / CDN"; "mobile-store"="Mobile store"; desktop="Desktop install" }
    $scaleMap    = @{ personal="Personal / side project"; "small-team"="Small team"; growth="Growth"; enterprise="Enterprise" }

    $typeDisplay  = if ($Project.SecondaryTypeId) {
        "$($Project.TypeLabel)  $(dim "+")  $($Project.SecondaryTypeLabel)"
    } else { $Project.TypeLabel }

    $audienceLabel = if ($Project.Audience -and $audienceMap[$Project.Audience])          { $audienceMap[$Project.Audience] }           else { dim "not set" }
    $deployLabel   = if ($Project.DeploymentTarget -and $deployMap[$Project.DeploymentTarget]) { $deployMap[$Project.DeploymentTarget] } else { dim "not set" }
    $scaleLabel    = if ($Project.ScaleProfile -and $scaleMap[$Project.ScaleProfile])     { $scaleMap[$Project.ScaleProfile] }          else { dim "not set" }
    $authLabel     = if ($Project.NeedsAuth)            { ok "Yes" }  else { dim "No" }
    $dataLabel     = if ($Project.HandlesSensitiveData) {
        $tags = if ($Project.PSObject.Properties["SensitiveDataTags"]) { $Project.SensitiveDataTags } else { "Yes" }
        warn $tags
    } else { dim "None" }

    # ── Project panel ─────────────────────────────────────────────────────────
    Write-Section "Project"
    Write-KVTable @(
        @{ Key="Name";        Value=$Project.Name;        Color="BrCyan" }
        @{ Key="Type";        Value=$typeDisplay;         Color="White"  }
        @{ Key="Mode";        Value=$Project.Mode;        Color="Gray"   }
        @{ Key="Description"; Value=$Project.Description; Color="White"  }
        @{ Key="Stack";       Value=$(if ($Project.Stack -and $Project.Stack.Count -gt 0) { $Project.Stack -join ' · ' } else { "not specified" }); Color="Gray" }
        @{ Key="Milestone";   Value=$Project.Milestone;   Color="BrYellow" }
        @{ Key="Target";      Value=$Project.TargetPath;  Color="Gray"   }
    )

    # ── Intake panel ──────────────────────────────────────────────────────────
    Write-Section "Intake profile"
    Write-KVTable @(
        @{ Key="Audience";       Value=$audienceLabel; Color="White"   }
        @{ Key="Auth required";  Value=$(if ($Project.NeedsAuth) { "Yes" } else { "No" }); Color=$(if ($Project.NeedsAuth) { "BrGreen" } else { "Gray" }) }
        @{ Key="Sensitive data"; Value=$(if ($Project.HandlesSensitiveData) { if ($Project.PSObject.Properties["SensitiveDataTags"]) { $Project.SensitiveDataTags } else { "Yes" } } else { "None" }); Color=$(if ($Project.HandlesSensitiveData) { "BrYellow" } else { "Gray" }) }
        @{ Key="Deployment";     Value=$deployLabel;  Color="White"   }
        @{ Key="Scale";          Value=$scaleLabel;   Color="White"   }
    )

    # ── Agents panel ──────────────────────────────────────────────────────────
    Write-Section "Agents  ($($Agents.Count))"
    foreach ($a in $Agents) {
        Write-Host "  $($C.BrGreen)●$($C.Reset)  $($C.Bold)$($a.name)$($C.Reset)  $($C.Gray)$($a.file)$($C.Reset)"
    }

    # ── Skills panel ──────────────────────────────────────────────────────────
    Write-Section "Skills  ($($Skills.Count))"
    $cols = [Math]::Max(1, [Math]::Floor(([Console]::WindowWidth - 6) / 32))
    $col  = 0
    $line = "  "
    foreach ($s in $Skills) {
        $pill = "$(pill $s.name $(if ($s.baseline) { "BrGreen" } else { "BrCyan" }))"
        $line += $pill + "  "
        $col++
        if ($col -ge $cols) { Write-Host $line; $line = "  "; $col = 0 }
    }
    if ($col -gt 0) { Write-Host $line }

    # ── Files panel ───────────────────────────────────────────────────────────
    Write-Section "Generated files"
    Write-Info "CONTEXT.md  TASKS.md  DISCOVERY.md  WORKSTREAMS.md  DOMAIN.md"
    Write-Info "CHANGELOG.md  STRUCTURE.md  README.md  PLANS.md"
    Write-Info "QUALITY.md  SECURITY.md  ENVIRONMENTS.md  OBSERVABILITY.md"
    Write-Info "agents/  skills/<id>/{SKILL.md,gotchas.md,scripts/}  scratchpads/  memory/decisions/  docs/  .plans/"
    foreach ($a in $Agents) {
        $nc = $a.nativeConfig
        if ($nc -and $nc.configDir) {
            $supList = ($nc.supports | ForEach-Object { $_ }) -join ", "
            Write-Info "$($nc.configDir)/ ($supList)  $(dim "← $($a.name) native")"
        } elseif ($nc -and $nc.supports) {
            Write-Info "$($a.name) native: $(($nc.supports | ForEach-Object { $_ }) -join ', ')"
        }
    }
    if ($Project.TypeId -eq "android") {
        Write-Info "GRADLE.md  gradle/libs.versions.toml  proguard-rules.pro"
    }
    Write-Host ""
    Write-Rule
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

# ── msingi -Update ─────────────────────────────────────────────────────────────
if ($Update) {
    Clear-Host
    Write-Host ""
    Write-Host "  $BRAND_B⬡ Msingi  v$VERSION$($C.Reset)  $($C.Gray)Self-update$($C.Reset)"
    Write-Host ""

    $scriptPath = $PSCommandPath
    if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
        Write-Warn "Cannot determine script path. Run from the Msingi tool directory."
        exit 1
    }

    Write-Info "Checking GitHub for latest release..."

    try {
        $headers = @{ "User-Agent" = "Msingi/$VERSION" }
        $apiUrl  = "https://api.github.com/repos/xdagee/msingi/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10

        $latestTag  = $release.tag_name -replace '^v', ''
        $latestFull = $release.tag_name
        $pubDate    = $release.published_at.Substring(0, 10)

        Write-Done "Current version : $VERSION"
        Write-Done "Latest release  : $latestFull  ($pubDate)"
        Write-Host ""

        if ($latestTag -eq $VERSION) {
            Write-Done "You are already on the latest version."
            Write-Host ""
            exit 0
        }

        # Find PS1 asset in the release, fall back to raw main
        $ps1Asset = $release.assets | Where-Object { $_.name -like "msingi*.ps1" } | Select-Object -First 1
        $ps1Url   = if ($ps1Asset) { $ps1Asset.browser_download_url } else {
            Write-Info "No release asset found — downloading from main branch"
            "https://raw.githubusercontent.com/xdagee/msingi/main/msingi.ps1"
        }

        Write-Host "  $BRAND?$($C.Reset)  $($C.Bold)Update to $latestFull?$($C.Reset)  $($C.Gray)(Y/n)$($C.Reset)  " -NoNewline
        $confirm = Read-Host
        if ($confirm -match '^[nN]') { Write-Info "Update cancelled."; exit 0 }

        # Backup
        $backupPath = "$scriptPath.bak.$VERSION"
        Copy-Item -Path $scriptPath -Destination $backupPath -Force
        Write-Done "Backup: $backupPath"

        # Download
        Write-Info "Downloading $latestFull..."
        $tmp = [System.IO.Path]::GetTempFileName() + ".ps1"
        Invoke-WebRequest -Uri $ps1Url -OutFile $tmp -Headers $headers -TimeoutSec 30
        Unblock-File -Path $tmp -ErrorAction SilentlyContinue

        # Validate
        $newContent = Get-Content $tmp -Raw -ErrorAction Stop
        if (-not ($newContent -match '#Requires -Version 7') -or -not ($newContent -match '\$VERSION')) {
            Remove-Item $tmp -ErrorAction SilentlyContinue
            Write-Warn "Downloaded file failed validation. Update aborted."
            Write-Info "Backup preserved at: $backupPath"
            exit 1
        }

        Copy-Item -Path $tmp -Destination $scriptPath -Force
        Remove-Item $tmp -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Done "Updated to $latestFull"
        Write-Host ""
        Write-Info "Restart your terminal or run `` . `$PROFILE `` to reload."
        Write-Info "Backup at: $backupPath  (delete once confirmed working)"
        Write-Host ""

    } catch {
        Write-Warn "Update failed: $_"
        Write-Info "Update manually: https://github.com/xdagee/msingi/releases"
        exit 1
    }
    exit 0
}

# ── msingi -Check ──────────────────────────────────────────────────────────────
if ($Check) {
    $checkRoot = if ($Path) { $Path } else { Get-Location }
    Clear-Host
    Write-Host ""
    Write-Host "  $BRAND_B⬡ Msingi  v$VERSION$($C.Reset)  $($C.Gray)Context health check$($C.Reset)"
    Write-Host ""

    # Verify this is a Msingi project
    $recordPath = Join-Path $checkRoot "memory\bootstrap-record.json"
    if (-not (Test-Path $recordPath)) {
        Write-Warn "No bootstrap-record.json found. Is this a Msingi project?"
        Write-Info "Expected: $recordPath"
        Write-Info "Run 'msingi' in a new directory to initialise a project."
        exit 1
    }

    $record = Get-Content $recordPath -Raw | ConvertFrom-Json
    $projName = $record.project.name
    Write-Done "Project: $projName ($(if($record.project.typeLabel){$record.project.typeLabel}else{'?'}))"
    Write-Done "Bootstrapped with Msingi v$($record.version)"
    Write-Host ""
    Write-Rule
    Write-Host ""

    $issues   = 0
    $warnings = 0

    # ── Core file freshness ────────────────────────────────────────────────────
    $coreFiles = @(
        @{ path="CONTEXT.md";     maxAgeDays=30; label="CONTEXT.md";     critical=$true  }
        @{ path="TASKS.md";       maxAgeDays=7;  label="TASKS.md";       critical=$true  }
        @{ path="DOMAIN.md";      maxAgeDays=60; label="DOMAIN.md";      critical=$false }
        @{ path="WORKSTREAMS.md"; maxAgeDays=14; label="WORKSTREAMS.md"; critical=$false }
        @{ path="DISCOVERY.md";   maxAgeDays=30; label="DISCOVERY.md";   critical=$false }
        @{ path="SECURITY.md";    maxAgeDays=90; label="SECURITY.md";    critical=$false }
    )

    Write-Section "Core files"
    foreach ($f in $coreFiles) {
        $fp = Join-Path $checkRoot $f.path
        if (-not (Test-Path $fp)) {
            if ($f.critical) {
                Write-Fail "$($f.label) is MISSING — this will break agent context"
                $issues++
            } else {
                Write-Warn "$($f.label) not found (run 'msingi' to generate)"
                $warnings++
            }
            continue
        }
        $age = [int]((Get-Date) - (Get-Item $fp).LastWriteTime).TotalDays
        if ($age -gt $f.maxAgeDays) {
            Write-Warn "$($f.label) last modified $age days ago — review for drift"
            $warnings++
        } else {
            Write-Done "$($f.label)  $($C.Gray)(updated $age day$(if($age -ne 1){'s'}) ago)$($C.Reset)"
        }
    }

    # ── ESCALATE check ─────────────────────────────────────────────────────────
    Write-Host ""
    Write-Section "Escalation status"
    $scratchpadsDir = Join-Path $checkRoot "scratchpads"
    $escalated = @()
    if (Test-Path $scratchpadsDir) {
        Get-ChildItem $scratchpadsDir -Directory | ForEach-Object {
            $sess = Join-Path $_.FullName "SESSION.md"
            if (Test-Path $sess) {
                $sessContent = Get-Content $sess -Raw -ErrorAction SilentlyContinue
                if ($sessContent -match 'Status:.*ESCALATE' -and $sessContent -notmatch '\[x\].*ESCALATE') {
                    $escalated += $_.Name
                }
            }
        }
    }
    if ($escalated.Count -gt 0) {
        Write-Fail "ESCALATE unresolved in: $($escalated -join ', ')"
        Write-Info "Resolve escalation before the next agent session."
        $issues++
    } else {
        Write-Done "No unresolved escalations"
    }

    # ── NOTES.md size check ────────────────────────────────────────────────────
    Write-Host ""
    Write-Section "Memory tiers"
    if (Test-Path $scratchpadsDir) {
        Get-ChildItem $scratchpadsDir -Directory | ForEach-Object {
            $notes = Join-Path $_.FullName "NOTES.md"
            if (Test-Path $notes) {
                $lineCount = (Get-Content $notes).Count
                if ($lineCount -gt 300) {
                    Write-Warn "$($_.Name)/NOTES.md is $lineCount lines — compress to NOTES-archive.md"
                    $warnings++
                } else {
                    Write-Done "$($_.Name)/NOTES.md  $($C.Gray)($lineCount lines — healthy)$($C.Reset)"
                }
            }
        }
    }

    # ── Skill implementation status ────────────────────────────────────────────
    Write-Host ""
    Write-Section "Skills"
    $skillsDir = Join-Path $checkRoot "skills"
    $unimpl = 0; $inprog = 0; $done = 0; $stale = 0
    if (Test-Path $skillsDir) {
        Get-ChildItem $skillsDir -Directory | ForEach-Object {
            $spec = Join-Path $_.FullName "SKILL.md"
            if (Test-Path $spec) {
                $specContent = Get-Content $spec -Raw -ErrorAction SilentlyContinue
                $age = [int]((Get-Date) - (Get-Item $spec).LastWriteTime).TotalDays
                if     ($specContent -match 'Status:.*UNIMPLEMENTED') { $unimpl++ }
                elseif ($specContent -match 'Status:.*IN PROGRESS')   { $inprog++ }
                elseif ($specContent -match 'Status:.*IMPLEMENTED')   { $done++   }
                if ($age -gt 45 -and $specContent -match 'Status:.*IN PROGRESS') { $stale++ }
            }
        }
        Write-Done "IMPLEMENTED: $done  IN PROGRESS: $inprog  UNIMPLEMENTED: $unimpl"
        if ($stale -gt 0) {
            Write-Warn "$stale skill(s) have been IN PROGRESS for over 45 days"
            $warnings++
        }
        if ($unimpl -gt 0) {
            Write-Info "$unimpl skill(s) still unimplemented — update TASKS.md priority"
        }
    } else {
        Write-Warn "skills/ directory not found"
        $warnings++
    }

    # ── Summary ────────────────────────────────────────────────────────────────
    Write-Host ""
    Write-Rule
    Write-Host ""
    if ($issues -eq 0 -and $warnings -eq 0) {
        Write-Host "  $($C.BrGreen)$($C.Bold)✓  Context health: GOOD$($C.Reset)  $($C.Gray)No issues found.$($C.Reset)"
    } elseif ($issues -eq 0) {
        Write-Host "  $(warn "⚠")  $($C.Bold)Context health: FAIR$($C.Reset)  $($C.Gray)$warnings warning(s) — review above.$($C.Reset)"
    } else {
        Write-Host "  $(err "✗")  $($C.Bold)Context health: DEGRADED$($C.Reset)  $($C.Gray)$issues critical issue(s), $warnings warning(s).$($C.Reset)"
    }
    Write-Host ""
    exit 0
}

# ── Independent window detection ────────────────────────────────────────────
# If MSINGI_LAUNCHED is not set, we are running in the user's existing shell.
# Spawn a clean Windows Terminal / conhost window at ideal dimensions and exit.
# Exception: -Update and -Check are lightweight — they run inline.
if (-not $env:MSINGI_LAUNCHED -and -not $DryRun -and -not $Update -and -not $Check) {
    $env:MSINGI_LAUNCHED = "1"
    $scriptPath = $PSCommandPath

    # Resolve the full path to pwsh.exe up front.
    # wt.exe and Start-Process resolve executables against the system PATH,
    # which may NOT include pwsh.exe's directory (per-user or session install).
    $pwshExe = (Get-Process -Id $PID).Path   # guaranteed: the running pwsh

    # Prefer Windows Terminal (wt) — best colour and Unicode support
    $wt = Get-Command "wt.exe" -ErrorAction SilentlyContinue
    if ($wt) {
        # Build a single argument string with explicit quoting.
        # Start-Process -ArgumentList with a string[] joins elements with spaces
        # but does NOT quote them — so "Msingi v3.8.1" becomes two tokens and
        # wt.exe misparses the command line.  A single pre-quoted string avoids this.
        $userArgs = ($args | ForEach-Object { $_ }) -join ' '
        $wtArgStr = "new-tab --title `"Msingi v$VERSION`" --tabColor `"#00D2C8`" -- `"$pwshExe`" -NoLogo -ExecutionPolicy Bypass -File `"$scriptPath`" $userArgs"
        Start-Process "wt.exe" -ArgumentList $wtArgStr
        exit 0
    }

    # Fallback: open in a new pwsh conhost window at 120×38
    $pwshArgs = "-NoLogo -ExecutionPolicy Bypass -Command `$host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(120,38); `$host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(120,200); & '$scriptPath' $($args -join ' ')"
    Start-Process $pwshExe -ArgumentList $pwshArgs
    exit 0
}

# ── Splash screen (only when running in a launched window) ──────────────────
if (-not $DryRun) {
    Write-Splash
}

if ($DryRun) {
    Clear-Host
    Write-Header -Mode "dry-run" -StepLabel "1/7"
    Write-Host ""
    Write-Host "  $(warn "⚠  DRY RUN — no files will be written")  $($C.Reset)"
    Write-Host ""
}

# ── Workflow Mode Selection ─────────────────────────────────────────────────────
function Select-WorkflowMode {
    Clear-Host
    Write-Host ""
    Write-Host "  $BRAND$($C.Bold)Msingi$($C.Reset)  $($C.Gray)v$VERSION  ·  Context Engineering$($C.Reset)"
    Write-Host ""
    Write-Host "  Select workflow mode:$($C.Reset)"
    Write-Host ""
    Write-Host "  $(dim "·" * 3)$(hi " Quick")      $(dim "— fastest, 3 questions")$(dim "|")"
    Write-Host "  $(dim "·" * 3)$(hi " Guided")    $(dim "— balanced, 7 steps")$(dim "|")" 
    Write-Host "  $(dim "·" * 3)$(hi " Advanced")  $(dim "— full control, 12+ options")$(dim "|")"
    Write-Host ""
    
    $modeItems = @(
        "Quick Mode      — 3 questions, fastest scaffold"
        "Guided Mode    — 7 steps, balanced experience"
        "Advanced Mode  — 12+ options, full control"
    )
    
    $modeIdx = Read-Choice -Items $modeItems -Selected 0 -Prompt "Select workflow"
    
    $workflowMode = @("quick", "guided", "advanced")[$modeIdx]
    return $workflowMode
}

$WORKFLOW_MODE = Select-WorkflowMode

# Define step counts per mode
$STEP_COUNTS = @{
    "quick" = 4      # Mode, Type, Details, Review (skip Intake, Agents, Skills - use defaults)
    "guided" = 7     # Mode, Type, Details, Intake, Agents, Skills, Review
    "advanced" = 12  # Mode, Type, Details, Intake, Agents, Skills, + Advanced questions, Review
}

$STEP_DEFS = @{
    "quick" = @("Mode", "Type", "Details", "Review")
    "guided" = @("Mode", "Type", "Details", "Intake", "Agents", "Skills", "Review")
    "advanced" = @("Mode", "Type", "Details", "Intake", "Agents", "Skills", "Auth", "Data", "Scale", "Env", "Obs", "Review")
}

$currentStepDefs = $STEP_DEFS[$WORKFLOW_MODE]
$totalSteps = $STEP_COUNTS[$WORKFLOW_MODE]

# Load data
$allAgents        = Load-Agents
$allSkillPatterns = Load-SkillPatterns

# ── Step Navigation State ────────────────────────────────────────────────────
$stepState = @{
    Completed = @()
    ModeIdx = 0
    TypeChecked = @()
    Project = $null
    SelectedAgents = @()
    SelectedSkills = @()
    QuickAgents = @()  # Default agents for Quick Mode
    QuickSkills = @()  # Default skills for Quick Mode
}
$stepCompleted = @($false) * $totalSteps

function Complete-Step {
    param([int]$Index)
    if ($Index -ge 0 -and $Index -lt $totalSteps -and -not $stepCompleted[$Index]) {
        $stepCompleted[$Index] = $true
        if ($Index -notin $stepState.Completed) {
            $stepState.Completed += $Index
        }
    }
}

function Can-Proceed-To {
    param([int]$TargetStep)
    if ($TargetStep -le 0) { return $true }
    for ($i = 0; $i -lt $TargetStep; $i++) {
        if (-not $stepCompleted[$i]) { return $false }
    }
    return $true
}

function Show-StepMenu {
    param([int]$CurrentStep)
    Write-Host ""
    Write-Host "  $(hi "?") Jump to step: $(dim "(Tab to cycle, Enter to go, Esc to stay)")"
    Write-Host ""
    for ($i = 0; $i -lt $totalSteps; $i++) {
        $label = $currentStepDefs[$i]
        $prefix = "     "
        if ($i -eq $CurrentStep) {
            $prefix = " $(hi "▶")"
        } elseif ($stepCompleted[$i]) {
            $prefix = " $(ok "✓")"
        } else {
            $prefix = " $(dim "·")"
        }
        $status = if ($stepCompleted[$i]) { "$(dim "done")" } elseif ($i -eq $CurrentStep) { "$(hi "current")" } else { "$(dim "pending")" }
        Write-Host "  $prefix  $(bold $label)  $(dim $status)"
    }
    Write-Host ""
}

$currentStep = 0
$exitLoop = $false

# Quick Mode defaults
if ($WORKFLOW_MODE -eq "quick") {
    $stepState.QuickAgents = @($allAgents | ForEach-Object { $true })
    $stepState.QuickSkills = @()
}

while ($currentStep -lt $totalSteps) {
    $stepName = $currentStepDefs[$currentStep]
    switch ($stepName) {
        "Mode" {
            Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Mode" -SectionSub "How would you like to proceed?"
            $defaultIdx = if ($stepState.ModeIdx -ge 0) { $stepState.ModeIdx } else { 0 }
            $modeIdx = Read-Choice -Items @(
                "New project       — start from scratch"
                "Existing project  — scan codebase and overlay structure"
            ) -Selected $defaultIdx -Prompt "What are we doing?"
            
            if ($modeIdx -eq -4) { # G (Goto)
                Show-StepMenu -CurrentStep $currentStep
                $jumpTo = Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"
                if ($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])) { $currentStep = $jumpTo }
                continue
            }
            if ($modeIdx -eq -1 -or $modeIdx -eq -3) { # Esc or Prev
                if (Read-Confirm "Exit Msingi?" $false) { exit 0 }
                continue
            }
            if ($modeIdx -ge 0 -or $modeIdx -eq -2) { # Selected or Next
                $idx = if ($modeIdx -eq -2) { $defaultIdx } else { $modeIdx }
                $stepState.ModeIdx = $idx
                $mode = if ($idx -eq 0) { "greenfield" } else { "brownfield" }
                Complete-Step -Index $currentStep
                $currentStep++
            }
        }
        "Type" {
            Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Project type" -SectionSub "Select one or two types. Hybrid merges skill pools — primary drives architecture." -Summary @($mode)
            $typeLabels = @($PROJECT_TYPES | ForEach-Object {
                $name = $_.label.PadRight(22)
                "$name  $($_.description)"
            })
            if ($stepState.TypeChecked.Count -eq 0) {
                $typeChecked = @($PROJECT_TYPES | ForEach-Object { $false })
                $typeChecked[0] = $true
            } else {
                $typeChecked = $stepState.TypeChecked
            }
            $validSelection = $false
            while (-not $validSelection) {
                $typeChecked = Read-Checkboxes -Items $typeLabels -Checked $typeChecked -Prompt "Project type(s)"
                if ($typeChecked -is [int]) {
                    if ($typeChecked -eq -4) { # G (Goto)
                        Show-StepMenu -CurrentStep $currentStep
                        $jumpTo = Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"
                        if ($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])) { $currentStep = $jumpTo }
                        $exitWhile = $true; break
                    }
                    if ($typeChecked -eq -1 -or $typeChecked -eq -3) { $currentStep--; $exitWhile = $true; break }
                    if ($typeChecked -eq -2) { $validSelection = $true; break }
                }
                if ($typeChecked -eq $null) { $currentStep--; $exitWhile = $true; break }
                
                $selectedTypeCount = ($typeChecked | Where-Object { $_ }).Count
                if ($selectedTypeCount -eq 0) {
                    Write-Warn "Select at least one type."
                } elseif ($selectedTypeCount -gt 2) {
                    Write-Warn "Select at most two types for hybrid composition."
                } else {
                    $validSelection = $true
                }
            }
            if ($exitWhile) { $exitWhile = $false; continue }
            $stepState.TypeChecked = $typeChecked
            $selectedTypeIndices = @(0..($PROJECT_TYPES.Count - 1) | Where-Object { $typeChecked[$_] })
            $selectedType = $PROJECT_TYPES[$selectedTypeIndices[0]]
            $secondaryType = if ($selectedTypeIndices.Count -gt 1) { $PROJECT_TYPES[$selectedTypeIndices[1]] } else { $null }
            if ($secondaryType) {
                $androidCombo = ($selectedType.id -eq "android" -or $secondaryType.id -eq "android")
                $bothMobile = ($selectedType.id -eq "android" -and $secondaryType.id -eq "android")
                if ($androidCombo -and -not $bothMobile) {
                    Write-Warn "Android + $( if ($selectedType.id -eq "android") { $secondaryType.label } else { $selectedType.label } ) is an unusual combination."
                    Write-Info "Android scaffold is self-contained. Secondary type skills will still be merged."
                    Write-Host ""
                }
                Write-Host "  $(ok "✓") Hybrid: $($selectedType.label)  $(dim "+")  $($secondaryType.label)"
            } else {
                Write-Host "  $(ok "✓") $($selectedType.label)"
            }
            Complete-Step -Index $currentStep
            $currentStep++
        }
        "Details" {
            Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Project details" -Summary @($mode, $selectedType.label)
            Write-Section "Project details"
            if ($null -eq $stepState.Project) {
                $project = [ordered]@{
                    Mode = $mode
                    TypeId = $selectedType.id
                    TypeLabel = $selectedType.label
                    SecondaryTypeId = if ($secondaryType) { $secondaryType.id } else { "" }
                    SecondaryTypeLabel = if ($secondaryType) { $secondaryType.label } else { "" }
                    Name = ""
                    Description = ""
                    Stack = @()
                    Milestone = "v1.0 release"
                    Audience = ""
                    NeedsAuth = $true
                    HandlesSensitiveData = $false
                    DeploymentTarget = ""
                    ScaleProfile = ""
                }
            } else {
                $project = $stepState.Project
            }
            if ($mode -eq "brownfield") {
                $defaultScan = if ($Path) { $Path } else { (Get-Location).Path }
                $scanInput = Read-Line "Directory to scan" $defaultScan
                if ($null -eq $scanInput) { $currentStep--; continue }
                if ($scanInput -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }

                $scanInput = [System.Environment]::ExpandEnvironmentVariables($scanInput) -replace "^~", $env:USERPROFILE
                if (-not (Test-Path $scanInput)) { Write-Fail "Directory not found: $scanInput"; exit 1 }
                $scanned = Invoke-ProjectScan -ScanPath $scanInput -Deep $false
                $goDeep = Read-Confirm "Run deeper scan? (slower, more thorough)" $false
                if ($goDeep -eq $null) { $currentStep--; continue }
                if ($goDeep) { $scanned = Invoke-ProjectScan -ScanPath $scanInput -Deep $true }
                Write-Host "  $(dim "Scan complete — review and edit inferred values.")"
                Write-Host ""
                $project.Name = Read-Line "Project name" $scanned.Name
                if ($project.Name -eq $null) { $currentStep--; continue }
                $project.Description = Read-Line "Description" $scanned.Description "(edit or confirm)"
                if ($project.Description -eq $null) { $currentStep--; continue }
                $stackStr = Read-Line "Stack" ($scanned.Stack -join ", ") "(edit freely)"
                if ($stackStr -eq $null) { $currentStep--; continue }
                $project.Stack = if ($stackStr) { @($stackStr -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } else { @() }
                $project.Milestone = Read-Line "Current milestone" $scanned.Milestone
                if ($project.Milestone -eq $null) { $currentStep--; continue }
                $project.TargetPath = $scanInput
            } else {
                $project.Name = Read-Line "Project name" $project.Name "(e.g. xdagee-web)"
                if ($project.Name -eq $null) { $currentStep--; continue }
                if (-not $project.Name) { Write-Fail "Project name is required."; exit 1 }
                $project.Description = Read-Line "Description" $project.Description "(one sentence — what it does and who it's for)"
                if ($project.Description -eq $null) { $currentStep--; continue }
                $stackStr = Read-Line "Stack" ($project.Stack -join ", ") "(e.g. PHP, MySQL, Tailwind CSS — or Kotlin, Jetpack Compose)"
                if ($stackStr -eq $null) { $currentStep--; continue }
                $project.Stack = if ($stackStr) { @($stackStr -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } else { @() }
                $project.Milestone = Read-Line "First milestone" $project.Milestone "(e.g. Auth & core API, Play Store release, v1.0 release)"
                if ($project.Milestone -eq $null) { $currentStep--; continue }
                $defaultTarget = if ($Path) { $Path } else { Join-Path (Get-Location).Path $project.Name }
                $targetInput = Read-Line "Target directory" $defaultTarget
                if ($targetInput -eq $null) { $currentStep--; continue }
                $project.TargetPath = [System.Environment]::ExpandEnvironmentVariables($targetInput) -replace "^~", $env:USERPROFILE
            }
            $stepState.Project = $project
            Complete-Step -Index 2
            
            # Quick Mode: skip Intake, Agents, Skills and go to Review
            if ($WORKFLOW_MODE -eq "quick") {
                # Apply Quick Mode defaults
                $project.Audience = "public"
                $project.NeedsAuth = $true
                $project.HandlesSensitiveData = $false
                $project.DeploymentTarget = "cloud"
                $project.ScaleProfile = "personal"
                
                # Select all agents by default
                $selectedAgents = $allAgents
                
                # Infer skills for Quick Mode
                $intakeSignals = @("public", "cloud", "personal", "auth login")
                $haystack = "$($project.Description) $(if ($project.Stack) { $project.Stack -join ' ' } else { '' }) $($project.TypeLabel) $($intakeSignals -join ' ')"
                $inferredSkills = Invoke-SkillInference -Haystack $haystack -TypeId $project.TypeId -Patterns $allSkillPatterns
                
                $stepState.QuickSkills = $inferredSkills
                $stepState.SelectedAgents = @($allAgents | ForEach-Object { $true })
                
                # Go directly to Review (step 3 in Quick Mode)
                $currentStep++
            } else {
                $currentStep++
            }
        }
        "Intake" {
            Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Smart intake" -SectionSub "A few targeted questions to sharpen your scaffold." -Summary @($project.Name, $project.TypeLabel, $mode)
            $audienceIdx = Read-Choice -Items @(
                "Public users        — anyone on the internet"
                "Internal team       — employees or developers only"
                "B2B clients         — other companies / API consumers"
                "Mobile app users    — primarily iOS or Android"
            ) -Selected ($stepState.Project.AudienceIdx -ge 0 ? $stepState.Project.AudienceIdx : 0) -Prompt "Who is the primary audience?"
            if ($audienceIdx -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
            if ($audienceIdx -lt 0) { $currentStep--; continue }
            $project.Audience = @("public","internal","b2b","mobile")[$audienceIdx]
            $stepState.Project.AudienceIdx = $audienceIdx
            
            # If Advanced Mode, we move to separate steps for Auth, Data, Scale
            if ($WORKFLOW_MODE -eq "advanced") {
                Write-Host ""
                Write-Host "  $(ok "✓") Audience recorded"
                Complete-Step -Index $currentStep
                $currentStep++
                continue
            }
            
            Write-Host ""
            if ($project.TypeId -ne "android") {
                $authIdx = Read-Choice -Items @(
                    "Yes — users or services must authenticate"
                    "No  — fully public or pre-authenticated environment"
                ) -Selected ($stepState.Project.AuthIdx -ge 0 ? $stepState.Project.AuthIdx : 0) -Prompt "Does this system require authentication?"
                if ($authIdx -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
                if ($authIdx -lt 0) { $currentStep--; continue }
                $project.NeedsAuth = ($authIdx -eq 0)
                $stepState.Project.AuthIdx = $authIdx
            } else {
                $project.NeedsAuth = $true
                Write-Info "Auth: required (Android — defaulting to Yes)"
            }
            Write-Host ""
            Write-Host "  $(hi "?") What sensitive data will this system handle? $(dim "(Space toggle · Enter confirm)")"
            Write-Host ""
            $sensitiveItems = @(
                "PII  — names, emails, addresses, identity"
                "Payment data  — cards, bank details, billing"
                "Health / medical data"
                "None — no sensitive data"
            )
            $sensitiveChecked = if ($stepState.Project.SensitiveChecked) { $stepState.Project.SensitiveChecked } else { @($false, $false, $false, $true) }
            $sensitiveChecked = Read-Checkboxes -Items $sensitiveItems -Checked $sensitiveChecked -Prompt "Sensitive data"
            if ($sensitiveChecked -is [int]) {
                if ($sensitiveChecked -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
                $currentStep--; continue
            }
            if ($sensitiveChecked -eq $null) { $currentStep--; continue }
            $anySelected = $sensitiveChecked[0] -or $sensitiveChecked[1] -or $sensitiveChecked[2]
            if ($anySelected) { $sensitiveChecked[3] = $false }
            if ($sensitiveChecked[3]) { $project.HandlesSensitiveData = $false }
            else {
                $project.HandlesSensitiveData = $true
                $tags = @()
                if ($sensitiveChecked[0]) { $tags += "PII" }
                if ($sensitiveChecked[1]) { $tags += "payment" }
                if ($sensitiveChecked[2]) { $tags += "health" }
                $project | Add-Member -NotePropertyName SensitiveDataTags -NotePropertyValue ($tags -join ", ") -Force
            }
            $stepState.Project.SensitiveChecked = $sensitiveChecked
            Write-Host ""
            $deployIdx = Read-Choice -Items @(
                "Cloud (managed)    — AWS, GCP, Azure, Vercel, Render, etc."
                "On-premises        — self-hosted, private datacenter"
                "Edge / CDN         — Cloudflare Workers, Lambda@Edge, Deno Deploy"
                "Mobile store       — Google Play / Apple App Store"
                "Desktop install    — Windows / macOS / Linux app"
            ) -Selected ($stepState.Project.DeployIdx -ge 0 ? $stepState.Project.DeployIdx : 0) -Prompt "Where will this be deployed?"
            if ($deployIdx -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
            if ($deployIdx -lt 0) { $currentStep--; continue }
            $project.DeploymentTarget = @("cloud","on-prem","edge","mobile-store","desktop")[$deployIdx]
            $stepState.Project.DeployIdx = $deployIdx
            Write-Host ""
            $scaleIdx = Read-Choice -Items @(
                "Personal / side project   — <10 users, no SLA"
                "Small team                — 10–500 users, basic availability"
                "Growth                    — 500–50k users, 99.9% uptime target"
                "Enterprise                — 50k+ users, SLA, compliance requirements"
            ) -Selected ($stepState.Project.ScaleIdx -ge 0 ? $stepState.Project.ScaleIdx : 0) -Prompt "What is the expected scale?"
            if ($scaleIdx -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
            if ($scaleIdx -lt 0) { $currentStep--; continue }
            $project.ScaleProfile = @("personal","small-team","growth","enterprise")[$scaleIdx]
            $stepState.Project.ScaleIdx = $scaleIdx
            Write-Host ""
            Write-Host "  $(ok "✓") Intake complete"
            Write-Host ""
            $audienceLabel = @("Public","Internal","B2B","Mobile")[$audienceIdx]
            $scaleLabel = @("Personal","Small team","Growth","Enterprise")[$scaleIdx]
            $deployLabel = @("Cloud","On-premises","Edge","Mobile store","Desktop")[$deployIdx]
            $authLabel = if ($project.NeedsAuth) { "Yes" } else { "No" }
            $dataLabel = if ($project.HandlesSensitiveData) { $project.SensitiveDataTags } else { "None" }
            Write-Info "Audience: $audienceLabel  ·  Auth: $authLabel  ·  Sensitive data: $dataLabel"
            Write-Info "Deployment: $deployLabel  ·  Scale: $scaleLabel"
            Write-Host ""
            Complete-Step -Index $currentStep
            $currentStep++
        }
        "Auth" {
            Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Authentication" -SectionSub "Control access to your system." -Summary @($project.Name, $project.TypeLabel)
            if ($project.TypeId -eq "android") {
                $project.NeedsAuth = $true
                Write-Info "Auth: required (Android — defaulting to Yes)"
            } else {
                $authIdx = Read-Choice -Items @(
                    "Yes — users or services must authenticate"
                    "No  — fully public or pre-authenticated environment"
                ) -Selected ($stepState.Project.AuthIdx -ge 0 ? $stepState.Project.AuthIdx : 0) -Prompt "Does this system require authentication?"
                if ($authIdx -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
                if ($authIdx -lt 0) { $currentStep--; continue }
                $project.NeedsAuth = ($authIdx -eq 0)
                $stepState.Project.AuthIdx = $authIdx
            }
            Write-Host ""
            Complete-Step -Index $currentStep
            $currentStep++
        }
        "Data" {
            Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Sensitive data" -SectionSub "Identify target data categories for encryption and compliance seeds." -Summary @($project.Name, $project.TypeLabel)
            Write-Host "  $(hi "?") What sensitive data will this system handle? $(dim "(Space toggle · Enter confirm)")"
            Write-Host ""
            $sensitiveItems = @(
                "PII  — names, emails, addresses, identity"
                "Payment data  — cards, bank details, billing"
                "Health / medical data"
                "None — no sensitive data"
            )
            $sensitiveChecked = if ($stepState.Project.SensitiveChecked) { $stepState.Project.SensitiveChecked } else { @($false, $false, $false, $true) }
            $sensitiveChecked = Read-Checkboxes -Items $sensitiveItems -Checked $sensitiveChecked -Prompt "Sensitive data"
            if ($sensitiveChecked -is [int]) {
                if ($sensitiveChecked -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
                $currentStep--; continue
            }
            if ($sensitiveChecked -eq $null) { $currentStep--; continue }
            $anySelected = $sensitiveChecked[0] -or $sensitiveChecked[1] -or $sensitiveChecked[2]
            if ($anySelected) { $sensitiveChecked[3] = $false }
            if ($sensitiveChecked[3]) { $project.HandlesSensitiveData = $false }
            else {
                $project.HandlesSensitiveData = $true
                $tags = @()
                if ($sensitiveChecked[0]) { $tags += "PII" }
                if ($sensitiveChecked[1]) { $tags += "payment" }
                if ($sensitiveChecked[2]) { $tags += "health" }
                $project | Add-Member -NotePropertyName SensitiveDataTags -NotePropertyValue ($tags -join ", ") -Force
            }
            $stepState.Project.SensitiveChecked = $sensitiveChecked
            Write-Host ""
            Complete-Step -Index $currentStep
            $currentStep++
        }
        "Scale" {
            Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Scale & Deployment" -SectionSub "Infrastructure and uptime targets." -Summary @($project.Name, $project.TypeLabel)
            $deployIdx = Read-Choice -Items @(
                "Cloud (managed)    — AWS, GCP, Azure, Vercel, Render, etc."
                "On-premises        — self-hosted, private datacenter"
                "Edge / CDN         — Cloudflare Workers, Lambda@Edge, Deno Deploy"
                "Mobile store       — Google Play / Apple App Store"
                "Desktop install    — Windows / macOS / Linux app"
            ) -Selected ($stepState.Project.DeployIdx -ge 0 ? $stepState.Project.DeployIdx : 0) -Prompt "Where will this be deployed?"
            if ($deployIdx -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
            if ($deployIdx -lt 0) { $currentStep--; continue }
            $project.DeploymentTarget = @("cloud","on-prem","edge","mobile-store","desktop")[$deployIdx]
            $stepState.Project.DeployIdx = $deployIdx
            Write-Host ""
            $scaleIdx = Read-Choice -Items @(
                "Personal / side project   — <10 users, no SLA"
                "Small team                — 10–500 users, basic availability"
                "Growth                    — 500–50k users, 99.9% uptime target"
                "Enterprise                — 50k+ users, SLA, compliance requirements"
            ) -Selected ($stepState.Project.ScaleIdx -ge 0 ? $stepState.Project.ScaleIdx : 0) -Prompt "What is the expected scale?"
            if ($scaleIdx -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
            if ($scaleIdx -lt 0) { $currentStep--; continue }
            $project.ScaleProfile = @("personal","small-team","growth","enterprise")[$scaleIdx]
            $stepState.Project.ScaleIdx = $scaleIdx
            Write-Host ""
            Complete-Step -Index $currentStep
            $currentStep++
        }
        "Env" {
            Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Environment" -SectionSub "Configuration management strategy." -Summary @($project.Name, $project.TypeLabel)
            $envIdx = Read-Choice -Items @(
                "Standard .env / local config"
                "Secret manager (AWS, Vault, etc.)"
                "Compile-time constants (Android)"
            ) -Selected 0 -Prompt "How will secrets be managed?"
            if ($envIdx -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
            if ($envIdx -lt 0) { $currentStep--; continue }
            Write-Host ""
            Complete-Step -Index $currentStep
            $currentStep++
        }
        "Obs" {
            Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Observability" -SectionSub "Logging, telemetry, and health monitoring." -Summary @($project.Name, $project.TypeLabel)
            $obsIdx = Read-Choice -Items @(
                "Standard logging (stdout/syslog)"
                "Centralized (ELK, Datadog, etc.)"
                "Sentry / Crashlytics (Error tracking)"
            ) -Selected 0 -Prompt "Primary observability focus?"
            if ($obsIdx -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
            if ($obsIdx -lt 0) { $currentStep--; continue }
            Write-Host ""
            Complete-Step -Index $currentStep
            $currentStep++
        }
        "Agents" {
                Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Agents" -SectionSub "Select which agents will work on this project." -Summary @($project.Name, $project.TypeLabel)
            Write-Section "Agents" "Choose which AI coding agents will work on this project."
            Write-Host ""
            $agentLabels = @($allAgents | ForEach-Object { "$($_.name)  $(dim "· $($_.file)")" })
            $agentChecked = if ($stepState.SelectedAgents.Count -gt 0) {
                $stepState.SelectedAgents
            } else {
                @($allAgents | ForEach-Object { $true })
            }
            $agentChecked = Read-Checkboxes -Items $agentLabels -Checked $agentChecked -Prompt "Select agents"
            if ($agentChecked -is [int]) {
                if ($agentChecked -eq -4) { Show-StepMenu -CurrentStep $currentStep; $jumpTo=Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"; if($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])){$currentStep=$jumpTo}; continue }
                $currentStep--; continue
            }
            if ($agentChecked -eq $null) { $currentStep--; continue }
            $selectedAgents = [System.Collections.Generic.List[object]]::new()
            for ($i = 0; $i -lt $allAgents.Count; $i++) {
                if ($agentChecked[$i]) { $selectedAgents.Add($allAgents[$i]) }
            }
            $stepState.SelectedAgents = $agentChecked
            Write-Host ""
            $addCustom = Read-Confirm "Add a custom agent?" $false
            if ($addCustom -eq $null) { $currentStep--; continue }
            while ($addCustom) {
                $cName = Read-Line "Agent name" "" "(e.g. My Custom Agent)"
                if ($cName -eq $null) { continue }
                $cFile = Read-Line "Config file" "" "(e.g. MYAGENT.md)"
                if ($cFile -eq $null) { continue }
                $cDocs = Read-Line "Docs URL" "" "(optional)"
                if ($cName -and $cFile) {
                    $cId = $cName.ToLower() -replace "\s+","-" -replace "[^a-z0-9\-]",""
                    $selectedAgents.Add([PSCustomObject]@{
                        id = $cId; name = $cName; file = $cFile
                        scratchpad = $cId; description = "Custom agent"
                        docsUrl = if ($cDocs) { $cDocs } else { "" }
                    })
                    Write-Done "Added: $cName"
                }
                $addCustom = Read-Confirm "Add another?" $false
                if ($addCustom -eq $null) { $addCustom = $false }
            }
            Write-Host ""
            $editDocs = Read-Confirm "Review agent docs URLs?" $false
            Complete-Step -Index $currentStep
            $currentStep++
        }
        "Skills" {
                Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Skills" -SectionSub "Inferred from description, stack, and intake." -Summary @($project.Name, $project.TypeLabel, "$($selectedAgents.Count) agents")
            Write-Section "Skills" "Inferred from your description, stack, and intake answers."
            $intakeSignals = @(
                $project.Audience
                $project.DeploymentTarget
                $project.ScaleProfile
                if ($project.NeedsAuth) { "auth login" }
                if ($project.HandlesSensitiveData) { "sensitive data security encryption" }
            ) | Where-Object { $_ }
            $haystack = "$($project.Description) $(if ($project.Stack) { $project.Stack -join ' ' } else { '' }) $($project.TypeLabel) $($intakeSignals -join ' ')"
            $inferTypeId = $project.TypeId
            if ($project.SecondaryTypeId) {
                $primary = Invoke-SkillInference -Haystack $haystack -TypeId $project.TypeId -Patterns $allSkillPatterns
                $secondary = Invoke-SkillInference -Haystack $haystack -TypeId $project.SecondaryTypeId -Patterns $allSkillPatterns
                $seen = [System.Collections.Generic.HashSet[string]]::new()
                $merged = [System.Collections.Generic.List[object]]::new()
                foreach ($s in ($primary + $secondary)) {
                    if ($seen.Add($s.id)) { $merged.Add($s) }
                    if ($merged.Count -ge $MAX_SKILLS) { break }
                }
                $inferredSkills = $merged
            } else {
                $inferredSkills = Invoke-SkillInference -Haystack $haystack -TypeId $project.TypeId -Patterns $allSkillPatterns
            }
            $selectedSkills = Invoke-SkillsReview -InferredSkills $inferredSkills
            if ($selectedSkills -is [int]) {
                if ($selectedSkills -eq -4) { # G (Goto)
                    Show-StepMenu -CurrentStep $currentStep
                    $jumpTo = Read-Choice -Items $currentStepDefs -Selected $currentStep -Prompt "Jump to"
                    if ($jumpTo -ge 0 -and ($jumpTo -eq 0 -or $stepCompleted[$jumpTo-1])) { $currentStep = $jumpTo }
                    continue
                }
                $currentStep--; continue
            }
            if ($null -eq $selectedSkills) { $currentStep--; continue }
            Complete-Step -Index $currentStep
            $currentStep++
        }
        "Review" {
                Write-TwoColumn -StepIndex $currentStep -Mode $mode -SectionTitle "Review" -SectionSub "Confirm your project configuration before generating." -Summary @($project.Name, $project.TypeLabel, "$($selectedAgents.Count) agents", "$($selectedSkills.Count) skills")
            Write-Section "Review" "Confirm everything before generation begins."
            
            # Show Execution Plan first
            Show-ExecutionPlan -Project $project -Agents $selectedAgents -Skills $selectedSkills -WorkflowMode $WORKFLOW_MODE
            
            $viewPlan = Read-Confirm "View detailed review?" $false
            if ($null -eq $viewPlan) { $currentStep--; continue }
            if ($viewPlan) {
                Show-Review -Project $project -Agents $selectedAgents -Skills $selectedSkills
            }
            $initGit = Read-Confirm "Initialise git repository?" $true
            if ($initGit -eq $null) { $currentStep--; continue }
            $confirmed = Read-Confirm "Generate project?" $true
            if ($confirmed -eq $null) { $currentStep--; continue }
            if (-not $confirmed) {
                Write-Host ""
                Write-Info "Aborted. Nothing written."
                Write-Host ""
                exit 0
            }
            if ($mode -eq "greenfield" -and (Test-Path $project.TargetPath)) {
                Write-Host ""
                Write-Warn "Directory already exists: $($project.TargetPath)"
                $merge = Read-Confirm "Merge into existing directory?" $false
                if (-not $merge) { Write-Info "Aborted."; exit 0 }
            }
            Complete-Step -Index $currentStep
            $currentStep++
        }
        default {
            Write-Info "Step '$stepName' is not implemented yet. Skipping..."
            $currentStep++
        }
    }
}

if ($currentStep -ge $totalSteps) {
    $root = $project.TargetPath

    # ── Generate ──────────────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host ""
    Clear-Host
    Write-Header -Mode $mode -StepLabel "generating"
    Write-Host ""
    Write-Section "Generating project files" "Writing scaffold to disk..."
    Write-Host ""

    # Directories
    $dirs = @(
        $root,
        (Join-Path $root "agents"),
        (Join-Path $root "skills"),
        (Join-Path $root "memory\decisions"),
        (Join-Path $root "workstreams"),
        (Join-Path $root "workstreams\_coordinator"),
        (Join-Path $root "src"),
        (Join-Path $root "docs"),
        (Join-Path $root ".plans")
    )
    foreach ($a in $selectedAgents) { $dirs += Join-Path $root "scratchpads\$($a.scratchpad)" }
    if ($project.TypeId -eq "android") { $dirs += Join-Path $root "gradle\wrapper" }
    # Native agent config directories
    foreach ($a in $selectedAgents) {
        $nc = $a.nativeConfig
        if ($nc -and $nc.configDir) {
            $nativeDir = Join-Path $root $nc.configDir
            $dirs += $nativeDir
            $supports = @($nc.supports)
            if ($supports -contains "rules")     { $dirs += Join-Path $nativeDir "rules" }
            if ($supports -contains "commands")  { $dirs += Join-Path $nativeDir "commands" }
            if ($supports -contains "agents")    { $dirs += Join-Path $nativeDir "agents" }
            if ($supports -contains "workflows") { $dirs += Join-Path $nativeDir "workflows" }
            if ($supports -contains "skills")    { $dirs += Join-Path $nativeDir "skills" }
        }
    }
    # Skill subfolders — each skill is a folder with SKILL.md, gotchas.md, scripts/, assets/, references/, outputs/
    foreach ($s in $selectedSkills) {
        $dirs += Join-Path $root "skills\$($s.id)"
        $dirs += Join-Path $root "skills\$($s.id)\scripts"
        $dirs += Join-Path $root "skills\$($s.id)\assets"
        $dirs += Join-Path $root "skills\$($s.id)\references"
        $dirs += Join-Path $root "skills\$($s.id)\outputs"
    }

    if (-not $DryRun) {
        foreach ($d in $dirs) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    Write-Done "Directory structure"

    # Core context files
    Emit "CONTEXT.md"      (Build-ContextMd      -Project $project -Agents $selectedAgents -Skills $selectedSkills -Type $selectedType) $root
    Emit "TASKS.md"        (Build-TasksMd        -Project $project -Skills $selectedSkills) $root
    Emit "DISCOVERY.md"    (Build-DiscoveryMd    -Project $project) $root
    Emit "WORKSTREAMS.md"  (Build-WorkstreamsMd  -Project $project -Agents $selectedAgents) $root
    Emit "DOMAIN.md"       (Build-DomainMd       -Project $project -Type $selectedType) $root
    Emit "CHANGELOG.md"    (Build-ChangelogMd    -Project $project) $root
    Emit "PLANS.md"        (Build-PlansMd)       $root
    Emit ".plans\template.md" (Build-PlanTemplateMd) $root
    Emit "STRUCTURE.md"    (Build-StructureMd    -Project $project -Agents $selectedAgents -Skills $selectedSkills) $root
    Emit "README.md"       (Build-ReadmeMd       -Project $project -Agents $selectedAgents -Skills $selectedSkills) $root

    # Production ops files
    Emit "QUALITY.md"      (Build-QualityMd      -Project $project -Type $selectedType) $root
    Emit "SECURITY.md"     (Build-SecurityMd     -Project $project -Type $selectedType) $root
    Emit "ENVIRONMENTS.md" (Build-EnvironmentsMd -Project $project) $root
    Emit "OBSERVABILITY.md"(Build-ObservabilityMd -Project $project -Type $selectedType) $root

    # Gitignore
    Emit ".gitignore"      (Build-Gitignore      -Project $project) $root

    # Workstreams Registry
    Emit "workstreams\.keep" "# Core workstreams go here.`n" $root
    Emit "workstreams\_coordinator\DISPATCH.md" @"
# DISPATCH.md — Swarm Workstream Registry

## Active Workstreams
- ...

## Merged Workstreams
- ...
"@ $root

    # Agent configs
    foreach ($a in $selectedAgents) {
        Emit "agents\$($a.file)" (Build-AgentConfig -Agent $a -Project $project) $root
    }

    # Native agent config directories (per-agent native files)
    foreach ($a in $selectedAgents) {
        Build-NativeAgentFiles -Agent $a -Project $project -Skills $selectedSkills -Type $selectedType -Root $root
    }

    # Scratchpads
    foreach ($a in $selectedAgents) {
        Emit "scratchpads\$($a.scratchpad)\SESSION.md" (Build-SessionMd -Agent $a) $root
        Emit "scratchpads\$($a.scratchpad)\NOTES.md"   (Build-NotesMd  -Agent $a) $root
    }

    # Skills — each as a proper folder (SKILL.md + gotchas.md + scripts/ + assets/ + references/)
    if ($selectedSkills -and $selectedSkills.Count -gt 0) {
        Emit "skills\README.md" (Build-SkillsReadme -Skills $selectedSkills -Project $project) $root
        foreach ($s in $selectedSkills) {
            # Main spec — entry point for the agent
            Emit "skills\$($s.id)\SKILL.md"    (Build-SkillSpec   -Skill $s -Project $project) $root
            # Gotchas — seeded with category-specific failure patterns
            Emit "skills\$($s.id)\gotchas.md"  (Build-SkillGotchas -Skill $s -Project $project) $root
            # Placeholder README in scripts/ to guide the agent
            Emit "skills\$($s.id)\scripts\.keep" "# Add helper scripts here. Claude can run or compose these.`n# Example: validate_input.py, seed_data.sh, run_tests.ps1`n" $root
            # outputs/ — structured results from skill executions (compressed context for future sessions)
            Emit "skills\$($s.id)\outputs\.keep" "# Structured output records from skill executions.`n# Format: one JSON or markdown file per significant execution.`n# Agents read outputs/ instead of re-running expensive operations.`n# Example record: {date, outcome, summary, key_values}`n" $root

            # Auto-Dream scripts
            if ($s.id -eq "auto-dream") {
                Emit "skills\$($s.id)\scripts\dream.ps1" @"
param(
    [string]`$SessionFile = "scratchpads/antigravity/SESSION.md",
    [string]`$ContextFile = "CONTEXT.md"
)
Write-Host "Running Auto-Dream Compaction..."
# In a real environment, trigger the LLM to compress `$SessionFile into `$ContextFile
Write-Host "Compaction complete."
"@ $root

                Emit "skills\$($s.id)\scripts\dream.sh" @"
#!/usr/bin/env bash
SESSION_FILE="scratchpads/antigravity/SESSION.md"
CONTEXT_FILE="CONTEXT.md"
echo "Running Auto-Dream Compaction..."
# In a real environment, trigger the LLM to compress `$SESSION_FILE into `$CONTEXT_FILE
echo "Compaction complete."
"@ $root
            }

            # Swarm Orchestration scripts
            if ($s.id -eq "swarm-orchestration") {
                Emit "skills\$($s.id)\scripts\dispatch.ps1" @"
param(
    [Parameter(Mandatory=`$true)][string]`$WorkstreamName,
    [Parameter(Mandatory=`$true)][string]`$AgentRole,
    [string]`$Description = "Sub-task for `$WorkstreamName"
)

`$base = "workstreams/`$WorkstreamName"
New-Item -ItemType Directory -Force -Path `$base | Out-Null
Set-Content -Path "workstreams/_coordinator/DISPATCH.md" -Value "- [`$AgentRole] `$WorkstreamName: ACTIVE" -Append
Set-Content -Path "`$base/SCOPE.md" -Value "# Scope: `$WorkstreamName`n`n`$Description`n`n**Strict bounds:** Do not modify files outside this module."
Set-Content -Path "`$base/STATUS.json" -Value "{ `"status`": `"ACTIVE`", `"handoff`": `"`$AgentRole`" }"

Write-Host "Workstream `$WorkstreamName provisioned for `$AgentRole."
"@ $root

                Emit "skills\$($s.id)\scripts\dispatch.sh" @"
#!/usr/bin/env bash
set -u

WORKSTREAM="`$1"
ROLE="`$2"
DESC="`${3:-"Sub-task for `$WORKSTREAM"}"

BASE="workstreams/`$WORKSTREAM"
mkdir -p "`$BASE"

echo "- [`$ROLE] `$WORKSTREAM: ACTIVE" >> "workstreams/_coordinator/DISPATCH.md"
echo -e "# Scope: `$WORKSTREAM\n\n`$DESC\n\n**Strict bounds:** Do not modify files outside this module." > "`$BASE/SCOPE.md"
echo "{ \"status\": \"ACTIVE\", \"handoff\": \"`$ROLE\" }" > "`$BASE/STATUS.json"

echo "Workstream `$WORKSTREAM provisioned for `$ROLE."
"@ $root
            }
        }
        Write-Done "Skill folders: $($selectedSkills.Count) skills × (SKILL.md + gotchas.md + scripts/ + assets/ + references/)"
    }

    # Decisions seed
    Emit "memory\decisions\000-init.md" (Build-DecisionsSeed -Project $project) $root

    # Android-specific
    if ($project.TypeId -eq "android") {
        Write-Host ""
        Write-Done "Android extras:"
        Emit "GRADLE.md"                    (Build-GradleMd          -Project $project) $root
        Emit "gradle\libs.versions.toml"    (Build-LibsVersionsToml  -Project $project) $root
        Emit "proguard-rules.pro"           @"
# proguard-rules.pro — see GRADLE.md for full baseline rules
# Add project-specific rules here.
# Always test release build after adding rules — use '.\gradlew.bat assembleRelease' in PowerShell.
"@ $root
    }

    # Bootstrap record
    $record = @{
    version     = $VERSION
    generatedAt = (Get-Date -Format "o")
    project     = @{
        name               = $project.Name
        description        = $project.Description
        type               = $project.TypeId
        typeLabel          = $project.TypeLabel
        secondaryType      = $project.SecondaryTypeId
        secondaryTypeLabel = $project.SecondaryTypeLabel
        stack              = $project.Stack
        milestone          = $project.Milestone
        mode               = $project.Mode
    }
    intake  = @{
        audience           = $project.Audience
        needsAuth          = $project.NeedsAuth
        handlesSensitiveData = $project.HandlesSensitiveData
        sensitiveDataTags  = if ($project.PSObject.Properties["SensitiveDataTags"]) { $project.SensitiveDataTags } else { "" }
        deploymentTarget   = $project.DeploymentTarget
        scaleProfile       = $project.ScaleProfile
    }
    agents  = @($selectedAgents | ForEach-Object { @{ id=$_.id; name=$_.name; file=$_.file } })
    skills  = @($selectedSkills | ForEach-Object { @{ id=$_.id; name=$_.name; category=$_.category } })
    } | ConvertTo-Json -Depth 5

    if (-not $DryRun) {
        Set-Content -Path (Join-Path $root "memory\bootstrap-record.json") -Value $record -Encoding UTF8
    }
    Write-Done "memory\bootstrap-record.json"

    # Git
    if ($initGit -and -not $DryRun) {
        try {
            Push-Location $root
            git init --quiet 2>$null | Out-Null
            git add . 2>$null | Out-Null
            # Build a rich, informative first commit message
            $skillNames  = ($selectedSkills | ForEach-Object { $_.name }) -join ", "
            $agentNames  = ($selectedAgents | ForEach-Object { $_.name }) -join ", "
            $hybridNote  = if ($project.SecondaryTypeId) { " + $($project.SecondaryTypeLabel)" } else { "" }
            $scaleNote   = "$($project.Intake.ScaleProfile) · $($project.Intake.DeploymentTarget)"
            $commitBody  = "Generated by Msingi v$VERSION`n`nProject:   $($project.Name) ($($project.TypeLabel)$hybridNote)`nMilestone: $($project.Milestone)`nAgents:    $agentNames`nSkills:    $skillNames`nScale:     $scaleNote`nMode:      $($project.Mode)`n`nBuilt in Accra. Designed for everywhere."
            $commitMsg   = "feat(scaffold): initialise $($project.Name) ($($project.TypeLabel), $($selectedSkills.Count) skills, $($selectedAgents.Count) agents)"
            git commit --quiet -m $commitMsg -m $commitBody 2>$null | Out-Null
            Pop-Location
            Write-Done "git init + initial commit"
        } catch {
            Pop-Location -ErrorAction SilentlyContinue
            Write-Warn "git init skipped — git may not be in PATH"
        }
    }

    # ── Done ──────────────────────────────────────────────────────────────────────
    $androidSuffix = if ($project.TypeId -eq "android") { " · GRADLE.md + libs.versions.toml" } else { "" }
    $hybridSuffix  = if ($project.SecondaryTypeId) { "  $(dim "+")  $($project.SecondaryTypeLabel)" } else { "" }

    # ── Completion screen ────────────────────────────────────────────────────────
    Clear-Host
    Write-Header -Mode $mode -StepLabel "done"
    Write-Host ""

$nextSteps = @(
    "1  Read CONTEXT.md — confirm architecture and NFRs are correct"
    "2  Read SECURITY.md — confirm threat model covers your project"
    "3  Read QUALITY.md — know the gates before writing any code"
    "4  Open TASKS.md — your first session starts at the top"
    )
    if ($project.TypeId -eq "android") {
        $nextSteps += "5  Read GRADLE.md — before touching any .gradle.kts file"
    }
    $detailLines = @(
        "Type      $($project.TypeLabel)$hybridSuffix"
        "Agents    $(@($selectedAgents | ForEach-Object { $_.name }) -join ' · ')"
        "Skills    $($selectedSkills.Count) inferred$androidSuffix"
        "Scale     $($project.ScaleProfile)  ·  $($project.DeploymentTarget)"
        "Location  $root"
    ) + @("") + $nextSteps

    # ── Completion panel ────────────────────────────────────────────────────────
    $tw       = Get-TermWidth
    $boxInner = [Math]::Min($tw - 6, 70)
    $brand    = ansi-fg 0 210 200

    Write-Host ""
    Write-Host "  $(ansi-fg 0 210 200)╔$("═" * $boxInner)╗$($C.Reset)"

    # Title row — teal bold checkmark
    $titleText = "✓  Bootstrap complete"
    $titlePad  = [Math]::Max(0, $boxInner - $titleText.Length - 2)
    Write-Host "  $(ansi-fg 0 210 200)║$($C.Reset)  $($C.Bold)$(ansi-fg 0 210 200)$titleText$($C.Reset)$(' ' * $titlePad) $(ansi-fg 0 210 200)║$($C.Reset)"

    # Subtitle — version + type + counts
    $sub     = "Msingi v$VERSION  ·  $($project.TypeLabel)  ·  $($selectedAgents.Count) agents  ·  $($selectedSkills.Count) skills"
    $subPad  = [Math]::Max(0, $boxInner - $sub.Length - 2)
    Write-Host "  $(ansi-fg 0 210 200)║$($C.Reset)  $(ansi-fg 80 80 100)$sub$($C.Reset)$(' ' * $subPad) $(ansi-fg 0 210 200)║$($C.Reset)"

    # Divider
    Write-Host "  $(ansi-fg 0 210 200)╠$("─" * $boxInner)╣$($C.Reset)"

    # Detail lines
    foreach ($ln in $detailLines) {
        $lnPad = [Math]::Max(0, $boxInner - $ln.Length - 2)
        Write-Host "  $(ansi-fg 0 210 200)║$($C.Reset)  $(ansi-fg 100 100 120)$ln$($C.Reset)$(' ' * $lnPad) $(ansi-fg 0 210 200)║$($C.Reset)"
    }

    # Tagline row
    Write-Host "  $(ansi-fg 0 210 200)╠$("─" * $boxInner)╣$($C.Reset)"
    $tag    = "Built in Accra. Designed for everywhere."
    $tagPad = [Math]::Max(0, $boxInner - $tag.Length - 2)
    Write-Host "  $(ansi-fg 0 210 200)║$($C.Reset)  $(ansi-fg 60 60 80)$tag$($C.Reset)$(' ' * $tagPad) $(ansi-fg 0 210 200)║$($C.Reset)"

    Write-Host "  $(ansi-fg 0 210 200)╚$("═" * $boxInner)╝$($C.Reset)"
    Write-Host ""

    Write-Footer "Done"
    Write-Host ""
    
    # Final cleanup and exit to prevent loop
    exit 0
}
