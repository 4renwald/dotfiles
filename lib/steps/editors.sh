#!/usr/bin/env bash

install_catppuccin_editor_extensions() {
    local editor_command="$1"

    run_logged_command_with_title "Installing the Catppuccin theme for $editor_command" "$editor_command" --install-extension Catppuccin.catppuccin-vsc --force
    run_logged_command_with_title "Installing the Catppuccin icons for $editor_command" "$editor_command" --install-extension Catppuccin.catppuccin-vsc-icons --force
}

# Apply editor theme defaults for VS Code-compatible editors.
run_editor_theme_post_install_steps() {
    show_section "Applying Editor Themes"

    if have_command code; then
        if run_task_step "VS Code Catppuccin extensions" install_catppuccin_editor_extensions code; then
            :
        else
            warn "Could not install Catppuccin extensions for VS Code."
        fi
    else
        warn "VS Code CLI was not found; skipping Catppuccin extension install for VS Code."
    fi

    if have_command antigravity; then
        if run_task_step "Antigravity Catppuccin extensions" install_catppuccin_editor_extensions antigravity; then
            :
        else
            warn "Could not install Catppuccin extensions for Antigravity."
        fi
    else
        warn "Antigravity CLI was not found; skipping Catppuccin extension install for Antigravity."
    fi
}

# Apply Spotify and Spicetify theme defaults.
