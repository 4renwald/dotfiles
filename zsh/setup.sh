#!/usr/bin/env bash
# Standalone installer for this zsh configuration.
# Self-contained: depends on nothing else in this repo.
set -euo pipefail

ZSH_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d%H%M%S)"
INSTALL_DEPS=true
SET_SHELL=false
PM=''

usage() {
    cat <<'EOF'
Usage: ./setup.sh [options]
  --no-deps             only link the config, install nothing
  --set-default-shell   also run chsh to make zsh the login shell
  -h, --help            show this help
EOF
}

say() { printf '  %-8s %s\n' "$1" "$2"; }

have() { command -v "$1" >/dev/null 2>&1; }

detect_pm() {
    if have apt-get; then PM=apt
    elif have pacman; then PM=pacman
    fi
}

# Install the named packages, skipping any command that already resolves.
pm_install() {
    local -a missing=()
    local pkg cmd
    for pkg in "$@"; do
        # package name doubles as the command name for everything we ask for,
        # except zsh-syntax-highlighting which ships a sourceable file instead
        case "$pkg" in
            zsh-syntax-highlighting)
                cmd=''
                for f in /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
                         /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
                    [[ -r "$f" ]] && cmd=found && break
                done
                [[ -n "$cmd" ]] && { say ok "$pkg"; continue; }
                ;;
            *) have "$pkg" && { say ok "$pkg"; continue; };;
        esac
        missing+=("$pkg")
    done
    ((${#missing[@]})) || return 0

    case "$PM" in
        apt)
            say install "${missing[*]}"
            sudo apt-get update -qq
            sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
            ;;
        pacman)
            say install "${missing[*]}"
            sudo pacman -S --needed --noconfirm "${missing[@]}"
            ;;
        *) say warn "no apt/pacman — install manually: ${missing[*]}";;
    esac
}

install_autosuggestions() {
    local dest="$HOME/.zsh/zsh-autosuggestions"
    if [[ -d "$dest/.git" ]]; then
        say ok 'zsh-autosuggestions'
        git -C "$dest" pull --ff-only --quiet || say warn 'zsh-autosuggestions: pull failed'
    else
        say install 'zsh-autosuggestions'
        mkdir -p "$HOME/.zsh"
        rm -rf -- "$dest"
        git clone --depth 1 --quiet \
            https://github.com/zsh-users/zsh-autosuggestions.git "$dest"
    fi
}

install_oh_my_posh() {
    if have oh-my-posh; then say ok 'oh-my-posh'; return 0; fi
    say install 'oh-my-posh'
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
}

install_deps() {
    detect_pm
    [[ -n "$PM" ]] || say warn 'unknown package manager; skipping system packages'
    pm_install zsh lsd git curl zsh-syntax-highlighting
    install_autosuggestions
    install_oh_my_posh
    have nvim || say warn "nvim not found — the 'vim' alias won't work until it's installed"
}

# Point $2 at $1, preserving whatever is already there as <dest>.bak-<stamp>.
backup_and_link() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [[ -L "$dest" ]]; then
        if [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
            say ok "$dest"
            return 0
        fi
        rm -f "$dest"
    elif [[ -e "$dest" ]]; then
        mv -- "$dest" "$dest.bak-$STAMP"
        say backup "$dest -> $dest.bak-$STAMP"
    fi
    ln -s "$src" "$dest"
    say link "$dest -> $src"
}

link_config() {
    backup_and_link "$ZSH_DIR/zshrc" "$HOME/.zshrc"
    backup_and_link "$ZSH_DIR/oh-my-posh/themes" "$HOME/.config/oh-my-posh/themes"
}

set_default_shell() {
    local zsh_bin
    zsh_bin="$(command -v zsh)" || { say warn 'zsh not installed; cannot set default shell'; return 0; }
    if [[ "${SHELL:-}" == "$zsh_bin" ]]; then say ok 'zsh is already the login shell'; return 0; fi
    say chsh "$zsh_bin"
    chsh -s "$zsh_bin"
}

main() {
    while (($#)); do
        case "$1" in
            --no-deps) INSTALL_DEPS=false;;
            --set-default-shell) SET_SHELL=true;;
            -h|--help) usage; exit 0;;
            *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 1;;
        esac
        shift
    done

    printf '\nzsh config setup (%s)\n\n' "$ZSH_DIR"
    if [[ "$INSTALL_DEPS" == true ]]; then
        printf 'Dependencies\n'
        install_deps
        printf '\n'
    fi
    printf 'Config\n'
    link_config
    if [[ "$SET_SHELL" == true ]]; then
        printf '\nLogin shell\n'
        set_default_shell
    fi
    printf '\nDone. Start a new zsh to pick it up.\n\n'
}

main "$@"
