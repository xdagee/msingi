#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Msingi — context engineering infrastructure for AI agent sessions
#  macOS / Linux  ·  Bash 4+
#  https://github.com/stemaide/msingi
#
#  "Msingi" is Swahili for foundation — the groundwork you lay before building.
#   Built in Accra. Designed for everywhere.
#
#  Usage:
#    ./msingi.sh                # guided mode
#    ./msingi.sh --dry-run      # preview files without writing
#    ./msingi.sh --help
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

VERSION="3.8.1"
MAX_SKILLS=12
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0

# ─────────────────────────────────────────────────────────────────────────────
# ANSI COLOURS
# ─────────────────────────────────────────────────────────────────────────────
ESC=$'\033'
C_RESET="${ESC}[0m"
C_BOLD="${ESC}[1m"
C_DIM="${ESC}[2m"
C_CYAN="${ESC}[96m"
C_GREEN="${ESC}[92m"
C_YELLOW="${ESC}[93m"
C_RED="${ESC}[91m"
C_MAGENTA="${ESC}[95m"
C_GRAY="${ESC}[90m"
BRAND="${ESC}[38;2;0;210;200m"

hi()     { echo -n "${C_CYAN}${1}${C_RESET}"; }
ok()     { echo -n "${C_GREEN}${1}${C_RESET}"; }
warn()   { echo -n "${C_YELLOW}${1}${C_RESET}"; }
err()    { echo -n "${C_RED}${1}${C_RESET}"; }
dim()    { echo -n "${C_GRAY}${1}${C_RESET}"; }
bold()   { echo -n "${C_BOLD}${1}${C_RESET}"; }
brand()  { echo -n "${BRAND}${C_BOLD}${1}${C_RESET}"; }

write_done() { echo "  $(ok "✓")  ${1}"; }
write_warn() { echo "  $(warn "⚠")  ${1}"; }
write_fail() { echo "  $(err "✗")  ${1}"; exit 1; }
write_info() { echo "  ${C_GRAY}·  ${1}${C_RESET}"; }
write_rule() { echo "  ${C_GRAY}$(printf '─%.0s' {1..64})${C_RESET}"; }

# ─────────────────────────────────────────────────────────────────────────────
# ARGUMENT PARSING
# ─────────────────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=1 ;;
    --help|-h)
      echo ""
      echo "  $(brand "Msingi") ${C_GRAY}v${VERSION}${C_RESET}"
      echo "  ${C_GRAY}Context engineering infrastructure for AI agent sessions${C_RESET}"
      echo ""
      echo "  Usage: ./msingi.sh [--dry-run] [--help]"
      echo ""
      echo "  --dry-run   Preview all files that would be created without writing"
      echo "  --help      Show this message"
      echo ""
      exit 0 ;;
    *) write_fail "Unknown argument: ${arg}. Use --help for usage." ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# BANNER
# ─────────────────────────────────────────────────────────────────────────────
clear
echo ""
echo "  $(brand "Msingi")  ${C_GRAY}v${VERSION}${C_RESET}"
echo "  ${C_GRAY}Context engineering infrastructure for AI agent sessions${C_RESET}"
echo "  ${C_GRAY}Built in Accra. Designed for everywhere.${C_RESET}"
echo ""
write_rule
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
  echo "  $(warn "DRY RUN — no files will be written")"
  echo ""
fi

# ─────────────────────────────────────────────────────────────────────────────
# INPUT HELPERS
# ─────────────────────────────────────────────────────────────────────────────
# read_line PROMPT DEFAULT HINT → sets REPLY
read_line() {
  local prompt="$1" default="${2:-}" hint="${3:-}"
  local def_str="" hint_str=""
  [[ -n "$default" ]] && def_str="  ${C_GRAY}[${default}]${C_RESET}"
  [[ -n "$hint"    ]] && hint_str="  ${C_GRAY}${hint}${C_RESET}"
  printf "  ${BRAND}?${C_RESET}  ${C_BOLD}%s${C_RESET}%s%s  " "$prompt" "$def_str" "$hint_str"
  read -r REPLY || true
  [[ -z "$REPLY" && -n "$default" ]] && REPLY="$default"
}

# read_confirm PROMPT DEFAULT → sets CONFIRM (0=yes 1=no)
read_confirm() {
  local prompt="$1" default="${2:-y}"
  local hint
  [[ "$default" == "y" ]] && hint="Y/n" || hint="y/N"
  printf "  ${BRAND}?${C_RESET}  ${C_BOLD}%s${C_RESET}  ${C_GRAY}(%s)${C_RESET}  " "$prompt" "$hint"
  read -r REPLY || true
  if [[ -z "$REPLY" ]]; then
    [[ "$default" == "y" ]] && CONFIRM=0 || CONFIRM=1
  elif [[ "$REPLY" =~ ^[Yy] ]]; then
    CONFIRM=0
  else
    CONFIRM=1
  fi
}

# read_choice PROMPT ITEMS... → sets CHOICE_IDX (0-based)
read_choice() {
  local prompt="$1"; shift
  local items=("$@")
  echo ""
  echo "  ${BRAND}›${C_RESET}  ${C_BOLD}${prompt}${C_RESET}  ${C_GRAY}(enter number)${C_RESET}"
  echo ""
  local i=1
  for item in "${items[@]}"; do
    printf "  ${C_GRAY}%2d${C_RESET}  %s\n" "$i" "$item"
    ((i++)) || true
  done
  echo ""
  while true; do
    printf "  ${BRAND}?${C_RESET}  Choice [1-%d]: " "${#items[@]}"
    read -r REPLY || true
    if [[ "$REPLY" =~ ^[0-9]+$ ]] && \
       [[ "$REPLY" -ge 1 ]] && \
       [[ "$REPLY" -le "${#items[@]}" ]]; then
      CHOICE_IDX=$(( REPLY - 1 ))
      break
    fi
    echo "  $(warn "⚠")  Enter a number between 1 and ${#items[@]}"
  done
}

# read_checkboxes PROMPT ITEMS... → sets CHECKED_INDICES (space-separated)
# Pre-checked: pass PRECHECKED_INDICES env var with space-separated 0-based indices
read_checkboxes() {
  local prompt="$1"; shift
  local items=("$@")
  local prechecked="${PRECHECKED_INDICES:-0}"
  echo ""
  echo "  ${BRAND}›${C_RESET}  ${C_BOLD}${prompt}${C_RESET}  ${C_GRAY}(space-separated numbers, e.g. 1 3 5)${C_RESET}"
  echo ""

  # Show items with pre-check indicators
  local i=1
  for item in "${items[@]}"; do
    local idx=$(( i - 1 ))
    local marker="○"
    for p in $prechecked; do
      [[ "$p" == "$idx" ]] && marker="●" && break
    done
    if [[ "$marker" == "●" ]]; then
      printf "  ${C_GREEN}●${C_RESET}  ${C_GRAY}%2d${C_RESET}  ${C_GREEN}%s${C_RESET}\n" "$i" "$item"
    else
      printf "  ${C_GRAY}○  %2d  %s${C_RESET}\n" "$i" "$item"
    fi
    ((i++)) || true
  done
  echo ""
  write_info "Pre-selected shown with ●. Enter numbers to select (or press Enter to keep defaults)."
  printf "  ${BRAND}?${C_RESET}  Selections [default: %s]: " "$( echo "$prechecked" | awk '{for(i=1;i<=NF;i++) printf "%d ", $i+1}' )"
  read -r REPLY || true

  if [[ -z "$REPLY" ]]; then
    CHECKED_INDICES="$prechecked"
    return
  fi

  # Parse user input (1-based) → 0-based indices
  CHECKED_INDICES=""
  for num in $REPLY; do
    if [[ "$num" =~ ^[0-9]+$ ]] && \
       [[ "$num" -ge 1 ]] && \
       [[ "$num" -le "${#items[@]}" ]]; then
      CHECKED_INDICES="$CHECKED_INDICES $(( num - 1 ))"
    fi
  done
  CHECKED_INDICES="${CHECKED_INDICES# }"
}

# ─────────────────────────────────────────────────────────────────────────────
# DATE HELPER
# ─────────────────────────────────────────────────────────────────────────────
get_date() { date "+%Y-%m-%d"; }

# ─────────────────────────────────────────────────────────────────────────────
# FILE EMIT
# ─────────────────────────────────────────────────────────────────────────────
emit_file() {
  local rel_path="$1"
  local content="$2"
  local root="$3"
  local full_path="${root}/${rel_path}"
  local dir
  dir="$(dirname "$full_path")"

  if [[ $DRY_RUN -eq 1 ]]; then
    write_done "${rel_path} ${C_GRAY}(dry run)${C_RESET}"
    return
  fi

  mkdir -p "$dir"
  printf '%s' "$content" > "$full_path"
  write_done "$rel_path"
}

# ─────────────────────────────────────────────────────────────────────────────
# SKILL INFERENCE ENGINE
# ─────────────────────────────────────────────────────────────────────────────
# Skills registry — sourced from skills.json via generator script
# Each skill: ID NAME CAT TYPES TRIGGER BASELINE

declare -A SKILL_ID_MAP SKILL_NAME_MAP SKILL_CAT_MAP SKILL_TYPES_MAP SKILL_TRIGGER_MAP SKILL_BASELINE_MAP

register_skill() {
  local id="$1" name="$2" cat="$3" types="$4" trigger="$5" baseline="$6"
  local key="${id//-/_}"
  SKILL_ID_MAP[$key]="$id"
  SKILL_NAME_MAP[$key]="$name"
  SKILL_CAT_MAP[$key]="$cat"
  SKILL_TYPES_MAP[$key]="$types"
  SKILL_TRIGGER_MAP[$key]="$trigger"
  SKILL_BASELINE_MAP[$key]="$baseline"
  ALL_SKILL_KEYS+=("$key")
}

ALL_SKILL_KEYS=()

register_skill "user-authentication"       "User Authentication"                  "auth"     "web-app fullstack api-service"         "auth|login|signup|sign.?in|register|jwt|oauth|session|password|user.?account|credential"  0
register_skill "role-based-access"         "Role-Based Access Control"            "auth"     "web-app fullstack api-service"         "role|permission|admin|rbac|access.?control|privilege|authoris|authori[zs]"                 0
register_skill "api-key-management"        "API Key Management"                   "auth"     "api-service fullstack"                 "api.?key|service.?account|machine.?to.?machine|m2m|client.?secret|token.?rotation"        0
register_skill "android-auth"              "Android Authentication"               "auth"     "android"                               "biometric|fingerprint|pin|keystore.*auth|android.*auth|credential.*manager|accountmanager"  0
register_skill "database-crud"             "Database Operations"                  "data"     "web-app api-service fullstack ml-ai"   "database|mysql|postgres|postgresql|sqlite|mongo|prisma|orm|crud|model|schema|migration|supabase|planetscale|neon" 0
register_skill "file-storage"              "File Storage & Retrieval"             "data"     "web-app fullstack api-service"         "upload|file|storage|s3|blob|bucket|image|media|asset|attachment|cdn|object.?store"        0
register_skill "caching"                   "Caching Layer"                        "data"     "web-app api-service fullstack"         "cache|redis|memcache|ttl|invalidat|in.?memory|read.?through|write.?through"                0
register_skill "search"                    "Search & Filtering"                   "data"     "web-app fullstack api-service"         "search|filter|query|elasticsearch|algolia|typesense|full.?text|facet|ranking"              0
register_skill "room-local-db"             "Room Local Database"                  "data"     "android"                               "room|local.?db|local.?database|offline|sqlite.*android|dao\b|entity.*android"              0
register_skill "data-sync"                 "Offline Data Sync"                    "data"     "android web-app fullstack"             "offline|sync|conflict.*resolut|merge.*strategy|eventual.*consistency|optimistic.*update|workmanager" 0
register_skill "vector-store"              "Vector Store & Retrieval"             "data"     "ml-ai"                                 "vector|embedding|semantic.*search|pgvector|pinecone|weaviate|chroma|faiss|rag\b|retrieval.?augmented" 0
register_skill "feature-store"             "Feature Store"                        "data"     "ml-ai"                                 "feature.?store|feast|tecton|feature.*engineer|feature.*pipeline|online.*feature|offline.*feature" 0
register_skill "rest-api"                  "REST API Layer"                       "api"      "web-app api-service fullstack ml-ai"   "api|rest|endpoint|route|fastapi|express|flask|django|laravel|hono|nestjs|controller|resource" 0
register_skill "api-versioning"            "API Versioning"                       "api"      "api-service fullstack"                 "version|v1|v2|backward.*compat|breaking.*change|deprecat|sunset|api.*contract"            0
register_skill "api-validation"            "Input Validation"                     "api"      "web-app api-service fullstack ml-ai"   "validat|sanitiz|schema|zod|yup|pydantic|joi|form.?data|input.*check|request.*body"        0
register_skill "error-handling"            "Error Handling & Structured Logging"  "api"      "web-app api-service fullstack ml-ai cli-tool android" "error|exception|log|logger|sentry|monitor|trace|debug|structured.*log|log.*level" 1
register_skill "rate-limiting"             "Rate Limiting & Throttling"           "api"      "api-service web-app fullstack"         "rate.?limit|throttl|quota|burst|concurrency.*limit|ddos|abuse.*prevent"                   0
register_skill "third-party-integration"   "Third-Party Integration"              "api"      "web-app api-service fullstack"         "integrat|external.?api|payment|stripe|sendgrid|twilio|slack|zapier|hubspot|third.?party"  0
register_skill "webhook-delivery"          "Webhook Delivery"                     "api"      "api-service fullstack"                 "webhook|outbound.*event|event.*delivery|webhook.*retry|webhook.*signature|svix|hookdeck"  0
register_skill "api-documentation"         "API Documentation"                    "api"      "api-service fullstack"                 "openapi|swagger|redoc|api.?doc|spec.*generat|schema.*export|contract.*first"               0
register_skill "graphql"                   "GraphQL API"                          "api"      "api-service fullstack web-app"         "graphql|apollo|relay|hasura|resolver|subscription.*graphql|mutation.*graphql"             0
register_skill "service-health"            "Health & Readiness Endpoints"         "api"      "api-service fullstack ml-ai"           "health|readiness|liveness|probe|heartbeat|/ready|/health|/ping|uptime"                    0
register_skill "cli-arg-parsing"           "CLI Argument Parsing"                 "api"      "cli-tool"                              "arg|flag|option|subcommand|commander|clap|click|cobra|argv|argparse|cli.*parse|command.?line|interactive.*prompt|wizard" 1
register_skill "cli-output-formatting"     "CLI Output Formatting"                "api"      "cli-tool"                              "colour|color|ansi|terminal|tty|spinner|progress.*bar|table.*output|json.*output|stdout|stderr|pretty.*print|human.?readable|machine.?readable" 1
register_skill "cli-config-management"     "CLI Configuration Management"         "api"      "cli-tool"                              "config.*file|dotfile|.config|settings.*file|user.*config|global.*config|local.*config|toml|yaml.*config|ini|profile.*config|persist.*setting" 1
register_skill "ui-components"             "UI Component System"                  "ui"       "web-app fullstack"                     "component|react|vue|svelte|tailwind|shadcn|design.?system|storybook|radix|headless.?ui"   0
register_skill "forms"                     "Form Handling & Validation"           "ui"       "web-app fullstack"                     "form|input|submit|formik|react.?hook.?form|react.*form|form.*validat"                      0
register_skill "data-visualisation"        "Data Visualisation"                   "ui"       "web-app fullstack ml-ai"               "chart|graph|dashboard|visualis|plot|recharts|d3|analytics.?ui|chart.js|echarts"           0
register_skill "accessibility"             "Accessibility"                        "ui"       "web-app fullstack"                     "accessib|a11y|aria|wcag|screen.?reader|keyboard.*nav|focus.*trap|contrast.*ratio"          0
register_skill "seo"                       "SEO & Metadata"                       "ui"       "web-app fullstack"                     "seo|meta.*tag|open.?graph|sitemap|robots.txt|canonical|structured.*data|schema.org|next.*head" 0
register_skill "android-ui"                "Jetpack Compose UI"                   "ui"       "android"                               "compose|composable|recomposition|modifier|theme.*android|material.*3|preview.*composable|scaffold.*compose" 0
register_skill "android-navigation"        "Android Navigation"                   "ui"       "android"                               "navigation|navcontroller|backstack|deeplink|bottom.*nav|drawer.*nav|navgraph|destination"  0
register_skill "model-inference"           "Model Inference Pipeline"             "ml"       "ml-ai"                                 "inference|predict|llm|transformer|onnx|tflite|torchserve|triton|vllm|batch.*infer|realtime.*infer" 0
register_skill "data-preprocessing"        "Data Preprocessing"                   "ml"       "ml-ai"                                 "preprocess|clean.*data|normaliz|tokeniz|dataset|pipeline.*ml|etl|data.*transform|feature.*extract" 0
register_skill "model-training"            "Model Training Pipeline"              "ml"       "ml-ai"                                 "finetun|fine.?tun|lora|qlora|unsloth|epoch|checkpoint|training.?loop|train.*script|trainer" 0
register_skill "experiment-tracking"       "Experiment Tracking"                  "ml"       "ml-ai"                                 "experiment|mlflow|wandb|neptune|comet|run.*track|metric.*log|artifact.*log|hyperparamet"   0
register_skill "model-registry"            "Model Registry & Versioning"          "ml"       "ml-ai"                                 "model.*registry|model.*version|model.*store|model.*artifact|stage.*model|promote.*model|model.*lineage" 0
register_skill "model-monitoring"          "Model Monitoring & Drift Detection"   "ml"       "ml-ai"                                 "drift|data.*drift|model.*degrad|monitor.*model|concept.*drift|distribut.*shift|evalu.*production|shadow.*deploy" 0
register_skill "prompt-management"         "Prompt Management"                    "ml"       "ml-ai"                                 "prompt|system.?message|context.?window|few.?shot|prompt.?template|prompt.*version|prompt.*eval" 0
register_skill "data-validation"           "Data Validation & Quality"            "ml"       "ml-ai"                                 "great.*expectations|pandera|data.*valid|schema.*valid.*data|data.*quality|data.*contract|data.*test" 0
register_skill "environment-config"        "Environment & Secrets Management"     "infra"    "web-app api-service fullstack ml-ai cli-tool android" "env|config|dotenv|secret|environment|settings|.env|vault|ssm|secret.*manager|key.*management" 1
register_skill "background-jobs"           "Background Jobs & Queues"             "infra"    "web-app api-service fullstack ml-ai"   "queue|job|worker|celery|bull|beanstalk|cron|schedule|async.?task|message.*queue|sqs|rabbitmq" 0
register_skill "deployment"                "Deployment Pipeline"                  "infra"    "web-app api-service fullstack ml-ai"   "deploy|docker|ci.?cd|github.?action|pipeline|vercel|railway|render|kubernetes|k8s|ecs|cloud.*run" 0
register_skill "cli-distribution"          "CLI Distribution & Installation"      "infra"    "cli-tool"                              "distribut|publish|npm.*publish|cargo.*publish|brew|chocolatey|winget|scoop|install.*script|binary.*release|cross.?compil" 0
register_skill "cli-self-update"           "Self-Update Mechanism"                "infra"    "cli-tool"                              "self.?update|auto.?update|update.*check|new.*version.*available|upgrade.*cli|check.*release" 0
register_skill "android-build-pipeline"   "Android Build & Release Pipeline"     "infra"    "android"                               "play.*store|release.*build|signing|keystore.*sign|fastlane|gradle.*ci|github.*action.*android|bundle.*release|aab" 0
register_skill "monorepo-tooling"          "Monorepo Tooling"                     "infra"    "fullstack"                             "monorepo|turborepo|nx\b|pnpm.*workspace|lerna|yarn.*workspace|shared.*package|workspace.*root" 0
register_skill "container-orchestration"  "Container Orchestration"              "infra"    "api-service fullstack ml-ai"           "kubernetes|k8s|helm|kustomize|ecs|fargate|container.*orchestrat|pod\b|namespace.*k8s|ingress.*controller" 0
register_skill "observability"             "Observability & Monitoring"           "infra"    "web-app api-service fullstack ml-ai"   "observ|opentelemetry|otel|datadog|prometheus|grafana|trace|span|metric.*collect|alert.*rule|uptime.*monitor" 0
register_skill "notifications"             "Notification System"                  "messaging" "web-app fullstack android"            "notif|email|sms|push|alert|toast|inbox|fcm|apns|onesignal|sendgrid|email.*templat"         0
register_skill "realtime"                  "Real-Time Communication"              "messaging" "web-app fullstack api-service"        "realtime|real.?time|websocket|socket.io|live|sse|event.?stream|pubsub|long.?poll"          0
register_skill "event-streaming"           "Event Streaming"                      "messaging" "api-service fullstack ml-ai"          "kafka|kinesis|pubsub|event.*stream|event.*bus|event.*driven|event.*sourcing|cqrs|domain.*event" 0
register_skill "automated-testing"         "Automated Testing"                    "testing"  "web-app api-service fullstack ml-ai cli-tool android" "test|jest|pytest|vitest|junit|kotest|mockk|cypress|playwright|unit|integration|e2e|coverage" 1
register_skill "contract-testing"          "API Contract Testing"                 "testing"  "api-service fullstack"                 "contract.*test|pact\b|consumer.*driven|provider.*test|api.*test.*contract|breaking.*change.*test" 0
register_skill "android-testing"           "Android Instrumented Testing"         "testing"  "android"                               "espresso|ui.*automator|instrumented.*test|android.*test|robolectric|compose.*test|test.*rule" 0
register_skill "load-testing"              "Load & Performance Testing"           "testing"  "api-service fullstack ml-ai"           "load.*test|stress.*test|performance.*test|k6\b|locust|artillery|gatling|benchmark|throughput.*test" 0
register_skill "android-di"                "Dependency Injection (Hilt)"          "android"  "android"                               "hilt|dagger|inject\b|di\b|dependency.*inject|module.*android|component.*android"            0
register_skill "android-viewmodel"         "ViewModel & State Management"         "android"  "android"                               "viewmodel|uistate|stateflow|sharedflow|mutablestate|remember.*state|state.*hoist|ui.*state.*android" 0
register_skill "android-network"           "Networking & API Client"              "android"  "android"                               "retrofit|ktor.*client|okhttp|api.*client.*android|network.*layer.*android|remote.*datasource" 0
register_skill "android-crash-reporting"  "Crash Reporting & Analytics"          "android"  "android"                               "crashlytics|firebase|crash.*report|analytics.*android|logcat.*production|non.?fatal|anr\b"  0
register_skill "app-signing"               "App Signing & Release Management"     "android"  "android"                               "signing|keystore|upload.*key|release.*key|sign.*apk|sign.*aab|proguard|r8.*minif|obfuscat"  0

# Infer skills from haystack + type_id
# Sets INFERRED_SKILL_IDS (space-separated) and INFERRED_SKILL_NAMES (newline-separated)
infer_skills() {
  local haystack="${1,,}"   # lower-cased
  local type_id="$2"
  local -a matched_ids=() matched_names=() baseline_ids=() baseline_names=()

  for key in "${ALL_SKILL_KEYS[@]}"; do
    local types="${SKILL_TYPES_MAP[$key]}"
    local trigger="${SKILL_TRIGGER_MAP[$key]}"
    local sid="${SKILL_ID_MAP[$key]}"
    local sname="${SKILL_NAME_MAP[$key]}"
    local is_baseline="${SKILL_BASELINE_MAP[$key]}"

    # Type scope check
    if [[ -n "$types" ]]; then
      local type_match=0
      for t in $types; do
        [[ "$t" == "$type_id" ]] && type_match=1 && break
      done
      [[ $type_match -eq 0 ]] && continue
    fi

    # Trigger match (case-insensitive extended regex)
    if echo "$haystack" | grep -qEi "$trigger" 2>/dev/null; then
      if [[ "$is_baseline" == "1" ]]; then
        baseline_ids+=("$sid")
        baseline_names+=("$sname")
      else
        matched_ids+=("$sid")
        matched_names+=("$sname")
      fi
    elif [[ "$is_baseline" == "1" ]]; then
      baseline_ids+=("$sid")
      baseline_names+=("$sname")
    fi
  done

  # Combine: trigger matches first, then baselines not already included
  local final_ids=() final_names=()
  local seen=""
  for i in "${!matched_ids[@]}"; do
    local sid="${matched_ids[$i]}"
    if [[ "$seen" != *" $sid "* ]]; then
      seen=" $sid $seen"
      final_ids+=("$sid")
      final_names+=("${matched_names[$i]}")
      [[ "${#final_ids[@]}" -ge "$MAX_SKILLS" ]] && break
    fi
  done
  for i in "${!baseline_ids[@]}"; do
    local sid="${baseline_ids[$i]}"
    if [[ "$seen" != *" $sid "* ]] && [[ "${#final_ids[@]}" -lt "$MAX_SKILLS" ]]; then
      seen=" $sid $seen"
      final_ids+=("$sid")
      final_names+=("${baseline_names[$i]}")
    fi
  done

  INFERRED_SKILL_IDS="${final_ids[*]:-}"
  INFERRED_SKILL_NAMES="$(printf '%s\n' "${final_names[@]:-}")"
}

# ─────────────────────────────────────────────────────────────────────────────
# SCREEN 1: MODE
# ─────────────────────────────────────────────────────────────────────────────
echo "  ${C_GRAY}[1/7]${C_RESET}  $(bold "Mode")"
echo ""
read_choice "What are we doing?" \
  "New project        — start from scratch" \
  "Existing project   — scan codebase and overlay structure"

if [[ $CHOICE_IDX -eq 0 ]]; then
  MODE="greenfield"
else
  MODE="brownfield"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SCREEN 2: PROJECT TYPE
# ─────────────────────────────────────────────────────────────────────────────
echo "  ${C_GRAY}[2/7]${C_RESET}  $(bold "Project type")"
echo ""
write_info "Select one or two types. Hybrid merges skill pools — primary drives architecture."
echo ""

TYPE_LABELS=(
  "Web Application    — server-rendered or SPA, user-facing"
  "API Service        — headless backend, contracts are everything"
  "ML / AI System     — model pipeline, data flows, inference serving"
  "CLI Tool           — developer tooling, distribution, reliability"
  "Full-Stack Platform — web + API + optional ML"
  "Android App        — Kotlin + Jetpack Compose, Clean Architecture"
)
TYPE_IDS=("web-app" "api-service" "ml-ai" "cli-tool" "fullstack" "android")
TYPE_NAMES=("Web Application" "API Service" "ML / AI System" "CLI Tool" "Full-Stack Platform" "Android App")

PRECHECKED_INDICES="0"

VALID_SELECTION=0
while [[ $VALID_SELECTION -eq 0 ]]; do
  read_checkboxes "Project type(s) — max 2 for hybrid" "${TYPE_LABELS[@]}"
  local_checked=($CHECKED_INDICES)
  count="${#local_checked[@]}"
  if [[ $count -eq 0 ]]; then
    write_warn "Select at least one type."
  elif [[ $count -gt 2 ]]; then
    write_warn "Select at most two types for hybrid composition."
  else
    VALID_SELECTION=1
  fi
done

PRIMARY_TYPE_IDX="${local_checked[0]}"
TYPE_ID="${TYPE_IDS[$PRIMARY_TYPE_IDX]}"
TYPE_LABEL="${TYPE_NAMES[$PRIMARY_TYPE_IDX]}"

SECONDARY_TYPE_ID=""
SECONDARY_TYPE_LABEL=""
if [[ ${#local_checked[@]} -eq 2 ]]; then
  sec_idx="${local_checked[1]}"
  SECONDARY_TYPE_ID="${TYPE_IDS[$sec_idx]}"
  SECONDARY_TYPE_LABEL="${TYPE_NAMES[$sec_idx]}"
  echo "  $(ok "✓") Hybrid: ${C_BOLD}${TYPE_LABEL}${C_RESET}  ${C_GRAY}+${C_RESET}  ${SECONDARY_TYPE_LABEL}"
else
  echo "  $(ok "✓") ${C_BOLD}${TYPE_LABEL}${C_RESET}"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SCREEN 3: PROJECT DETAILS
# ─────────────────────────────────────────────────────────────────────────────
echo "  ${C_GRAY}[3/7]${C_RESET}  $(bold "Project details")"
echo ""

if [[ "$MODE" == "brownfield" ]]; then
  read_line "Directory to scan" "$(pwd)"
  SCAN_PATH="$REPLY"
  if [[ ! -d "$SCAN_PATH" ]]; then
    write_fail "Directory not found: ${SCAN_PATH}"
  fi

  # Simple brownfield scan: read README for description, sniff common files
  PROJECT_NAME="$(basename "$SCAN_PATH")"
  PROJECT_DESC=""
  PROJECT_STACK=""
  PROJECT_MILESTONE="v1.0 release"

  # Try to extract description from README
  for readme in "${SCAN_PATH}/README.md" "${SCAN_PATH}/README.txt" "${SCAN_PATH}/README"; do
    if [[ -f "$readme" ]]; then
      PROJECT_DESC="$(grep -v '^#' "$readme" | grep -v '^$' | head -3 | tr '\n' ' ' | cut -c1-200 || true)"
      break
    fi
  done

  # Sniff stack
  STACK_HINTS=()
  [[ -f "${SCAN_PATH}/package.json" ]]      && STACK_HINTS+=("Node.js")
  [[ -f "${SCAN_PATH}/requirements.txt" ]]  && STACK_HINTS+=("Python")
  [[ -f "${SCAN_PATH}/Pipfile" ]]           && STACK_HINTS+=("Python")
  [[ -f "${SCAN_PATH}/go.mod" ]]            && STACK_HINTS+=("Go")
  [[ -f "${SCAN_PATH}/Cargo.toml" ]]        && STACK_HINTS+=("Rust")
  [[ -f "${SCAN_PATH}/pom.xml" ]]           && STACK_HINTS+=("Java")
  [[ -f "${SCAN_PATH}/build.gradle.kts" ]]  && STACK_HINTS+=("Kotlin")
  [[ -f "${SCAN_PATH}/composer.json" ]]     && STACK_HINTS+=("PHP")
  [[ -f "${SCAN_PATH}/Gemfile" ]]           && STACK_HINTS+=("Ruby")
  PROJECT_STACK="$(IFS=', '; echo "${STACK_HINTS[*]}")"

  write_info "Scan complete — review and edit inferred values."
  echo ""
  read_line "Project name" "$PROJECT_NAME"; PROJECT_NAME="$REPLY"
  read_line "Description" "$PROJECT_DESC" "(edit or confirm)"; PROJECT_DESC="$REPLY"
  read_line "Stack" "$PROJECT_STACK" "(edit freely)"; PROJECT_STACK="$REPLY"
  read_line "Current milestone" "$PROJECT_MILESTONE"; PROJECT_MILESTONE="$REPLY"
  PROJECT_TARGET="$SCAN_PATH"
else
  read_line "Project name" "" "(e.g. stemaide-api)"
  PROJECT_NAME="$REPLY"
  [[ -z "$PROJECT_NAME" ]] && write_fail "Project name is required."

  read_line "Description" "" "(one sentence — what it does and who it's for)"
  PROJECT_DESC="$REPLY"

  read_line "Stack" "" "(e.g. PHP, MySQL, Tailwind — or Kotlin, Jetpack Compose)"
  PROJECT_STACK="$REPLY"

  read_line "First milestone" "v1.0 release" "(e.g. Auth & core API, Play Store release, v1.0 release)"
  PROJECT_MILESTONE="$REPLY"

  DEFAULT_TARGET="$(pwd)/${PROJECT_NAME}"
  read_line "Target directory" "$DEFAULT_TARGET"
  PROJECT_TARGET="$REPLY"
fi

# ─────────────────────────────────────────────────────────────────────────────
# SCREEN 4: SMART INTAKE
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "  ${C_GRAY}[4/7]${C_RESET}  $(bold "Smart intake")"
echo ""
write_info "A few targeted questions to sharpen your scaffold."
echo ""

# Q1 Audience
read_choice "Who is the primary audience?" \
  "Public users        — anyone on the internet" \
  "Internal team       — employees or developers only" \
  "B2B clients         — other companies / API consumers" \
  "Mobile app users    — primarily iOS or Android"
AUDIENCE_IDX=$CHOICE_IDX
AUDIENCE_VALUES=("public" "internal" "b2b" "mobile")
AUDIENCE_LABELS=("Public users" "Internal / team" "B2B clients" "Mobile app users")
PROJECT_AUDIENCE="${AUDIENCE_VALUES[$AUDIENCE_IDX]}"

# Q2 Auth
echo ""
if [[ "$TYPE_ID" != "android" ]]; then
  read_choice "Does this system require authentication?" \
    "Yes — users or services must authenticate" \
    "No  — fully public or pre-authenticated environment"
  [[ $CHOICE_IDX -eq 0 ]] && NEEDS_AUTH=1 || NEEDS_AUTH=0
else
  NEEDS_AUTH=1
  write_info "Auth: required (Android — defaulting to Yes)"
fi

# Q3 Sensitive data
echo ""
PRECHECKED_INDICES="3"
read_checkboxes "What sensitive data will this system handle?" \
  "PII  — names, emails, addresses, identity" \
  "Payment data  — cards, bank details, billing" \
  "Health / medical data" \
  "None — no sensitive data"

HANDLES_SENSITIVE=0
SENSITIVE_TAGS=""
checked_items=($CHECKED_INDICES)
for idx in "${checked_items[@]}"; do
  case $idx in
    0) HANDLES_SENSITIVE=1; SENSITIVE_TAGS="${SENSITIVE_TAGS} PII" ;;
    1) HANDLES_SENSITIVE=1; SENSITIVE_TAGS="${SENSITIVE_TAGS} payment" ;;
    2) HANDLES_SENSITIVE=1; SENSITIVE_TAGS="${SENSITIVE_TAGS} health" ;;
  esac
done
SENSITIVE_TAGS="${SENSITIVE_TAGS# }"
[[ $HANDLES_SENSITIVE -eq 0 ]] && SENSITIVE_TAGS="None"

# Q4 Deployment
echo ""
read_choice "Where will this be deployed?" \
  "Cloud (managed)    — AWS, GCP, Azure, Vercel, Render, etc." \
  "On-premises        — self-hosted, private datacenter" \
  "Edge / CDN         — Cloudflare Workers, Lambda@Edge, Deno Deploy" \
  "Mobile store       — Google Play / Apple App Store" \
  "Desktop install    — Windows / macOS / Linux app"
DEPLOY_IDX=$CHOICE_IDX
DEPLOY_VALUES=("cloud" "on-prem" "edge" "mobile-store" "desktop")
DEPLOY_LABELS=("Cloud (managed)" "On-premises" "Edge / CDN" "Mobile store" "Desktop install")
PROJECT_DEPLOY="${DEPLOY_VALUES[$DEPLOY_IDX]}"

# Q5 Scale
echo ""
read_choice "What is the expected scale?" \
  "Personal / side project   — <10 users, no SLA" \
  "Small team                — 10–500 users, basic availability" \
  "Growth                    — 500–50k users, 99.9% uptime target" \
  "Enterprise                — 50k+ users, SLA, compliance requirements"
SCALE_IDX=$CHOICE_IDX
SCALE_VALUES=("personal" "small-team" "growth" "enterprise")
SCALE_LABELS=("Personal" "Small team" "Growth" "Enterprise")
PROJECT_SCALE="${SCALE_VALUES[$SCALE_IDX]}"

echo ""
echo "  $(ok "✓") Intake complete"
write_info "Audience: ${AUDIENCE_LABELS[$AUDIENCE_IDX]}  ·  Auth: $([ $NEEDS_AUTH -eq 1 ] && echo Yes || echo No)  ·  Data: ${SENSITIVE_TAGS}"
write_info "Deployment: ${DEPLOY_LABELS[$DEPLOY_IDX]}  ·  Scale: ${SCALE_LABELS[$SCALE_IDX]}"

# ─────────────────────────────────────────────────────────────────────────────
# SCREEN 5: AGENTS
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "  ${C_GRAY}[5/7]${C_RESET}  $(bold "Agents")"
echo ""

AGENT_IDS=("claude-code" "gemini-cli" "codex" "opencode" "qwen-code" "antigravity")
AGENT_NAMES=("Claude Code" "Gemini CLI" "Codex" "Opencode" "Qwen Code" "Antigravity")
AGENT_FILES=("CLAUDE.md" "GEMINI.md" "AGENTS.md" "opencode.json" "QWEN.md" "ANTIGRAVITY.md")
AGENT_DOCS=(
  "https://code.claude.com/docs/en/overview"
  "https://geminicli.com/docs/"
  "https://developers.openai.com/codex/"
  "https://opencode.ai/docs"
  "https://qwenlm.github.io/qwen-code-docs/en/users/overview/"
  "https://antigravity.google/docs/get-started"
)

PRECHECKED_INDICES="0 1 2 3 4 5"
read_checkboxes "Select agents (all pre-selected)" "${AGENT_NAMES[@]}"
SELECTED_AGENT_INDICES=($CHECKED_INDICES)

SELECTED_AGENT_IDS=()
SELECTED_AGENT_NAMES=()
SELECTED_AGENT_FILES=()
SELECTED_AGENT_DOCS=()
for idx in "${SELECTED_AGENT_INDICES[@]}"; do
  SELECTED_AGENT_IDS+=("${AGENT_IDS[$idx]}")
  SELECTED_AGENT_NAMES+=("${AGENT_NAMES[$idx]}")
  SELECTED_AGENT_FILES+=("${AGENT_FILES[$idx]}")
  SELECTED_AGENT_DOCS+=("${AGENT_DOCS[$idx]}")
done

# ─────────────────────────────────────────────────────────────────────────────
# SCREEN 6: SKILLS
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "  ${C_GRAY}[6/7]${C_RESET}  $(bold "Skills")"
echo ""
write_info "Inferring skills from description, stack, and intake answers..."

# Build haystack
INTAKE_SIGNALS="$PROJECT_AUDIENCE $PROJECT_DEPLOY $PROJECT_SCALE"
[[ $NEEDS_AUTH -eq 1 ]] && INTAKE_SIGNALS="$INTAKE_SIGNALS auth login"
[[ $HANDLES_SENSITIVE -eq 1 ]] && INTAKE_SIGNALS="$INTAKE_SIGNALS sensitive data security encryption"
HAYSTACK="$PROJECT_DESC $PROJECT_STACK $TYPE_LABEL $INTAKE_SIGNALS"

infer_skills "$HAYSTACK" "$TYPE_ID"
PRIMARY_SKILL_IDS="$INFERRED_SKILL_IDS"

# Hybrid merge
if [[ -n "$SECONDARY_TYPE_ID" ]]; then
  infer_skills "$HAYSTACK" "$SECONDARY_TYPE_ID"
  SECONDARY_SKILL_IDS="$INFERRED_SKILL_IDS"
  # Merge deduplicated
  MERGED=""
  MERGED_NAMES=()
  COUNT=0
  for sid in $PRIMARY_SKILL_IDS $SECONDARY_SKILL_IDS; do
    if [[ "$MERGED" != *" $sid "* ]] && [[ $COUNT -lt $MAX_SKILLS ]]; then
      MERGED=" $sid $MERGED"
      MERGED_NAMES+=("$sid")
      ((COUNT++))
    fi
  done
  INFERRED_SKILL_IDS="${MERGED_NAMES[*]}"
fi

echo ""
echo "  Inferred ${C_BOLD}$(echo "$INFERRED_SKILL_IDS" | wc -w | tr -d ' ')${C_RESET} skills:"
for sid in $INFERRED_SKILL_IDS; do
  key="${sid//-/_}"
  echo "  $(ok "●")  ${SKILL_NAME_MAP[$key]:-$sid}  ${C_GRAY}[${SKILL_CAT_MAP[$key]:-?}]${C_RESET}"
done
echo ""
write_info "All inferred skills included. Run again with different description to change selection."

SELECTED_SKILL_IDS="$INFERRED_SKILL_IDS"

# ─────────────────────────────────────────────────────────────────────────────
# SCREEN 7: REVIEW + CONFIRM
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "  ${C_GRAY}[7/7]${C_RESET}  $(bold "Review")"
echo ""
write_rule
echo ""
echo "  $(hi "Project")       ${C_BOLD}${PROJECT_NAME}${C_RESET}"
echo "  $(hi "Type")          ${C_BOLD}${TYPE_LABEL}${C_RESET}$([ -n "$SECONDARY_TYPE_LABEL" ] && echo "  ${C_GRAY}+${C_RESET}  ${SECONDARY_TYPE_LABEL}")"
echo "  $(hi "Mode")          ${MODE}"
echo "  $(hi "Description")   ${PROJECT_DESC}"
echo "  $(hi "Stack")         ${PROJECT_STACK:-not specified}"
echo "  $(hi "Milestone")     ${PROJECT_MILESTONE}"
echo "  $(hi "Target")        ${PROJECT_TARGET}"
echo ""
write_rule
echo ""
echo "  $(hi "Intake")"
echo "  ${C_GRAY}·${C_RESET}  Audience        ${AUDIENCE_LABELS[$AUDIENCE_IDX]}"
echo "  ${C_GRAY}·${C_RESET}  Auth required   $([ $NEEDS_AUTH -eq 1 ] && ok "Yes" || dim "No")"
echo "  ${C_GRAY}·${C_RESET}  Sensitive data  $([ $HANDLES_SENSITIVE -eq 1 ] && warn "$SENSITIVE_TAGS" || dim "None")"
echo "  ${C_GRAY}·${C_RESET}  Deployment      ${DEPLOY_LABELS[$DEPLOY_IDX]}"
echo "  ${C_GRAY}·${C_RESET}  Scale           ${SCALE_LABELS[$SCALE_IDX]}"
echo ""
write_rule
echo ""
echo "  $(hi "Agents") (${#SELECTED_AGENT_IDS[@]})"
for name in "${SELECTED_AGENT_NAMES[@]}"; do
  echo "  ${C_GRAY}·${C_RESET}  $name"
done
echo ""
echo "  $(hi "Skills") ($(echo "$SELECTED_SKILL_IDS" | wc -w | tr -d ' '))"
for sid in $SELECTED_SKILL_IDS; do
  key="${sid//-/_}"
  echo "  ${C_GRAY}·${C_RESET}  ${SKILL_NAME_MAP[$key]:-$sid}  ${C_GRAY}[${SKILL_CAT_MAP[$key]:-?}]${C_RESET}"
done
echo ""
write_rule
echo ""

read_confirm "Initialise git repository?" "y"; INIT_GIT=$CONFIRM
read_confirm "Generate project?" "y"
if [[ $CONFIRM -ne 0 ]]; then
  echo ""
  write_info "Aborted. Nothing written."
  echo ""
  exit 0
fi

# Guard existing dir
if [[ "$MODE" == "greenfield" ]] && [[ -d "$PROJECT_TARGET" ]]; then
  echo ""
  write_warn "Directory already exists: ${PROJECT_TARGET}"
  read_confirm "Merge into existing directory?" "n"
  if [[ $CONFIRM -ne 0 ]]; then
    write_info "Aborted."
    exit 0
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# GENERATE
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "  ${C_BOLD}Generating…${C_RESET}"
echo ""

ROOT="$PROJECT_TARGET"

# Create directories
if [[ $DRY_RUN -eq 0 ]]; then
  mkdir -p "${ROOT}/agents" "${ROOT}/skills" "${ROOT}/memory/decisions" "${ROOT}/src" "${ROOT}/scratchpads"
  for aid in "${SELECTED_AGENT_IDS[@]}"; do
    mkdir -p "${ROOT}/scratchpads/${aid}"
  done
  if [[ "$TYPE_ID" == "android" ]]; then
    mkdir -p "${ROOT}/gradle/wrapper"
  fi
  for sid in $SELECTED_SKILL_IDS; do
    mkdir -p "${ROOT}/skills/${sid}/scripts" "${ROOT}/skills/${sid}/assets" \
             "${ROOT}/skills/${sid}/references" "${ROOT}/skills/${sid}/outputs"
  done
fi
write_done "Directory structure"

# ─────────────────────────────────────────────────────────────────────────────
# BUILDERS — each function writes to CONTENT variable
# ─────────────────────────────────────────────────────────────────────────────
TODAY="$(get_date)"
REVIEW_DATE="$(date -d "+3 months" "+%Y-%m-%d" 2>/dev/null || date -v+3m "+%Y-%m-%d" 2>/dev/null || echo "$(get_date)")"
AUTH_LABEL="$([ $NEEDS_AUTH -eq 1 ] && echo "Required" || echo "Not required")"
DATA_LABEL="$([ $HANDLES_SENSITIVE -eq 1 ] && echo "Yes — ${SENSITIVE_TAGS}" || echo "None")"

# AUDIENCE display map
case "$PROJECT_AUDIENCE" in
  public)   AUD_DISPLAY="Public users" ;;
  internal) AUD_DISPLAY="Internal / team" ;;
  b2b)      AUD_DISPLAY="B2B clients" ;;
  mobile)   AUD_DISPLAY="Mobile app users" ;;
  *)        AUD_DISPLAY="Not specified" ;;
esac

case "$PROJECT_DEPLOY" in
  cloud)        DEP_DISPLAY="Cloud (managed)" ;;
  "on-prem")    DEP_DISPLAY="On-premises" ;;
  edge)         DEP_DISPLAY="Edge / CDN" ;;
  "mobile-store") DEP_DISPLAY="Mobile store" ;;
  desktop)      DEP_DISPLAY="Desktop install" ;;
  *)            DEP_DISPLAY="Not specified" ;;
esac

case "$PROJECT_SCALE" in
  personal)    SCALE_DISPLAY="Personal / side project" ;;
  "small-team") SCALE_DISPLAY="Small team (<500 users)" ;;
  growth)      SCALE_DISPLAY="Growth (500–50k users)" ;;
  enterprise)  SCALE_DISPLAY="Enterprise (50k+ users)" ;;
  *)           SCALE_DISPLAY="Not specified" ;;
esac

# Build agent lines for docs
AGENT_LIST_MD=""
AGENT_DOCS_MD=""
for i in "${!SELECTED_AGENT_NAMES[@]}"; do
  AGENT_LIST_MD="${AGENT_LIST_MD}- ${SELECTED_AGENT_NAMES[$i]} (${SELECTED_AGENT_FILES[$i]})\n"
  AGENT_DOCS_MD="${AGENT_DOCS_MD}- [${SELECTED_AGENT_NAMES[$i]}](${SELECTED_AGENT_DOCS[$i]})\n"
done

# Build skill lines
SKILL_LIST_MD=""
for sid in $SELECTED_SKILL_IDS; do
  key="${sid//-/_}"
  sname="${SKILL_NAME_MAP[$key]:-$sid}"
  scat="${SKILL_CAT_MAP[$key]:-?}"
  SKILL_LIST_MD="${SKILL_LIST_MD}- [${sname}](skills/${sid}/SKILL.md) · ${scat} · UNIMPLEMENTED\n"
done

HYBRID_LINE=""
[[ -n "$SECONDARY_TYPE_LABEL" ]] && HYBRID_LINE="\n**Hybrid secondary:** ${SECONDARY_TYPE_LABEL}"

# ── CONTEXT.md ───────────────────────────────────────────────────────────────
STATUS_LINE="Active — greenfield"
[[ "$MODE" == "brownfield" ]] && STATUS_LINE="Active — brownfield overlay applied"

emit_file "CONTEXT.md" "# CONTEXT.md — Project Source of Truth

## Project
**Name:** ${PROJECT_NAME}
**Type:** ${TYPE_LABEL}${HYBRID_LINE}
**Status:** ${STATUS_LINE}
**Bootstrapped:** ${TODAY}

## Purpose
${PROJECT_DESC}

## Project profile
| Dimension | Value |
|---|---|
| Audience | ${AUD_DISPLAY} |
| Authentication | ${AUTH_LABEL} |
| Sensitive data | ${DATA_LABEL} |
| Deployment target | ${DEP_DISPLAY} |
| Scale profile | ${SCALE_DISPLAY} |

## Tech Stack
$(echo "$PROJECT_STACK" | tr ',' '\n' | sed 's/^ */- /' | grep -v '^- $' || echo "- To be defined")

## Operational context
- **DISCOVERY.md** — exploration log; variant approaches, experiments, hypotheses
- **WORKSTREAMS.md** — parallel agent coordination; scope boundaries, phases, merge checkpoints
- **DOMAIN.md** — business domain context; rules, concepts, vocabulary, what good looks like
- **SECURITY.md** — threat model and security requirements
- **QUALITY.md** — production quality gates; agents must verify before marking work complete
- **ENVIRONMENTS.md** — environment strategy (dev / staging / production)
- **OBSERVABILITY.md** — logging, metrics, alerting specification

## Active Agents
$(printf '%b' "$AGENT_LIST_MD")
## Agent Documentation
$(printf '%b' "$AGENT_DOCS_MD")
## Required Skills
$(printf '%b' "$SKILL_LIST_MD")
## Current Milestone
${PROJECT_MILESTONE}

## Process rules
- memory/decisions/ is append-only — never edit existing entries
- Agent configs are pointers, not primary context — update CONTEXT.md first
- All architectural decisions logged in memory/decisions/ before implementation
- SESSION.md filled at every session end — including on context limit hits
- ESCALATE status in SESSION.md means: human must review before next session proceeds

---
*Canonical context. All agent files and decisions derive from this. Update here first.*
" "$ROOT"

# ── TASKS.md ─────────────────────────────────────────────────────────────────
INTAKE_TASKS=""
[[ $NEEDS_AUTH -eq 1 ]] && INTAKE_TASKS="${INTAKE_TASKS}\n- [ ] Design and document auth flow before any implementation (login, logout, token lifecycle)"
[[ $HANDLES_SENSITIVE -eq 1 ]] && INTAKE_TASKS="${INTAKE_TASKS}\n- [ ] Complete sensitive data inventory (${SENSITIVE_TAGS}) — map all fields before coding\n- [ ] Define data retention and deletion policy — log decision to memory/decisions/"
[[ "$PROJECT_SCALE" == "growth" || "$PROJECT_SCALE" == "enterprise" ]] && INTAKE_TASKS="${INTAKE_TASKS}\n- [ ] Define SLO targets (uptime, latency p95) and configure alerting before launch\n- [ ] Load test at 2x expected peak before promotion to production"
[[ "$PROJECT_SCALE" == "enterprise" ]] && INTAKE_TASKS="${INTAKE_TASKS}\n- [ ] Compliance requirements identified and documented in memory/decisions/\n- [ ] Penetration test scheduled before first external release"
[[ "$PROJECT_DEPLOY" == "mobile-store" ]] && INTAKE_TASKS="${INTAKE_TASKS}\n- [ ] App store listing and review requirements documented before feature freeze"
[[ "$PROJECT_DEPLOY" == "on-prem" ]] && INTAKE_TASKS="${INTAKE_TASKS}\n- [ ] Deployment runbook written before handoff — install, upgrade, rollback"
[[ "$PROJECT_AUDIENCE" == "public" ]] && INTAKE_TASKS="${INTAKE_TASKS}\n- [ ] Abuse prevention strategy defined (rate limiting, CAPTCHA, anomaly detection)"
[[ -n "$SECONDARY_TYPE_LABEL" ]] && INTAKE_TASKS="${INTAKE_TASKS}\n- [ ] Hybrid integration points identified — boundary between ${TYPE_LABEL} and ${SECONDARY_TYPE_LABEL}"

BROWNFIELD_NOTE=""
[[ "$MODE" == "brownfield" ]] && BROWNFIELD_NOTE="\n- [ ] Verify inferred CONTEXT.md is accurate — confirm description, stack, architecture\n- [ ] Audit existing src/ against generated skill specs\n- [ ] Identify gaps between current state and production quality gates (QUALITY.md)"

SKILL_BACKLOG=""
if [[ -n "$SELECTED_SKILL_IDS" ]]; then
  SKILL_BACKLOG="- [ ] Review skill specs in skills/ — define interfaces before any implementation
- [ ] Implement skills in priority order per skills/README.md
- [ ] Verify each skill against its acceptance criteria before marking done"
fi

emit_file "TASKS.md" "# TASKS.md — Active Work

## Milestone: ${PROJECT_MILESTONE}

### In Progress
- [ ] Review all generated context files — correct anything that doesn't match the project
- [ ] Verify SECURITY.md threat model is complete for this project
- [ ] Set up dev environment per ENVIRONMENTS.md${BROWNFIELD_NOTE}

### Backlog — Foundation
- [ ] Confirm architecture decisions in CONTEXT.md; log any changes to memory/decisions/
- [ ] Define data models and API contracts before implementation
- [ ] Set up CI pipeline with lint, test, and security audit gates
- [ ] Configure observability stack per OBSERVABILITY.md$(printf '%b' "$INTAKE_TASKS")

### Backlog — Skills
${SKILL_BACKLOG}

### Backlog — Launch readiness
- [ ] All QUALITY.md gates passing
- [ ] Load test performed and baseline documented
- [ ] Runbook written: deploy, rollback, incident response
- [ ] Staging validated before production promotion

### Done
- [x] Project bootstrapped (${TODAY})

---
*Update after every agent session. A task is not done until QUALITY.md gates pass.*
*ESCALATE items in SESSION.md take priority over all backlog work.*
" "$ROOT"

# ── DISCOVERY.md ─────────────────────────────────────────────────────────────
emit_file "DISCOVERY.md" "# DISCOVERY.md — Exploration & Experiments Log

**Project:** ${PROJECT_NAME}
**Type:** ${TYPE_LABEL}
**Created:** ${TODAY}

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

## Exploration log

### ${TODAY} — Project initialisation

**Question:** What is the right scaffold structure for ${PROJECT_NAME}?
**Approach:** Msingi v${VERSION} — ${TYPE_LABEL} scaffold with context engineering.
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
" "$ROOT"

# ── WORKSTREAMS.md ────────────────────────────────────────────────────────────
WS_DEFS=""
WS_NUM=1
declare -A WS_SCOPE_HINTS=(
  [claude-code]="auth, API layer, business logic"
  [gemini-cli]="data layer, migrations, schema"
  [codex]="tests, CI config, tooling scripts"
  [opencode]="frontend, UI components, styles"
  [qwen-code]="infrastructure, deployment config"
  [antigravity]="documentation, code review, refactoring"
)

for i in "${!SELECTED_AGENT_IDS[@]}"; do
  aid="${SELECTED_AGENT_IDS[$i]}"
  aname="${SELECTED_AGENT_NAMES[$i]}"
  afile="${SELECTED_AGENT_FILES[$i]}"
  scope="${WS_SCOPE_HINTS[$aid]:-define scope before starting}"
  WS_DEFS="${WS_DEFS}
### WS-${WS_NUM} — ${aname}
**Agent:** ${aname} (\`${afile}\`)
**Status:** IDLE
**Scope:** ${scope}
**Owns:** *(define: which src/ subdirectories or files this workstream exclusively writes)*
**Depends on:** *(list any WS- numbers that must complete a phase before this starts)*

**Current task:**
*(describe the specific task currently in progress, or leave blank if IDLE)*

**Merge checkpoint:**
- [ ] Tests pass for owned scope
- [ ] No writes outside owned scope
- [ ] QUALITY.md gates relevant to this scope verified
- [ ] SESSION.md complete with current state

**Last active:** —

---
"
  ((WS_NUM++)) || true
done

emit_file "WORKSTREAMS.md" "# WORKSTREAMS.md — Parallel Agent Coordination

**Project:** ${PROJECT_NAME}
**Type:** ${TYPE_LABEL}
**Created:** ${TODAY}

> The skill is now how to manage a small org of agents.
> Carve the codebase into parallel non-conflicting workstreams.
> Each workstream owns a defined scope. Agents do not write outside their scope.
> Human reviews at merge checkpoints — not after every commit.

---

## Coordination rules

1. **Scope is exclusive write, unrestricted read.**
2. **Declare conflicts before starting** — resolve ownership before parallel work begins.
3. **Phase gates before parallel work** — some work must be sequential.
4. **Merge checkpoints are mandatory** — human reviews at merge, not agents.
5. **SESSION.md is per-agent, WORKSTREAMS.md is shared.**

---

## Phases

| Phase | Workstreams | Gate to advance |
|-------|-------------|-----------------|
| 1 — Foundation | *(define)* | Schema confirmed, contracts signed off |
| 2 — Core build  | *(define)* | Phase 1 merged and green |
| 3 — Integration | *(all)* | All scopes merged, integration tests pass |

---

## Workstreams
${WS_DEFS}
---

## Conflict log

| Date | File | WS-A | WS-B | Resolution |
|------|------|------|------|------------|
| | | | | |

## Merge history

| Date | Workstream | What merged | Reviewer |
|------|------------|-------------|----------|
| ${TODAY} | — | Initial scaffold | Msingi v${VERSION} |

---
*Update this file at every merge checkpoint and whenever scope changes.*
" "$ROOT"

# ── DOMAIN.md ─────────────────────────────────────────────────────────────────
case "$TYPE_ID" in
  web-app)    DOMAIN_PROMPT="What are the core user journeys? What does a user do from landing to value? What is the most common failure path? What does 'success' look like from the user's perspective?" ;;
  api-service) DOMAIN_PROMPT="Who are the API consumers and what do they expect? What is the contract — the guarantees this API makes? What are the latency and reliability requirements per endpoint? What happens when a consumer misuses the API?" ;;
  ml-ai)      DOMAIN_PROMPT="What is the ground truth for this problem — how is correctness defined? What does the training data distribution look like? Where is the model most likely to fail silently? What is the cost of a false positive vs false negative?" ;;
  cli-tool)   DOMAIN_PROMPT="Who runs this tool and in what context? What is the most common invocation? What does the user do when the tool fails or produces unexpected output?" ;;
  fullstack)  DOMAIN_PROMPT="What is the primary user action this system enables? Where is the boundary between frontend and backend concerns? What data flows from user action to persistent state?" ;;
  android)    DOMAIN_PROMPT="What does the user do in the first 30 seconds? What happens when the app is backgrounded mid-task? What are the device constraints (minimum SDK, offline support, battery budget)?" ;;
  *)          DOMAIN_PROMPT="What is the core problem this system solves? Who is the primary user and what do they need?" ;;
esac

emit_file "DOMAIN.md" "# DOMAIN.md — Business Domain Context

**Project:** ${PROJECT_NAME}
**Type:** ${TYPE_LABEL}
**Created:** ${TODAY}

> This file teaches agents the *domain* — not the tech stack, not the task list.
> Execution docs (CONTEXT.md, TASKS.md, SKILL.md) tell agents what to build.
> This file tells agents *why it matters*, *who it's for*, and *what good looks like*.

---

## Project in plain language

${PROJECT_DESC}

**What this system does for its users:**
*(One paragraph. Write it the way you'd explain it to a smart person outside tech.)*

---

## Core domain concepts

| Concept | What it means in this domain | Notes |
|---------|------------------------------|-------|
| *(add)* | *(domain-specific definition)* | |

---

## Business rules

*(Non-negotiable constraints from the domain — not technical decisions.)*

- *(add as discovered)*

---

## What good looks like

A successful session in this system means:

-

---

## Questions that reveal domain depth

${DOMAIN_PROMPT}

---

## Domain-specific gotchas

- *(add as discovered)*

---

## Glossary

| Term | Definition |
|------|------------|
| *(add)* | |

---
*Created: ${TODAY} — Msingi v${VERSION}*
*Grow this file over time. A 500-word DOMAIN.md after 10 sessions is worth more than a perfect one written at bootstrap.*
" "$ROOT"

# ── CHANGELOG.md ─────────────────────────────────────────────────────────────
ACTION="Project initialised"
[[ "$MODE" == "brownfield" ]] && ACTION="Brownfield overlay applied"
emit_file "CHANGELOG.md" "# CHANGELOG.md — Context Evolution Log

Records when and why canonical context changed.
This is not a code changelog — it tracks context drift and correction.

---

## ${TODAY} — Bootstrap

- ${ACTION}: ${PROJECT_NAME}
- Project type: ${TYPE_LABEL}
- Milestone set: ${PROJECT_MILESTONE}
- All context files generated by Msingi v${VERSION}

---

<!-- Template:

## YYYY-MM-DD — [reason for update]

- Changed: [what changed in CONTEXT.md or project structure]
- Why: [what happened that made the old context wrong or incomplete]
- Agent that surfaced it: [which agent or session revealed the drift]
- Impact: [which decisions or implementations are affected]

-->
" "$ROOT"

# ── STRUCTURE.md ─────────────────────────────────────────────────────────────
emit_file "STRUCTURE.md" "# STRUCTURE.md — Directory Map and Agent Scope

---

## Directory Layout

\`\`\`
${PROJECT_NAME}/
├── CONTEXT.md              ← canonical truth (human maintains)
├── TASKS.md                ← active work and milestone
├── DISCOVERY.md            ← exploration log
├── WORKSTREAMS.md          ← parallel agent coordination
├── DOMAIN.md               ← business domain context
├── CHANGELOG.md            ← context evolution log
├── STRUCTURE.md            ← this file
├── QUALITY.md              ← production quality gates
├── SECURITY.md             ← threat model
├── ENVIRONMENTS.md         ← environment strategy
├── OBSERVABILITY.md        ← logging, metrics, alerting
├── README.md
├── agents/                 ← agent pointer files
├── skills/                 ← skill specs (folders, not flat files)
│   └── <skill-id>/
│       ├── SKILL.md
│       ├── gotchas.md
│       ├── scripts/
│       ├── assets/
│       ├── references/
│       └── outputs/
├── memory/
│   ├── decisions/          ← ADRs — append only
│   └── bootstrap-record.json
├── scratchpads/
│   └── <agent-id>/
│       ├── SESSION.md
│       └── NOTES.md
└── src/
\`\`\`

---

## Protocol rules

**Retrieval:** src/ is on-demand only. Never load directories wholesale.
**Quality:** No feature is complete until QUALITY.md gates pass.
**Compaction:** SESSION.md filled at every session end, including on context limit hits.
**Escalation:** Status: ESCALATE in SESSION.md means the next session must resolve it first.
**Decisions:** memory/decisions/ is append-only. Never edit or delete existing ADRs.

---

*Last reviewed: ${TODAY}*
" "$ROOT"

# ── README.md ─────────────────────────────────────────────────────────────────
AGENT_README_LIST=""
for name in "${SELECTED_AGENT_NAMES[@]}"; do
  AGENT_README_LIST="${AGENT_README_LIST}- ${name}\n"
done

emit_file "README.md" "# ${PROJECT_NAME}

${PROJECT_DESC}

## Type
${TYPE_LABEL}$([ -n "$SECONDARY_TYPE_LABEL" ] && echo " + ${SECONDARY_TYPE_LABEL}")

## Stack
$(echo "$PROJECT_STACK" | tr ',' '\n' | sed 's/^ */- /' | grep -v '^- $' || echo "- To be defined")

## Active agents
$(printf '%b' "$AGENT_README_LIST")
## Start here

1. Read \`CONTEXT.md\` — confirm architecture and NFRs are correct
2. Read \`SECURITY.md\` — confirm threat model covers your project
3. Read \`QUALITY.md\` — know the gates before writing any code
4. Open \`TASKS.md\` — your first session starts at the top

---
*Bootstrapped by [Msingi](https://github.com/stemaide/msingi) v${VERSION} on ${TODAY}*
*Built in Accra. Designed for everywhere.*
" "$ROOT"

# ── SECURITY.md ───────────────────────────────────────────────────────────────
AUTH_THREATS=""
if [[ $NEEDS_AUTH -eq 1 ]]; then
  AUTH_THREATS="
## Authentication requirements (from project intake)
This project requires authentication. The following controls are mandatory:
- Implement credential stuffing protection (rate limiting + lockout on repeated failures)
- Enforce MFA for admin or privileged roles
- Session tokens must be rotated on privilege escalation
- Password reset flows must use time-limited, single-use tokens
- OAuth/OIDC flows: validate \`state\` parameter to prevent CSRF; verify \`aud\` claim on JWTs
"
fi

DATA_THREATS=""
if [[ $HANDLES_SENSITIVE -eq 1 ]]; then
  DATA_THREATS="
## Sensitive data requirements (from project intake)
This project handles: **${SENSITIVE_TAGS}**

Mandatory controls:
- Encrypt all sensitive fields at rest (AES-256 minimum) and in transit (TLS 1.2+)
- Implement field-level access control
- Audit log all access to sensitive records: who, when, what operation
- Data retention policy must be defined before launch — log to memory/decisions/
- Never include sensitive values in logs, error messages, or analytics events
"
fi

SCALE_THREATS=""
if [[ "$PROJECT_SCALE" == "growth" || "$PROJECT_SCALE" == "enterprise" ]]; then
  SCALE_THREATS="
## Scale-specific security requirements (from project intake)
- DDoS mitigation must be in place before public launch
- Security incident response runbook must be written before go-live
- Penetration test required before first external-facing release
- Dependency vulnerability scanning must run in CI on every merge
"
fi

SECURITY_CHECKLIST=""
[[ $HANDLES_SENSITIVE -eq 1 ]] && SECURITY_CHECKLIST="${SECURITY_CHECKLIST}\n- [ ] Sensitive data inventory complete and reviewed\n- [ ] Encryption at rest verified for all sensitive fields"
[[ $NEEDS_AUTH -eq 1 ]] && SECURITY_CHECKLIST="${SECURITY_CHECKLIST}\n- [ ] Auth flows tested: login, logout, token expiry, session rotation, MFA (if applicable)"
[[ "$PROJECT_SCALE" == "growth" || "$PROJECT_SCALE" == "enterprise" ]] && SECURITY_CHECKLIST="${SECURITY_CHECKLIST}\n- [ ] Penetration test scheduled or completed\n- [ ] Incident response runbook written and reviewed"

emit_file "SECURITY.md" "# SECURITY.md — Threat Model and Security Requirements

**Project:** ${PROJECT_NAME}
**Type:** ${TYPE_LABEL}
**Review date:** ${TODAY}
**Next review:** ${REVIEW_DATE}

> Every agent reads this before working on authentication, data handling, or configuration.
> Security decisions are logged in memory/decisions/ with Severity: CRITICAL.

---
${AUTH_THREATS}${DATA_THREATS}${SCALE_THREATS}
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

---

## Review checklist (complete before any release)
- [ ] All items in the threat model above have been addressed or explicitly accepted
- [ ] Dependency audit run — no HIGH or CRITICAL CVEs unaddressed
- [ ] Secrets scan run — no credentials in source or history
- [ ] Authentication and authorisation tested explicitly for each protected resource
- [ ] Error messages reviewed — no stack traces or internal paths exposed to users
$(printf '%b' "$SECURITY_CHECKLIST")
" "$ROOT"

# ── QUALITY.md ────────────────────────────────────────────────────────────────
emit_file "QUALITY.md" "# QUALITY.md — Production Quality Gates

**Project:** ${PROJECT_NAME}
**Type:** ${TYPE_LABEL}

> These gates are non-negotiable. A feature is not complete until all applicable gates pass.
> Agents self-verify — not humans covering for agents.

---

## Definition of done (per feature)

- [ ] Acceptance criteria from the relevant SKILL.md are met
- [ ] Unit tests written and passing
- [ ] Integration tests written and passing (where applicable)
- [ ] No new lint errors or warnings
- [ ] No hardcoded secrets or credentials
- [ ] Error paths handled and tested
- [ ] Inputs validated at the boundary
- [ ] Performance: no regression vs baseline (measure if in doubt)
- [ ] SECURITY.md applicable checks passed

## Definition of done (per milestone)

- [ ] All feature-level gates passing
- [ ] Load test performed — baseline documented
- [ ] Dependency audit clean — no HIGH/CRITICAL CVEs
- [ ] Staging environment validated
- [ ] Rollback procedure tested
- [ ] Monitoring and alerting configured per OBSERVABILITY.md

---

*Non-compliance with these gates is not a shortcut — it is deferred cost.*
*If a gate cannot be met, log the reason in memory/decisions/ and escalate.*
" "$ROOT"

# ── ENVIRONMENTS.md ───────────────────────────────────────────────────────────
emit_file "ENVIRONMENTS.md" "# ENVIRONMENTS.md — Environment Strategy

**Project:** ${PROJECT_NAME}
**Deployment target:** ${DEP_DISPLAY}

---

## Environments

### Development (local)
**Purpose:** Individual developer / agent work. Fast iteration. Debugging enabled.
**Data:** Local or shared dev database. Never real user data.
**Config source:** \`.env.local\` (gitignored). See \`.env.example\` for required keys.

### Staging
**Purpose:** Pre-production validation. Mirrors production configuration.
**Data:** Anonymised copy of production data OR synthetic data. Never real PII.
**Promotion gate:** All QUALITY.md gates pass. Security scan clean.

### Production
**Purpose:** Live system serving real users.
**Config source:** Secrets manager only. No .env files on production servers.
**Promotion gate:** Staging validated. Rollback plan confirmed.

---

## Configuration rules

1. Never commit secrets. Use \`.env.example\` with placeholder values.
2. Staging config must mirror production — differences are risks.
3. All secrets must be rotatable without downtime.

---

## Required environment variables

| Variable | Purpose | Dev | Staging | Production |
|----------|---------|-----|---------|------------|
| \`APP_ENV\` | Environment name | local | staging | production |
| \`DB_URL\` | Database connection string | ✓ | ✓ | ✓ |
| \`SECRET_KEY\` | Application secret / JWT signing | ✓ | ✓ | ✓ |
| *(add as project grows)* | | | | |
" "$ROOT"

# ── OBSERVABILITY.md ─────────────────────────────────────────────────────────
emit_file "OBSERVABILITY.md" "# OBSERVABILITY.md — Logging, Metrics, and Alerting

**Project:** ${PROJECT_NAME}

> Defines what the system must emit and what must be monitored.
> Observability is not optional — it is a production requirement.

---

## Structured logging

Every request must emit a structured log event containing:
\`timestamp\`, \`level\`, \`request_id\`, \`method\`, \`path\`, \`status_code\`,
\`duration_ms\`, \`user_id\` (if authenticated), \`error\` (if applicable).

Never log: passwords, tokens, full PII. Log: anonymised IDs, event types, durations.

## Metrics (expose or emit)
- Request rate (rpm) per endpoint
- Error rate (%) per endpoint — alert if > 1% sustained for 5 min
- p50 / p95 / p99 response time
- Active users / DAU (business metric)

## Tooling decisions (fill in before first production deploy)

| Concern | Tool chosen | ADR reference |
|---------|-------------|---------------|
| Log aggregation | *(define)* | |
| Metrics / APM | *(define)* | |
| Error tracking | *(define)* | |
| Alerting | *(define)* | |

---
*Log tooling decisions in memory/decisions/ with Severity: HIGH.*
" "$ROOT"

# ── .gitignore ────────────────────────────────────────────────────────────────
GITIGNORE_EXTRAS=""
[[ "$PROJECT_STACK" =~ [Pp]ython ]] && GITIGNORE_EXTRAS="${GITIGNORE_EXTRAS}
# Python
__pycache__/
*.py[cod]
.venv/
venv/
dist/
build/
*.egg-info/
.pytest_cache/"

[[ "$PROJECT_STACK" =~ [Nn]ode|[Rr]eact|[Nn]ext|[Vv]ue|[Ss]velte|[Tt]ype[Ss]cript ]] && GITIGNORE_EXTRAS="${GITIGNORE_EXTRAS}
# Node
node_modules/
.next/
dist/
.nuxt/
.output/
.cache/"

[[ "$PROJECT_STACK" =~ [Pp][Hh][Pp]|[Ll]aravel ]] && GITIGNORE_EXTRAS="${GITIGNORE_EXTRAS}
# PHP
vendor/
storage/logs/
*.log"

[[ "$TYPE_ID" == "android" || "$PROJECT_STACK" =~ [Aa]ndroid|[Kk]otlin ]] && GITIGNORE_EXTRAS="${GITIGNORE_EXTRAS}
# Android
*.iml
.gradle/
local.properties
build/
captures/
*.apk
*.aab
*.jks
*.keystore"

emit_file ".gitignore" "# ${PROJECT_NAME} — .gitignore

# Context engineering — scratchpads are ephemeral working files
scratchpads/

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
${GITIGNORE_EXTRAS}
" "$ROOT"

# ── Agent configs ─────────────────────────────────────────────────────────────
for i in "${!SELECTED_AGENT_IDS[@]}"; do
  aid="${SELECTED_AGENT_IDS[$i]}"
  aname="${SELECTED_AGENT_NAMES[$i]}"
  afile="${SELECTED_AGENT_FILES[$i]}"
  adocs="${SELECTED_AGENT_DOCS[$i]}"
  heading="${afile%.md}"
  heading="${heading^^}"

  if [[ "$afile" == "opencode.json" ]]; then
    emit_file "agents/${afile}" "{
  \"project\": \"${PROJECT_NAME}\",
  \"description\": \"${PROJECT_DESC}\",
  \"milestone\": \"${PROJECT_MILESTONE}\",
  \"context_files\": [\"CONTEXT.md\", \"TASKS.md\"],
  \"session_file\": \"scratchpads/${aid}/SESSION.md\",
  \"notes_file\": \"scratchpads/${aid}/NOTES.md\",
  \"scratchpad\": \"scratchpads/${aid}/\",
  \"memory\": \"memory/decisions/\",
  \"docs\": \"${adocs}\",
  \"retrieval_rules\": [
    \"At session start: read SESSION.md, TASKS.md, NOTES.md, WORKSTREAMS.md, then CONTEXT.md selectively\",
    \"Read SECURITY.md and ENVIRONMENTS.md before any feature touching auth, data, or config\",
    \"Read src/ files only when directly required — never load entire directories\",
    \"Pull memory/decisions/ only when relevant to a current decision\"
  ],
  \"compaction_protocol\": [
    \"When approaching context limits: write compaction summary to SESSION.md\",
    \"Record decisions made, files modified, current file states, exact next action\",
    \"Promote architectural decisions to memory/decisions/ before stopping\",
    \"If a production blocker is unresolved: set Status: ESCALATE in SESSION.md\"
  ],
  \"rules\": [
    \"Every feature must pass QUALITY.md gates before being marked complete\",
    \"Security decisions must be recorded in memory/decisions/ with CRITICAL severity\",
    \"Write observations to NOTES.md; never write unverified assumptions as facts\",
    \"Do not modify memory/decisions/ — append only\",
    \"Flag out-of-scope or high-risk actions in SESSION.md for human review\"
  ]
}" "$ROOT"
  else
    emit_file "agents/${afile}" "# ${heading}
> Pointer file — canonical context lives in CONTEXT.md

## Role
Production engineer on **${PROJECT_NAME}** — ${TYPE_LABEL}.
${PROJECT_DESC}

## Stack
${PROJECT_STACK:-See CONTEXT.md}

## Current Milestone
${PROJECT_MILESTONE}

## Session start — read in this order (recency first)

1. \`scratchpads/${aid}/SESSION.md\` — where did I leave off? Resolve any ESCALATE first
2. \`TASKS.md\` — what is the current work?
3. \`WORKSTREAMS.md\` — which workstream am I in? What is my scope?
4. \`scratchpads/${aid}/NOTES.md\` — what do I persistently know?
5. \`CONTEXT.md\` — architecture and NFRs (skim if unchanged)
6. \`DOMAIN.md\` — consult before any feature touching business rules
7. \`QUALITY.md\` — read fully before writing any implementation code
8. \`SECURITY.md\` — read before any auth, data handling, or config work
9. \`ENVIRONMENTS.md\` — read before touching config, secrets, or deployment
10. \`DISCOVERY.md\` — check before starting any significant new feature

## Context budget rules
**Always include:** SESSION.md, the specific SKILL.md for the current task, its gotchas.md (high-confidence entries first)
**Selectively fetch:** CONTEXT.md sections relevant to today's task, src/ files being modified
**Never load wholesale:** entire src/ directory, all skill specs at once, all memory/decisions/ entries

## How to use skills
Each skill is a folder in \`skills/<id>/\`:
- \`SKILL.md\` — the contract. Opens with **When to use** trigger.
- \`gotchas.md\` — confidence-weighted failure patterns. Read ●●●●● and ●●●●○ entries first.
- \`scripts/\` — helper scripts to run or compose
- \`outputs/\` — structured results from prior executions

After completing a skill: write a compact record to \`outputs/\`, update \`last_seen\` on triggered gotchas.

## Production rules
- Every feature must pass all gates in \`QUALITY.md\` before being marked complete
- Security decisions logged in \`memory/decisions/\` as CRITICAL
- No speculative implementation: if the spec is ambiguous, flag in SESSION.md
- When you hit a failure: update \`gotchas.md\` before continuing

## On-demand hooks
\`/careful\` — blocks destructive operations. Invoke before any production-touching session.
\`/freeze\` — blocks file writes outside a specified directory. Invoke when debugging.

## Compaction protocol
1. Write compaction summary to \`scratchpads/${aid}/SESSION.md\`
2. Record: decisions made, files modified, exact state of each touched file, next action
3. Promote architectural decisions to \`memory/decisions/\` before stopping
4. If a production blocker is unresolved: set **Status: ESCALATE**

## Scope
- Read:  \`CONTEXT.md\`, \`TASKS.md\`, \`WORKSTREAMS.md\`, \`DOMAIN.md\`, \`QUALITY.md\`, \`SECURITY.md\`, \`ENVIRONMENTS.md\`, \`OBSERVABILITY.md\`, \`DISCOVERY.md\`, \`src/\` (on demand), \`skills/*/SKILL.md\`, \`skills/*/gotchas.md\`
- Write: \`src/\`, \`scratchpads/${aid}/\`, \`skills/*/gotchas.md\` (append only), \`skills/*/assets/\`, \`skills/*/outputs/\`, \`DISCOVERY.md\` (append only), \`WORKSTREAMS.md\` (status only), \`DOMAIN.md\` (append only)
- Avoid: \`agents/\`, \`memory/decisions/\` (append only — never edit existing entries)

## Reference
${adocs}
" "$ROOT"
  fi
done

# ── Scratchpads ───────────────────────────────────────────────────────────────
for i in "${!SELECTED_AGENT_IDS[@]}"; do
  aid="${SELECTED_AGENT_IDS[$i]}"
  aname="${SELECTED_AGENT_NAMES[$i]}"

  emit_file "scratchpads/${aid}/SESSION.md" "# SESSION.md — ${aname} Handoff

> Fill this at the end of every session without exception.
> The next session reads this first — before any other file.
> Keep each section tight. This file is read every session — every token counts.

---

## Session metadata
**Date:**
**Agent:** ${aname}
**Status:** [ ] Complete  [ ] Partial  [ ] **ESCALATE**

---

## Context cost log

**Files loaded at session start:**
**Avoidable re-reads:**
**Estimated context cost:** [ ] Low (<5k)  [ ] Medium (5–15k)  [ ] High (>15k)

**Token efficiency note:**

**Token leverage note:**
<!-- What did this session discover beyond the task? High leverage = understanding, not just execution. -->

---

## Escalation (fill if Status = ESCALATE)
**Blocker:**
**Why this requires human review:**
**Proposed options (if any):**

---

## What was accomplished

-

## What was attempted but did not work

-

## Current state of src/

-

## Decisions made this session

-

## Quality gates checked

-

## Open blockers (non-escalation)

-

## Next action

---

## Context drift check
[ ] No drift — CONTEXT.md is still accurate
[ ] CONTEXT.md needs update — reason:
[ ] CHANGELOG.md entry added
[ ] memory/decisions/ updated if any architectural decision was made
" "$ROOT"

  emit_file "scratchpads/${aid}/NOTES.md" "# NOTES.md — ${aname} Working Memory

> This file is loaded at every session start. Every line costs tokens.
> Verified facts only — confirm against src/ or CONTEXT.md before recording.

## Tiered memory protocol
**Active tier (this file):** observations from the last ~10 sessions or ~2 weeks.
**Archive tier (NOTES-archive.md):** older observations compressed to compact fact blocks.

When this file exceeds 300 lines: compress the oldest half into NOTES-archive.md, keep recent half here.

---

## API and integration quirks

## Conventions in this codebase

## Performance observations

## Security notes

## Things that failed and why

## Human preferences

## Open questions requiring human input

---
*Created: ${TODAY} — ${aname}*
*Target: under 300 lines. Archive when over.*
" "$ROOT"
done

# ── Skills ────────────────────────────────────────────────────────────────────
for sid in $SELECTED_SKILL_IDS; do
  key="${sid//-/_}"
  sname="${SKILL_NAME_MAP[$key]:-$sid}"
  scat="${SKILL_CAT_MAP[$key]:-?}"

  # Quick start per category
  case "$scat" in
    auth)     QS="**Interface:** takes credentials or token → returns auth result + session. **#1 gotcha:** JWTs are signed, not encrypted — never put sensitive data in the payload." ;;
    data)     QS="**Interface:** takes query params → returns typed result or error. **#1 gotcha:** N+1 queries are the silent killer — profile every list endpoint before marking done." ;;
    api)      QS="**Interface:** HTTP request in → validated response out, consistent error envelope. **#1 gotcha:** returning 200 with an error body breaks all downstream monitoring." ;;
    ui)       QS="**Interface:** accepts typed props → renders component, emits typed events. **#1 gotcha:** missing loading and error states will crash the UI — always handle all three states." ;;
    ml)       QS="**Interface:** takes typed input tensor/dataframe → returns prediction + confidence. **#1 gotcha:** train/val data leakage — always split before shuffling, never after." ;;
    infra)    QS="**Interface:** declarative config in → provisioned resource out. **#1 gotcha:** secrets in build args get baked into image layers — use runtime env vars." ;;
    messaging) QS="**Interface:** message in → processed + ack/nack out. **#1 gotcha:** consumers must be idempotent — the same message will be delivered more than once." ;;
    testing)  QS="**Interface:** test subject in → assertion result out. **#1 gotcha:** tests that never assert pass silently — require a minimum assertion count in linter config." ;;
    android)  QS="**Interface:** ViewModel state in → Compose UI out, user events up. **#1 gotcha:** any I/O on the main thread causes an ANR — all data work must run on Dispatchers.IO." ;;
    *)        QS="**Interface:** define before implementing. **#1 gotcha:** check gotchas.md before writing any code." ;;
  esac

  emit_file "skills/${sid}/SKILL.md" "# ${sname}

> **When to use:** Use this skill when implementing ${sname,,} functionality in **${PROJECT_NAME}**.

**ID:** ${sid}  **Category:** ${scat}  **Status:** UNIMPLEMENTED  **Created:** ${TODAY}

---

## Quick start
> Read this first. Load the rest only when you need the detail.

${QS}

**Before writing any code:** read \`gotchas.md\` — start with ●●●●● and ●●●●○ entries.
**After implementing:** write a compact record to \`outputs/\`, update \`last_seen\` on triggered gotchas.

---

## Skill folder contents

| File | Purpose |
|------|---------|
| \`SKILL.md\` | This file — the contract |
| \`gotchas.md\` | Confidence-weighted failure patterns |
| \`scripts/\` | Helper scripts to run or compose |
| \`assets/\` | Templates, config, reference files |
| \`references/\` | API docs, type definitions |
| \`outputs/\` | Structured results from prior executions |

---

## Purpose

One sentence: what this skill does and why it exists in **${PROJECT_NAME}**.

---

## Interface

### Inputs
| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| — | — | — | — | Define before implementing |

### Outputs
\`\`\`
{ success: true, data: <define shape here> }
{ success: false, error: { code: string, message: string } }
\`\`\`

### Side effects
- *(none defined yet)*

---

## Acceptance criteria
- [ ] Happy path: *(define)*
- [ ] Auth failure: *(define)*
- [ ] Validation failure: *(define)*
- [ ] Downstream failure: *(define)*
- [ ] Performance: *(define target)*

---

## Verification checklist
- [ ] Interface matches spec — no undocumented parameters or return shapes
- [ ] All acceptance criteria passing — tested, not assumed
- [ ] New gotchas discovered during implementation added to \`gotchas.md\`
- [ ] QUALITY.md gates applicable to this skill all pass

---
*Spec created: ${TODAY} — Msingi v${VERSION}*
" "$ROOT"

  # Gotchas — seeded per category with confidence metadata
  SEED_BLOCK=""
  case "$scat" in
    auth) SEED_BLOCK='
### G-001 · JWTs are not encrypted — only signed
`confidence: ●●●●● critical`  `triggers: jwt, token, payload, claims`  `last_seen: seeded`  `status: ACTIVE`
**What:** Sensitive data placed in JWT payload is exposed — base64 is not encryption.
**Why:** JWT signing proves authenticity but not secrecy. Any party can decode the payload.
**Prevention:** Never put PII or secrets in a JWT payload. Store a user ID only.

### G-002 · OAuth state param not validated → CSRF
`confidence: ●●●●○ high`  `triggers: oauth, callback, redirect, authorization_code`  `last_seen: seeded`  `status: ACTIVE`
**What:** CSRF attack on the OAuth callback forces victim to link attacker'"'"'s account.
**Why:** The `state` param exists to bind the request to the initiating session.
**Prevention:** Generate a random `state` before redirect. Verify it matches exactly on callback.

### G-003 · Password reset tokens reused after first use
`confidence: ●●●●○ high`  `triggers: reset, password, token, forgot`  `last_seen: seeded`  `status: ACTIVE`
**What:** Reset link works multiple times — attacker who intercepts it can use it later.
**Why:** Token not invalidated on first use.
**Prevention:** Mark token used before processing. Single-use, expire in ≤15 minutes.

### G-004 · Raw Authorization header logged
`confidence: ●●●●○ high`  `triggers: log, error, authorization, header, bearer`  `last_seen: seeded`  `status: ACTIVE`
**What:** Bearer tokens appear in logs — accessible to anyone with log access.
**Why:** Error handlers log full request headers without redacting credentials.
**Prevention:** Strip Authorization header from logs. Log only scheme + first 8 chars.' ;;

    data) SEED_BLOCK='
### G-001 · N+1 query in data loops
`confidence: ●●●●● critical`  `triggers: loop, forEach, map, list, collection`  `last_seen: seeded`  `status: ACTIVE`
**What:** One query fires per iteration instead of one batch query for the whole set.
**Why:** ORM lazy-loading resolves associations inside a loop.
**Prevention:** Enable query logging in dev. Profile every list endpoint before marking done.

### G-002 · Migration runs on wrong database
`confidence: ●●●●○ high`  `triggers: migrate, migration, schema, database, env`  `last_seen: seeded`  `status: ACTIVE`
**What:** Migration runs against production because APP_ENV was not set.
**Prevention:** Assert APP_ENV at the top of every migration script. Confirm target DB before running.

### G-003 · ORM silently returns null on not-found
`confidence: ●●●●○ high`  `triggers: findOne, findById, get, fetch, lookup`  `last_seen: seeded`  `status: ACTIVE`
**What:** Code assumes a row exists; ORM returns null; downstream code throws a cryptic error.
**Prevention:** Always handle null explicitly at the query point. Use findOrFail where available.

### G-004 · Soft-delete not filtered in joins
`confidence: ●●●●○ high`  `triggers: join, relation, soft, deleted_at`  `last_seen: seeded`  `status: ACTIVE`
**What:** Soft-deleted records appear in query results via joined relations.
**Prevention:** Apply deleted_at IS NULL to every relation in every join.' ;;

    api) SEED_BLOCK='
### G-001 · 200 status with error body
`confidence: ●●●●● critical`  `triggers: response, status, error, return, handler`  `last_seen: seeded`  `status: ACTIVE`
**What:** Client receives 200 OK with {"error": "..."} — monitoring logs success; client code breaks.
**Prevention:** Use proper 4xx/5xx status codes. Never return 200 for an error condition.

### G-002 · Content-Type not validated → silent empty body
`confidence: ●●●●○ high`  `triggers: body, parse, request, json, content-type`  `last_seen: seeded`  `status: ACTIVE`
**What:** Client sends JSON as text/plain; body parser ignores it; handler receives empty object.
**Prevention:** Validate Content-Type header. Return 415 for unexpected types.

### G-003 · Rate limit not scoped per user
`confidence: ●●●●○ high`  `triggers: rate, limit, throttle, quota, counter`  `last_seen: seeded`  `status: ACTIVE`
**What:** One user exhausts the rate limit for all users sharing an IP (e.g. office NAT).
**Prevention:** Scope rate limits by authenticated user ID, falling back to IP.

### G-004 · Inconsistent error envelope across endpoints
`confidence: ●●●●○ high`  `triggers: error, message, response, envelope`  `last_seen: seeded`  `status: ACTIVE`
**What:** Some endpoints return {"error":"..."}, others return {"message":"..."}. Clients cannot handle generically.
**Prevention:** Define the error envelope once in SKILL.md before writing any handler.' ;;

    *) SEED_BLOCK="
*(No seed gotchas for this category — add the first one when you hit a failure)*
" ;;
  esac

  emit_file "skills/${sid}/gotchas.md" "# Gotchas: ${sname}

> Each entry is a **belief with evidence** — not just a note.
> Confidence reflects how often this gotcha was triggered and whether it was ever contradicted.
> Read high-confidence entries first. This file is append-only — mark resolved ones [RESOLVED: date].

---

## Confidence scale

\`●●●●● critical\` — triggered repeatedly, causes data loss or security issues, never contradicted
\`●●●●○ high\`     — triggered 3+ times, well-understood cause and prevention
\`●●●○○ medium\`   — seeded from known patterns, not yet confirmed in this project
\`●●○○○ low\`      — single observation, needs more evidence
\`●○○○○ weak\`     — theoretical, contradicted once, or very edge-case

---

## How to update an entry

When a gotcha triggers: find its entry, update \`last_seen\`, raise confidence one level.
If the gotcha did NOT apply: lower confidence one level and add a note.
If permanently fixed: mark \`status: RESOLVED (date)\` — never delete.

---

## Seeded gotchas (medium confidence until confirmed in this project)
${SEED_BLOCK}

---

## Project-specific gotchas

*(Add entries discovered during actual work on ${PROJECT_NAME})*

---
*Created: ${TODAY} — Msingi v${VERSION}*
" "$ROOT"

  emit_file "skills/${sid}/scripts/.keep" "# Add helper scripts here. Claude can run or compose these.
# Example: validate_input.py, seed_data.sh, run_tests.sh
" "$ROOT"

  emit_file "skills/${sid}/outputs/.keep" "# Structured output records from skill executions.
# Format: one JSON or markdown file per significant execution.
# Example: { date, outcome, summary, key_values }
" "$ROOT"
done

# ── Skills README ─────────────────────────────────────────────────────────────
SKILLS_INDEX=""
for sid in $SELECTED_SKILL_IDS; do
  key="${sid//-/_}"
  sname="${SKILL_NAME_MAP[$key]:-$sid}"
  scat="${SKILL_CAT_MAP[$key]:-?}"
  SKILLS_INDEX="${SKILLS_INDEX}- [${sname}](${sid}/SKILL.md) · ${scat} · UNIMPLEMENTED\n"
done

emit_file "skills/README.md" "# skills/ — Capability Library

**Project:** ${PROJECT_NAME}

Each skill is a **folder** containing: contract (SKILL.md), failure knowledge (gotchas.md),
helper scripts (scripts/), templates (assets/), and execution records (outputs/).

Agents read SKILL.md first. Fetch gotchas.md before implementing. Check outputs/ for prior results.

---

## Skills index

$(printf '%b' "$SKILLS_INDEX")
---

## Workflow

1. Identify the right skill by its **When to use** trigger
2. Read \`SKILL.md\` — understand the interface and acceptance criteria
3. Read \`gotchas.md\` — start with ●●●●● and ●●●●○ entries
4. Check \`scripts/\` — use existing helpers instead of rebuilding
5. Check \`outputs/\` — verify prior execution results before re-running
6. Implement in \`src/\` — spec stays unchanged
7. Write execution record to \`outputs/\`; update gotcha \`last_seen\` if triggered

---
*Generated by Msingi v${VERSION} on ${TODAY}*
" "$ROOT"

# ── ADR seed ──────────────────────────────────────────────────────────────────
emit_file "memory/decisions/000-init.md" "# 000-init.md — Project Initialisation

**Date:** ${TODAY}
**Status:** CONFIRMED
**Severity:** HIGH
**Made by:** Human (Msingi bootstrap)
**Supersedes:** none
**Superseded by:** *(leave blank until a future ADR replaces this one)*

---

## Decision
Initialise **${PROJECT_NAME}** as a ${TYPE_LABEL} with a production-grade
context engineering structure for multi-agent development.

## Context
Project requires coordination across multiple AI agents across many sessions.
Without a canonical structure, each agent session risks context drift, repeated decisions,
quality regression, and security gaps.

## Spec reference
CONTEXT.md — full architecture and non-functional requirements.

## Alternatives considered
| Option | Why rejected |
|--------|-------------|
| Ad-hoc prompting per session | No continuity, repeated context loss |
| Single shared system prompt | Context rot at scale, no per-agent specialisation |

## Consequences
- Enables: multi-agent coordination with consistent context across sessions
- Constrains: all agents must read CONTEXT.md before starting work
- Defers: specific technology choices within each skill domain

## Review trigger
After first milestone completion — verify structure served the project well.

---

<!-- ADR template for future entries:

# NNN-short-title.md

**Date:** YYYY-MM-DD
**Status:** PENDING | CONFIRMED | SUPERSEDED
**Severity:** LOW | MEDIUM | HIGH | CRITICAL
**Made by:** [agent name or human]
**Supersedes:** [NNN-prior-decision.md or none]
**Superseded by:** [leave blank until superseded]

## Decision
[One clear sentence.]

## Context
[Why this decision was needed.]

## Spec reference
[Link to relevant SKILL.md or CONTEXT.md section]

## Alternatives considered
| Option | Why rejected |
|--------|-------------|

## Consequences
- Enables:
- Constrains:
- Defers:

## Review trigger
[Specific condition that would cause this to be revisited]

Reminder: this file is append-only.

-->
" "$ROOT"

# ── bootstrap-record.json ─────────────────────────────────────────────────────
SKILL_JSON_IDS=""
for sid in $SELECTED_SKILL_IDS; do
  key="${sid//-/_}"
  sname="${SKILL_NAME_MAP[$key]:-$sid}"
  scat="${SKILL_CAT_MAP[$key]:-?}"
  SKILL_JSON_IDS="${SKILL_JSON_IDS}    {\"id\": \"${sid}\", \"name\": \"${sname}\", \"category\": \"${scat}\"},\n"
done
SKILL_JSON_IDS="${SKILL_JSON_IDS%,*}"  # remove trailing comma

AGENT_JSON=""
for i in "${!SELECTED_AGENT_IDS[@]}"; do
  AGENT_JSON="${AGENT_JSON}    {\"id\": \"${SELECTED_AGENT_IDS[$i]}\", \"name\": \"${SELECTED_AGENT_NAMES[$i]}\", \"file\": \"${SELECTED_AGENT_FILES[$i]}\"},\n"
done
AGENT_JSON="${AGENT_JSON%,*}"

if [[ $DRY_RUN -eq 0 ]]; then
  mkdir -p "${ROOT}/memory"
  cat > "${ROOT}/memory/bootstrap-record.json" << JSONEOF
{
  "tool": "msingi",
  "version": "${VERSION}",
  "generatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "project": {
    "name": "${PROJECT_NAME}",
    "description": "${PROJECT_DESC}",
    "type": "${TYPE_ID}",
    "typeLabel": "${TYPE_LABEL}",
    "secondaryType": "${SECONDARY_TYPE_ID}",
    "secondaryTypeLabel": "${SECONDARY_TYPE_LABEL}",
    "stack": "${PROJECT_STACK}",
    "milestone": "${PROJECT_MILESTONE}",
    "mode": "${MODE}"
  },
  "intake": {
    "audience": "${PROJECT_AUDIENCE}",
    "needsAuth": ${NEEDS_AUTH},
    "handlesSensitiveData": ${HANDLES_SENSITIVE},
    "sensitiveDataTags": "${SENSITIVE_TAGS}",
    "deploymentTarget": "${PROJECT_DEPLOY}",
    "scaleProfile": "${PROJECT_SCALE}"
  },
  "agents": [
$(printf '%b' "$AGENT_JSON")
  ],
  "skills": [
$(printf '%b' "$SKILL_JSON_IDS")
  ]
}
JSONEOF
  write_done "memory/bootstrap-record.json"
fi

# ── Git init ──────────────────────────────────────────────────────────────────
if [[ $INIT_GIT -eq 0 ]] && [[ $DRY_RUN -eq 0 ]]; then
  if command -v git &>/dev/null; then
    (
      cd "$ROOT"
      git init --quiet
      git add .
      AGENT_STR=$(IFS=", "; echo "${SELECTED_AGENT_NAMES[*]}")
      SKILL_STR="$INFERRED_SKILL_COUNT skills"
      HYBRID_NOTE=""
      [[ -n "$SECONDARY_TYPE_LABEL" ]] && HYBRID_NOTE=" + ${SECONDARY_TYPE_LABEL}"
      COMMIT_SUBJECT="feat(scaffold): initialise ${PROJECT_NAME} (${TYPE_LABEL}${HYBRID_NOTE}, $(echo "$SELECTED_SKILL_IDS" | wc -w | tr -d ' ') skills, ${#SELECTED_AGENT_NAMES[@]} agents)"
      COMMIT_BODY="Generated by Msingi v${VERSION}

Project:   ${PROJECT_NAME} (${TYPE_LABEL}${HYBRID_NOTE})
Milestone: ${PROJECT_MILESTONE}
Agents:    ${AGENT_STR}
Scale:     ${PROJECT_SCALE} · ${PROJECT_DEPLOY}
Mode:      ${MODE}

Built in Accra. Designed for everywhere."
      git commit --quiet -m "$COMMIT_SUBJECT" -m "$COMMIT_BODY"
    ) && write_done "git init + initial commit" || write_warn "git init failed — git may not be installed"
  else
    write_warn "git not found — skipping git init"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# COMPLETION
# ─────────────────────────────────────────────────────────────────────────────
SKILL_COUNT=$(echo "$SELECTED_SKILL_IDS" | wc -w | tr -d ' ')
AGENT_COUNT="${#SELECTED_AGENT_IDS[@]}"
HYBRID_SUFFIX=""
[[ -n "$SECONDARY_TYPE_LABEL" ]] && HYBRID_SUFFIX=" + ${SECONDARY_TYPE_LABEL}"

echo ""
echo "  ${C_GRAY}╔$(printf '═%.0s' {1..64})╗${C_RESET}"
echo "  ${C_GRAY}║${C_RESET}  $(brand "✓  Bootstrap complete")$(printf ' %.0s' {1..42})${C_GRAY}║${C_RESET}"
echo "  ${C_GRAY}║${C_RESET}  ${C_GRAY}Msingi v${VERSION} · ${TYPE_LABEL}${HYBRID_SUFFIX} · ${AGENT_COUNT} agents · ${SKILL_COUNT} skills${C_RESET}$(printf ' %.0s' {1..10})${C_GRAY}║${C_RESET}"
echo "  ${C_GRAY}╠$(printf '─%.0s' {1..64})╣${C_RESET}"
echo "  ${C_GRAY}║${C_RESET}  ${C_GRAY}Location  ${C_RESET}${ROOT}$(printf ' %.0s' {1..5})${C_GRAY}║${C_RESET}"
echo "  ${C_GRAY}║${C_RESET}  ${C_GRAY}Scale     ${PROJECT_SCALE}  ·  ${PROJECT_DEPLOY}${C_RESET}$(printf ' %.0s' {1..30})${C_GRAY}║${C_RESET}"
echo "  ${C_GRAY}╚$(printf '═%.0s' {1..64})╝${C_RESET}"
echo ""
echo "  $(bold "Start here:")"
write_info "1. Read CONTEXT.md — confirm architecture and NFRs are correct"
write_info "2. Read SECURITY.md — confirm threat model covers your project"
write_info "3. Read QUALITY.md — know the gates before writing any code"
write_info "4. Open TASKS.md — your first session starts at the top"
echo ""
echo "  ${C_GRAY}Built in Accra. Designed for everywhere.${C_RESET}"
echo ""
