#!/usr/bin/env bash

init_logs() {
    mkdir -p "$LOGS_DIR"
    : >"$LOG_FILE"
}

append_log_line() {
    [[ -n "${LOG_FILE:-}" ]] || return 0
    mkdir -p "${LOGS_DIR:-$(dirname "$LOG_FILE")}" 2>/dev/null || true
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

format_command() {
    local item
    local -a quoted=()
    for item in "$@"; do quoted+=("$(printf '%q' "$item")"); done
    printf '%s\n' "${quoted[*]}"
}

run_logged_command() {
    append_log_line "RUN $(format_command "$@")"
    "$@" >>"$LOG_FILE" 2>&1
}

run_logged_command_in_dir() {
    local workdir="$1"
    shift
    append_log_line "RUN (cd $(printf '%q' "$workdir") && $(format_command "$@"))"
    (cd "$workdir" && "$@" >>"$LOG_FILE" 2>&1)
}

run_logged_command_with_title() { shift; run_logged_command "$@"; }
run_logged_command_in_dir_with_title() { shift; run_logged_command_in_dir "$@"; }

log_message() {
    local level="$1"
    shift
    append_log_line "[$level] $*"
    case "$level" in
        INFO) printf '%sℹ%s %s\n' "${C_BLUE:-}" "${C_RESET:-}" "$*" ;;
        WARN) printf '%s⚠%s %s\n' "${C_WARN:-}" "${C_RESET:-}" "$*" >&2 ;;
        ERROR) printf '%s✗%s %s\n' "${C_ERROR:-}" "${C_RESET:-}" "$*" >&2 ;;
    esac
}

info() { log_message INFO "$@"; }
warn() { log_message WARN "$@"; }
error() { log_message ERROR "$@"; }
success() { log_message INFO "$@"; }
die() { error "$@"; exit 1; }

have_command() { command -v "$1" >/dev/null 2>&1; }

trim_whitespace() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s\n' "$value"
}

join_by() {
    local delimiter="$1" first=true item result=""
    shift
    for item in "$@"; do
        if [[ "$first" == true ]]; then result="$item"; first=false; else result+="$delimiter$item"; fi
    done
    printf '%s\n' "$result"
}
