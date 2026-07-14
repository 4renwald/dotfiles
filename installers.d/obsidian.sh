#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_obsidian() { recipe_github_deb obsidianmd/obsidian-releases 'amd64[.]deb$'; }
