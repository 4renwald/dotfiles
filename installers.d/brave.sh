#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_brave() { recipe_install_apt_repo_package brave https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg 'deb [signed-by=/etc/apt/keyrings/brave.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main' brave-browser; }
