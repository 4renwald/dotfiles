#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_starship() { recipe_run_script https://starship.rs/install.sh --yes --bin-dir "$HOME/.local/bin"; }
