#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_proton_mail() { recipe_github_deb ProtonMail/inbox-desktop 'amd64[.]deb$'; }
