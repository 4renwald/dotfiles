#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_krohnkite() {
    local url tool temp; tool="$(get_kpackagetool_command)" || return 1; url="$(github_release_asset anametologin/krohnkite '[.]kwinscript$')" || return 1; temp="$(mktemp)"
    run_logged_command curl -fL "$url" -o "$temp" || return 1
    if "$tool" --type KWin/Script --show krohnkite >/dev/null 2>&1; then run_logged_command "$tool" --type KWin/Script --upgrade "$temp"; else run_logged_command "$tool" --type KWin/Script --install "$temp"; fi
    local rc=$?; rm -f "$temp"; return "$rc"
}
