#!/usr/bin/env bash

install_app_jellyfin_mpv_shim() {
    [[ "${JELLYFIN_SHIM_INSTALLED:-false}" == true ]] && return 0
    pipx_install jellyfin-mpv-shim && run_logged_command pipx inject jellyfin-mpv-shim mpv-shim-default-shaders && JELLYFIN_SHIM_INSTALLED=true
}
