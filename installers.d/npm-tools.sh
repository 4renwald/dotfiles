#!/usr/bin/env bash

source "$INSTALLERS_DIR/_common.sh"
install_app_npm_tools() {
    [[ "${NPM_TOOLS_INSTALLED:-false}" == true ]] && return 0
    npm_global @google/gemini-cli @openai/codex tree-sitter-cli typescript opencode-ai && NPM_TOOLS_INSTALLED=true
}
