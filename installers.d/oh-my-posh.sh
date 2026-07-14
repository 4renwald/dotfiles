#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_oh_my_posh() { recipe_run_script https://ohmyposh.dev/install.sh -d "$HOME/.local/bin"; }
