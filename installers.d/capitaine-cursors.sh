#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_capitaine_cursors() {
    local url temp source; url="$(github_release_asset keeferrourke/capitaine-cursors 'capitaine-cursors.*(tar[.]gz|zip)$')" || return 1; temp="$(mktemp -d)"
    run_logged_command curl -fL "$url" -o "$temp/archive" || return 1; mkdir -p "$temp/out"
    if [[ "$url" == *.zip ]]; then run_logged_command unzip -q "$temp/archive" -d "$temp/out"; else run_logged_command tar -xf "$temp/archive" -C "$temp/out"; fi || return 1
    source="$(find "$temp/out" -type f -name index.theme -printf '%h\n' | head -n1)"; [[ -n "$source" ]] && run_logged_command sudo cp -a "$source" /usr/share/icons/
    local rc=$?; rm -rf -- "$temp"; return "$rc"
}
