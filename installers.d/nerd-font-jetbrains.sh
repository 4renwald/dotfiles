#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_nerd_font_jetbrains() {
    local url temp; url="$(github_release_asset ryanoasis/nerd-fonts 'JetBrainsMono[.]zip$')" || return 1; temp="$(mktemp -d)"
    run_logged_command curl -fL "$url" -o "$temp/font.zip" && run_logged_command unzip -q "$temp/font.zip" -d "$temp/font" && run_logged_command install -d "$HOME/.local/share/fonts/JetBrainsMonoNerdFont" && run_logged_command find "$temp/font" -type f \( -name '*.ttf' -o -name '*.otf' \) -exec cp -f '{}' "$HOME/.local/share/fonts/JetBrainsMonoNerdFont/" \; && run_logged_command fc-cache -f
    local rc=$?; rm -rf -- "$temp"; return "$rc"
}
