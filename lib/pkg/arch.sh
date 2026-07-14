#!/usr/bin/env bash

install_paru_from_dir() {
    local temp="$1"
    run_logged_command sudo pacman -S --needed --noconfirm base-devel git &&
        run_logged_command git clone --depth 1 https://aur.archlinux.org/paru.git "$temp/paru" &&
        run_logged_command_in_dir "$temp/paru" makepkg -si --noconfirm
}

ensure_paru() {
    have_command paru && return 0
    local temp
    ui_confirm 'An AUR package requires paru. Install it now?' || return 1
    temp="$(mktemp -d)"
    install_paru_from_dir "$temp"; local rc=$?
    rm -rf -- "$temp"
    ((rc == 0)) && have_command paru
}

prepare_openai_codex_install() {
    local codex_bin="/usr/bin/codex"
    local codex_dir="/usr/lib/node_modules/@openai/codex"
    local codex_target=""
    if [[ ! -e "$codex_bin" && ! -d "$codex_dir" ]]; then return 0; fi
    if pacman -Qo "$codex_bin" >/dev/null 2>&1 || pacman -Qo "$codex_dir" >/dev/null 2>&1; then return 0; fi
    codex_target="$(readlink -f "$codex_bin" 2>/dev/null || true)"
    if [[ -n "$codex_target" && "$codex_target" != "$codex_dir"* && ! -d "$codex_dir" ]]; then
        append_log_line 'Unmanaged /usr/bin/codex does not match the expected npm Codex layout.'
        return 1
    fi
    append_log_line 'Removing unmanaged npm Codex so pacman can install openai-codex.'
    [[ ! -e "$codex_bin" ]] || run_logged_command sudo rm -f "$codex_bin" || return 1
    [[ ! -d "$codex_dir" ]] || run_logged_command sudo rm -rf "$codex_dir" || return 1
    [[ ! -d /usr/lib/node_modules/@openai ]] || run_logged_command sudo rmdir /usr/lib/node_modules/@openai || true
}

pkg_backend_install() {
    local package="$1"
    if [[ "$package" == openai-codex ]]; then prepare_openai_codex_install || return 1; fi
    if pacman -Si "$package" >/dev/null 2>&1; then
        run_logged_command sudo pacman -S --needed --noconfirm "$package"
    elif ensure_paru && paru -Si "$package" >/dev/null 2>&1; then
        run_logged_command paru -S --needed --noconfirm "$package"
    else
        append_log_line "MISSING Arch package: $package"
        return 1
    fi
}
