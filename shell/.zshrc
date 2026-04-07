# Minimal .zshrc that forwards to fish shell if available
# This prevents being stuck in an unconfigured zsh shell while moving to fish.

# Launch fish if it's installed and we are in an interactive terminal
if [[ -x "$(command -v fish)" ]] && [[ -z "$BASH_EXECUTION_STRING" ]] && [[ $- == *i* ]]; then
    exec fish
fi

# Fallback (if fish is not present):
# You might want to manually set your path here if fish isn't installed.
export PATH="$HOME/bin:/usr/local/bin:/snap/bin:$HOME/.local/bin:$PATH"

alias ls='ls --color=auto'
