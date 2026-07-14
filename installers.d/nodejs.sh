#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_nodejs() {
    local script; script="$(mktemp)"
    run_logged_command curl -fsSL https://deb.nodesource.com/setup_22.x -o "$script" && run_logged_command sudo bash "$script" && pkg_backend_install nodejs
    local rc=$?; rm -f "$script"; return "$rc"
}
