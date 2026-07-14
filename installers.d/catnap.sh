#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_catnap() {
    local url arch; arch="$(recipe_arch)" || return 1
    url="$(github_release_asset iinsertNameHere/catnap "catnap.*${arch}.*(tar|zip)|${arch}.*linux.*(tar|zip)")" || return 1
    install_bin_from_archive "$url" catnap "$HOME/.local/bin"
}
