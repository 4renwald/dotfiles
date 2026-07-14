#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_kwin_rounded_corners() { mapfile -t deps < <(recipe_kde_build_deps); recipe_clone_cmake_install matinlotfali/KDE-Rounded-Corners rounded-corners "${deps[@]}"; }
