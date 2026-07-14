#!/usr/bin/env bash
set -uo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$DOTFILES_DIR/packages"; INSTALLERS_DIR="$DOTFILES_DIR/installers.d"
LOGS_DIR="$DOTFILES_DIR/logs"; LOG_FILE="$LOGS_DIR/install-$(date +%Y%m%d_%H%M%S).log"
SYSTEM_DIR="$DOTFILES_DIR/system"; EXCLUDE_DIRS=(.git logs packages scripts lib installers.d)
ASSUME_YES=false; FORCE_SCOPE=auto; ONLY_PHASE=''; declare -A SKIP_PHASES=()
PHASE_ORDER=(packages configs system desktop media editors)
SUDO_KEEPALIVE_PID=''; OVERALL_SUCCESS=true; RUN_DESKTOP=false

# Load the distro-neutral modules and preserved Plasma behavior.
# shellcheck disable=SC1091
source "$DOTFILES_DIR/lib/steps/kde.sh"
source "$DOTFILES_DIR/lib/log.sh"
source "$DOTFILES_DIR/lib/ui.sh"
source "$DOTFILES_DIR/lib/os.sh"
source "$DOTFILES_DIR/lib/configs.sh"
source "$DOTFILES_DIR/lib/pkg.sh"
source "$DOTFILES_DIR/lib/steps/system.sh"
source "$DOTFILES_DIR/lib/steps/sddm.sh"
source "$DOTFILES_DIR/lib/steps/media.sh"
source "$DOTFILES_DIR/lib/steps/editors.sh"

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]
  --yes                 do not prompt
  --cli-only            force CLI-only scope
  --desktop             force desktop scope
  --skip PHASE          skip packages, configs, system, desktop, media, or editors
  --only PHASE          run only one phase
  --list                print manifest resolution for Arch and Debian
  -h, --help            show this help
EOF
}

valid_phase() { [[ " ${PHASE_ORDER[*]} " == *" $1 "* ]]; }
parse_args() {
    while (($#)); do
        case "$1" in
            --yes) ASSUME_YES=true;;
            --cli-only) FORCE_SCOPE=cli;;
            --desktop) FORCE_SCOPE=desktop;;
            --skip) shift; (($#)) || die '--skip requires a phase'; valid_phase "$1" || die "Unknown phase: $1"; SKIP_PHASES[$1]=1;;
            --only) shift; (($#)) || die '--only requires a phase'; valid_phase "$1" || die "Unknown phase: $1"; ONLY_PHASE="$1";;
            --list) LIST_ONLY=true;;
            -h|--help) usage; exit 0;;
            *) die "Unknown option: $1";;
        esac
        shift
    done
}

phase_enabled() { [[ -z "$ONLY_PHASE" || "$ONLY_PHASE" == "$1" ]] && [[ -z "${SKIP_PHASES[$1]:-}" ]]; }

install_needs_sudo() {
    phase_enabled packages && return 0
    phase_enabled system && [[ "$IS_WSL" == false ]] && return 0
    phase_enabled desktop && [[ "$RUN_DESKTOP" == true && "$HAS_PLASMA6" == true ]] && return 0
    phase_enabled media && [[ "$RUN_DESKTOP" == true ]] && return 0
    return 1
}

review_plan() {
    local group config scope marker count target
    printf '%s%sReview%s\n' "$C_BOLD" "$C_ACCENT" "$C_RESET"
    printf '  Package groups:\n'
    while IFS= read -r group; do scope="$(group_scope "$group")"; marker=OUT; in_scope "$scope" && marker=IN; count="$(count_packages_in_group "$group")"; printf '    %-9s %-9s %3s packages\n' "[$marker]" "$group" "$count"; done < <(discover_package_groups)
    printf '  Config trees:\n'
    while IFS= read -r config; do scope="$(config_scope "$config")"; marker=OUT; in_scope "$scope" && marker=IN; target="$(read_target_path "$DOTFILES_DIR/$config" 2>/dev/null || printf '?')"; printf '    %-9s %-9s → %s\n' "[$marker]" "$config" "$target"; done < <(discover_config_dirs)
    printf '\n'
}

ensure_sudo_ready() {
    append_log_line 'RUN sudo -v'
    if [[ $(id -u) -eq 0 ]]; then return 0; fi
    sudo -v || return 1
    (while :; do sleep 60; sudo -n -v >/dev/null 2>&1 || exit; done) & SUDO_KEEPALIVE_PID=$!
}

cleanup() {
    [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    cleanup_ui
}

skip_phase() { CURRENT_PHASE="$1"; ui_skip_task "$2"; }

main() {
    parse_args "$@"; init_logs; ui_init
    trap cleanup EXIT
    trap 'exit 130' INT TERM
    if [[ "${LIST_ONLY:-false}" == true ]]; then pkg_manifest_resolve_all; exit 0; fi
    detect_distro; detect_environment
    case "$FORCE_SCOPE" in desktop) RUN_DESKTOP=true;; cli) RUN_DESKTOP=false;; auto) RUN_DESKTOP="$HAS_GUI";; esac
    ui_banner; review_plan
    ui_confirm 'Apply this install plan?' || { info 'Installation cancelled.'; exit 0; }
    if install_needs_sudo; then ensure_sudo_ready || die 'sudo authentication failed.'; fi
    # shellcheck disable=SC1090
    source "$DOTFILES_DIR/lib/pkg/$DISTRO_FAMILY.sh"
    if [[ "$DISTRO_FAMILY" == debian ]] && phase_enabled packages; then debian_bootstrap || OVERALL_SUCCESS=false; fi

    if phase_enabled packages; then install_all_packages; else skip_phase packages 'packages phase'; fi
    if phase_enabled configs; then deploy_all_configs; else skip_phase configs 'configs phase'; fi
    if phase_enabled system && [[ "$IS_WSL" == false ]]; then run_system_post_install_steps || OVERALL_SUCCESS=false; else skip_phase system 'system phase'; fi
    if phase_enabled desktop && [[ "$RUN_DESKTOP" == true && "$HAS_PLASMA6" == true ]]; then run_sddm_post_install_steps || OVERALL_SUCCESS=false; run_kde_post_install_steps || OVERALL_SUCCESS=false; else skip_phase desktop 'desktop phase'; fi
    if phase_enabled media && [[ "$RUN_DESKTOP" == true ]]; then run_media_post_install_steps || OVERALL_SUCCESS=false; else skip_phase media 'media phase'; fi
    if phase_enabled editors; then run_editor_theme_post_install_steps || OVERALL_SUCCESS=false; else skip_phase editors 'editors phase'; fi
    ui_summary "$OVERALL_SUCCESS"
    [[ "$OVERALL_SUCCESS" == true ]]
}

main "$@"
