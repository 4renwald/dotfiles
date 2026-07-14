#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_vscode() { recipe_install_apt_repo_package microsoft https://packages.microsoft.com/keys/microsoft.asc 'deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main' code; }
