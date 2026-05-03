#!/usr/bin/env bash
# ✨═══════════════════════════════════════════════════════════════════════════✨
#  Msingi v3.8.1 — Self-configuring multi-agent project scaffold tool.
#  macOS / Linux  ·  Bash 4.4+
#  https://github.com/xdagee/msingi
#
#  Built in Accra. Designed for everywhere.
# ✨═══════════════════════════════════════════════════════════════════════════✨
set -uo pipefail

VERSION="3.9.0"
MAX_SKILLS=12
DRY_RUN=0
TARGET_PATH=""
STATE_FILE="${MSINGI_STATE_PATH:-$HOME/.msingi_state.json}"

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
    cat <<EOF
# CONTEXT.md — Static-Context Cache Layer
> This file represents the static baseline of the project. Cache this
> understanding and only re-read when architecture or fundamental NFRs change.
Project: ${1:-Project}
Msingi v${VERSION}
Generated: $(date)

## Architecture
- Mode: ${WORKFLOW_MODE}
- Stack: ${STACK:-Custom}

## Non-Functional Requirements
- Performance: < 2.5s page load
- Quality Gate: 90% test coverage
EOF
}

build_tasks_md() {
    cat <<EOF
# TASKS.md — Project Roadmap
- [ ] Initialize repository
- [ ] Implement core logic
- [ ] Add unit tests
EOF
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
    cat <<EOF
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

*Copy this skeleton to a new file (e.g., \`.plans/feature-name.md\`) when starting a complex task.*

## Purpose / Big Picture
Explain in a few sentences what someone gains after this change and how they can see it working. State the user-visible behavior you will enable.

## Progress
Use a list with checkboxes to summarize granular steps. Every stopping point must be documented here.
- [ ] (YYYY-MM-DD HH:MM) Example step 1.
- [ ] Example step 2.

## Surprises & Discoveries
Document unexpected behaviors, bugs, optimizations, or insights discovered during implementation. Provide concise evidence.

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
EOF
}

build_plan_template_md() {
    cat <<EOF
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
EOF
}

build_quality_md() {
    cat <<EOF
# QUALITY.md — Production Quality Gates

**Project:** ${PROJECT_NAME:-Project}

> These are not suggestions. A feature is not complete until every applicable
> gate below is checked. Agents self-verify — do not mark done and move on.
> Gates that cannot be met without changing requirements trigger an ESCALATE.

---

## Gate verification process

When an agent completes a feature:
1. Confirm it passes, or document why it does not apply
2. Write verification results to scratchpads/[agent]/NOTES.md
3. If any gate fails: either fix it (preferred) or log the exception in memory/decisions/
   with Severity: HIGH and the rationale for accepting the exception
4. Only then mark the task done in TASKS.md

## Entropy Control (Golden Principles)
Codebases naturally degrade over time. Agents must actively fight entropy by enforcing these golden principles when modifying existing code:
- **Centralize shared utilities:** If you see the same logic in two places, extract it to a shared module.
- **Prune dead code:** If you replace a function or deprecate a feature, delete the old code immediately. Do not leave it commented out.
- **Refactor as you go:** If you touch a file that violates current style or architecture standards, upgrade it to the new standard as part of your PR.
EOF
}

build_observability_md() {
    cat <<EOF
# OBSERVABILITY.md — Logging, Metrics, and Alerting

**Project:** ${PROJECT_NAME:-Project}

> Defines what the system must emit and what must be monitored.
> Agents read this before implementing any logging, metrics, or health check logic.
> Observability is not optional — it is a production requirement.

---

## General logging rules

### What to log
- Significant business events (user registered, order placed, model inference complete)
- All errors with full context: error code, message, relevant IDs, stack trace (server-side only)
- Performance measurements for critical paths: duration, resource consumed
- Security events: login attempt, permission denied, token issued/revoked

### What never to log
- Passwords, tokens, API keys, or any credential — even partially
- Full PII: names, emails, phone numbers, addresses in production logs

## Application Legibility
The system must be transparent to both humans and agents during runtime.
- **Correlation IDs:** Every external request must generate or inherit a trace ID passed to all downstream services and logs.
- **Health endpoints:** The system must expose a \`/_health\` or similar endpoint returning component status and version.
- **Readiness/Liveness:** For orchestrated deployments (e.g., Kubernetes), expose distinct liveness and readiness probes.
EOF
}

build_agent_config() {
    local agent_name="${1:-Agent}"
    cat <<EOF
# ${agent_name}
> Pointer file — canonical context lives in CONTEXT.md

## Core Context
> Context engineering principle: dynamic state before static context.
> Read this section at the start of every session.

1. \`scratchpads/own/SESSION.md\` — where did I leave off? Resolve any ESCALATE before proceeding
2. \`TASKS.md\` — what is the current work for this milestone?
3. \`WORKSTREAMS.md\` — which workstream am I in? What is my scope? Any phase gates to check?
4. \`scratchpads/own/NOTES.md\` — what do I persistently know across sessions?
5. \`CONTEXT.md\` — architecture and NFRs (skim if unchanged)

## Where to look next
> Progressive disclosure: fetch these documents only when relevant to your current task.

- **Design & Architecture**: Check \`docs/\` for architectural diagrams, API contracts, or data models
- **Execution Plans**: Check \`.plans/\` for active and historical ExecPlans (see PLANS.md for protocol)
- **Domain Logic**: Check \`DOMAIN.md\` before features touching business rules
- **Production Rules**: Check \`QUALITY.md\`, \`SECURITY.md\`, \`ENVIRONMENTS.md\`, and \`OBSERVABILITY.md\` before implementation

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
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# NAVIGATION STATE
# ═══════════════════════════════════════════════════════════════════════════════
current_step=0; TOTAL_STEPS=3; declare -a STEP_DEFS=()
declare -a STEP_COMPLETED=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)

select_workflow_mode() {
    clear; write_header "INIT" "1/1"
    local modes=("Quick Mode (3 steps)" "Guided Mode (7 steps)" "Advanced Mode (12 steps)")
    read_choice "Select Workflow" "${modes[@]}"; res_code=$?
    [[ $res_code -eq 4 ]] && exit 0
    case ${CHOICE_IDX:-1} in
        0) WORKFLOW_MODE="quick";     STEP_DEFS=("Mode" "Details" "Review") ;;
        1) WORKFLOW_MODE="guided";    STEP_DEFS=("Mode" "Type" "Details" "Agents" "Skills" "Review") ;;
        *) WORKFLOW_MODE="advanced";  STEP_DEFS=("Mode" "Type" "Details" "Intake" "Agents" "Skills" "Auth" "Review") ;;
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
test_terminal
ALL_AGENTS_JSON=$(load_agents)
ALL_SKILLS_JSON=$(load_skills)

select_workflow_mode
while [[ $current_step -lt $TOTAL_STEPS ]]; do
    step_name="${STEP_DEFS[$current_step]}"
    clear; write_header "${WORKFLOW_MODE^^}" "$((current_step+1))/$TOTAL_STEPS"
    write_section "$step_name"
    
    case "$step_name" in
        "Mode")    read_choice "Start" "New" "Existing"; res_code=$? ;;
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
