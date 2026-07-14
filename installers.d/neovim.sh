#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_neovim() {
    local arch asset url temp root; arch="$(recipe_arch)" || return 1
    case "$arch" in x86_64) asset=nvim-linux-x86_64.tar.gz;; aarch64) asset=nvim-linux-arm64.tar.gz;; esac
    url="$(github_release_asset neovim/neovim "$asset$")" || return 1; temp="$(mktemp -d)"
    run_logged_command curl -fL "$url" -o "$temp/nvim.tar.gz" && run_logged_command tar -xzf "$temp/nvim.tar.gz" -C "$temp" || return 1
    root="$(find "$temp" -mindepth 1 -maxdepth 1 -type d -name 'nvim-*' | head -n1)"; [[ -n "$root" ]] || return 1
    run_logged_command sudo rm -rf /opt/nvim-linux && run_logged_command sudo cp -a "$root" /opt/nvim-linux && run_logged_command sudo ln -sf /opt/nvim-linux/bin/nvim /usr/local/bin/nvim
    local rc=$?; rm -rf -- "$temp"; return "$rc"
}
