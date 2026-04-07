if status is-interactive
    if command -sq catnap
        catnap
    end

    # Standard prompt setup - choosing starship as default since it's in your dotfiles.
    # To use oh-my-posh instead, comment starship and uncomment oh-my-posh.
    if command -sq starship
        starship init fish | source
    end
    # if command -sq oh-my-posh
    #     oh-my-posh init fish --config ~/.oh-my-posh/themes/catppuccin.omp.json | source
    # end

    # Helpful utility initialization
    if command -sq zoxide
        zoxide init fish | source
    end
end

# Add specific paths to PATH
fish_add_path -a $HOME/bin
fish_add_path -a /usr/local/bin
fish_add_path -a /snap/bin
fish_add_path -a $HOME/.local/bin
fish_add_path -a $HOME/.local/share/gem/ruby/3.4.0/bin

# Aliases
alias vim=nvim
alias ls=lsd
alias l='lsd -l'
alias la='lsd -a'
alias lla='lsd -la'
alias lt='lsd --tree'
alias exegol="sudo -E $HOME/.local/bin/exegol"

# Suppress default fish greeting
set fish_greeting
