#!/usr/bin/env bash

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

# Apply system-level tweaks.
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
