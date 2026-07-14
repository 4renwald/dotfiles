#!/usr/bin/env bash

APT_NEEDS_UPDATE=false

debian_bootstrap() {
    run_logged_command sudo env DEBIAN_FRONTEND=noninteractive apt-get update &&
        run_logged_command sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates gnupg git unzip fontconfig xz-utils
}

apt_update_if_needed() {
    [[ "$APT_NEEDS_UPDATE" == true ]] || return 0
    run_logged_command sudo env DEBIAN_FRONTEND=noninteractive apt-get update && APT_NEEDS_UPDATE=false
}

pkg_backend_install() {
    local package="$1"
    apt_update_if_needed || return 1
    if ! apt-cache show "$package" >/dev/null 2>&1; then append_log_line "MISSING Debian package: $package"; return 1; fi
    run_logged_command sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
}

apt_add_repo() {
    local name="$1" key_url="$2" repo_line="$3" temp keyring
    keyring="/etc/apt/keyrings/$name.gpg"
    temp="$(mktemp)"
    run_logged_command curl -fsSL "$key_url" -o "$temp" || { rm -f "$temp"; return 1; }
    run_logged_command sudo install -d -m 0755 /etc/apt/keyrings || return 1
    if grep -q 'BEGIN PGP PUBLIC KEY BLOCK' "$temp"; then
        run_logged_command gpg --dearmor --yes --output "$temp.gpg" "$temp" || return 1
        run_logged_command sudo install -m 0644 "$temp.gpg" "$keyring" || return 1
    else
        run_logged_command sudo install -m 0644 "$temp" "$keyring" || return 1
    fi
    # shellcheck disable=SC2024 # tee owns the privileged write; redirect only captures its stdout
    printf '%s\n' "$repo_line" | sudo tee "/etc/apt/sources.list.d/$name.list" >>"$LOG_FILE" || return 1
    rm -f "$temp" "$temp.gpg"
    APT_NEEDS_UPDATE=true
}

install_deb_url() {
    local url="$1" temp
    temp="$(mktemp -d)"
    run_logged_command curl -fL "$url" -o "$temp/pkg.deb" && apt_update_if_needed && run_logged_command sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$temp/pkg.deb"
    local rc=$?; rm -rf -- "$temp"; return "$rc"
}

github_release_asset() {
    local repo="$1" regex="$2" api json url
    api="https://api.github.com/repos/$repo/releases/latest"
    json="$(curl -fsSL "$api" 2>>"$LOG_FILE")" || return 1
    url="$(printf '%s' "$json" | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | grep -E "$regex" | head -n1)"
    [[ -n "$url" ]] || return 1
    printf '%s\n' "$url"
}

install_bin_from_archive() {
    local url="$1" binary="$2" destination="${3:-/usr/local/bin}" temp candidate
    temp="$(mktemp -d)"; run_logged_command curl -fL "$url" -o "$temp/archive" || return 1
    if [[ "$url" == *.zip ]]; then run_logged_command unzip -q "$temp/archive" -d "$temp/out" || return 1; else mkdir -p "$temp/out"; run_logged_command tar -xf "$temp/archive" -C "$temp/out" || return 1; fi
    candidate="$(find "$temp/out" -type f -name "$binary" -perm -u+x | head -n1)"; [[ -n "$candidate" ]] || candidate="$(find "$temp/out" -type f -name "$binary" | head -n1)"
    [[ -n "$candidate" ]] || return 1
    if [[ "$destination" == "$HOME"/* ]]; then run_logged_command install -d "$destination" && run_logged_command install -m 0755 "$candidate" "$destination/$binary"; else run_logged_command sudo install -m 0755 "$candidate" "$destination/$binary"; fi
    local rc=$?; rm -rf -- "$temp"; return "$rc"
}

npm_global() { pkg_backend_install npm >/dev/null 2>&1 || true; run_logged_command sudo npm install --global "$@"; }
pipx_install() { pkg_backend_install pipx && pkg_backend_install python3-venv && run_logged_command pipx install --force "$1"; }
