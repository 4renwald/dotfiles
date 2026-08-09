# zsh

Standalone zsh setup: oh-my-posh prompt (Catppuccin), zsh-autosuggestions,
zsh-syntax-highlighting, `lsd` aliases. Self-contained — it does not use
`install.sh` or anything else in this repo.

## Install

```bash
git clone https://github.com/4rewald/dotfiles ~/dotfiles && ~/dotfiles/zsh/setup.sh
```

Idempotent: re-running reports `ok` for everything already in place.

| Flag | Effect |
| --- | --- |
| `--no-deps` | Only link the config, install nothing |
| `--set-default-shell` | Also `chsh` to zsh (off by default — needs your password) |

## What it does

Installs anything missing (`zsh`, `lsd`, `zsh-syntax-highlighting` via apt/pacman;
zsh-autosuggestions cloned to `~/.zsh/`; oh-my-posh to `~/.local/bin`), then symlinks:

| Link | Target |
| --- | --- |
| `~/.zshrc` | `zsh/zshrc` |
| `~/.config/oh-my-posh/themes` | `zsh/oh-my-posh/themes` |

Anything already at those paths is preserved as `<path>.bak-<timestamp>`.

`nvim` is warned about but not installed — the `vim` alias needs it, but distro
packages lag badly.

Because these are symlinks, `~/.zshrc` **is** the repo file: edit it in place and
commit, and `git pull` alone updates your shell. Themes other than `catppuccin`
(`cinnamon`, `gruvbox`, `kali`) ship too — switch by changing the `--config` path
in `zshrc`.

## Rollback

```bash
rm ~/.zshrc && mv ~/.zshrc.bak-<timestamp> ~/.zshrc
```
