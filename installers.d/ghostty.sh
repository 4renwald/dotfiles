#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_ghostty() { if apt-cache show ghostty >/dev/null 2>&1; then pkg_backend_install ghostty; else recipe_github_deb mkasberg/ghostty-ubuntu 'amd64[.]deb$'; fi; }
