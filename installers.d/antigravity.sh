#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_antigravity() { recipe_install_apt_repo_package antigravity https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg 'deb [signed-by=/etc/apt/keyrings/antigravity.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main' antigravity; }
