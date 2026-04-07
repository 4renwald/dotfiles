# Dotfiles

Arch/CachyOS dotfiles with one installer and a repo layout built around discovery.

## Quick Start

```bash
git clone git@github.com:4renwald/dotfiles.git
cd dotfiles
./install.sh
```

The installer will:

- install every package manifest in `packages/*.txt`
- deploy every top-level config tree that contains a `.target`
- apply KDE, SDDM, shortcut, and system post-install steps
- write logs to `logs/`

## How It Works

This repo is intentionally all-in. There is no picker UI anymore: whatever is present in the repo is what gets installed.

- `packages/*.txt`: package manifests grouped by purpose
- `shell/`, `nvim/`, `apps/`, `media/`, `desktop/`: config trees copied to the location declared by each folder's `.target`
- `system/`: system-level files such as udev rules

If you want to change what gets installed:

- add or remove package names in `packages/*.txt`
- add or remove files inside the config trees
- create a new top-level config folder with a `.target` if you want the installer to deploy it

## Defaults

- KDE uses Catppuccin Mocha Lavender with 14px Krohnkite gaps
- Ghostty is the main terminal
- Neovim, Ghostty, and Starship are based on Omarchy
- MPV ships with a default HQ shader chain plus 4 Anime4K presets

## Notes

- Arch/CachyOS only
- `gum` is bootstrapped if missing
- `paru` is bootstrapped only when an AUR package is needed
- Plasma may need one logout/login before a newly added command shortcut becomes active
