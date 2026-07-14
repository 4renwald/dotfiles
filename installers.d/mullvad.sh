#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_mullvad() { recipe_install_apt_repo_package mullvad https://repository.mullvad.net/deb/mullvad-keyring.asc 'deb [signed-by=/etc/apt/keyrings/mullvad.gpg arch=amd64] https://repository.mullvad.net/deb/stable stable main' mullvad-vpn; }
