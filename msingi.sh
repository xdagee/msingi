#!/usr/bin/env bash
# ✨═══════════════════════════════════════════════════════════════════════════✨
#  Msingi v3.8.1 — Self-configuring multi-agent project scaffold tool.
#  macOS / Linux  ·  Bash 4.4+
#  https://github.com/xdagee/msingi
#
#  Built in Accra. Designed for everywhere.
# ✨═══════════════════════════════════════════════════════════════════════════✨
set -uo pipefail

VERSION="3.8.1"
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
# CONTEXT.md — msingi Canonical Source of Truth
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
            read_choice "Select Agent" "${agent_names[@]}"; res_code=$? ;;
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
write_done "CONTEXT.md"
write_done "TASKS.md"

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
