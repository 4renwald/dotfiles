#!/usr/bin/env bash

install_app_spicetify() {
    local target json tag url temp install_dir="$HOME/.local/share/spicetify-cli"
    case "$(uname -sm)" in
        'Linux x86_64') target=linux-amd64;;
        'Linux aarch64') target=linux-arm64;;
        *) append_log_line "Unsupported Spicetify platform: $(uname -sm)"; return 1;;
    esac
    json="$(curl -fsSL https://api.github.com/repos/spicetify/cli/releases/latest 2>>"$LOG_FILE")" || return 1
    tag="$(printf '%s\n' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' | head -n1)"
    [[ -n "$tag" ]] || return 1
    url="https://github.com/spicetify/cli/releases/download/v${tag}/spicetify-${tag}-${target}.tar.gz"
    temp="$(mktemp -d)"; mkdir -p "$temp/out"
    run_logged_command curl -fL "$url" -o "$temp/spicetify.tar.gz" && run_logged_command tar -xzf "$temp/spicetify.tar.gz" -C "$temp/out" && [[ -x "$temp/out/spicetify" ]] || return 1
    run_logged_command rm -rf "$install_dir" && run_logged_command install -d "$install_dir" "$HOME/.local/bin" && run_logged_command cp -a "$temp/out/." "$install_dir/" && run_logged_command ln -sf "$install_dir/spicetify" "$HOME/.local/bin/spicetify"
    local rc=$?; rm -rf -- "$temp"; return "$rc"
}
