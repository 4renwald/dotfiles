#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_charm_repo() { recipe_install_apt_repo_package charm https://repo.charm.sh/apt/gpg.key 'deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *' gum; }
