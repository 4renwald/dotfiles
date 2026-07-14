#!/usr/bin/env bash

declare -Ag LOADED_RECIPES=()

discover_package_groups() {
    [[ -d "$PACKAGES_DIR" ]] || return 0
    find "$PACKAGES_DIR" -maxdepth 1 -type f -name '*.txt' -printf '%f\n' | sed 's/[.]txt$//' | sort
}

read_package_group() {
    local file="$1" line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"; line="$(trim_whitespace "$line")"; [[ -n "$line" ]] && printf '%s\n' "$line"
    done <"$file"
}

pkg_resolve_line() {
    local line="$1" display token action=''
    read -r -a fields <<<"$line"; display="${fields[0]}"; action="$display"
    for token in "${fields[@]:1}"; do
        case "$token" in "${DISTRO_FAMILY}="*) action="${token#*=}";; esac
    done
    printf '%s\t%s\n' "$display" "$action"
}

count_packages_in_group() { read_package_group "$PACKAGES_DIR/$1.txt" | awk 'NF {n++} END {print n+0}'; }

pkg_load_recipe() {
    local recipe="$1" file function_name
    file="$INSTALLERS_DIR/$recipe.sh"; function_name="install_app_${recipe//-/_}"
    if [[ -z "${LOADED_RECIPES[$recipe]:-}" ]]; then
        [[ -r "$file" ]] || { append_log_line "Missing recipe: $file"; return 1; }
        # shellcheck disable=SC1090
        source "$file"
        LOADED_RECIPES[$recipe]=1
    fi
    declare -F "$function_name" >/dev/null || { append_log_line "Recipe $recipe does not define $function_name"; return 1; }
    PKG_RECIPE_FUNCTION="$function_name"
}

pkg_install_group() {
    local group="$1" line display action recipe function_name failed=false
    # shellcheck disable=SC2034 # consumed by ui.sh
    CURRENT_PHASE=packages
    while IFS= read -r line; do
        IFS=$'\t' read -r display action < <(pkg_resolve_line "$line")
        case "$action" in
            skip) ui_skip_task "$display";;
            script:*)
                recipe="${action#script:}"
                if pkg_load_recipe "$recipe"; then ui_task "$display" "$PKG_RECIPE_FUNCTION" || failed=true; else ui_skip_task "$display (missing recipe)"; failed=true; fi
                ;;
            *) ui_task "$display" pkg_backend_install "$action" || failed=true;;
        esac
    done < <(read_package_group "$PACKAGES_DIR/$group.txt")
    [[ "$failed" == false ]]
}

install_all_packages() {
    local group
    ui_section 'Installing Packages' packages
    while IFS= read -r group; do
        if in_scope "$(group_scope "$group")"; then
            info "Package group: $group"
            # shellcheck disable=SC2034 # shared orchestrator state
            pkg_install_group "$group" || OVERALL_SUCCESS=false
        else
            ui_skip_task "package group $group"
        fi
    done < <(discover_package_groups)
}

pkg_manifest_resolve_all() {
    local family group line
    for family in arch debian; do
        DISTRO_FAMILY="$family"; printf '[%s]\n' "$family"
        while IFS= read -r group; do while IFS= read -r line; do printf '%s/%s\t' "$group" "${line%% *}"; pkg_resolve_line "$line" | cut -f2; done < <(read_package_group "$PACKAGES_DIR/$group.txt"); done < <(discover_package_groups)
    done
}
