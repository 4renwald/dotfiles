#!/usr/bin/env bash
# shellcheck disable=SC2034 # status values are exposed for callers/logging

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

run_plasma_script() {
    local script="$1" qdbus_bin
    qdbus_bin="$(get_qdbus_command)" || return 1
    append_log_line "RUN $qdbus_bin org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript <script>"
    "$qdbus_bin" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" 2>>"$LOG_FILE"
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
