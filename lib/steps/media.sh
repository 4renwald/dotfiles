#!/usr/bin/env bash

get_spicetify_command() {
    if have_command spicetify; then
        printf 'spicetify\n'
        return 0
    fi

    if [[ -x "$HOME/.local/bin/spicetify" ]]; then
        printf '%s\n' "$HOME/.local/bin/spicetify"
        return 0
    fi

    return 1
}

# Initialize the repo-local log file.
install_spicetify_catppuccin_theme() {
    local temp_dir=""
    local repo_dir=""
    local theme_source_dir=""
    local theme_target_dir="$HOME/.config/spicetify/Themes/catppuccin"

    if ! have_command git; then
        append_log_line "git is unavailable; cannot install the Catppuccin Spicetify theme."
        return 1
    fi

    temp_dir="$(mktemp -d)"
    repo_dir="$temp_dir/catppuccin-spicetify"
    theme_source_dir="$repo_dir/catppuccin"

    run_logged_command_with_title "Cloning the Catppuccin Spicetify theme" git clone --depth 1 https://github.com/catppuccin/spicetify.git "$repo_dir"

    if [[ ! -f "$theme_source_dir/user.css" || ! -f "$theme_source_dir/color.ini" || ! -f "$theme_source_dir/theme.js" ]]; then
        append_log_line "The Catppuccin Spicetify repo did not contain the expected theme files."
        rm -rf -- "$temp_dir"
        return 1
    fi

    run_logged_command install -d -m 0755 "$HOME/.config/spicetify/Themes" || {
        rm -rf -- "$temp_dir"
        return 1
    }
    run_logged_command rm -rf "$theme_target_dir" || {
        rm -rf -- "$temp_dir"
        return 1
    }
    run_logged_command cp -a "$theme_source_dir" "$theme_target_dir" || {
        rm -rf -- "$temp_dir"
        return 1
    }

    rm -rf -- "$temp_dir"
}

# Point Spicetify at the Catppuccin Mocha theme defaults.
configure_spicetify_catppuccin_theme() {
    local spicetify_bin=""

    spicetify_bin="$(get_spicetify_command)" || {
        append_log_line "Spicetify is unavailable; cannot configure the Catppuccin theme."
        return 1
    }

    run_logged_command_with_title "Configuring Spicetify for Catppuccin Mocha" \
        "$spicetify_bin" config \
        current_theme catppuccin \
        color_scheme mocha \
        inject_css 1 \
        inject_theme_js 1 \
        replace_colors 1 \
        overwrite_assets 1
}

# Grant the current user group write access to Spotify's install directory for Spicetify.
ensure_spotify_write_access_for_spicetify() {
    local spotify_root="/opt/spotify"
    local spotify_apps="/opt/spotify/Apps"
    local primary_group=""

    if [[ ! -d "$spotify_root" || ! -d "$spotify_apps" ]]; then
        append_log_line "Spotify is not installed in /opt/spotify; cannot apply the Spicetify theme."
        return 1
    fi

    if [[ -w "$spotify_root" && -w "$spotify_apps" ]]; then
        return 0
    fi

    primary_group="$(id -gn)"
    run_logged_command_with_title "Granting Spotify write access for Spicetify" sudo chgrp "$primary_group" "$spotify_root"
    run_logged_command sudo chgrp -R "$primary_group" "$spotify_apps"
    run_logged_command sudo chmod 775 "$spotify_root"
    run_logged_command sudo chmod -R 775 "$spotify_apps"
}

# Apply the configured Spicetify theme to the local Spotify install.
apply_spicetify_catppuccin_theme() {
    local spicetify_bin=""

    spicetify_bin="$(get_spicetify_command)" || {
        append_log_line "Spicetify is unavailable; cannot apply the Catppuccin theme."
        return 1
    }

    if [[ ! -f "$HOME/.config/spotify/prefs" ]]; then
        append_log_line "Spotify prefs are missing; launch Spotify once before applying the Spicetify theme."
        return 1
    fi

    pkill -x spotify >>"$LOG_FILE" 2>&1 || true
    run_logged_command_with_title "Applying the Spicetify Catppuccin theme" "$spicetify_bin" backup apply
}

# Install every discovered package group.
run_media_post_install_steps() {
    show_section "Applying Media Themes"

    if ! get_spicetify_command >/dev/null 2>&1; then
        warn "Spicetify is unavailable; skipping the Catppuccin Spotify theme."
        return 0
    fi

    if run_task_step "Catppuccin Spicetify theme" install_spicetify_catppuccin_theme; then
        :
    else
        warn "Could not install the Catppuccin Spicetify theme files automatically."
    fi

    if run_task_step "Spicetify Catppuccin config" configure_spicetify_catppuccin_theme; then
        :
    else
        warn "Could not configure Spicetify for Catppuccin Mocha automatically."
    fi

    if [[ -d /opt/spotify && -d /opt/spotify/Apps ]]; then
        if run_task_step "Spicetify Spotify permissions" ensure_spotify_write_access_for_spicetify; then
            :
        else
            warn "Could not grant Spotify write access for Spicetify automatically."
            return 1
        fi

        if run_task_step "Apply Spicetify Catppuccin" apply_spicetify_catppuccin_theme; then
            :
        else
            warn "Could not apply the Catppuccin Spicetify theme automatically."
            return 1
        fi
    else
        warn "Spotify is not installed in /opt/spotify; skipping the live Spicetify theme apply step."
    fi
}

# Apply system-level tweaks that require root privileges.
