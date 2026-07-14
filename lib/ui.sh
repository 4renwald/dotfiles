#!/usr/bin/env bash

declare -Ag UI_OK=() UI_FAILED=() UI_SKIPPED=()
CURRENT_PHASE=general

ui_init() {
    if [[ -t 1 && "${TERM:-dumb}" != dumb && -z "${NO_COLOR:-}" ]]; then
        C_ACCENT=$'\e[38;2;245;194;231m'; C_ACCENT2=$'\e[38;2;180;190;254m'
        C_BLUE=$'\e[38;2;137;180;250m'; C_SUCCESS=$'\e[38;2;166;227;161m'
        C_ERROR=$'\e[38;2;243;139;168m'; C_WARN=$'\e[38;2;250;179;135m'
        C_DIM=$'\e[38;2;108;112;134m'; C_TEXT=$'\e[38;2;205;214;244m'
        C_BOLD=$'\e[1m'; C_RESET=$'\e[0m'
    else
        C_ACCENT=; C_ACCENT2=; C_BLUE=; C_SUCCESS=; C_ERROR=; C_WARN=; C_DIM=; C_TEXT=; C_BOLD=; C_RESET=
    fi
    export C_ACCENT C_ACCENT2 C_BLUE C_SUCCESS C_ERROR C_WARN C_DIM C_TEXT C_BOLD C_RESET
}

ui_banner() {
    local scope_label=cli-only width=62 distro_line log_line inner
    [[ "${RUN_DESKTOP:-false}" == true ]] && scope_label='full desktop'
    distro_line="${DISTRO_NAME:-Unknown} (${DISTRO_FAMILY:-unknown}) · $scope_label"
    log_line="Log: ${LOG_FILE:-not initialized}"
    ((${#distro_line} + 4 > width)) && width=$((${#distro_line} + 4))
    ((${#log_line} + 4 > width)) && width=$((${#log_line} + 4))
    inner=$((width - 2))
    printf '\n%s┌%*s┐%s\n' "$C_ACCENT" "$width" '' "$C_RESET"
    printf '%s│%s %-*s %s│%s\n' "$C_ACCENT" "$C_RESET" "$inner" 'dotfiles installer' "$C_ACCENT" "$C_RESET"
    printf '%s│%s %-*s %s│%s\n' "$C_ACCENT" "$C_RESET" "$inner" "$distro_line" "$C_ACCENT" "$C_RESET"
    printf '%s│%s %-*s %s│%s\n' "$C_ACCENT" "$C_RESET" "$inner" "$log_line" "$C_ACCENT" "$C_RESET"
    printf '%s└%*s┘%s\n\n' "$C_ACCENT" "$width" '' "$C_RESET"
}

ui_section() {
    CURRENT_PHASE="${2:-${1,,}}"
    CURRENT_PHASE="${CURRENT_PHASE// /_}"
    printf '\n%s%s%s%s\n%s%s\n' "$C_BOLD" "$C_ACCENT" "$1" "$C_RESET" "$C_ACCENT2" '────────────────────────────────────────────────────────────'
}

ui_count() {
    local kind="$1" phase="${CURRENT_PHASE:-general}" value
    case "$kind" in
        ok) value=${UI_OK[$phase]:-0}; UI_OK[$phase]=$((value + 1)) ;;
        failed) value=${UI_FAILED[$phase]:-0}; UI_FAILED[$phase]=$((value + 1)) ;;
        skipped) value=${UI_SKIPPED[$phase]:-0}; UI_SKIPPED[$phase]=$((value + 1)) ;;
    esac
}

ui_spinner() {
    local label="$1" frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
    while :; do
        printf '\r  %s%s%s %s' "$C_ACCENT" "${frames:i++%10:1}" "$C_RESET" "$label"
        sleep 0.09
    done
}

ui_task() {
    local label="$1" spinner_pid='' rc=0
    shift
    append_log_line "TASK START $label"
    if [[ -t 1 ]]; then
        tput civis 2>/dev/null || true
        ui_spinner "$label" & spinner_pid=$!
    fi
    run_logged_command "$@" || rc=$?
    if [[ -n "$spinner_pid" ]]; then
        kill "$spinner_pid" 2>/dev/null || true
        wait "$spinner_pid" 2>/dev/null || true
        tput cnorm 2>/dev/null || true
        printf '\r\033[2K'
    fi
    if ((rc == 0)); then
        append_log_line "TASK OK $label"; ui_count ok
        [[ -t 1 ]] && printf '  %s✓%s %s\n' "$C_SUCCESS" "$C_RESET" "$label" || printf '[ ok ] %s\n' "$label"
    else
        append_log_line "TASK FAILED ($rc) $label"; ui_count failed
        [[ -t 1 ]] && printf '  %s✗%s %s\n' "$C_ERROR" "$C_RESET" "$label" || printf '[fail] %s\n' "$label"
    fi
    return "$rc"
}

ui_skip_task() {
    ui_count skipped
    append_log_line "TASK SKIPPED $1"
    [[ -t 1 ]] && printf '  %s○ %s (skipped)%s\n' "$C_DIM" "$1" "$C_RESET" || printf '[skip] %s\n' "$1"
}

ui_confirm() {
    local reply=''
    [[ "${ASSUME_YES:-false}" == true ]] && return 0
    printf '%s%s%s [y/N]: ' "$C_ACCENT" "$1" "$C_RESET" >&2
    read -r reply || true
    [[ "$reply" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]
}

ui_summary() {
    local phase
    printf '\n%s%sSummary%s\n' "$C_BOLD" "$C_ACCENT" "$C_RESET"
    printf '  %-18s %6s %8s %8s\n' Phase OK Failed Skipped
    for phase in "${PHASE_ORDER[@]:-general}"; do
        printf '  %-18s %6d %8d %8d\n' "$phase" "${UI_OK[$phase]:-0}" "${UI_FAILED[$phase]:-0}" "${UI_SKIPPED[$phase]:-0}"
    done
    printf '\n'
    if [[ "$1" == true ]]; then
        printf '%s✓ Install complete%s\n' "$C_SUCCESS" "$C_RESET"
    else
        printf '%s✗ Install finished with errors → see %s%s\n' "$C_ERROR" "$LOG_FILE" "$C_RESET"
    fi
}

cleanup_ui() { tput cnorm 2>/dev/null || true; }

# Compatibility names used by the preserved KDE/config functions.
show_section() {
    local phase=general
    case "${1,,}" in
        *package*) phase=packages;; *config*) phase=configs;; *system*) phase=system;;
        *kde*|*desktop*|*sddm*) phase=desktop;; *media*) phase=media;; *editor*) phase=editors;;
    esac
    ui_section "$1" "$phase"
}
show_task_header() { printf '\n%s%s%s\n' "$C_ACCENT2" "$1" "$C_RESET"; }
run_task_step() { ui_task "$@"; }
run_task_step_with_title() { shift; ui_task "$@"; }
confirm_action() { ui_confirm "$@"; }
clear_if_tty() { [[ -t 1 ]] && clear 2>/dev/null || true; }
