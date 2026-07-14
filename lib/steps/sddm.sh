#!/usr/bin/env bash
# shellcheck disable=SC2034 # status values are exposed for callers/logging

install_qylock_sddm_themes() {
    local temp_dir=""
    local repo_dir=""
    local themes_source_dir=""
    local theme_source_dir=""
    local theme_name=""
    local target_dir=""
    local active_theme="nier-automata"
    local qylock_conf="/etc/sddm.conf.d/00-qylock.conf"
    local legacy_conf="/etc/sddm.conf.d/00-nier-automata.conf"
    local -a installed_theme_names=()

    temp_dir="$(mktemp -d)"
    repo_dir="$temp_dir/qylock"
    themes_source_dir="$repo_dir/themes"

    run_logged_command_with_title "Cloning qylock SDDM themes" git clone --depth 1 https://github.com/Darkkal44/qylock "$repo_dir"

    if [[ ! -d "$themes_source_dir" ]]; then
        append_log_line "qylock clone did not contain a themes directory"
        rm -rf -- "$temp_dir"
        return 1
    fi

    for theme_source_dir in "$themes_source_dir"/*; do
        [[ -d "$theme_source_dir" ]] || continue
        [[ -f "$theme_source_dir/metadata.desktop" ]] || continue

        theme_name="${theme_source_dir##*/}"
        target_dir="/usr/share/sddm/themes/$theme_name"

        run_logged_command sudo install -d -m 0755 "$target_dir"
        run_logged_command_with_title "Installing qylock theme $theme_name" sudo cp -a "$theme_source_dir/." "$target_dir/"
        installed_theme_names+=("$theme_name")
    done

    if [[ "${#installed_theme_names[@]}" -eq 0 ]]; then
        append_log_line "qylock clone did not contain any installable SDDM themes"
        rm -rf -- "$temp_dir"
        return 1
    fi

    if [[ ! -f "$themes_source_dir/$active_theme/metadata.desktop" ]]; then
        active_theme="${installed_theme_names[0]}"
        append_log_line "qylock clone did not contain themes/nier-automata; using $active_theme as the active theme"
    fi

    run_logged_command sudo install -d -m 0755 /etc/sddm.conf.d
    run_logged_command sudo rm -f "$legacy_conf"

    append_log_line "Installed qylock themes: ${installed_theme_names[*]}"
    append_log_line "RUN write $qylock_conf"
    {
        printf '%s\n' "[Theme]" "Current=$active_theme" | sudo tee "$qylock_conf" >/dev/null
    } >> "$LOG_FILE" 2>&1

    QYLOCK_INSTALLED_THEME_COUNT="${#installed_theme_names[@]}"
    QYLOCK_ACTIVE_THEME="$active_theme"

    rm -rf -- "$temp_dir"
}

# Switch the display-manager alias to SDDM so the installed theme is used on the next boot.
activate_sddm_display_manager() {
    if ! have_command systemctl; then
        append_log_line "systemctl is unavailable; cannot switch the active display manager to SDDM."
        return 1
    fi

    local manager
    for manager in gdm.service gdm3.service lightdm.service plasmalogin.service; do
        if systemctl cat "$manager" >/dev/null 2>&1; then run_logged_command sudo systemctl disable "$manager" || true; fi
    done

    run_logged_command_with_title "Setting SDDM as the active display manager" sudo systemctl enable sddm.service --force
}

run_sddm_post_install_steps() {
    ui_section 'Applying SDDM Themes' desktop
    ui_task 'qylock SDDM themes' install_qylock_sddm_themes || return 1
    ui_task 'Activate SDDM' activate_sddm_display_manager
}
