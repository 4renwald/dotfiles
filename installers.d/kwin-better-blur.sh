#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_kwin_better_blur() { mapfile -t deps < <(recipe_kde_build_deps); recipe_clone_cmake_install taj-ny/kwin-effects-forceblur forceblur "${deps[@]}"; }
