#!/usr/bin/env bash
set -euo pipefail

# ── Config ────────────────────────────────────────
DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$DOTFILES_DIR/packages"
LOGS_DIR="$DOTFILES_DIR/logs"
LOG_FILE="$LOGS_DIR/install-$(date +%Y%m%d_%H%M%S).log"
SYSTEM_DIR="$DOTFILES_DIR/system"
EXCLUDE_DIRS=(".git" "logs" "packages" "scripts")

# ── Theme ─────────────────────────────────────────
CLR_ACCENT="#f5c2e7"   # Pink — primary accent
CLR_ACCENT2="#b4befe"  # Lavender — secondary accent
CLR_BLUE="#89b4fa"     # Blue — info highlight
CLR_TEAL="#94e2d5"     # Teal — tertiary accent
CLR_SUCCESS="#a6e3a1"  # Green — success
CLR_ERROR="#f38ba8"    # Red — error / failure
CLR_WARN="#fab387"     # Peach — warning
CLR_DIM="#6c7086"      # Overlay0 — secondary text
CLR_TEXT="#cdd6f4"     # Text — primary body copy
CLR_CRUST="#11111b"    # Crust — badge foreground
CLR_SURFACE="#313244"  # Surface0 — muted backgrounds

ICON_INFO="ℹ"
ICON_SUCCESS="✓"
ICON_WARN="⚠"
ICON_ERROR="✗"
ICON_STEP="•"

export GUM_CHOOSE_CURSOR_FOREGROUND="$CLR_ACCENT"
export GUM_CHOOSE_HEADER_FOREGROUND="$CLR_BLUE"
export GUM_CHOOSE_ITEM_FOREGROUND="$CLR_TEXT"
export GUM_CHOOSE_SELECTED_FOREGROUND="$CLR_ACCENT"
export GUM_CHOOSE_CURSOR_PREFIX="▸ "
export GUM_CHOOSE_SELECTED_PREFIX="${ICON_SUCCESS} "
export GUM_CHOOSE_UNSELECTED_PREFIX="${ICON_STEP} "
export GUM_CONFIRM_PROMPT_FOREGROUND="$CLR_ACCENT"
export GUM_CONFIRM_SELECTED_FOREGROUND="$CLR_CRUST"
export GUM_CONFIRM_SELECTED_BACKGROUND="$CLR_SUCCESS"
export GUM_CONFIRM_UNSELECTED_FOREGROUND="$CLR_TEXT"
export GUM_CONFIRM_UNSELECTED_BACKGROUND="$CLR_SURFACE"
export GUM_CONFIRM_PADDING="0 1"
export GUM_SPIN_SPINNER_FOREGROUND="$CLR_ACCENT"
export GUM_SPIN_TITLE_FOREGROUND="$CLR_BLUE"
export GUM_SPIN_PADDING="0 1"

# Return success when a graphical Plasma session appears to be available.
is_plasma_session() {
    local desktop="${XDG_CURRENT_DESKTOP:-}"
    local session="${DESKTOP_SESSION:-}"
    local normalized=""

    normalized="${desktop,,} ${session,,}"
    [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || return 1
    [[ "$normalized" == *kde* || "$normalized" == *plasma* ]]
}

# Check whether a command exists.
have_command() {
    command -v "$1" >/dev/null 2>&1
}

# Return the available kwriteconfig command name.
get_kwriteconfig_command() {
    if have_command kwriteconfig6; then
        printf 'kwriteconfig6\n'
        return 0
    fi

    if have_command kwriteconfig5; then
        printf 'kwriteconfig5\n'
        return 0
    fi

    return 1
}

# Return the available qdbus command name.
get_qdbus_command() {
    if have_command qdbus6; then
        printf 'qdbus6\n'
        return 0
    fi

    if have_command qdbus; then
        printf 'qdbus\n'
        return 0
    fi

    return 1
}

# Return the available kpackagetool command name.
get_kpackagetool_command() {
    if have_command kpackagetool6; then
        printf 'kpackagetool6\n'
        return 0
    fi

    if have_command kpackagetool5; then
        printf 'kpackagetool5\n'
        return 0
    fi

    if have_command kpackagetool; then
        printf 'kpackagetool\n'
        return 0
    fi

    return 1
}

# Return the available Spicetify command path.
get_spicetify_command() {
    if have_command spicetify; then
        printf 'spicetify\n'
        return 0
    fi

    if [[ -x "$HOME/.local/bin/spicetify" ]]; then
        printf '%s\n' "$HOME/.local/bin/spicetify"
        return 0
    fi

    return 1
}

# Initialize the repo-local log file.
init_logs() {
    mkdir -p "$LOGS_DIR"
    : > "$LOG_FILE"
}

# Append a timestamped line to the install log.
append_log_line() {
    local message="$1"

    if [[ ! -d "$LOGS_DIR" ]]; then
        return 0
    fi

    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" >> "$LOG_FILE"
}

# Clear the screen when running in an interactive terminal.
clear_if_tty() {
    if [[ -t 1 ]]; then
        clear >/dev/null 2>&1 || true
    fi
}

# Render a compact pill-shaped badge.
render_badge() {
    local color="$1"
    local label="$2"

    if have_command gum; then
        gum style \
            --foreground "$CLR_CRUST" --background "$color" \
            --bold --padding "0 1" \
            "$label"
        return 0
    fi

    printf '%s\n' "$label"
}

# Render a single-line notice with a colored badge.
render_notice() {
    local color="$1"
    local label="$2"
    shift 2

    if have_command gum; then
        printf '%s %s\n' \
            "$(render_badge "$color" "$label")" \
            "$(gum style --foreground "$CLR_TEXT" "$*")"
        return 0
    fi

    printf '%s %s\n' "$label" "$*" >&2
}

# Print a leveled log message with a fallback before gum exists.
log_message() {
    local level="$1"
    local prefix="$2"
    local badge_color="$CLR_BLUE"
    local badge_label=""
    shift 2

    if [[ -n "$prefix" ]]; then
        append_log_line "[$level] $prefix $*"
    else
        append_log_line "[$level] $*"
    fi

    case "$level" in
        info)
            if [[ -n "$prefix" ]]; then
                badge_color="$CLR_SUCCESS"
                badge_label="${prefix} DONE"
            else
                badge_color="$CLR_BLUE"
                badge_label="${ICON_INFO} INFO"
            fi
            ;;
        warn)
            badge_color="$CLR_WARN"
            badge_label="${ICON_WARN} WARN"
            ;;
        error)
            badge_color="$CLR_ERROR"
            badge_label="${ICON_ERROR} ERROR"
            ;;
        *)
            badge_color="$CLR_DIM"
            badge_label="$level"
            ;;
    esac

    if have_command gum; then
        if [[ -n "$prefix" ]]; then
            printf '\n'
        fi
        render_notice "$badge_color" "$badge_label" "$*"
        return 0
    fi

    if [[ -n "$prefix" ]]; then
        printf '[%s] %s %s\n' "$level" "$prefix" "$*" >&2
    else
        printf '[%s] %s\n' "$level" "$*" >&2
    fi
}

# Log an informational message.
info() {
    log_message info "" "$@"
}

# Log a warning message.
warn() {
    log_message warn "" "$@"
}

# Log an error message.
error() {
    log_message error "" "$@"
}

# Log a success message.
success() {
    log_message info "$ICON_SUCCESS" "$@"
}

# Exit with an error message.
die() {
    error "$@"
    exit 1
}

# Trim leading and trailing whitespace from a string.
trim_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s\n' "$value"
}

# Minify a JSON file into a single-line string.
json_minify_file() {
    local json_file="$1"

    tr -d '\r\n' < "$json_file"
}

# Join an array with a delimiter.
join_by() {
    local delimiter="$1"
    local result=""
    local item=""
    local first=true
    shift

    for item in "$@"; do
        if [[ "$first" == true ]]; then
            result="$item"
            first=false
        else
            result+="$delimiter$item"
        fi
    done

    printf '%s\n' "$result"
}

# Check whether a value already exists in an array.
array_contains() {
    local needle="$1"
    shift
    local candidate=""

    for candidate in "$@"; do
        if [[ "$candidate" == "$needle" ]]; then
            return 0
        fi
    done

    return 1
}

# Return success when a directory name is excluded from discovery.
is_excluded_dir() {
    local candidate="$1"
    local excluded=""

    for excluded in "${EXCLUDE_DIRS[@]}"; do
        if [[ "$candidate" == "$excluded" ]]; then
            return 0
        fi
    done

    return 1
}

# Prompt for confirmation, falling back before gum is installed.
confirm_action() {
    local prompt="$1"
    local reply=""

    if have_command gum; then
        gum confirm "$prompt"
        return $?
    fi

    printf '%s [y/N]: ' "$prompt" >&2
    read -r reply || true
    [[ "$reply" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]
}

# Render a safe shell command string for logging.
format_command() {
    local quoted=""
    local result=()

    for quoted in "$@"; do
        result+=("$(printf '%q' "$quoted")")
    done

    printf '%s\n' "${result[*]}"
}

# Return success when the first command token matches a shell function.
command_is_shell_function() {
    local candidate="${1:-}"

    [[ -n "$candidate" ]] || return 1
    declare -F "$candidate" >/dev/null 2>&1
}

# Return a styled spinner title.
format_spinner_title() {
    local title="$1"

    if have_command gum; then
        printf '%s' "$(gum style --foreground "$CLR_TEXT" --bold "$title")"
        return 0
    fi

    printf '%s' "$title"
}

# Run a logged command with an optional spinner.
run_logged_command() {
    local -a command=("$@")

    append_log_line "RUN $(format_command "${command[@]}")"

    if command_is_shell_function "${command[0]}"; then
        "${command[@]}" >> "$LOG_FILE" 2>&1
        return $?
    fi

    if have_command gum && [[ -t 1 ]] && [[ -n "${INSTALLER_SPIN_TITLE:-}" ]]; then
        gum spin --spinner dot \
            --title "$(format_spinner_title "$INSTALLER_SPIN_TITLE")" \
            -- bash -lc 'log_file="$1"; shift; exec "$@" >>"$log_file" 2>&1' bash "$LOG_FILE" "${command[@]}"
        return $?
    fi

    "${command[@]}" >> "$LOG_FILE" 2>&1
}

# Run a logged command in a specific directory without a spinner.
run_logged_command_in_dir() {
    local workdir="$1"
    shift
    local -a command=("$@")

    append_log_line "RUN (cd $workdir && $(format_command "${command[@]}"))"

    if have_command gum && [[ -t 1 ]] && [[ -n "${INSTALLER_SPIN_TITLE:-}" ]] && ! command_is_shell_function "${command[0]}"; then
        gum spin --spinner dot \
            --title "$(format_spinner_title "$INSTALLER_SPIN_TITLE")" \
            -- bash -lc 'workdir="$1"; log_file="$2"; shift 2; cd "$workdir"; exec "$@" >>"$log_file" 2>&1' bash "$workdir" "$LOG_FILE" "${command[@]}"
        return $?
    fi

    (
        cd "$workdir"
        "${command[@]}" >> "$LOG_FILE" 2>&1
    )
}

# Run a logged command with an explicit spinner title.
run_logged_command_with_title() {
    local INSTALLER_SPIN_TITLE="$1"
    shift

    run_logged_command "$@"
}

# Run a logged command in a specific directory with an explicit spinner title.
run_logged_command_in_dir_with_title() {
    local INSTALLER_SPIN_TITLE="$1"
    local workdir="$2"
    shift 2

    run_logged_command_in_dir "$workdir" "$@"
}

# Run a PlasmaShell JavaScript snippet and return its stdout.
run_plasma_script() {
    local script="$1"
    local qdbus_bin=""

    qdbus_bin="$(get_qdbus_command)" || return 1
    append_log_line "RUN $qdbus_bin org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript <script>"
    "$qdbus_bin" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" 2>>"$LOG_FILE"
}

# Print a task header for a concrete install stage.
show_task_header() {
    printf '\n'
    gum style \
        --foreground "$CLR_ACCENT2" --border-foreground "$CLR_ACCENT2" --border rounded \
        --bold --padding "0 2" \
        "$1"
}

# Print the status word for a task line.
print_task_status() {
    local status="$1"
    local color="$2"
    local symbol=""

    case "$status" in
        OK)      symbol="✓" ;;
        FAILED)  symbol="✗" ;;
        MISSING) symbol="?" ;;
        *)       symbol="·" ;;
    esac

    if have_command gum; then
        gum style \
            --foreground "$CLR_CRUST" --background "$color" \
            --bold --padding "0 1" \
            "${symbol} ${status}"
        return 0
    fi

    printf '%s %s\n' "$symbol" "$status"
}

# Print one completed task line with its final status.
print_task_result() {
    local status="$1"
    local color="$2"
    local label="$3"

    if have_command gum; then
        printf '%s %s\n' \
            "$(print_task_status "$status" "$color")" \
            "$(gum style --foreground "$CLR_TEXT" "$label")"
        return 0
    fi

    printf '%s %s\n' "$(print_task_status "$status" "$color")" "$label"
}

# Run a concrete task and show OK/FAILED inline.
run_task_step() {
    local label="$1"
    shift
    local -a command=("$@")

    if [[ -z "${INSTALLER_SPIN_TITLE:-}" ]]; then
        local INSTALLER_SPIN_TITLE="$label"
    fi

    append_log_line "TASK START $label"

    if run_logged_command "${command[@]}"; then
        append_log_line "TASK OK $label"
        print_task_result "OK" "$CLR_SUCCESS" "$label"
        return 0
    fi

    append_log_line "TASK FAILED $label"
    print_task_result "FAILED" "$CLR_ERROR" "$label"
    return 1
}

# Run one task step with an explicit spinner title.
run_task_step_with_title() {
    local INSTALLER_SPIN_TITLE="$1"
    shift

    run_task_step "$@"
}

# Show a styled section title.
show_section() {
    printf '\n'
    gum style \
        --foreground "$CLR_ACCENT" --border-foreground "$CLR_ACCENT2" --border double \
        --bold --padding "0 2" --margin "1 0 0 0" \
        "$1"
}

# Print the installer banner.
show_banner() {
    local title_card=""
    local context_card=""

    title_card="$(gum style \
        --foreground "$CLR_ACCENT" --border-foreground "$CLR_ACCENT" --border double \
        --align center --width 36 --padding "1 4" \
        'dotfiles' \
        'installer')"

    context_card="$(gum style \
        --foreground "$CLR_BLUE" --border-foreground "$CLR_BLUE" --border rounded \
        --align center --width 36 --padding "1 3" \
        'CachyOS / Arch Linux' \
        "$(gum style --foreground "$CLR_DIM" 'gum-powered setup flow')")"

    printf '\n'
    gum join --horizontal "$title_card" "$context_card"
}

# Print a short introduction block before the review screen.
show_intro_panel() {
    local markdown=""

    markdown="$(printf '# Install Session\n- Review the plan before changes are applied\n- Full command output is written to `%s`\n' "$LOG_FILE")"
    printf '\n'
    gum format -- "$markdown"
}

# Ensure the script is running on an Arch-based system with pacman.
ensure_arch_system() {
    if [[ ! -f /etc/arch-release ]] && ! have_command pacman; then
        die "This installer only supports Arch-based systems with pacman."
    fi

    if ! have_command pacman; then
        die "pacman is required. This installer only supports Arch-based systems."
    fi
}

# Request sudo credentials before package installation begins.
ensure_sudo_ready() {
    info "Requesting sudo credentials before package installation."
    append_log_line "RUN sudo -v"

    if sudo -v; then
        success "sudo credentials ready."
        return 0
    fi

    error "sudo authentication failed."
    return 1
}

# Install gum with the available package manager.
install_gum() {
    if have_command pacman; then
        info "Installing gum with pacman."
        run_logged_command_with_title "Installing gum with pacman" sudo pacman -S --needed --noconfirm gum
        return 0
    fi

    if have_command paru; then
        info "Installing gum with paru."
        run_logged_command_with_title "Installing gum with paru" paru -S --needed --noconfirm gum
        return 0
    fi

    die "Could not install gum because neither pacman nor paru is available."
}

# Ensure gum is installed before the UI starts.
ensure_gum() {
    if have_command gum; then
        return 0
    fi

    warn "gum is required to run this installer."
    if ! confirm_action "Install gum now?"; then
        die "gum is required at runtime."
    fi

    install_gum

    if ! have_command gum; then
        die "gum installation did not succeed."
    fi

    success "gum is available."
}

# Install paru from a prepared temporary directory.
install_paru_from_dir() {
    local temp_dir="$1"

    info "Installing paru from the AUR."
    run_logged_command_with_title "Installing paru build dependencies" sudo pacman -S --needed --noconfirm base-devel git
    run_logged_command_with_title "Cloning paru from the AUR" git clone --depth 1 https://aur.archlinux.org/paru.git "$temp_dir/paru"
    run_logged_command_in_dir_with_title "Building and installing paru" "$temp_dir/paru" makepkg -si --noconfirm
}

# Ensure paru is available for AUR package installs.
ensure_paru() {
    local temp_dir=""

    if have_command paru; then
        return 0
    fi

    warn "AUR packages were detected and paru is required."
    if ! confirm_action "Install paru now?"; then
        error "paru is required to continue with AUR packages."
        return 1
    fi

    temp_dir="$(mktemp -d)"
    if ! install_paru_from_dir "$temp_dir"; then
        rm -rf -- "$temp_dir"
        error "paru installation did not succeed."
        return 1
    fi
    rm -rf -- "$temp_dir"

    if ! have_command paru; then
        error "paru installation did not succeed."
        return 1
    fi

    success "paru is available."
}

# Discover package groups from packages/*.txt.
discover_package_groups() {
    local package_file=""

    if [[ ! -d "$PACKAGES_DIR" ]]; then
        return 0
    fi

    while IFS= read -r package_file; do
        printf '%s\n' "${package_file%.txt}"
    done < <(find "$PACKAGES_DIR" -maxdepth 1 -type f -name '*.txt' -printf '%f\n' | sort)
}

# Read package names from a package group file.
read_package_group() {
    local package_file="$1"
    local line=""
    local trimmed=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        trimmed="$(trim_whitespace "$line")"

        if [[ -z "$trimmed" || "${trimmed:0:1}" == "#" ]]; then
            continue
        fi

        printf '%s\n' "$trimmed"
    done < "$package_file"
}

# Count the packages in one package group.
count_packages_in_group() {
    local group="$1"
    local count=0
    local package=""

    while IFS= read -r package; do
        [[ -n "$package" ]] || continue
        count=$((count + 1))
    done < <(read_package_group "$PACKAGES_DIR/$group.txt")

    printf '%s\n' "$count"
}

# Count unique packages across all package groups.
count_unique_packages() {
    local -a groups=()
    local -a unique_packages=()
    local group=""
    local package=""

    mapfile -t groups < <(discover_package_groups)
    for group in "${groups[@]}"; do
        while IFS= read -r package; do
            [[ -n "$package" ]] || continue
            if ! array_contains "$package" "${unique_packages[@]}"; then
                unique_packages+=("$package")
            fi
        done < <(read_package_group "$PACKAGES_DIR/$group.txt")
    done

    printf '%s\n' "${#unique_packages[@]}"
}

# Discover top-level config directories with a .target file.
discover_config_dirs() {
    local dir=""
    local dir_name=""

    for dir in "$DOTFILES_DIR"/*; do
        [[ -d "$dir" ]] || continue
        dir_name="$(basename "$dir")"

        if is_excluded_dir "$dir_name"; then
            continue
        fi

        if [[ -f "$dir/.target" ]]; then
            printf '%s\n' "$dir_name"
        fi
    done | sort
}

# Collapse a config repository path into a deployable unit path.
config_unit_from_relative_path() {
    local relative_path="$1"
    local -a parts=()

    IFS='/' read -r -a parts <<< "$relative_path"
    if ((${#parts[@]} == 0)); then
        return 0
    fi

    case "${parts[0]}" in
        ".config")
            if ((${#parts[@]} >= 2)); then
                printf '.config/%s\n' "${parts[1]}"
            else
                printf '.config\n'
            fi
            ;;
        ".local")
            if ((${#parts[@]} >= 3)); then
                printf '.local/%s/%s\n' "${parts[1]}" "${parts[2]}"
            elif ((${#parts[@]} >= 2)); then
                printf '.local/%s\n' "${parts[1]}"
            else
                printf '.local\n'
            fi
            ;;
        *)
            printf '%s\n' "${parts[0]}"
            ;;
    esac
}

# Discover deployable config units inside a config category.
discover_config_units() {
    local config_name="$1"
    local config_dir="$DOTFILES_DIR/$config_name"
    local path=""
    local relative_path=""

    if [[ ! -d "$config_dir" ]]; then
        return 0
    fi

    while IFS= read -r -d '' path; do
        relative_path="${path#"$config_dir"/}"
        if [[ "$relative_path" == ".target" ]]; then
            continue
        fi

        config_unit_from_relative_path "$relative_path"
    done < <(find "$config_dir" -mindepth 1 ! -name '.target' \( -type f -o -type l \) -print0) | sort -u
}

# Expand $HOME or ~ inside a target path without eval.
expand_target_path() {
    local raw_target="$1"
    local expanded=""

    expanded="${raw_target//\$HOME/$HOME}"

    if [[ "$expanded" == \~ ]]; then
        expanded="$HOME"
    elif [[ "$expanded" == \~/* ]]; then
        expanded="$HOME/${expanded#~/}"
    fi

    printf '%s\n' "$expanded"
}

# Read and normalize a config directory target path.
read_target_path() {
    local config_dir="$1"
    local raw_target=""

    if [[ ! -f "$config_dir/.target" ]]; then
        return 1
    fi

    read -r raw_target < "$config_dir/.target" || true
    raw_target="$(trim_whitespace "$raw_target")"

    if [[ -z "$raw_target" ]]; then
        return 1
    fi

    expand_target_path "$raw_target"
}

# Count the deployable units in one config category.
count_config_units() {
    local config_name="$1"
    local count=0
    local unit=""

    while IFS= read -r unit; do
        [[ -n "$unit" ]] || continue
        count=$((count + 1))
    done < <(discover_config_units "$config_name")

    printf '%s\n' "$count"
}

# Render the review screen markdown.
render_review_markdown() {
    local -a package_groups=()
    local -a config_dirs=()
    local group=""
    local config_name=""
    local target_root=""
    local package_count=""
    local unit_count=""

    mapfile -t package_groups < <(discover_package_groups)
    mapfile -t config_dirs < <(discover_config_dirs)

    printf '## Package Groups\n\n'

    if ((${#package_groups[@]} == 0)); then
        printf -- '- No package groups found\n'
    else
        for group in "${package_groups[@]}"; do
            package_count="$(count_packages_in_group "$group")"
            printf -- '- **%s**: %s packages\n' "$group" "$package_count"
        done
    fi

    printf '\n## Configs\n\n'

    if ((${#config_dirs[@]} == 0)); then
        printf -- '- No config directories found\n'
    else
        for config_name in "${config_dirs[@]}"; do
            unit_count="$(count_config_units "$config_name")"
            if ! target_root="$(read_target_path "$DOTFILES_DIR/$config_name")"; then
                target_root="invalid target"
            fi
            printf -- "- **%s** -> \`%s\`: %s deploy units\n" "$config_name" "$target_root" "$unit_count"
        done
    fi

}

# Show a review screen for the full install plan.
show_review_screen() {
    local -a package_groups=()
    local -a config_dirs=()
    local package_group_count=0
    local config_dir_count=0
    local unique_package_count=0
    local total_config_units=0
    local config_name=""
    local intro=""
    local markdown=""

    mapfile -t package_groups < <(discover_package_groups)
    mapfile -t config_dirs < <(discover_config_dirs)

    package_group_count="${#package_groups[@]}"
    config_dir_count="${#config_dirs[@]}"
    unique_package_count="$(count_unique_packages)"

    for config_name in "${config_dirs[@]}"; do
        total_config_units=$((total_config_units + $(count_config_units "$config_name")))
    done

    intro="$(printf '# Install Review\nReview the package groups and config targets below before continuing.\n')"
    markdown="$(render_review_markdown)"

    printf '\n'
    gum join --vertical \
        "$(gum format -- "$intro")" \
        "$(gum join --horizontal \
            "$(gum style --foreground "$CLR_ACCENT" --border-foreground "$CLR_ACCENT" --border rounded --width 22 --align center --padding '1 2' 'Package Groups' "$package_group_count")" \
            "$(gum style --foreground "$CLR_BLUE" --border-foreground "$CLR_BLUE" --border rounded --width 22 --align center --padding '1 2' 'Unique Packages' "$unique_package_count")" \
            "$(gum style --foreground "$CLR_TEAL" --border-foreground "$CLR_TEAL" --border rounded --width 22 --align center --padding '1 2' 'Config Groups' "$config_dir_count")" \
            "$(gum style --foreground "$CLR_ACCENT2" --border-foreground "$CLR_ACCENT2" --border rounded --width 22 --align center --padding '1 2' 'Config Units' "$total_config_units")")" \
        "$(gum format -- "$markdown")"
}

# Show a batch summary for one operation type.
show_summary() {
    local title="$1"
    local success_count="$2"
    local success_list="$3"
    local failure_count="$4"
    local failure_list="$5"
    local success_color="$CLR_SUCCESS"
    local failure_color="$CLR_ERROR"
    local markdown=""

    if [[ "$success_count" -eq 0 ]]; then
        success_color="$CLR_DIM"
    fi

    if [[ "$failure_count" -eq 0 ]]; then
        failure_color="$CLR_DIM"
    fi

    printf '\n'
    gum join --vertical \
        "$(gum style --foreground "$CLR_ACCENT" --border-foreground "$CLR_ACCENT" --border rounded --bold --padding '0 2' "$title")" \
        "$(gum join --horizontal \
            "$(gum style --foreground "$success_color" --border-foreground "$success_color" --border rounded --width 22 --align center --padding '1 2' 'Succeeded' "$success_count")" \
            "$(gum style --foreground "$failure_color" --border-foreground "$failure_color" --border rounded --width 22 --align center --padding '1 2' 'Failed' "$failure_count")")"

    if [[ -n "$success_list" ]]; then
        markdown+=$(printf -- '- **Succeeded**: `%s`\n' "$success_list")
    else
        markdown+=$(printf -- '- **Succeeded**: `none`\n')
    fi

    if [[ -n "$failure_list" ]]; then
        markdown+=$(printf -- '- **Failed**: `%s`\n' "$failure_list")
    else
        markdown+=$(printf -- '- **Failed**: `none`\n')
    fi

    gum format -- "$markdown"
}

# Install every package in one group.
install_package_group() {
    local group="$1"
    local -a packages=()
    local package=""
    local paru_ready=false
    local failed=false

    if [[ -z "$group" || ! -f "$PACKAGES_DIR/$group.txt" ]]; then
        error "Package group '$group' does not exist."
        return 1
    fi

    mapfile -t packages < <(read_package_group "$PACKAGES_DIR/$group.txt")
    if ((${#packages[@]} == 0)); then
        warn "Package group '$group' is empty."
        return 1
    fi

    show_task_header "Installing ${group} packages..."

    for package in "${packages[@]}"; do
        if [[ "$package" == "openai-codex" ]]; then
            if ! prepare_openai_codex_install; then
                error "Could not prepare the existing Codex install for pacman."
                failed=true
                continue
            fi
        fi

        if [[ "$package" == "spicetify-cli" ]]; then
            if ! run_task_step_with_title "Installing Spicetify CLI" "$package" install_spicetify_cli; then
                error "The official Spicetify CLI install failed."
                failed=true
            fi
            continue
        fi

        if pacman -Si "$package" >/dev/null 2>&1; then
            if ! run_task_step_with_title "Installing $package" "$package" sudo pacman -S --needed --noconfirm "$package"; then
                error "pacman failed while installing '$package' from '$group'."
                failed=true
            fi
            continue
        fi

        if [[ "$paru_ready" == false ]]; then
            if ! ensure_paru; then
                error "paru is required before '$package' can be installed."
                failed=true
                continue
            fi
            paru_ready=true
        fi

        if paru -Si "$package" >/dev/null 2>&1; then
            if ! run_task_step_with_title "Installing $package from the AUR" "$package" paru -S --needed --noconfirm "$package"; then
                error "paru failed while installing '$package' from '$group'."
                failed=true
            fi
        else
            append_log_line "TASK FAILED $package"
            print_task_result "MISSING" "$CLR_WARN" "$package"
            warn "Unknown package '$package' in '$group'."
            failed=true
        fi
    done

    if [[ "$failed" == true ]]; then
        return 1
    fi

    success "Installed package group '$group'."
}

# Remove an unmanaged npm-based Codex install so pacman can install openai-codex cleanly.
prepare_openai_codex_install() {
    local codex_bin="/usr/bin/codex"
    local codex_dir="/usr/lib/node_modules/@openai/codex"
    local codex_target=""

    if [[ ! -e "$codex_bin" && ! -d "$codex_dir" ]]; then
        return 0
    fi

    if pacman -Qo "$codex_bin" >/dev/null 2>&1 || pacman -Qo "$codex_dir" >/dev/null 2>&1; then
        return 0
    fi

    codex_target="$(readlink -f "$codex_bin" 2>/dev/null || true)"
    if [[ -n "$codex_target" && "$codex_target" != "$codex_dir"* ]] && [[ ! -d "$codex_dir" ]]; then
        append_log_line "Unmanaged /usr/bin/codex exists but did not match the expected npm Codex layout."
        return 1
    fi

    append_log_line "Removing unmanaged npm-based Codex install from /usr so pacman can install openai-codex."
    [[ ! -e "$codex_bin" ]] || run_logged_command sudo rm -f "$codex_bin" || return 1
    [[ ! -d "$codex_dir" ]] || run_logged_command sudo rm -rf "$codex_dir" || return 1

    if [[ -d /usr/lib/node_modules/@openai ]]; then
        run_logged_command sudo rmdir /usr/lib/node_modules/@openai || true
    fi

    return 0
}

# Install Spicetify from the upstream release archive because the AUR package is currently broken.
install_spicetify_cli() {
    local release_api="https://api.github.com/repos/spicetify/cli/releases/latest"
    local release_json=""
    local tag=""
    local target=""
    local download_url=""
    local temp_dir=""
    local archive_path=""
    local extract_dir=""
    local install_dir="$HOME/.local/share/spicetify-cli"
    local bin_dir="$HOME/.local/bin"

    if ! have_command curl; then
        append_log_line "curl is unavailable; cannot install Spicetify CLI from upstream."
        return 1
    fi

    if ! have_command tar; then
        append_log_line "tar is unavailable; cannot install Spicetify CLI from upstream."
        return 1
    fi

    case "$(uname -sm)" in
        "Linux x86_64")
            target="linux-amd64"
            ;;
        "Linux aarch64")
            target="linux-arm64"
            ;;
        *)
            append_log_line "Unsupported platform for Spicetify CLI: $(uname -sm)"
            return 1
            ;;
    esac

    append_log_line "RUN curl -fsSL $release_api"
    release_json="$(curl -fsSL "$release_api" 2>>"$LOG_FILE")" || return 1
    tag="$(printf '%s\n' "$release_json" | sed -n 's/.*"tag_name": "v\{0,1\}\([^"]*\)".*/\1/p' | head -n 1)"

    if [[ -z "$tag" ]]; then
        append_log_line "Could not determine the latest Spicetify CLI release tag."
        return 1
    fi

    temp_dir="$(mktemp -d)"
    archive_path="$temp_dir/spicetify.tar.gz"
    extract_dir="$temp_dir/extract"
    download_url="https://github.com/spicetify/cli/releases/download/v${tag}/spicetify-${tag}-${target}.tar.gz"

    run_logged_command install -d -m 0755 "$extract_dir" || {
        rm -rf -- "$temp_dir"
        return 1
    }

    if ! run_logged_command_with_title "Downloading Spicetify CLI v$tag" curl -fsSL --output "$archive_path" "$download_url"; then
        rm -rf -- "$temp_dir"
        return 1
    fi

    if ! run_logged_command_with_title "Extracting Spicetify CLI v$tag" tar -xzf "$archive_path" -C "$extract_dir"; then
        rm -rf -- "$temp_dir"
        return 1
    fi

    if [[ ! -x "$extract_dir/spicetify" ]]; then
        append_log_line "The Spicetify archive did not contain an executable spicetify binary."
        rm -rf -- "$temp_dir"
        return 1
    fi

    run_logged_command rm -rf "$install_dir" || {
        rm -rf -- "$temp_dir"
        return 1
    }
    run_logged_command install -d -m 0755 "$install_dir" || {
        rm -rf -- "$temp_dir"
        return 1
    }
    run_logged_command cp -a "$extract_dir/." "$install_dir/" || {
        rm -rf -- "$temp_dir"
        return 1
    }
    run_logged_command install -d -m 0755 "$bin_dir" || {
        rm -rf -- "$temp_dir"
        return 1
    }
    run_logged_command ln -sf "$install_dir/spicetify" "$bin_dir/spicetify" || {
        rm -rf -- "$temp_dir"
        return 1
    }

    append_log_line "Installed Spicetify CLI v$tag into $install_dir"
    rm -rf -- "$temp_dir"
}

# Install the Catppuccin theme assets into the local Spicetify themes directory.
install_spicetify_catppuccin_theme() {
    local temp_dir=""
    local repo_dir=""
    local theme_source_dir=""
    local theme_target_dir="$HOME/.config/spicetify/Themes/catppuccin"

    if ! have_command git; then
        append_log_line "git is unavailable; cannot install the Catppuccin Spicetify theme."
        return 1
    fi

    temp_dir="$(mktemp -d)"
    repo_dir="$temp_dir/catppuccin-spicetify"
    theme_source_dir="$repo_dir/catppuccin"

    run_logged_command_with_title "Cloning the Catppuccin Spicetify theme" git clone --depth 1 https://github.com/catppuccin/spicetify.git "$repo_dir"

    if [[ ! -f "$theme_source_dir/user.css" || ! -f "$theme_source_dir/color.ini" || ! -f "$theme_source_dir/theme.js" ]]; then
        append_log_line "The Catppuccin Spicetify repo did not contain the expected theme files."
        rm -rf -- "$temp_dir"
        return 1
    fi

    run_logged_command install -d -m 0755 "$HOME/.config/spicetify/Themes" || {
        rm -rf -- "$temp_dir"
        return 1
    }
    run_logged_command rm -rf "$theme_target_dir" || {
        rm -rf -- "$temp_dir"
        return 1
    }
    run_logged_command cp -a "$theme_source_dir" "$theme_target_dir" || {
        rm -rf -- "$temp_dir"
        return 1
    }

    rm -rf -- "$temp_dir"
}

# Point Spicetify at the Catppuccin Mocha theme defaults.
configure_spicetify_catppuccin_theme() {
    local spicetify_bin=""

    spicetify_bin="$(get_spicetify_command)" || {
        append_log_line "Spicetify is unavailable; cannot configure the Catppuccin theme."
        return 1
    }

    run_logged_command_with_title "Configuring Spicetify for Catppuccin Mocha" \
        "$spicetify_bin" config \
        current_theme catppuccin \
        color_scheme mocha \
        inject_css 1 \
        inject_theme_js 1 \
        replace_colors 1 \
        overwrite_assets 1
}

# Grant the current user group write access to Spotify's install directory for Spicetify.
ensure_spotify_write_access_for_spicetify() {
    local spotify_root="/opt/spotify"
    local spotify_apps="/opt/spotify/Apps"
    local primary_group=""

    if [[ ! -d "$spotify_root" || ! -d "$spotify_apps" ]]; then
        append_log_line "Spotify is not installed in /opt/spotify; cannot apply the Spicetify theme."
        return 1
    fi

    if [[ -w "$spotify_root" && -w "$spotify_apps" ]]; then
        return 0
    fi

    primary_group="$(id -gn)"
    run_logged_command_with_title "Granting Spotify write access for Spicetify" sudo chgrp "$primary_group" "$spotify_root"
    run_logged_command sudo chgrp -R "$primary_group" "$spotify_apps"
    run_logged_command sudo chmod 775 "$spotify_root"
    run_logged_command sudo chmod -R 775 "$spotify_apps"
}

# Apply the configured Spicetify theme to the local Spotify install.
apply_spicetify_catppuccin_theme() {
    local spicetify_bin=""

    spicetify_bin="$(get_spicetify_command)" || {
        append_log_line "Spicetify is unavailable; cannot apply the Catppuccin theme."
        return 1
    }

    if [[ ! -f "$HOME/.config/spotify/prefs" ]]; then
        append_log_line "Spotify prefs are missing; launch Spotify once before applying the Spicetify theme."
        return 1
    fi

    pkill -x spotify >>"$LOG_FILE" 2>&1 || true
    run_logged_command_with_title "Applying the Spicetify Catppuccin theme" "$spicetify_bin" backup apply
}

# Install every discovered package group.
install_all_packages() {
    local -a package_groups=()
    local -a succeeded=()
    local -a failed=()
    local group=""

    mapfile -t package_groups < <(discover_package_groups)
    if ((${#package_groups[@]} == 0)); then
        warn "No package groups were found in $PACKAGES_DIR."
        return 0
    fi

    show_section "Installing Packages"
    if ! ensure_sudo_ready; then
        return 1
    fi

    for group in "${package_groups[@]}"; do
        if install_package_group "$group"; then
            succeeded+=("$group")
        else
            failed+=("$group")
        fi
    done

    show_summary \
        "Package Installation" \
        "${#succeeded[@]}" \
        "$(join_by ', ' "${succeeded[@]}")" \
        "${#failed[@]}" \
        "$(join_by ', ' "${failed[@]}")"

    ((${#failed[@]} == 0))
}

# Deploy one config unit to its configured destination.
deploy_config_unit() {
    local config_name="$1"
    local unit_path="$2"
    local config_dir="$DOTFILES_DIR/$config_name"
    local target_root=""
    local source_path=""
    local destination_path=""

    if ! target_root="$(read_target_path "$config_dir")"; then
        warn "Skipping '$config_name' because its .target file is missing or empty."
        return 1
    fi

    source_path="$config_dir/$unit_path"
    if [[ ! -e "$source_path" && ! -L "$source_path" ]]; then
        error "Config unit '$config_name/$unit_path' does not exist."
        return 1
    fi

    destination_path="$target_root/$unit_path"
    mkdir -p "$(dirname "$destination_path")"
    run_task_step "$unit_path" cp -rf "$source_path" "$(dirname "$destination_path")/"
}

# Deploy every unit inside one config category.
deploy_config_group() {
    local config_name="$1"
    local -a units=()

    if [[ -z "$config_name" || ! -d "$DOTFILES_DIR/$config_name" ]]; then
        error "Config directory '$config_name' does not exist."
        return 1
    fi

    mapfile -t units < <(discover_config_units "$config_name")
    if ((${#units[@]} == 0)); then
        warn "Config directory '$config_name' has no deployable units."
        return 1
    fi

    show_task_header "Deploying ${config_name} configs..."
    if ! deploy_config_group_units "$config_name" "${units[@]}"; then
        error "Failed to deploy '$config_name'."
        return 1
    fi

    success "Deployed config group '$config_name'."
}

# Deploy a list of config units for one config category.
deploy_config_group_units() {
    local config_name="$1"
    shift
    local unit=""
    local had_failure=false

    for unit in "$@"; do
        if ! deploy_config_unit "$config_name" "$unit"; then
            had_failure=true
        fi
    done

    if [[ "$had_failure" == true ]]; then
        return 1
    fi
}

# Deploy every discovered config category.
deploy_all_configs() {
    local -a config_dirs=()
    local -a succeeded=()
    local -a failed=()
    local config_name=""

    mapfile -t config_dirs < <(discover_config_dirs)
    if ((${#config_dirs[@]} == 0)); then
        warn "No config directories with .target files were found."
        return 0
    fi

    show_section "Deploying Configs"
    for config_name in "${config_dirs[@]}"; do
        if deploy_config_group "$config_name"; then
            succeeded+=("$config_name")
        else
            failed+=("$config_name")
        fi
    done

    show_summary \
        "Config Deployment" \
        "${#succeeded[@]}" \
        "$(join_by ', ' "${succeeded[@]}")" \
        "${#failed[@]}" \
        "$(join_by ', ' "${failed[@]}")"

    ((${#failed[@]} == 0))
}

# Show the final result screen.
show_final_screen() {
    local overall_success="$1"
    local status_color="$CLR_SUCCESS"
    local status_title="${ICON_SUCCESS} Install Complete"
    local status_body="Your dotfiles, packages, and follow-up tweaks are in place."

    printf '\n'
    if [[ "$overall_success" != true ]]; then
        status_color="$CLR_ERROR"
        status_title="${ICON_ERROR} Install Finished With Errors"
        status_body="Review the summaries above and the install log for details."
    fi

    gum join --vertical \
        "$(gum style \
            --foreground "$status_color" --border-foreground "$status_color" --border double \
            --align center --padding '1 4' --margin '1 0' \
            "$status_title" \
            '' \
            "$status_body")" \
        "$(gum style \
            --foreground "$CLR_DIM" --border-foreground "$CLR_DIM" --border rounded \
            --padding '0 2' \
            "Log → $LOG_FILE")"

    printf '\n'
}

# Return the ID of the first available Plasma panel.
get_primary_plasma_panel_id() {
    run_plasma_script '
var panelList = panels();
if (panelList.length === 0) {
    print("");
} else {
    print(panelList[0].id);
}
'
}

# Ensure the Panel Colorizer widget exists on the first Plasma panel.
ensure_panel_colorizer_widget() {
    run_plasma_script '
var panelList = panels();
if (panelList.length === 0) {
    print("");
} else {
    var panel = panelList[0];
    var widgets = panel.widgets();
    var widget = null;

    for (var i = 0; i < widgets.length; ++i) {
        if (widgets[i].type === "luisbocanegra.panel.colorizer") {
            widget = widgets[i];
            break;
        }
    }

    if (widget === null) {
        widget = panel.addWidget("luisbocanegra.panel.colorizer");
    }

    print(widget.id);
}
'
}

# Return the widget list for the first Plasma panel as JSON.
get_primary_panel_widgets_json() {
    run_plasma_script '
var panelList = panels();
if (panelList.length === 0) {
    print("[]");
} else {
    var widgets = panelList[0].widgets();
    var entries = [];

    for (var i = 0; i < widgets.length; ++i) {
        entries.push({
            id: widgets[i].id,
            name: widgets[i].type,
            title: widgets[i].title || "",
            icon: widgets[i].icon || "",
            inTray: false
        });
    }

    print(JSON.stringify(entries));
}
'
}

# Ask a running Panel Colorizer widget to reload its config.
reload_panel_colorizer_widget() {
    local widget_id="$1"

    run_plasma_script "
var panelList = panels();
if (panelList.length === 0) {
    print(\"\");
} else {
    var widgets = panelList[0].widgets();

    for (var i = 0; i < widgets.length; ++i) {
        if (String(widgets[i].id) === \"$widget_id\") {
            if (typeof widgets[i].reloadConfig === \"function\") {
                widgets[i].reloadConfig();
            }
            print(\"ok\");
            break;
        }
    }
}
"
}

# Install every qylock SDDM theme and keep a deterministic active default.
install_qylock_sddm_themes() {
    local temp_dir=""
    local repo_dir=""
    local themes_source_dir=""
    local theme_source_dir=""
    local theme_name=""
    local target_dir=""
    local active_theme="nier-automata"
    local qylock_conf="/etc/sddm.conf.d/00-qylock.conf"
    local legacy_conf="/etc/sddm.conf.d/00-nier-automata.conf"
    local -a installed_theme_names=()

    temp_dir="$(mktemp -d)"
    repo_dir="$temp_dir/qylock"
    themes_source_dir="$repo_dir/themes"

    run_logged_command_with_title "Cloning qylock SDDM themes" git clone --depth 1 https://github.com/Darkkal44/qylock "$repo_dir"

    if [[ ! -d "$themes_source_dir" ]]; then
        append_log_line "qylock clone did not contain a themes directory"
        rm -rf -- "$temp_dir"
        return 1
    fi

    for theme_source_dir in "$themes_source_dir"/*; do
        [[ -d "$theme_source_dir" ]] || continue
        [[ -f "$theme_source_dir/metadata.desktop" ]] || continue

        theme_name="${theme_source_dir##*/}"
        target_dir="/usr/share/sddm/themes/$theme_name"

        run_logged_command sudo install -d -m 0755 "$target_dir"
        run_logged_command_with_title "Installing qylock theme $theme_name" sudo cp -a "$theme_source_dir/." "$target_dir/"
        installed_theme_names+=("$theme_name")
    done

    if [[ "${#installed_theme_names[@]}" -eq 0 ]]; then
        append_log_line "qylock clone did not contain any installable SDDM themes"
        rm -rf -- "$temp_dir"
        return 1
    fi

    if [[ ! -f "$themes_source_dir/$active_theme/metadata.desktop" ]]; then
        active_theme="${installed_theme_names[0]}"
        append_log_line "qylock clone did not contain themes/nier-automata; using $active_theme as the active theme"
    fi

    run_logged_command sudo install -d -m 0755 /etc/sddm.conf.d
    run_logged_command sudo rm -f "$legacy_conf"

    append_log_line "Installed qylock themes: ${installed_theme_names[*]}"
    append_log_line "RUN write $qylock_conf"
    {
        printf '%s\n' "[Theme]" "Current=$active_theme" | sudo tee "$qylock_conf" >/dev/null
    } >> "$LOG_FILE" 2>&1

    QYLOCK_INSTALLED_THEME_COUNT="${#installed_theme_names[@]}"
    QYLOCK_ACTIVE_THEME="$active_theme"

    rm -rf -- "$temp_dir"
}

# Switch the display-manager alias to SDDM so the installed theme is used on the next boot.
activate_sddm_display_manager() {
    if ! have_command systemctl; then
        append_log_line "systemctl is unavailable; cannot switch the active display manager to SDDM."
        return 1
    fi

    if systemctl cat plasmalogin.service >/dev/null 2>&1; then
        run_logged_command sudo systemctl disable plasmalogin.service || true
    fi

    run_logged_command_with_title "Setting SDDM as the active display manager" sudo systemctl enable sddm.service --force
}

# Install the MCHOSE Ace 68 Turbo udev rule and reload the ruleset.
install_mchose_ace68turbo_udev_rule() {
    local source_rule="$SYSTEM_DIR/udev/rules.d/99-mchose-ace68turbo.rules"
    local target_rule="/etc/udev/rules.d/99-mchose-ace68turbo.rules"

    if [[ ! -f "$source_rule" ]]; then
        append_log_line "Missing udev rule source: $source_rule"
        return 1
    fi

    if ! have_command udevadm; then
        append_log_line "udevadm is unavailable; cannot install the Ace 68 Turbo rule."
        return 1
    fi

    run_logged_command_with_title "Installing the Ace 68 Turbo udev rule" sudo install -D -m 0644 "$source_rule" "$target_rule"
    run_logged_command sudo udevadm control --reload-rules
    run_logged_command sudo udevadm trigger
}

# Apply the Krohnkite gap settings.
apply_krohnkite_settings() {
    local kwriteconfig_bin=""
    local qdbus_bin=""

    kwriteconfig_bin="$(get_kwriteconfig_command)"
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Plugins --key krohnkiteEnabled true
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Script-krohnkite --key screenGapBetween 14
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Script-krohnkite --key screenGapTop 14
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Script-krohnkite --key screenGapRight 14
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Script-krohnkite --key screenGapBottom 14
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Script-krohnkite --key screenGapLeft 14

    if qdbus_bin="$(get_qdbus_command)" && is_plasma_session; then
        "$qdbus_bin" org.kde.KWin /KWin reconfigure >> "$LOG_FILE" 2>&1 || true
    fi
}

apply_kde_shortcuts() {
    local kwriteconfig_bin=""

    kwriteconfig_bin="$(get_kwriteconfig_command)"
    "$kwriteconfig_bin" --file "$HOME/.config/kglobalshortcutsrc" --group kwin --key KrohnkiteTileLayout ",none,Krohnkite: Tile Layout"
    "$kwriteconfig_bin" --file "$HOME/.config/kglobalshortcutsrc" --group kwin --key KrohnkiteQuarterLayout ",none,Krohnkite: Quarter Layout"
    "$kwriteconfig_bin" --file "$HOME/.config/kglobalshortcutsrc" --group kwin --key "Window Close" $'Meta+X\tAlt+F4,Meta+X\tAlt+F4,Close Window'
    rm -f "$HOME/.local/share/applications/com.mitchellh.ghostty-new-window.desktop"
    rm -f "$HOME/.local/share/applications/net.local.ghostty.desktop"
    rm -f "$HOME/.local/share/kglobalaccel/ghostty-shortcut.desktop"
}

reload_global_shortcuts() {
    if ! is_plasma_session; then
        append_log_line "Global shortcuts reload skipped because no active Plasma session was detected."
        return 1
    fi

    if have_command kbuildsycoca6; then
        run_logged_command_with_title "Refreshing KDE shortcut metadata" kbuildsycoca6 --noincremental || true
    elif have_command kbuildsycoca5; then
        run_logged_command_with_title "Refreshing KDE shortcut metadata" kbuildsycoca5 --noincremental || true
    fi

    if have_command kquitapp6; then
        kquitapp6 kglobalacceld >> "$LOG_FILE" 2>&1 || true
    elif have_command kquitapp5; then
        kquitapp5 kglobalacceld >> "$LOG_FILE" 2>&1 || true
    else
        pkill -x kglobalacceld >> "$LOG_FILE" 2>&1 || true
    fi

    if [[ -x /usr/lib/kglobalacceld ]]; then
        append_log_line "RUN setsid /usr/lib/kglobalacceld"
        setsid /usr/lib/kglobalacceld >> "$LOG_FILE" 2>&1 &
        sleep 1
        return 0
    fi

    append_log_line "Global shortcuts reload skipped because kglobalacceld was not found."
    return 1
}

# Pin the vendored KDE theme assets and UI defaults.
apply_kde_theme_defaults() {
    local kwriteconfig_bin=""

    kwriteconfig_bin="$(get_kwriteconfig_command)"
    mkdir -p "$HOME/.config/klassy"
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group General --key ColorScheme CatppuccinMochaLavender
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group General --key font "JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group General --key fixed "JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group General --key menuFont "JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group General --key toolBarFont "JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group General --key smallestReadableFont "JetBrainsMono Nerd Font,8,-1,5,50,0,0,0,0,0"
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group General --key taskbarFont "JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group Icons --key Theme Papirus-Dark
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group KDE --key LookAndFeelPackage Catppuccin-Mocha-Lavender
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group KDE --key widgetStyle kvantum
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group WM --key frame "137,180,250"
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group WM --key inactiveFrame "69,71,90"
    "$kwriteconfig_bin" --file "$HOME/.config/kdeglobals" --group WM --key activeFont "JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
    "$kwriteconfig_bin" --file "$HOME/.config/kcminputrc" --group Mouse --key cursorTheme capitaine-cursors
    "$kwriteconfig_bin" --file "$HOME/.config/plasmarc" --group Theme --key name default
    "$kwriteconfig_bin" --file "$HOME/.config/breezerc" --group Common --key OutlineEnabled true
    "$kwriteconfig_bin" --file "$HOME/.config/breezerc" --group Common --key OutlineIntensity OutlineHigh
    "$kwriteconfig_bin" --file "$HOME/.config/Kvantum/kvantum.kvconfig" --group General --key theme catppuccin-mocha-lavender
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Plugins --key better_blur_dxEnabled true
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Plugins --key blurEnabled true
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Plugins --key shapecornersEnabled true
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key ActiveOutlineAlpha 255
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key ActiveOutlineUseCustom true
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key DisableOutlineFullScreen false
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key DisableOutlineMaximize false
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key DisableOutlineTile false
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key InactiveCornerRadius 10
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key InactiveOutlineAlpha 96
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key InactiveOutlineColor "69,71,90"
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key InactiveOutlineThickness 1
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key InactiveOutlineUsePalette false
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key InactiveOutlineUseCustom true
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key UseNativeDecorationShadows false
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key IncludeDialogs true
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key IncludeNormalWindows true
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key OutlineColor "137,180,250"
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key OutlineThickness 3
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key ActiveOutlineUsePalette false
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key ShadowSize 0
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key Size 10
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group Round-Corners --key InactiveShadowSize 0
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group org.kde.kdecoration2 --key BorderSizeAuto false
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group org.kde.kdecoration2 --key BorderSize Tiny
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
    "$kwriteconfig_bin" --file "$HOME/.config/kwinrc" --group org.kde.kdecoration2 --key theme __aurorae__svg__CatppuccinMocha-Classic
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group ShadowStyle --key ShadowSize ShadowNone
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group ShadowStyle --key ShadowStrength 25
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group ButtonColors --key ButtonOverrideColorsActiveClose '{"BackgroundHover":[243,139,168],"BackgroundPress":[70,243,139,168],"IconHover":["TitleBarBackgroundAuto"],"IconNormal":[243,139,168],"IconPress":["TitleBarBackgroundAuto"],"OutlineHover":[243,139,168],"OutlinePress":[243,139,168]}'
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group ButtonColors --key ButtonOverrideColorsActiveMaximize '{"BackgroundHover":[166,227,161],"BackgroundPress":[70,166,227,161],"IconNormal":[166,227,161],"OutlineHover":[166,227,161],"OutlinePress":[166,227,161]}'
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group ButtonColors --key ButtonOverrideColorsActiveMinimize '{"BackgroundHover":[249,226,175],"BackgroundPress":[70,249,226,175],"IconNormal":[249,226,175],"OutlineHover":[249,226,175],"OutlinePress":[249,226,175]}'
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group ButtonColors --key ButtonOverrideColorsInactiveClose '{"BackgroundHover":[60,243,139,168],"BackgroundPress":[45,243,139,168],"IconHover":["TitleBarBackgroundAuto"],"IconNormal":[50,243,139,168],"IconPress":["TitleBarBackgroundAuto"],"OutlineHover":[60,243,139,168],"OutlinePress":[60,243,139,168]}'
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group ButtonColors --key ButtonOverrideColorsInactiveKeepAbove '{"IconHover":["TitleBarBackgroundAuto"],"IconPress":["TitleBarBackgroundAuto"]}'
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group ButtonColors --key ButtonOverrideColorsInactiveMaximize '{"BackgroundHover":[60,166,227,161],"BackgroundPress":[45,166,227,161],"IconHover":["TitleBarBackgroundAuto"],"IconNormal":[50,166,227,161],"IconPress":["TitleBarBackgroundAuto"],"OutlineHover":[60,166,227,161],"OutlinePress":[60,166,227,161]}'
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group ButtonColors --key ButtonOverrideColorsInactiveMinimize '{"BackgroundHover":[60,249,226,175],"BackgroundPress":[45,249,226,175],"IconHover":["TitleBarBackgroundAuto"],"IconNormal":[50,249,226,175],"IconPress":["TitleBarBackgroundAuto"],"OutlineHover":[249,226,175],"OutlinePress":[249,226,175]}'
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group WindowOutlineStyle --key WindowOutlineCustomColorActive "137,180,250"
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group WindowOutlineStyle --key WindowOutlineCustomColorInactive "69,71,90"
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group WindowOutlineStyle --key WindowOutlineCustomColorOpacityActive 100
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group WindowOutlineStyle --key WindowOutlineCustomColorOpacityInactive 45
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group WindowOutlineStyle --key WindowOutlineStyleActive WindowOutlineCustomColor
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group WindowOutlineStyle --key WindowOutlineStyleInactive WindowOutlineCustomColor
    "$kwriteconfig_bin" --file "$HOME/.config/klassy/klassyrc" --group WindowOutlineStyle --key WindowOutlineThickness 3
}

apply_papirus_folder_color() {
    if ! have_command papirus-folders; then
        append_log_line "papirus-folders is unavailable; skipping folder accent update."
        return 1
    fi

    run_logged_command_with_title "Updating the Papirus folder accent" sudo papirus-folders --theme Papirus-Dark --color cat-mocha-lavender --update-caches
}

apply_plasma_session_defaults() {
    local kwriteconfig_bin=""

    kwriteconfig_bin="$(get_kwriteconfig_command)"
    "$kwriteconfig_bin" --file "$HOME/.config/ksmserverrc" --group General --key loginMode emptySession
}

apply_performance_power_profile() {
    if ! have_command powerprofilesctl; then
        append_log_line "powerprofilesctl is unavailable; skipping power profile update."
        return 1
    fi

    if run_logged_command_with_title "Setting the power profile to performance" powerprofilesctl set performance; then
        return 0
    fi

    run_logged_command_with_title "Setting the power profile to performance" sudo powerprofilesctl set performance
}

reload_kwin_config() {
    local qdbus_bin=""

    if ! is_plasma_session; then
        append_log_line "KWin reload skipped because no active Plasma session was detected."
        return 1
    fi

    if ! qdbus_bin="$(get_qdbus_command)"; then
        append_log_line "KWin reload skipped because qdbus is unavailable."
        return 1
    fi

    run_logged_command_with_title "Reloading the KWin configuration" timeout 5s "$qdbus_bin" org.kde.KWin /KWin reconfigure
}

# Reload the Rounded Corners effect the same way its KCM Apply button does.
reload_shapecorners_effect() {
    local qdbus_bin=""
    local effect_name="kwin4_effect_shapecorners"

    if ! is_plasma_session; then
        append_log_line "Rounded Corners effect reload skipped because no active Plasma session was detected."
        return 1
    fi

    if ! qdbus_bin="$(get_qdbus_command)"; then
        append_log_line "Rounded Corners effect reload skipped because qdbus is unavailable."
        return 1
    fi

    append_log_line "RUN $qdbus_bin org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect $effect_name"
    "$qdbus_bin" org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect "$effect_name" >>"$LOG_FILE" 2>&1 || true

    append_log_line "RUN $qdbus_bin org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect $effect_name"
    "$qdbus_bin" org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "$effect_name" >>"$LOG_FILE" 2>&1 || true

    append_log_line "RUN $qdbus_bin org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect $effect_name"
    "$qdbus_bin" org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect "$effect_name" >>"$LOG_FILE" 2>&1
}

# Reload PlasmaShell so the vendored panel layout and plasmoids apply live.
reload_plasma_shell() {
    if ! is_plasma_session; then
        append_log_line "Plasma shell reload skipped because no active Plasma session was detected."
        return 1
    fi

    if ! have_command plasmashell; then
        append_log_line "Plasma shell reload skipped because plasmashell is unavailable."
        return 1
    fi

    if have_command kquitapp6; then
        kquitapp6 plasmashell >> "$LOG_FILE" 2>&1 || true
    elif have_command kquitapp5; then
        kquitapp5 plasmashell >> "$LOG_FILE" 2>&1 || true
    else
        pkill -x plasmashell >> "$LOG_FILE" 2>&1 || true
    fi

    sleep 2
    append_log_line "RUN setsid plasmashell --replace"
    setsid plasmashell --replace >> "$LOG_FILE" 2>&1 &
    sleep 2
}

# Set the default Omarchy Catppuccin wallpaper on every Plasma desktop.
apply_omarchy_wallpaper() {
    local wallpaper_path="$HOME/.local/share/wallpapers/omarchy-catppuccin/1-totoro.png"

    if [[ ! -f "$wallpaper_path" ]]; then
        append_log_line "Omarchy wallpaper missing: $wallpaper_path"
        return 1
    fi

    if ! get_qdbus_command >/dev/null 2>&1 || ! is_plasma_session; then
        append_log_line "Plasma wallpaper update requires an active Plasma session."
        return 1
    fi

    run_plasma_script "
var wallpaper = \"file://$wallpaper_path\";
var desktopsList = desktops();
for (var i = 0; i < desktopsList.length; ++i) {
    var desktop = desktopsList[i];
    desktop.wallpaperPlugin = \"org.kde.image\";
    desktop.currentConfigGroup = [\"Wallpaper\", \"org.kde.image\", \"General\"];
    desktop.writeConfig(\"Image\", wallpaper);
    desktop.writeConfig(\"FillMode\", 6);
}
" >/dev/null
}

# Ensure a Panel Colorizer preset exists in the applet's native presets directory layout.
resolve_panel_colorizer_preset_dir() {
    local requested_path="$1"
    local preset_root="$HOME/.config/panel-colorizer/presets"
    local preset_dir=""
    local preset_name=""

    if [[ -d "$requested_path" && -f "$requested_path/settings.json" ]]; then
        printf '%s\n' "$requested_path"
        return 0
    fi

    if [[ -f "$requested_path" ]]; then
        preset_name="$(basename "$requested_path" .json)"
        preset_dir="$preset_root/$preset_name"
        run_logged_command install -d -m 0755 "$preset_dir" || return 1
        run_logged_command install -m 0644 "$requested_path" "$preset_dir/settings.json" || return 1
        printf '%s\n' "$preset_dir"
        return 0
    fi

    return 1
}

# Normalize the imported Rice mocha_vanilla preset for an island-style panel.
normalize_rice_mocha_vanilla_panel_preset() {
    local preset_dir="$1"
    local preset_file="$preset_dir/settings.json"
    local python_bin=""

    if [[ ! -f "$preset_file" ]]; then
        append_log_line "Rice Panel Colorizer preset is missing: $preset_file"
        return 1
    fi

    if have_command python3; then
        python_bin="python3"
    elif have_command python; then
        python_bin="python"
    else
        append_log_line "python is unavailable; cannot normalize the Rice Panel Colorizer preset."
        return 1
    fi

    append_log_line "RUN $python_bin - <normalize Rice mocha_vanilla preset> $preset_file"
    "$python_bin" - "$preset_file" >>"$LOG_FILE" 2>&1 <<'PY'
import copy
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
global_settings = data.setdefault("globalSettings", {})

native_panel = global_settings.setdefault("nativePanel", {})
native_background = native_panel.setdefault("background", {})
native_background["enabled"] = False
native_background["opacity"] = 0

widgets = global_settings.setdefault("widgets", {})
widget_normal = widgets.setdefault("normal", {})
widget_normal["enabled"] = True

widget_bg = widget_normal.setdefault("backgroundColor", {})
widget_bg["enabled"] = True
widget_bg["sourceType"] = 1
widget_bg.setdefault("custom", "#11111b")
widget_bg.setdefault("alpha", 1)

widget_radius = widget_normal.setdefault(
    "radius",
    {
        "enabled": True,
        "corner": {
            "topLeft": 17,
            "topRight": 17,
            "bottomRight": 17,
            "bottomLeft": 17,
        },
    },
)
widget_radius["enabled"] = True

widget_margin = widget_normal.setdefault(
    "margin",
    {
        "enabled": True,
        "side": {
            "right": 4,
            "left": 4,
            "top": 4,
            "bottom": 4,
        },
    },
)
widget_margin["enabled"] = True

tray_widgets = global_settings.setdefault("trayWidgets", {})
tray_normal = tray_widgets.setdefault("normal", {})
tray_normal["enabled"] = True

tray_bg = tray_normal.setdefault("backgroundColor", {})
tray_bg["enabled"] = True
tray_bg["sourceType"] = 1
tray_bg["custom"] = widget_bg.get("custom", "#11111b")
tray_bg["alpha"] = widget_bg.get("alpha", 1)

tray_normal["radius"] = copy.deepcopy(widget_radius)
tray_normal["margin"] = copy.deepcopy(widget_margin)

path.write_text(json.dumps(data, separators=(",", ":")))
PY
}

# Remap Panel Colorizer preset widget IDs to the current panel widget IDs.
remap_panel_colorizer_preset_widget_ids() {
    local preset_file="$1"
    local panel_widgets_json="$2"
    local python_bin=""

    if [[ ! -f "$preset_file" || -z "$panel_widgets_json" ]]; then
        return 1
    fi

    if have_command python3; then
        python_bin="python3"
    elif have_command python; then
        python_bin="python"
    else
        append_log_line "python is unavailable; cannot remap Panel Colorizer preset widget IDs."
        return 1
    fi

    append_log_line "RUN $python_bin - <remap Panel Colorizer preset widget IDs> $preset_file"
    PANEL_WIDGETS_JSON="$panel_widgets_json" "$python_bin" - "$preset_file" >>"$LOG_FILE" 2>&1 <<'PY'
import json
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
panel_widgets = json.loads(os.environ["PANEL_WIDGETS_JSON"])
data = json.loads(path.read_text())
global_settings = data.setdefault("globalSettings", {})

widgets_by_name = {}
for widget in panel_widgets:
    name = widget.get("name")
    if not name:
        continue
    widgets_by_name.setdefault(name, []).append(widget)


def remap(items):
    if not isinstance(items, list):
        return []
    result = []
    positions = {}
    for item in items:
        name = item.get("name")
        if not name:
            continue
        matches = widgets_by_name.get(name, [])
        index = positions.get(name, 0)
        if index >= len(matches):
            continue
        mapped = dict(item)
        mapped["id"] = matches[index].get("id", mapped.get("id"))
        positions[name] = index + 1
        result.append(mapped)
    return result


global_settings["associations"] = remap(global_settings.get("associations"))
global_settings["unifiedBackground"] = remap(global_settings.get("unifiedBackground"))

path.write_text(json.dumps(data, separators=(",", ":")))
PY
}

# Apply the Panel Colorizer preset through Plasma's applet config.
apply_panel_colorizer_settings() {
    local kwriteconfig_bin=""
    local qdbus_bin=""
    local preset_path="${PANEL_COLORIZER_IMPORTED_PRESET_DIR:-$HOME/.config/panel-colorizer/presets/mocha_vanilla}"
    local preset_dir=""
    local panel_id=""
    local widget_id=""
    local panel_widgets_json=""
    local service_name=""
    local attempt=0

    if [[ ! -d "$preset_path" || ! -f "$preset_path/settings.json" ]] && [[ -f "$HOME/.config/panel-colorizer/mocha_vanilla.json" ]]; then
        preset_path="$HOME/.config/panel-colorizer/mocha_vanilla.json"
    fi

    if [[ ! -d "$preset_path" || ! -f "$preset_path/settings.json" ]] && [[ -d "$HOME/.config/panel-colorizer/presets/catppuccin-mocha-lavender" ]]; then
        preset_path="$HOME/.config/panel-colorizer/presets/catppuccin-mocha-lavender"
    fi

    if [[ ! -d "$preset_path" || ! -f "$preset_path/settings.json" ]] && [[ -f "$HOME/.config/panel-colorizer/catppuccin-mocha-lavender.json" ]]; then
        preset_path="$HOME/.config/panel-colorizer/catppuccin-mocha-lavender.json"
    fi

    if ! preset_dir="$(trim_whitespace "$(resolve_panel_colorizer_preset_dir "$preset_path")")"; then
        append_log_line "Panel Colorizer preset is unavailable: $preset_path"
        return 1
    fi

    if ! qdbus_bin="$(get_qdbus_command)" || ! is_plasma_session; then
        append_log_line "Panel Colorizer requires an active Plasma session."
        return 1
    fi

    kwriteconfig_bin="$(get_kwriteconfig_command)"
    panel_id="$(trim_whitespace "$(get_primary_plasma_panel_id)")"
    widget_id="$(trim_whitespace "$(ensure_panel_colorizer_widget)")"
    panel_widgets_json="$(trim_whitespace "$(get_primary_panel_widgets_json)")"

    if [[ -z "$panel_id" || -z "$widget_id" ]]; then
        append_log_line "Could not determine Plasma panel or Panel Colorizer widget ID."
        return 1
    fi

    if ! remap_panel_colorizer_preset_widget_ids "$preset_dir/settings.json" "$panel_widgets_json"; then
        append_log_line "Could not remap Panel Colorizer preset widget IDs for $preset_dir/settings.json"
    fi

    "$kwriteconfig_bin" --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group Containments --group "$panel_id" --group Applets --group "$widget_id" \
        --group Configuration --group General --key isEnabled true

    "$kwriteconfig_bin" --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group Containments --group "$panel_id" --group Applets --group "$widget_id" \
        --group Configuration --group General --key hideWidget false

    "$kwriteconfig_bin" --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group Containments --group "$panel_id" --group Applets --group "$widget_id" \
        --group Configuration --group General --key enableDBusService true

    "$kwriteconfig_bin" --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group Containments --group "$panel_id" --group Applets --group "$widget_id" \
        --group Configuration --group General --key lastPreset "$preset_dir"

    "$kwriteconfig_bin" --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group Containments --group "$panel_id" --group Applets --group "$widget_id" \
        --group Configuration --group General --key panelWidgets "$panel_widgets_json"

    reload_panel_colorizer_widget "$widget_id" >/dev/null || true
    service_name="luisbocanegra.panel.colorizer.c${panel_id}.w${widget_id}"

    for attempt in 1 2 3 4 5; do
        if "$qdbus_bin" "$service_name" /preset preset "$preset_dir" >>"$LOG_FILE" 2>&1; then
            return 0
        fi
        sleep 1
    done

    append_log_line "Could not apply Panel Colorizer preset over D-Bus: $service_name -> $preset_dir"
    return 1
}

# Install or upgrade a Plasma applet from an upstream Git repository.
install_plasma_applet_from_repo() {
    local repo_url="$1"
    local package_rel_path="$2"
    local package_id="$3"
    local temp_dir=""
    local repo_dir=""
    local package_dir=""
    local kpackagetool_bin=""

    if ! have_command git; then
        append_log_line "git is unavailable; cannot install Plasma applet $package_id from $repo_url"
        return 1
    fi

    kpackagetool_bin="$(get_kpackagetool_command)" || {
        append_log_line "kpackagetool is unavailable; cannot install Plasma applet $package_id"
        return 1
    }

    temp_dir="$(mktemp -d)"
    repo_dir="$temp_dir/applet"

    run_logged_command_with_title "Cloning $package_id" git clone --depth 1 "$repo_url" "$repo_dir"
    package_dir="$repo_dir/$package_rel_path"

    if [[ ! -f "$package_dir/metadata.json" && ! -f "$package_dir/metadata.desktop" ]]; then
        append_log_line "Plasma applet source at $repo_url did not contain metadata in $package_rel_path"
        rm -rf -- "$temp_dir"
        return 1
    fi

    if "$kpackagetool_bin" --type Plasma/Applet --show "$package_id" >/dev/null 2>&1; then
        run_logged_command_with_title "Upgrading the $package_id Plasma widget" "$kpackagetool_bin" --type Plasma/Applet --upgrade "$package_dir"
    else
        run_logged_command_with_title "Installing the $package_id Plasma widget" "$kpackagetool_bin" --type Plasma/Applet --install "$package_dir"
    fi

    rm -rf -- "$temp_dir"
}

# Install the Command Output Plasma widget from upstream.
install_commandoutput_plasma_widget() {
    install_plasma_applet_from_repo \
        "https://github.com/Zren/plasma-applet-commandoutput" \
        "package" \
        "com.github.zren.commandoutput"
}

# Sync helper scripts for the Command Output Plasma widget.
sync_commandoutput_plasma_scripts() {
    local source_dir="$DOTFILES_DIR/scripts/commandoutput"
    local target_dir="$HOME/.local/share/plasma-commandoutput/scripts"

    if [[ ! -d "$source_dir" ]]; then
        append_log_line "Command Output helper scripts directory is missing: $source_dir"
        return 1
    fi

    run_logged_command install -d -m 0755 "$target_dir" || return 1
    run_logged_command cp -rf "$source_dir"/. "$target_dir"/ || return 1
}

# Install the Shutdown or Switch Plasma widget from upstream.
install_shutdown_or_switch_plasma_widget() {
    install_plasma_applet_from_repo \
        "https://github.com/Davide-sd/shutdown_or_switch" \
        "package" \
        "org.kde.plasma.shutdownorswitch"
}

# Import the Rice panel presets into the local Panel Colorizer config directory.
import_rice_panel_colorizer_presets() {
    local temp_dir=""
    local repo_dir=""
    local panel_dir=""
    local preset_root="$HOME/.config/panel-colorizer/presets"
    local preset_source_dir=""
    local preset_dir=""
    local imported_count=0
    local preserved_existing_mocha_vanilla=false

    if ! have_command git; then
        append_log_line "git is unavailable; cannot import Rice panel presets."
        return 1
    fi

    if [[ -f "$preset_root/mocha_vanilla/settings.json" ]]; then
        PANEL_COLORIZER_IMPORTED_PRESET_DIR="$preset_root/mocha_vanilla"
        preserved_existing_mocha_vanilla=true
        append_log_line "Keeping existing Panel Colorizer preset at $PANEL_COLORIZER_IMPORTED_PRESET_DIR"
    fi

    temp_dir="$(mktemp -d)"
    repo_dir="$temp_dir/rice"

    run_logged_command_with_title "Cloning Rice panel presets" git clone --depth 1 https://github.com/revaljonathan/Rice "$repo_dir"
    panel_dir="$repo_dir/panel"

    if [[ ! -d "$panel_dir" ]]; then
        append_log_line "Rice clone did not contain a panel directory"
        rm -rf -- "$temp_dir"
        return 1
    fi

    run_logged_command install -d -m 0755 "$preset_root"

    for preset_source_dir in "$panel_dir"/*; do
        [[ -d "$preset_source_dir" ]] || continue
        [[ -f "$preset_source_dir/settings.json" ]] || continue

        preset_dir="$preset_root/${preset_source_dir##*/}"
        run_logged_command install -d -m 0755 "$preset_dir"
        if [[ -f "$preset_dir/settings.json" ]]; then
            append_log_line "Keeping existing Panel Colorizer preset $preset_dir/settings.json"
            imported_count=$((imported_count + 1))
            continue
        fi
        run_logged_command install -m 0644 "$preset_source_dir/settings.json" "$preset_dir/settings.json"
        imported_count=$((imported_count + 1))
    done

    if (( imported_count == 0 )); then
        append_log_line "Rice clone did not contain any panel presets"
        rm -rf -- "$temp_dir"
        return 1
    fi

    PANEL_COLORIZER_IMPORTED_PRESET_DIR="$preset_root/mocha_vanilla"
    if [[ ! -d "$PANEL_COLORIZER_IMPORTED_PRESET_DIR" || ! -f "$PANEL_COLORIZER_IMPORTED_PRESET_DIR/settings.json" ]]; then
        PANEL_COLORIZER_IMPORTED_PRESET_DIR="$(find "$preset_root" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)"
        append_log_line "Rice clone did not include mocha_vanilla; using $PANEL_COLORIZER_IMPORTED_PRESET_DIR instead"
    fi

    if [[ "$preserved_existing_mocha_vanilla" != true ]] && [[ -d "$preset_root/mocha_vanilla" && -f "$preset_root/mocha_vanilla/settings.json" ]]; then
        normalize_rice_mocha_vanilla_panel_preset "$preset_root/mocha_vanilla" || {
            rm -rf -- "$temp_dir"
            return 1
        }
    fi

    RICE_PANEL_PRESET_COUNT="$imported_count"
    rm -rf -- "$temp_dir"
}

# Open a script in a new terminal window without taking over the current console.
launch_script_in_new_terminal() {
    local script_path="$1"

    if have_command konsole; then
        konsole --hold -e bash "$script_path" >/dev/null 2>&1 &
        return 0
    fi

    if have_command ghostty; then
        ghostty -e bash "$script_path" >/dev/null 2>&1 &
        return 0
    fi

    return 1
}

# Launch the official Catppuccin KDE installer in a separate terminal window.
launch_catppuccin_kde_installer() {
    local launcher_script=""

    if ! have_command git; then
        append_log_line "Catppuccin KDE launcher skipped because git is missing."
        return 1
    fi

    launcher_script="$(mktemp "${TMPDIR:-/tmp}/catppuccin-kde-launch.XXXXXX.sh")"

    cat > "$launcher_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d)"
cleanup() {
    rm -rf -- "$workdir"
    rm -f -- "$0"
}
trap cleanup EXIT

cd "$workdir"
git clone --depth=1 https://github.com/catppuccin/kde catppuccin-kde
cd catppuccin-kde
printf 'y\ny\n' | ./install.sh 1 14 1

printf '\nCatppuccin KDE Mocha Lavender installer finished.\n'
printf 'Press Enter to close this window...'
read -r _
EOF

    chmod +x "$launcher_script"
    launch_script_in_new_terminal "$launcher_script"
}

# Install the Catppuccin theme and icon extensions for a VS Code-compatible CLI.
install_catppuccin_editor_extensions() {
    local editor_command="$1"

    run_logged_command_with_title "Installing the Catppuccin theme for $editor_command" "$editor_command" --install-extension Catppuccin.catppuccin-vsc --force
    run_logged_command_with_title "Installing the Catppuccin icons for $editor_command" "$editor_command" --install-extension Catppuccin.catppuccin-vsc-icons --force
}

# Apply editor theme defaults for VS Code-compatible editors.
run_editor_theme_post_install_steps() {
    show_section "Applying Editor Themes"

    if have_command code; then
        if run_task_step "VS Code Catppuccin extensions" install_catppuccin_editor_extensions code; then
            :
        else
            warn "Could not install Catppuccin extensions for VS Code."
        fi
    else
        warn "VS Code CLI was not found; skipping Catppuccin extension install for VS Code."
    fi

    if have_command antigravity; then
        if run_task_step "Antigravity Catppuccin extensions" install_catppuccin_editor_extensions antigravity; then
            :
        else
            warn "Could not install Catppuccin extensions for Antigravity."
        fi
    else
        warn "Antigravity CLI was not found; skipping Catppuccin extension install for Antigravity."
    fi
}

# Apply Spotify and Spicetify theme defaults.
run_media_post_install_steps() {
    show_section "Applying Media Themes"

    if ! get_spicetify_command >/dev/null 2>&1; then
        warn "Spicetify is unavailable; skipping the Catppuccin Spotify theme."
        return 0
    fi

    if run_task_step "Catppuccin Spicetify theme" install_spicetify_catppuccin_theme; then
        :
    else
        warn "Could not install the Catppuccin Spicetify theme files automatically."
    fi

    if run_task_step "Spicetify Catppuccin config" configure_spicetify_catppuccin_theme; then
        :
    else
        warn "Could not configure Spicetify for Catppuccin Mocha automatically."
    fi

    if [[ -d /opt/spotify && -d /opt/spotify/Apps ]]; then
        if run_task_step "Spicetify Spotify permissions" ensure_spotify_write_access_for_spicetify; then
            :
        else
            warn "Could not grant Spotify write access for Spicetify automatically."
            return 1
        fi

        if run_task_step "Apply Spicetify Catppuccin" apply_spicetify_catppuccin_theme; then
            :
        else
            warn "Could not apply the Catppuccin Spicetify theme automatically."
            return 1
        fi
    else
        warn "Spotify is not installed in /opt/spotify; skipping the live Spicetify theme apply step."
    fi
}

# Apply system-level tweaks that require root privileges.
run_system_post_install_steps() {
    show_section "Applying System Tweaks"

    if run_task_step "MCHOSE Ace 68 Turbo udev rule" install_mchose_ace68turbo_udev_rule; then
        :
    else
        warn "Could not install the Ace 68 Turbo udev rule automatically."
        return 1
    fi
}

# Apply KDE-specific tweaks and optional theme helpers after deployment.
run_kde_post_install_steps() {
    show_section "Applying KDE Tweaks"

    if ! get_kwriteconfig_command >/dev/null 2>&1; then
        warn "Skipping KDE tweaks because kwriteconfig is unavailable."
        return 0
    fi

    if run_task_step "Catppuccin KDE defaults" apply_kde_theme_defaults; then
        :
    else
        warn "Could not pin the local KDE theme defaults automatically."
    fi

    if run_task_step "Plasma session restore" apply_plasma_session_defaults; then
        :
    else
        warn "Could not update Plasma's session-restore setting automatically."
    fi

    if run_task_step "Performance power profile" apply_performance_power_profile; then
        :
    else
        warn "Could not set the system power profile to performance automatically."
    fi

    if run_task_step "Papirus folder accent" apply_papirus_folder_color; then
        :
    else
        warn "Could not update the Papirus folder accent automatically."
    fi

    if run_task_step "Rice panel presets" import_rice_panel_colorizer_presets; then
        :
    else
        warn "Could not import the Rice Panel Colorizer presets automatically."
    fi

    if run_task_step "Command Output widget" install_commandoutput_plasma_widget; then
        :
    else
        warn "Could not install the Command Output Plasma widget automatically."
    fi

    if run_task_step "Command Output scripts" sync_commandoutput_plasma_scripts; then
        :
    else
        warn "Could not sync the Command Output helper scripts automatically."
    fi

    if run_task_step "Shutdown or Switch widget" install_shutdown_or_switch_plasma_widget; then
        :
    else
        warn "Could not install the Shutdown or Switch Plasma widget automatically."
    fi

    if run_task_step "KDE shortcuts" apply_kde_shortcuts; then
        :
    else
        warn "Could not update the KDE shortcuts automatically."
    fi

    if is_plasma_session; then
        if run_task_step "Reload KWin config" reload_kwin_config; then
            :
        else
            warn "Could not reload KWin automatically."
        fi

        if run_task_step "Reload Rounded Corners effect" reload_shapecorners_effect; then
            :
        else
            warn "Could not reload the Rounded Corners effect automatically."
        fi
    fi

    if is_plasma_session; then
        if run_task_step "Reload shortcuts daemon" reload_global_shortcuts; then
            :
        else
            warn "Could not reload KDE global shortcuts automatically."
        fi

        info "Plasma may still require a logout/login before a newly-added command shortcut becomes active without opening System Settings."
    fi

    if run_task_step "Krohnkite spacing" apply_krohnkite_settings; then
        :
    else
        warn "Could not apply the Krohnkite gap settings automatically."
    fi

    if ! is_plasma_session; then
        info "No active Plasma session was detected; the KDE configs and widget installs were applied, but the live panel reload, Panel Colorizer preset, and wallpaper update were skipped."
        return 0
    fi

    if run_task_step "Reload Plasma top bar" reload_plasma_shell; then
        :
    else
        warn "Could not reload PlasmaShell automatically."
    fi

    if run_task_step "Panel Colorizer preset" apply_panel_colorizer_settings; then
        :
    else
        warn "Could not apply the Rice Panel Colorizer preset automatically."
    fi

    if run_task_step "Omarchy Catppuccin wallpaper" apply_omarchy_wallpaper; then
        :
    else
        warn "Could not apply the Omarchy wallpaper automatically."
    fi
}

# Install desktop-specific themes and helpers that are not simple package/config drops.
run_desktop_post_install_steps() {
    show_section "Applying Desktop Themes"

    if run_task_step "qylock SDDM themes" install_qylock_sddm_themes; then
        info "Set '$QYLOCK_ACTIVE_THEME' as the active SDDM theme."
        warn "Some qylock themes expect extra fonts in /usr/share/sddm/themes/<theme>/font/ for the intended look."
        info "The qylock login themes only appear if SDDM is your active display manager."
    else
        error "Could not install the qylock SDDM themes."
        return 1
    fi

    if run_task_step "Activate SDDM" activate_sddm_display_manager; then
        info "SDDM is configured as the active display manager for the next boot."
    else
        warn "Could not switch the active display manager to SDDM automatically."
    fi

    run_kde_post_install_steps
    run_editor_theme_post_install_steps
}

# Bootstrap dependencies, show the review, and apply everything.
main() {
    local overall_success=true

    init_logs
    ensure_arch_system
    ensure_gum
    clear_if_tty
    show_banner
    info "Writing install log to $LOG_FILE"
    show_intro_panel
    show_review_screen

    if ! confirm_action "Install everything from this repo?"; then
        info "Installation cancelled."
        exit 0
    fi

    if ! install_all_packages; then
        overall_success=false
    fi

    if ! deploy_all_configs; then
        overall_success=false
    fi

    if ! run_system_post_install_steps; then
        overall_success=false
    fi

    if ! run_desktop_post_install_steps; then
        overall_success=false
    fi

    if ! run_media_post_install_steps; then
        overall_success=false
    fi
    show_final_screen "$overall_success"

    if [[ "$overall_success" == false ]]; then
        exit 1
    fi
}

main "$@"
