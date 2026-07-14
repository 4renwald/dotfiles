#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_vesktop() { recipe_github_deb Vencord/Vesktop 'amd64[.]deb$'; }
