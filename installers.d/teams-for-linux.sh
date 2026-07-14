#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_teams_for_linux() { recipe_install_apt_repo_package teams-for-linux https://repo.teamsforlinux.de/teams-for-linux.asc 'deb [signed-by=/etc/apt/keyrings/teams-for-linux.gpg] https://repo.teamsforlinux.de/debian/ stable main' teams-for-linux; }
