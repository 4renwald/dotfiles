#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_spotify() { recipe_install_apt_repo_package spotify https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg 'deb [signed-by=/etc/apt/keyrings/spotify.gpg] https://repository.spotify.com stable non-free' spotify-client; }
