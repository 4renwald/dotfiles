#!/usr/bin/env bash

recipe_arch() { case "$(uname -m)" in x86_64) printf 'x86_64\n';; aarch64|arm64) printf 'aarch64\n';; *) return 1;; esac; }

recipe_run_script() {
    local url="$1"; shift
    local script; script="$(mktemp)"
    run_logged_command curl -fsSL "$url" -o "$script" || { rm -f "$script"; return 1; }
    run_logged_command bash "$script" "$@"; local rc=$?; rm -f "$script"; return "$rc"
}

recipe_github_deb() {
    local repo="$1" regex="$2" url
    url="$(github_release_asset "$repo" "$regex")" || return 1
    install_deb_url "$url"
}

recipe_install_apt_repo_package() {
    local name="$1" key="$2" line="$3" package="$4"
    apt_add_repo "$name" "$key" "$line" && apt_update_if_needed && pkg_backend_install "$package"
}

recipe_clone_cmake_install() {
    local repo="$1" name="$2" temp
    shift 2
    local -a deps=(build-essential cmake ninja-build extra-cmake-modules gettext "$@") available=() dep
    for dep in "${deps[@]}"; do apt-cache show "$dep" >/dev/null 2>&1 && available+=("$dep"); done
    run_logged_command sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${available[@]}" || return 1
    temp="$(mktemp -d)"
    run_logged_command git clone --depth 1 "https://github.com/$repo.git" "$temp/$name" &&
        run_logged_command cmake -S "$temp/$name" -B "$temp/$name/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF &&
        run_logged_command cmake --build "$temp/$name/build" --parallel "$(nproc)" &&
        run_logged_command sudo cmake --install "$temp/$name/build"
    local rc=$?; rm -rf -- "$temp"
    ((rc == 0)) || append_log_line "Theme component $name skipped: source build failed"
    return "$rc"
}

recipe_kde_build_deps() {
    printf '%s\n' kwin-dev libkf6config-dev libkf6coreaddons-dev libkf6guiaddons-dev libkf6i18n-dev libkf6iconthemes-dev libkf6windowsystem-dev libkf6kcmutils-dev libkf6kirigami-dev qt6-base-dev qt6-declarative-dev qt6-svg-dev libx11-dev libxcb1-dev libwayland-dev
}

recipe_install_applet() { install_plasma_applet_from_repo "https://github.com/$1.git" "$2" "$3"; }
