#!/usr/bin/env bash

install_app_megasync() {
    local flavor
    if [[ "$DISTRO_ID" == ubuntu || "$DISTRO_LIKE" == *ubuntu* ]]; then flavor="xUbuntu_${DISTRO_VERSION}"; else flavor="Debian_${DISTRO_VERSION}"; fi
    install_deb_url "https://mega.nz/linux/repo/${flavor}/amd64/megasync-${flavor}_amd64.deb"
}
