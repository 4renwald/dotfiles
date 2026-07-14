#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_bluetui() { local url arch; arch="$(recipe_arch)" || return 1; url="$(github_release_asset pythops/bluetui "linux.*${arch}|${arch}.*linux")" || return 1; install_bin_from_archive "$url" bluetui "$HOME/.local/bin"; }
