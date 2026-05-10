#!/usr/bin/env bash
# ✨═══════════════════════════════════════════════════════════════════════════✨
#  Msingi v4.1.0 — Self-configuring multi-agent project scaffold tool.
#  macOS / Linux  ·  Bash 4.4+
#  https://github.com/xdagee/msingi
#
#  Built in Accra. Designed for everywhere.
# ✨═══════════════════════════════════════════════════════════════════════════✨
set -uo pipefail

VERSION="4.0.0"
MAX_SKILLS=12
DRY_RUN=0
TARGET_PATH=""
STATE_FILE="${MSINGI_STATE_PATH:-$HOME/.msingi_state.json}"
AUDIT=0

# Flag parsing
for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=1 ;;
        --audit)   AUDIT=1 ;;
        --test-harness) TEST_HARNESS=1 ;;
    esac
done

# ── msingi --audit ────────────────────────────────────────────────────────────
if [[ $AUDIT -eq 1 ]]; then
    if command -v python3 &>/dev/null; then
        python3 scripts/token-audit.py --dashboard
        exit $?
    else
        echo "Error: python3 is required for the Context Efficiency Hub."
        exit 1
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SUCCESS INFRASTRUCTURE
# ═══════════════════════════════════════════════════════════════════════════════

# 1. Terminal Capability Detection
declare -A TERM_CAPS=(
    [unicode]=1
    [color]=1
    [width]=80
)

test_terminal() {
    # Detect Unicode support
    if [[ "$OSTYPE" == "darwin"* ]]; then
        [[ "$LANG" == *"UTF-8"* ]] || TERM_CAPS[unicode]=0
    else
        [[ "$LANG" == *"UTF-8"* ]] || TERM_CAPS[unicode]=0
    fi

    # Detect Color support
    if [[ -v NO_COLOR ]] || [[ "${TERM:-}" == "dumb" ]]; then
        TERM_CAPS[color]=0
    elif [[ -v CI ]]; then
        TERM_CAPS[color]=1
    fi
    
    TERM_CAPS[width]=$(tput cols 2>/dev/null || echo 80)
    [[ ${TERM_CAPS[width]} -lt 20 ]] && TERM_CAPS[width]=80
}

# 2. Data Integrity Validation
validate_data() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Critical: Configuration file not found: $file" >&2
        exit 1
    fi
    
    # Basic JSON check using python (since it's a dependency for tests anyway)
    if ! python3 -c "import json; open('$file')" 2>/dev/null; then
        echo "Syntax Error: $file contains invalid JSON logic." >&2
        exit 1
    fi

    # Check schema_version
    local version
    version=$(python3 -c "import json; print(json.load(open('$file')).get('schema_version', ''))" 2>/dev/null)
    if [[ -z "$version" ]]; then
        echo "Invalid Schema: $file is missing schema_version. Please update your data files." >&2
        exit 1
    fi
}

# 3. State Persistence
save_state() {
    local json_data="$1"
    echo "$json_data" > "$STATE_FILE"
}

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "{}"
    fi
}

# 4. Data Loading
load_agents() {
    validate_data "agents.json"
    python3 -c "import json; print(json.dumps(json.load(open('agents.json'))['agents']))"
}

load_skills() {
    validate_data "skills.json"
    python3 -c "import json; print(json.dumps(json.load(open('skills.json'))['skills']))"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ANSI COLOURS & UI TOKENS
# ═══════════════════════════════════════════════════════════════════════════════
ESC=$'\033'
C_RESET="${ESC}[0m"; C_BOLD="${ESC}[1m"; C_DIM="${ESC}[2m"; C_GRAY="${ESC}[90m"
C_CYAN="${ESC}[96m"; C_GREEN="${ESC}[92m"; C_YELLOW="${ESC}[93m"; C_RED="${ESC}[91m"
BRAND="${ESC}[38;2;0;210;200m"; BRAND_B="${ESC}[1m${BRAND}"
STEP_DIM="${ESC}[38;2;80;80;90m"; STEP_DONE="${ESC}[38;2;80;200;120m"; STEP_ACTIVE="${ESC}[38;2;0;210;200m"

hi()     { echo -n "${C_CYAN}${1}${C_RESET}"; }
ok()     { echo -n "${C_GREEN}${1}${C_RESET}"; }
warn()   { echo -n "${C_YELLOW}${1}${C_RESET}"; }
err()    { echo -n "${C_RED}${1}${C_RESET}"; }
dim()    { echo -n "${C_GRAY}${1}${C_RESET}"; }
bold()   { echo -n "${C_BOLD}${1}${C_RESET}"; }
brand()  { echo -n "${BRAND}${C_BOLD}${1}${C_RESET}"; }

write_done() { echo "  $(ok "✓")  ${1}"; }
write_warn() { echo "  $(warn "!")  ${1}"; }
write_info() { echo "  ${C_GRAY}·  ${1}${C_RESET}"; }
write_rule() { local w=64; [[ $(tput cols 2>/dev/null) -lt 64 ]] && w=$(tput cols) || w=64; echo "  ${C_GRAY}$(printf '—%.0s' $(seq 1 $w))${C_RESET}"; }

# ═══════════════════════════════════════════════════════════════════════════════
# LAYOUT HELPERS
# ═══════════════════════════════════════════════════════════════════════════════
pad_str() { local s="$1" w="$2"; printf "%-${w}s" "$s"; }

write_header() {
    local mode="${1:-}" step="${2:-}" tw=$(tput cols 2>/dev/null || echo 80)
    local logo=" ⬡ Msingi  v${VERSION}"
    local right="${mode}  ${step}  BASH"
    printf "${C_BOLD}${BRAND}%s${C_RESET}${C_GRAY}%s%s${C_RESET}\n\n" "$logo" "$(printf '%*s' $((tw - ${#logo} - ${#right} - 1)) "")" "$right"
}

write_section() {
    local title="$1" sub="${2:-}"
    echo "  ${C_BOLD}${STEP_ACTIVE}${title}${C_RESET}  ${C_GRAY}$(printf '—%.0s' $(seq 1 48))${C_RESET}"
    [[ -n "$sub" ]] && echo "  ${C_GRAY}${sub}${C_RESET}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# INPUT ENGINE
# ═══════════════════════════════════════════════════════════════════════════════
render_template() {
    local template_name="$1"
    shift
    local content
    content=$(cat "templates/${template_name}" 2>/dev/null || echo "ERROR: Template ${template_name} not found.")
    for token_val in "$@"; do
        local token="${token_val%%=*}"
        local val="${token_val#*=}"
        content="${content//\{\{${token}\}\}/${val}}"
    done
    echo "$content"
}

read_line() {
    local prompt="$1" default="${2:-}" hint="${3:-}"
    printf "  ${STEP_ACTIVE}›${C_RESET}  ${C_BOLD}%s${C_RESET}  ${C_GRAY}[%s] %s${C_RESET}\n  > " "$prompt" "$default" "$hint"
    
    local key; IFS= read -r -n 1 -s key
    if [[ "$key" == $'\t' || "$key" == $'\e' ]]; then
        if [[ "$key" == $'\t' ]]; then
            read -r -n 2 -t 0.1 extra 2>/dev/null || extra=""
            [[ "$extra" == "[Z" ]] && return 3 || { REPLY="$default"; return 2; }
        fi
        return 4 # Esc/Back
    fi
    
    read -r rest; REPLY="${key}${rest}"; [[ -z "$REPLY" ]] && REPLY="$default"
    return 0
}

read_confirm() {
    local prompt="$1" default="${2:-y}"
    printf "  ${STEP_ACTIVE}›${C_RESET}  ${C_BOLD}%s${C_RESET}  ${C_GRAY}(Y/n) Enter confirm, Esc back${C_RESET} " "$prompt"
    local key; read -r -n 1 -s key; echo ""
    case "$key" in
        $'\e') return 4 ;;
        [gG]) return 6 ;; 
        $'\t') 
            read -r -n 2 -t 0.1 extra 2>/dev/null || extra=""
            [[ "$extra" == "[Z" ]] && return 3 || return 2 ;;
        [nN]) CONFIRM=1 ;;
        *) CONFIRM=0 ;;
    esac
    return 0
}

read_choice() {
    local prompt="$1"; shift; local items=("$@")
    echo "  ${STEP_ACTIVE}›${C_RESET}  ${C_BOLD}${prompt}${C_RESET}  ${C_GRAY}↑↓ navigate, Enter confirm, Esc back${C_RESET}"
    local cur=0; local size=${#items[@]}
    while true; do
        for ((i=0; i<size; i++)); do
            [[ $i -eq $cur ]] && printf "  ${STEP_ACTIVE}▶${C_RESET}  ${C_BOLD}${STEP_ACTIVE}%s${C_RESET}\n" "${items[$i]}" || printf "     ${C_GRAY}%s${C_RESET}\n" "${items[$i]}"
        done
        local key; read -r -n 1 -s key
        case "$key" in
            $'\e') 
                read -r -n 2 -t 0.1 extra 2>/dev/null || extra=""
                [[ "$extra" == "[A" ]] && ((cur > 0)) && ((cur--)) # Up
                [[ "$extra" == "[B" ]] && ((cur < size - 1)) && ((cur++)) # Down
                [[ -z "$extra" ]] && return 4 # Esc
                ;;
            "") CHOICE_IDX=$cur; return 0 ;; # Enter
            [gG]) return 6 ;;
            $'\t') 
                read -r -n 2 -t 0.1 extra 2>/dev/null || extra=""
                [[ "$extra" == "[Z" ]] && return 3 || return 2 ;;
        esac
        printf "${ESC}[%dA" "$size"
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# BUILDERS
# ═══════════════════════════════════════════════════════════════════════════════
build_context_md() {
    local stack_lines="- To be defined"
    if [[ -n "${PROJECT_STACK:-}" ]]; then
        stack_lines=$(echo "${PROJECT_STACK}" | tr ',' '\n' | sed 's/^/- /')
    fi

    local status="Active - greenfield"
    local hybrid_line=""
    if [[ -n "${PROJECT_SECONDARY_TYPE_LABEL:-}" ]]; then
        hybrid_line=$'\n'"**Hybrid secondary:** ${PROJECT_SECONDARY_TYPE_LABEL}"
    fi

    local audience_label="${PROJECT_AUDIENCE_LABEL:-Not specified}"
    local deploy_label="${PROJECT_DEPLOY_LABEL:-Not specified}"
    local scale_label="${PROJECT_SCALE_LABEL:-Not specified}"
    local auth_label="Not required"
    if [[ "${PROJECT_NEEDS_AUTH:-false}" == "true" ]]; then
        auth_label="Required"
    fi
    
    local data_label="None"
    if [[ "${PROJECT_HANDLES_SENSITIVE_DATA:-false}" == "true" ]]; then
        local tags="${PROJECT_SENSITIVE_TAGS:-Yes}"
        data_label="Yes — ${tags}"
    fi

    # Stubbing agents and skills for Phase 2 implementation
    local agent_lines="${AGENT_LINES:-- To be defined}"
    local docs_lines="${DOCS_LINES:-- To be defined}"
    local skill_lines="${SKILL_LINES:-- To be defined}"

    render_template "CONTEXT.md" \
        "PROJECT_NAME=${PROJECT_NAME:-Project}" \
        "PROJECT_TYPE_LABEL=${PROJECT_TYPE_LABEL:-Web}" \
        "HYBRID_LINE=${hybrid_line}" \
        "STATUS=${status}" \
        "DATE=$(date +%Y-%m-%d)" \
        "PROJECT_DESCRIPTION=${PROJECT_DESCRIPTION:-A new multi-agent project.}" \
        "AUDIENCE_LABEL=${audience_label}" \
        "AUTH_LABEL=${auth_label}" \
        "DATA_LABEL=${data_label}" \
        "DEPLOY_LABEL=${deploy_label}" \
        "SCALE_LABEL=${scale_label}" \
        "STACK_LINES=${stack_lines}" \
        "ARCHITECTURE=${PROJECT_ARCHITECTURE:-Standard architecture}" \
        "NFR=${PROJECT_NFR:-- Performance: < 2.5s page load}" \
        "AGENT_LINES=${agent_lines}" \
        "DOCS_LINES=${docs_lines}" \
        "SKILL_LINES=${skill_lines}" \
        "MILESTONE=${PROJECT_MILESTONE:-v0.1.0 MVP}"
}

build_tasks_md() {
    local skill_backlog=""
    if [[ "${HAS_SKILLS:-false}" == "true" ]]; then
        skill_backlog="- [ ] Review skill specs in skills/ — define interfaces before any implementation"$'\n'
        skill_backlog+="- [ ] Implement skills in priority order per skills/README.md"$'\n'
        skill_backlog+="- [ ] Verify each skill against its acceptance criteria before marking done"
    fi

    local intake_tasks=""
    if [[ "${PROJECT_NEEDS_AUTH:-false}" == "true" ]]; then
        intake_tasks+=$'\n'"- [ ] Design and document auth flow before any implementation (login, logout, token lifecycle)"
    fi
    if [[ "${PROJECT_HANDLES_SENSITIVE_DATA:-false}" == "true" ]]; then
        local tags="${PROJECT_SENSITIVE_TAGS:-sensitive data}"
        intake_tasks+=$'\n'"- [ ] Complete sensitive data inventory (${tags}) — map all fields before coding"
        intake_tasks+=$'\n'"- [ ] Define data retention and deletion policy — log decision to memory/decisions/"
    fi
    
    local scale_profile="${PROJECT_SCALE_PROFILE:-}"
    if [[ "$scale_profile" == "growth" || "$scale_profile" == "enterprise" ]]; then
        intake_tasks+=$'\n'"- [ ] Define SLO targets (uptime, latency p95) and configure alerting before launch"
        intake_tasks+=$'\n'"- [ ] Load test at 2x expected peak before promotion to production"
    fi
    if [[ "$scale_profile" == "enterprise" ]]; then
        intake_tasks+=$'\n'"- [ ] Compliance requirements identified and documented in memory/decisions/"
        intake_tasks+=$'\n'"- [ ] Penetration test scheduled before first external release"
    fi
    
    local deploy_target="${PROJECT_DEPLOYMENT_TARGET:-}"
    if [[ "$deploy_target" == "mobile-store" ]]; then
        intake_tasks+=$'\n'"- [ ] App store listing and review requirements documented before feature freeze"
        intake_tasks+=$'\n'"- [ ] Release signing and keystore management documented in SECURITY.md"
    fi
    if [[ "$deploy_target" == "on-prem" ]]; then
        intake_tasks+=$'\n'"- [ ] Deployment runbook written before handoff — install, upgrade, rollback"
        intake_tasks+=$'\n'"- [ ] Network and firewall requirements documented in ENVIRONMENTS.md"
    fi
    
    local audience="${PROJECT_AUDIENCE:-}"
    if [[ "$audience" == "public" ]]; then
        intake_tasks+=$'\n'"- [ ] Abuse prevention strategy defined (rate limiting, CAPTCHA, anomaly detection)"
    fi
    if [[ -n "${PROJECT_SECONDARY_TYPE_ID:-}" ]]; then
        intake_tasks+=$'\n'"- [ ] Hybrid type integration points identified — document boundary between ${PROJECT_TYPE_LABEL:-} and ${PROJECT_SECONDARY_TYPE_LABEL:-} concerns"
    fi

    render_template "TASKS.md" \
        "MILESTONE=${PROJECT_MILESTONE:-v0.1.0 MVP}" \
        "INTAKE_TASKS=${intake_tasks}" \
        "SKILL_BACKLOG=${skill_backlog}" \
        "DATE=$(date +%Y-%m-%d)"
}

build_workstreams_md() {
    cat <<EOF
# WORKSTREAMS.md — Supervisor Manifest & Swarm Routing

This project uses **Coordinator Mode** for multi-agent swarm orchestration.
Do not use this file to manually track task lists. This file defines the rules of engagement for \`coordinator\` and \`executor\` agents operating in the \`workstreams/\` directory.

---

## Agent Roles & Permissions

### \`roles: ["coordinator", "planner"]\`
- **Goal:** Break down architecture into parallel tasks, spawn sandboxes, and integrate results.
- **Permissions:** You have write access to \`workstreams/_coordinator/DISPATCH.md\`.
- **Workflow:** 
  1. Identify a parallelable component.
  2. Use the \`swarm-orchestration\` skill (if available) to generate \`workstreams/<task_name>/\`.
  3. Write the exact requirements into \`workstreams/<task_name>/SCOPE.md\`.
  4. Track the task in \`DISPATCH.md\` as \`ACTIVE\`.
  5. Wait for the executor to mark \`STATUS.json\` as \`READY_FOR_MERGE\`.
  6. Review the executor's code, integrate it into \`src/\`, and update \`DISPATCH.md\` to \`MERGED\`.

### \`roles: ["executor"]\`
- **Goal:** Implement the exact requirements defined in your sandbox.
- **Permissions:** You are strictly confined to modifying files related to your assigned \`workstreams/<task_name>/SCOPE.md\`. Do not touch files outside your scope unless absolutely necessary for integration.
- **Workflow:**
  1. Read \`workstreams/<task_name>/SCOPE.md\`.
  2. Write code, write tests, verify against \`QUALITY.md\`.
  3. When complete, update \`workstreams/<task_name>/STATUS.json\` from \`ACTIVE\` to \`READY_FOR_MERGE\`.
  4. Yield control back to the human or coordinator.

---

## Workstream Lifecycle State Machine
\`ACTIVE\` -> \`BLOCKED\` (requires human/coordinator unblocking) -> \`READY_FOR_MERGE\` -> \`MERGED\` | \`FAILED\`

---
*Canonical routing rules for swarm mechanics. Do not modify manually.*
EOF
}

build_plans_md() {
    render_template "PLANS.md"
}

build_plan_template_md() {
    render_template "plan_template.md"
}

build_quality_md() {
    render_template "QUALITY.md" \
        "PROJECT_NAME=${PROJECT_NAME:-Project}" \
        "PROJECT_TYPE_LABEL=Web" \
        "QUALITY_GATES=" \
        "ENTROPY_CONTROL="
}

build_observability_md() {
    render_template "OBSERVABILITY.md" \
        "PROJECT_NAME=${PROJECT_NAME:-Project}" \
        "PROJECT_TYPE_LABEL=Web" \
        "OBSERVABILITY_FOCUS="
}
build_agent_config() {
    local name="$1" date=$(date +%Y-%m-%d)
    cat <<EOF
# ${name^^}
> Pointer file — canonical context lives in CONTEXT.md

## Role
Production engineer on **\${PROJECT_NAME:-Project}**.

## How to use skills (Progressive Disclosure)
Context is a tax. Avoid "token tax" by using tiered loading:
1. **Index (Scan)**: Identify relevant skills by their **When to use** trigger (found in CONTEXT.md and individual SKILL.md headers).
2. **Body (Identify)**: Read the \`SKILL.md\` (the contract) and \`evals/EVAL.md\` (the definition of success) only after a trigger is matched.
3. **Runtime (Action)**: Fetch other files in the skill folder only when you need the detail.

Each skill is a **folder** in \`\`skills/<id>/\`\`:
- \`\`SKILL.md\`\` — the contract — read to understand the boundary and interface
- \`\`evals/EVAL.md\`\` — **definition of success** — read before implementation to write tests/evals
- \`\`gotchas.md\`\` — accumulated failure patterns — **always read before implementing**
- \`\`config.json\`\` — local settings and status — read to check if first-run setup is needed
- \`\`scripts/\`\` — helper scripts to run or compose (do not rebuild what is already here)
- \`\`assets/\`\` — templates, config, and reference files
- \`\`references/\`\` — detailed API docs and technical specs
- \`\`outputs/\`\` — structured results from prior skill executions (compressed context for future sessions)

When starting a task: identify the right skill, read its SKILL.md and EVAL.md, then read gotchas.md — starting with the highest-confidence entries (●●●●● and ●●●●○). Update gotchas.md and config.json before marking a skill task done.

## Compaction Protocol
When approaching context limits (80% utilization):
1. **Summarize**: Distill the current session's trajectory into a single Handoff.
2. **Reboot**: Use the handoff to clear history or prune non-essential files.
3. **Persist**: Promote architectural findings to \`memory/decisions/\` before compacting.

## Retrieval rules
- Read \`\`src/\`\` files only when directly required — never load entire directories
- Use file listing or grep to understand structure before opening files
- Pull \`\`memory/decisions/\`\` only when a current decision relates to a prior one
- Never preload speculatively — retrieve just-in-time
- Read \`\`workstreams/INBOX.md\`\` at session start for inter-agent signals.

## Doc Gardening Protocol
Codebases drift. You are responsible for ensuring the context layer remains accurate.
- Periodically check whether CONTEXT.md, DOMAIN.md, and the active skill's gotchas.md still match the codebase
- If you notice documentation that is stale, inaccurate, or missing key decisions: autonomously update it
- Stale context is a bug. Fix it just like you would fix broken code.
EOF
}

build_trajectory_md() {
    local name="$1" date=$(date +%Y-%m-%d)
    cat <<EOF
# CURRENT.md — Project Trajectory & Velocity

> **Kairos Memory (Claude Code):** This file tracks the "why" and the current momentum.
> Use this to understand the big picture trajectory before diving into task-level details.

## Current Milestone: [Set during bootstrap]
**Velocity:** NORMAL | ACCELERATED | BLOCKED
**Confidence:** ●●●●○

## Active Trajectory
- 

## Open Blockers & Architectural Debt
- 

## The "Next Big Why"
- 

---
*Last Consolidated: ${date} — Msingi v${VERSION}*
EOF
}

build_inbox_md() {
    render_template "INBOX.md"
}

build_skill_eval() {
    local name="$1" date=$(date +%Y-%m-%d)
    cat <<EOF
# EVAL.md — ${name} Evaluation Spec

> **Zen of Skills (Perplexity):** Define success before implementation. 
> Write evaluations/tests that cover the happy path, edge cases, and "neighbor confusion."

## 1. Happy Path Scenarios
- **Scenario:** 
- **Input:** 
- **Expected Output:** 

## 2. Edge Case Scenarios
- **Scenario:** 
- **Input:** 
- **Expected Output:** 

## 3. Neighbor Confusion (Routing Boundaries)
- **Scenario:** 
- **Why NOT this skill:** 
- **Which skill to use instead:** 

## 4. Verification Commands
- \` \`

---
*Created: ${date} — Msingi v${VERSION}*
EOF
}

build_skill_spec() {
    local id="$1" name="$2" category="$3" trigger="$4" guidance="$5" qs="$6" short="$7" date=$(date +%Y-%m-%d)
    cat <<EOF
---
allowed-tools: [read_file, grep_search, list_dir, write_to_file, run_command]
---

# ${name}

> **When to use:** ${trigger}

**ID:** ${id}  **Category:** ${category}  **Status:** UNIMPLEMENTED  **Created:** ${date}

---

## Quick start
> Read this section first. Load the rest of the spec only when you need the detail.
> This is the minimum context to begin implementing correctly.

${qs}

**Before writing any code:** read \`\`gotchas.md\`\` and \`\`evals/EVAL.md\`\` in this folder.
Start with \`\`●●●●●\`\` and \`\`●●●●○\`\` entries — they are the most likely to apply.
**After implementing:** write a compact result record to \`\`outputs/\`\`, update \`\`last_seen\`\` on any gotcha that triggered, and add new entries for anything unexpected.

---

> This is a contract, not an implementation plan.
> Status lifecycle: UNIMPLEMENTED → IN PROGRESS → NEEDS-REVIEW → IMPLEMENTED
> Any deviation from the Interface section must be logged in memory/decisions/.

---

## Skill folder contents

| File | Purpose |
|------|---------|
| \`\`SKILL.md\`\` | This file — the contract |
| \`\`gotchas.md\`\` | Failure patterns accumulated from real usage — read before implementing |
| \`\`evals/EVAL.md\`\`| **Definition of success** — define happy/edge/neighbor cases before code |
| \`\`config.json\`\` | First-run setup, local overrides, and runtime status |
| \`\`scripts/\`\` | Purpose-built scripts Claude can run (Utility Bundle pattern) |
| \`\`assets/\`\` | Templates, reference data, and intermediate plans |
| \`\`references/\`\` | API docs, type definitions, detailed specs |
| \`\`outputs/\`\` | Structured results from skill executions — compressed context |

**Progressive disclosure:** Read \`\`SKILL.md\`\` first. Fetch other files only when you need the detail.
**Eval-First:** Write evaluations to \`\`evals/EVAL.md\`\` before writing implementation code.
**Plan-Validate-Execute:** Insert a verifiable plan (saved to \`\`assets/plan.json\`\`) before any destructive or batch operation.

---

## Purpose

One sentence: what this skill does and why it exists in **${PROJECT_NAME:-Project}**.

*Project context: "${short}"*

---

## Interface

### Inputs
| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| — | — | — | — | Define before implementing |

### Outputs

**Success:**
\`\`\`\`\`\`
{ success: true, data: <define shape here> }
\`\`\`\`\`\`

**Error:**
\`\`\`\`\`\`
{ success: false, error: { code: string, message: string, details?: object } }
\`\`\`\`\`\`

### Side effects
<!-- DB writes, cache invalidations, events emitted, external API calls. Be explicit. -->

- *(none defined yet)*

---

## Examples
<!-- Calibration for style, tone, and formatting (In-Skill Examples pattern). -->

### Example 1
**Input:**
\`\`\`
[describe input]
\`\`\`
**Output:**
\`\`\`
[describe desired output]
\`\`\`

---

## Constraints

${guidance}

### Guardrails (Explain-the-Why)
- **Do not swallow errors silently.** If errors are swallowed, we lose the visibility needed to debug production failures and the system may enter an inconsistent state.
- **Validate all inputs at the boundary.** Unvalidated input is the primary source of injection attacks and malformed data in the persistence layer.
- **Avoid blocking the main thread for I/O.** Blocking the event loop causes latency spikes that degrade user experience and throughput.

### Acceptance criteria
- [ ] Happy path: *(define the expected successful flow)*
- [ ] Auth failure: *(define behaviour when caller is not authorised)*
- [ ] Validation failure: *(define behaviour on bad input)*
- [ ] Downstream failure: *(define behaviour when external dependency fails)*
- [ ] Performance: *(define latency or throughput target)*

---

## Execution Checklist
<!-- Linear workflow for multi-step procedures (Execution Checklist pattern). -->
<!-- Copy these into your response and tick them off as you progress. -->

- [ ] 1. Pre-execution verification (check state, dependencies)
- [ ] 2. Core implementation step A
- [ ] 3. Core implementation step B
- [ ] 4. Post-execution validation (verify side effects, run tests)

---

## Sprint contract (Plan-Validate-Execute)

> Before writing implementation code, the agent proposes a contract here.
> This bridges the gap between the high-level spec and the testable reality.
> For quality-critical tasks, use a **Self-Correcting Loop**: produce output,
> run a validator, fix if needed, and only then declare completion.

**Status:** [ ] Not started  [ ] Plan proposed  [ ] Plan confirmed  [ ] In progress  [ ] Done

### What will be built
*(Describe the specific implementation plan. If batch/destructive, reference assets/plan.json)*


### How it will be verified
*(Map each acceptance criterion above to a concrete, testable verification step)*

| Criterion | Verification method | Expected outcome |
|-----------|--------------------|-----------------:|
| Happy path | *(specific action + expected response)* | |
| Auth failure | *(unauthorised request + expected error)* | |
| Validation failure | *(malformed input + expected error)* | |
| Downstream failure | *(mock dependency failure + verify fallback)* | |
| Performance | *(benchmark command + target metric)* | |

### Out of scope
*(Explicitly define what will NOT be handled in this sprint)*

-

**Read \`\`gotchas.md\`\` for the full failure log.** Quick reference below:

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

- Read \`\`CONTEXT.md\`\` architecture section before writing any code
- Check \`\`memory/decisions/\`\` for prior decisions that affect this skill
- Check \`\`gotchas.md\`\` for known failure patterns before starting
- Write implementation to \`\`src/\`\` — this spec file stays unchanged
- Log deviations from this spec in \`\`memory/decisions/\`\` with Severity: HIGH
- If you need helper scripts: add them to \`\`scripts/\`\` and reference from here

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

- [ ] Scanned trigger keywords in \`\`gotchas.md\`\` against what happened this session
- [ ] For each gotcha whose trigger fired: raised confidence one level, updated \`\`last_seen\`\` to today
- [ ] For each novel failure not in \`\`gotchas.md\`\`: added a new G-NNN entry at \`\`●●○○○ low\`\` confidence
- [ ] For each gotcha that explicitly did NOT apply: lowered confidence one level, added a note
- [ ] No gotchas triggered and no new failures — noted this below

**Gotcha update log** *(fill or write "none triggered")*:

---

*Spec created: ${date} — Msingi v${VERSION}*
EOF
}

build_skill_gotchas() {
    local name="$1" category="$2" date=$(date +%Y-%m-%d)
    cat <<EOF
# gotchas.md — ${name} Institutional Knowledge

**Project:** ${PROJECT_NAME:-Project}
**Skill:** ${name}
**Last updated:** ${date}

> This is the accumulation of failures, edge cases, and "invisible" constraints
> discovered during actual execution. It is the most valuable context for
> avoiding wasted turns and regression.

---

## Confidence scoring model
Each gotcha is a belief with evidence, not just a note.
- ●●●●● critical — hit repeatedly, never contradicted, causes data loss or security issues
- ●●●●○ high     — hit 3+ times across projects, well-understood cause
- ●●●○○ medium   — seeded from known patterns, not yet confirmed in this project
- ●●○○○ low      — single observation, needs more evidence

---

## Failure Log (Seed Entries)

### G-001: PII Exposure in Auth Payloads
- **Confidence:** ●●●●● critical
- **Triggers:** jwt, oauth, session, profile
- **Last seen:** 2026-05-01
- **Status:** ACTIVE
- **The Gotcha:** Developers often put emails or names in JWT payloads for convenience.
- **The Failure:** JWTs are base64-encoded, NOT encrypted. Anyone with the token can read the PII.
- **The Fix:** Only store a non-PII \`user_id\` or \`sub\` in the token. Fetch PII from the DB on the server-side only.

### G-002: N+1 Query in List Endpoints
- **Confidence:** ●●●●○ high
- **Triggers:** database, list, index, orm
- **Last seen:** 2026-04-15
- **Status:** ACTIVE
- **The Gotcha:** Fetching a list of entities and then fetching related entities in a loop.
- **The Failure:** Causes O(N) database round-trips, leading to linear latency spikes.
- **The Fix:** Use eager loading (JOINs) or batching (WHERE IN) to fetch relations in 1-2 queries.

---
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# NAVIGATION STATE
# ═══════════════════════════════════════════════════════════════════════════════
current_step=0; TOTAL_STEPS=3; declare -a STEP_DEFS=()
declare -a STEP_COMPLETED=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)

select_workflow_mode() {
    clear; write_header "INIT" "1/1"
    local modes=("Quick Mode (2 steps)" "Guided Mode (5 steps)" "Advanced Mode (7 steps)")
    read_choice "Select Workflow" "${modes[@]}"; res_code=$?
    [[ $res_code -eq 4 ]] && exit 0
    case ${CHOICE_IDX:-1} in
        0) WORKFLOW_MODE="quick";     STEP_DEFS=("Details" "Review") ;;
        1) WORKFLOW_MODE="guided";    STEP_DEFS=("Type" "Details" "Agents" "Skills" "Review") ;;
        *) WORKFLOW_MODE="advanced";  STEP_DEFS=("Type" "Details" "Intake" "Agents" "Skills" "Auth" "Review") ;;
    esac
    TOTAL_STEPS=${#STEP_DEFS[@]}
}

show_step_selector() {
    echo -e "\n  ${C_BOLD}Jump to step:${C_RESET}"; 
    for ((i=0; i<TOTAL_STEPS; i++)); do printf "  %2d. %s\n" $((i+1)) "${STEP_DEFS[$i]}"; done
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════════════
if [[ -v TEST_HARNESS && $TEST_HARNESS -eq 1 ]]; then
    return 0 2>/dev/null || exit 0
fi

test_terminal
ALL_AGENTS_JSON=$(load_agents)
ALL_SKILLS_JSON=$(load_skills)

select_workflow_mode
while [[ $current_step -lt $TOTAL_STEPS ]]; do
    step_name="${STEP_DEFS[$current_step]}"
    clear; write_header "${WORKFLOW_MODE^^}" "$((current_step+1))/$TOTAL_STEPS"
    write_section "$step_name"
    
    case "$step_name" in
        "Type")    read_choice "Type" "Web" "Android" "API"; res_code=$? ;;
        "Details") read_line "Project Name" "my-project" "Enter name"; res_code=$?; PROJECT_NAME="${REPLY:-my-project}" ;;
        "Intake")  read_line "Audience" "Public" "Who is this for?"; res_code=$? ;;
        "Agents")  
            agent_names=($(echo "$ALL_AGENTS_JSON" | python3 -c "import json,sys; print(' '.join([a['name'].replace(' ', '_') for a in json.load(sys.stdin)]))"))
            read_choice "Select Agent" "${agent_names[@]}"; res_code=$? 
            SELECTED_AGENT="${agent_names[$CHOICE_IDX]}"
            ;;
        "Skills")  
            skill_names=($(echo "$ALL_SKILLS_JSON" | python3 -c "import json,sys; print(' '.join([s['id'] for s in json.load(sys.stdin)]))"))
            read_choice "Check Skill" "${skill_names[@]}"; res_code=$? ;;
        "Review")  read_confirm "Generate project?"; res_code=$? 
                   [[ $res_code -eq 0 && $CONFIRM -eq 1 ]] && { echo "Aborted."; exit 0; } ;;
        *) res_code=0 ;;
    esac

    if [[ $res_code -eq 6 ]]; then
        show_step_selector; read -p "  Jump: " j
        [[ "$j" =~ ^[0-9]+$ ]] && current_step=$((j-1)) || continue
    elif [[ $res_code -eq 4 || $res_code -eq 3 ]]; then # Back / Shift+Tab
        [[ $current_step -gt 0 ]] && ((current_step--))
    else # Next
        STEP_COMPLETED[$current_step]=1; ((current_step++))
    fi
done

# ═══════════════════════════════════════════════════════════════════════════════
# GENERATE
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n  $(hi "GENERATING SCAFFOLD...")\n"
mkdir -p "${PROJECT_NAME:-scaffold}"
echo "$(build_context_md "${PROJECT_NAME:-Project}")" > "${PROJECT_NAME:-scaffold}/CONTEXT.md"
echo "$(build_tasks_md)" > "${PROJECT_NAME:-scaffold}/TASKS.md"
echo "$(build_workstreams_md)" > "${PROJECT_NAME:-scaffold}/WORKSTREAMS.md"
echo "$(build_plans_md)" > "${PROJECT_NAME:-scaffold}/PLANS.md"
echo "$(build_quality_md)" > "${PROJECT_NAME:-scaffold}/QUALITY.md"
echo "$(build_observability_md)" > "${PROJECT_NAME:-scaffold}/OBSERVABILITY.md"

mkdir -p "${PROJECT_NAME:-scaffold}/.plans"
echo "$(build_plan_template_md)" > "${PROJECT_NAME:-scaffold}/.plans/template.md"

mkdir -p "${PROJECT_NAME:-scaffold}/agents"
if [[ -n "${SELECTED_AGENT:-}" ]]; then
    echo "$(build_agent_config "${SELECTED_AGENT}")" > "${PROJECT_NAME:-scaffold}/agents/${SELECTED_AGENT,,}.md"
fi

mkdir -p "${PROJECT_NAME:-scaffold}/workstreams/_coordinator"
mkdir -p "${PROJECT_NAME:-scaffold}/memory/trajectories"
echo "$(build_trajectory_md "${PROJECT_NAME:-Project}")" > "${PROJECT_NAME:-scaffold}/memory/trajectories/CURRENT.md"
echo "$(build_inbox_md)" > "${PROJECT_NAME:-scaffold}/workstreams/INBOX.md"

echo "# Core workstreams go here." > "${PROJECT_NAME:-scaffold}/workstreams/.keep"
cat <<EOF > "${PROJECT_NAME:-scaffold}/workstreams/_coordinator/DISPATCH.md"
# DISPATCH.md — Swarm Workstream Registry

## Active Workstreams
- ...

## Merged Workstreams
- ...
EOF

write_done "CONTEXT.md"
write_done "TASKS.md"
write_done "WORKSTREAMS.md"
write_done "PLANS.md & .plans/"
write_done "QUALITY.md"
write_done "OBSERVABILITY.md"
write_done "agents/ directory"
write_done "workstreams/ directory"

# Skills folder and files
# Note: msingi.sh uses a simplified skill emission. We only emit the SELECTED_SKILL if any.
# To achieve full parity, we would need to loop over inferred skills.
# For now, we ensure that if a skill folder is created, it follows the new hub-and-spoke pattern.
if [[ -n "${SELECTED_SKILL_ID:-}" ]]; then
    local skill_dir="${PROJECT_NAME:-scaffold}/skills/${SELECTED_SKILL_ID}"
    mkdir -p "${skill_dir}"/{scripts,assets,references,outputs,evals}
    echo "$(build_skill_spec "${SELECTED_SKILL_ID}" "${SELECTED_SKILL_NAME}" "general" "Load when..." "Guidance..." "Quickstart..." "Context...")" > "${skill_dir}/SKILL.md"
    echo "$(build_skill_gotchas "${SELECTED_SKILL_NAME}" "general")" > "${skill_dir}/gotchas.md"
    echo "$(build_skill_eval "${SELECTED_SKILL_NAME}")" > "${skill_dir}/evals/EVAL.md"
    echo -e "{\n  \"id\": \"${SELECTED_SKILL_ID}\",\n  \"status\": \"UNCONFIGURED\",\n  \"last_run\": null\n}" > "${skill_dir}/config.json"
    write_done "skills/${SELECTED_SKILL_ID}/ folder (Hub-and-Spoke)"
fi

# ── Completion panel (Parity with PS1) ──────────────────────────────────────────
tw=$(tput cols 2>/dev/null || echo 80)
box_inner=$((tw - 6))
[[ $box_inner -gt 70 ]] && box_inner=70

echo -e "  ${BRAND}╔$(printf '═%.0s' $(seq 1 $box_inner))╗${C_RESET}"
printf "  ${BRAND}║${C_RESET}  ${C_BOLD}${BRAND}✓  Bootstrap complete${C_RESET}%$((box_inner - 21))s${BRAND}║${C_RESET}\n" ""
printf "  ${BRAND}║${C_RESET}  ${C_GRAY}Msingi v${VERSION}  ·  BASH  ·  Accra/Everywhere${C_RESET}%$((box_inner - 42))s${BRAND}║${C_RESET}\n" ""
echo -e "  ${BRAND}╠$(printf '─%.0s' $(seq 1 $box_inner))╣${C_RESET}"
printf "  ${BRAND}║${C_RESET}  Location: ${PROJECT_NAME:-scaffold}%$((box_inner - 12 - ${#PROJECT_NAME}))s${BRAND}║${C_RESET}\n" ""
echo -e "  ${BRAND}╚$(printf '═%.0s' $(seq 1 $box_inner))╝${C_RESET}\n"

write_info "Bootstrap complete. msingi v${VERSION}"
