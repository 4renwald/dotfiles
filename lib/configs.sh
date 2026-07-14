#!/usr/bin/env bash

is_excluded_dir() {
    local candidate="$1" excluded
    for excluded in "${EXCLUDE_DIRS[@]}"; do [[ "$candidate" == "$excluded" ]] && return 0; done
    return 1
}

discover_config_dirs() {
    local dir name
    for dir in "$DOTFILES_DIR"/*; do
        [[ -d "$dir" ]] || continue
        name="$(basename "$dir")"
        is_excluded_dir "$name" && continue
        [[ -f "$dir/.target" ]] && printf '%s\n' "$name"
    done | sort
}

expand_target_path() {
    case "$1" in
        '~') printf '%s\n' "$HOME";;
        \~/*) printf '%s/%s\n' "$HOME" "${1#\~/}";;
        \$HOME) printf '%s\n' "$HOME";;
        \$HOME/*) printf '%s/%s\n' "$HOME" "${1#\$HOME/}";;
        /*) printf '%s\n' "$1";;
        *) printf '%s\n' "$1";;
    esac
}

read_target_path() {
    local raw
    raw="$(trim_whitespace "$(<"$1/.target")")"
    [[ -n "$raw" ]] && expand_target_path "$raw"
}

config_unit_from_relative_path() {
    local path="$1"; IFS=/ read -r -a parts <<<"$path"
    case "${parts[0]}" in
        .config) ((${#parts[@]} > 1)) && printf '.config/%s\n' "${parts[1]}" || printf '.config\n';;
        .local) ((${#parts[@]} > 2)) && printf '.local/%s/%s\n' "${parts[1]}" "${parts[2]}" || printf '%s\n' "$path";;
        *) printf '%s\n' "${parts[0]}";;
    esac
}

discover_config_units() {
    local config="$1" path
    while IFS= read -r path; do config_unit_from_relative_path "${path#./}"; done < <(
        cd "$DOTFILES_DIR/$config" && find . -mindepth 1 ! -name .target \( -type f -o -type l \) -print
    ) | sort -u
}

count_config_units() { discover_config_units "$1" | awk 'NF {n++} END {print n+0}'; }

deploy_config_unit() {
    local config="$1" unit="$2" target source destination
    target="$(read_target_path "$DOTFILES_DIR/$config")" || return 1
    source="$DOTFILES_DIR/$config/$unit"; destination="$target/$unit"
    mkdir -p "$(dirname "$destination")"
    ui_task "$config/$unit" cp -rf "$source" "$(dirname "$destination")/"
}

deploy_config_group() {
    local config="$1" unit failed=false
    while IFS= read -r unit; do [[ -n "$unit" ]] && deploy_config_unit "$config" "$unit" || failed=true; done < <(discover_config_units "$config")
    [[ "$failed" == false ]]
}

deploy_all_configs() {
    local config
    ui_section 'Deploying Configs' configs
    while IFS= read -r config; do
        # shellcheck disable=SC2034 # shared orchestrator state
        if in_scope "$(config_scope "$config")"; then deploy_config_group "$config" || OVERALL_SUCCESS=false; else ui_skip_task "config group $config"; fi
    done < <(discover_config_dirs)
}
