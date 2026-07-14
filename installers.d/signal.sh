#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_signal() { recipe_install_apt_repo_package signal https://updates.signal.org/desktop/apt/keys.asc 'deb [arch=amd64 signed-by=/etc/apt/keyrings/signal.gpg] https://updates.signal.org/desktop/apt xenial main' signal-desktop; }
