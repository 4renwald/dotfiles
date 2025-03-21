# dotfiles

This repository contains my personal dotfiles and configuration files.

## Requirements
> [!NOTE]  
> The packages listed below have been installed and configured on Arch Linux.

### Shell

Set Zsh as your default login shell:

```bash
chsh -s $(which zsh)
```

### Packages
```bash
yay -S colorls neovim-git catnap-git ghostty-git
```

### Oh-My-Posh

```bash
curl -s https://ohmyposh.dev/install.sh | bash -s
```

## Installation

Clone the repository and deploy the dotfiles in your home directory:

```bash
git clone git@github.com:4renwald/dotfiles.git
```
After cloning, move or symlink the configuration files into your `$HOME` directory as needed.




