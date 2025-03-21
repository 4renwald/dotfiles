# Set up the prompt
PATH=$HOME/bin:/usr/local/bin:/snap/bin:$PATH

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# Aliases command line
alias ls='colorls -l --sort-dirs'
alias la='colorls -A --sort-dirs'
alias ll='colorls -lA --sort-dirs'
alias tree='colorls --tree --sort-dirs'
alias gs='colorls --git-status --tree --sort-dirs'
alias vim='nvim'

# Plugins
eval "$(jump shell)"
eval "$(oh-my-posh init zsh --config ~/.oh-my-posh/themes/catppuccin.omp.json)"
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh
source ~/.zsh/zsh-syntax-highlightings/zsh-syntax-highlighting.zsh
catnap

# Created by pipx
export PATH="$PATH:/home/arenwald/.local/bin"

# Alias for Exegol
alias exegol='sudo -E /home/arenwald/.local/bin/exegol'
