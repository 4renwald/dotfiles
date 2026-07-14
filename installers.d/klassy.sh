#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_klassy() { mapfile -t deps < <(recipe_kde_build_deps); recipe_clone_cmake_install paulmcauley/klassy klassy "${deps[@]}"; }
