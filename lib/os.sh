#!/usr/bin/env bash

detect_distro() {
    [[ -r /etc/os-release ]] || die 'Cannot detect the operating system: /etc/os-release is missing.'
    local ID='' ID_LIKE='' NAME='' PRETTY_NAME='' VERSION_ID=''
    # shellcheck disable=SC1091
    source /etc/os-release
    local ids=" ${ID,,} ${ID_LIKE,,} "
    if [[ "$ids" == *arch* ]]; then
        DISTRO_FAMILY=arch
    elif [[ "$ids" == *debian* || "${ID,,}" == ubuntu ]]; then
        DISTRO_FAMILY=debian
    else
        die "Unsupported distribution '${PRETTY_NAME:-${NAME:-$ID}}'. Supported: Arch/CachyOS, Debian 13+, Ubuntu 24.04+."
    fi
    DISTRO_ID="${ID,,}"
    DISTRO_LIKE="${ID_LIKE,,}"
    DISTRO_VERSION="$VERSION_ID"
    DISTRO_NAME="${PRETTY_NAME:-${NAME:-$ID}}"
    local major="${VERSION_ID%%.*}"
    if [[ "$DISTRO_ID" == debian && "$major" =~ ^[0-9]+$ && "$major" -lt 13 ]]; then
        die "Debian $VERSION_ID is too old; Debian 13 or newer is required."
    fi
    if [[ "$DISTRO_ID" == ubuntu && "$major" =~ ^[0-9]+$ && "$major" -lt 24 ]]; then
        die "Ubuntu $VERSION_ID is too old; Ubuntu 24.04 or newer is required."
    fi
    export DISTRO_FAMILY DISTRO_ID DISTRO_LIKE DISTRO_VERSION DISTRO_NAME
}

detect_environment() {
    IS_WSL=false; HAS_GUI=false; HAS_PLASMA6=false
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || { [[ -r /proc/version ]] && grep -qi microsoft /proc/version; }; then IS_WSL=true; fi
    if [[ "$IS_WSL" == false ]] && { [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || have_command plasmashell || have_command sddm; }; then HAS_GUI=true; fi
    if have_command kwriteconfig6; then
        HAS_PLASMA6=true
    elif have_command plasmashell && plasmashell --version 2>/dev/null | grep -Eq '(^|[^0-9])6([.][0-9]+)'; then
        HAS_PLASMA6=true
    fi
    export IS_WSL HAS_GUI HAS_PLASMA6
}

is_plasma_session() {
    local normalized="${XDG_CURRENT_DESKTOP:-} ${DESKTOP_SESSION:-}"
    normalized="${normalized,,}"
    [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && [[ "$normalized" == *kde* || "$normalized" == *plasma* ]]
}

group_scope() {
    case "$1" in desktop|gui|media) printf 'desktop\n';; *) printf 'cli\n';; esac
}

config_scope() {
    case "$1" in desktop|media) printf 'desktop\n';; *) printf 'cli\n';; esac
}

in_scope() { [[ "$1" == cli || "${RUN_DESKTOP:-false}" == true ]]; }
