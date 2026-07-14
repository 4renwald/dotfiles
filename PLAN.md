# Cross-Distro Dotfiles Installer (Arch + Debian/Ubuntu)

## Context

This repo currently deploys dotfiles and packages for CachyOS/Arch only: `install.sh` (2,605 lines, monolithic) hard-requires `pacman`, bootstraps `paru` for AUR, bootstraps `gum` for its UI, and installs six manifests of Arch/AUR package names. The owner switches regularly between Debian/Ubuntu and CachyOS/Arch and wants **one repo that deploys equally well on both families**, with the installer staying good-looking but no longer needing `gum` (dropping it also removes a bootstrap problem: gum is not in Debian repos).

What is already distro-neutral and must be preserved as-is in behavior:
- The `.target` config-tree deployment model (`shell/`, `nvim/`, `apps/`, `media/`, `desktop/` → `$HOME`).
- Almost all KDE post-install logic (`kwriteconfig6`, `qdbus`, `kpackagetool6`, plasma scripting, SDDM via `systemctl`) — these tools are identical on a Debian Plasma 6 system.
- The Spicetify installer (already downloads upstream release archives — works anywhere).

What must change:
1. **Structure**: split the monolith into an entrypoint + `lib/` modules + per-app `installers.d/` recipes.
2. **UI**: replace gum with a small pure-bash ANSI UI (Catppuccin truecolor, spinner, ✓/✗ task lines).
3. **OS layer**: distro detection (`/etc/os-release` ID/ID_LIKE) + environment detection (GUI / Plasma 6 / WSL / headless) with **auto-scoped phases** (decision: auto-detect; desktop/gui/media phases only run where a desktop exists).
4. **Package layer**: a package-manager abstraction with an Arch backend (pacman+paru, existing logic) and a Debian backend (apt + vendor repos + .deb downloads + GitHub releases + npm/pipx). Decision: **vendor apt repos and official .debs**, not flatpak.
5. **Manifests**: keep one manifest per group, but each line gains optional per-distro overrides (`debian=…`, `arch=…`, `script:`, `skip`).
6. Supported targets: **Arch/CachyOS (ID_LIKE=arch) and Debian 13+ / Ubuntu 24.04+ (ID_LIKE=debian)**. KWin theming components with no Debian packages are **built from source, best-effort** (warn and continue on failure).

---

## New repository layout

```
install.sh                    # thin entrypoint: parse flags, detect OS, orchestrate phases
lib/
  log.sh                      # log file init, append_log_line, run_logged_command*
  ui.sh                       # ANSI palette, banner, sections, task runner w/ spinner, summary, confirm
  os.sh                       # distro + environment detection, phase gating predicates
  pkg.sh                      # manifest parsing + dispatch to the active backend
  pkg/arch.sh                 # pacman/paru backend (extracted from current install.sh)
  pkg/debian.sh               # apt backend + repo/.deb/github-release/npm/pipx helpers
  configs.sh                  # .target discovery + deployment (extracted, logic unchanged)
  steps/
    system.sh                 # udev rule
    sddm.sh                   # qylock themes + display-manager activation
    kde.sh                    # all KDE tweaks, plasma applets, panel colorizer, wallpaper
    media.sh                  # spicetify theme steps
    editors.sh                # VS Code / Antigravity Catppuccin extensions
installers.d/                 # one file per custom-install app, sourced on demand
  <app>.sh                    # defines install_app_<name>() using lib helpers
packages/*.txt                # same six groups, new line format with distro overrides
```

`EXCLUDE_DIRS` in config discovery must gain `lib` and `installers.d`.

---

## Step 1 — `lib/ui.sh`: gum-free UI

Remove all gum usage, gum env-var theming, `ensure_gum`/`install_gum`, and the gum package bootstrap. Re-implement with raw ANSI (keep the existing Catppuccin hex palette as `\e[38;2;r;g;bm` truecolor constants):

- `ui_init`: detect color support (`[[ -t 1 ]]`, `$TERM != dumb`, honor `$NO_COLOR`); define palette or empty strings.
- `ui_banner`: box-drawing banner showing repo name, detected distro (e.g. `CachyOS (arch)` / `Ubuntu 24.04 (debian)`), scope (`full desktop` / `cli-only`), and log path.
- `ui_section "Installing Packages"`: bold accent header with a horizontal rule (`─`).
- `ui_task "<label>" <cmd…>`: replaces `run_task_step`. Interactive TTY: show `  ⠋ label` (braille spinner via a background loop, cursor hidden with `tput civis`/restored on trap), then rewrite the line to `  ✓ label` (green) / `  ✗ label` (red) / `  ○ label (skipped)` (dim). Non-TTY: plain `[ ok ] label` lines. All command output still goes to the log file only.
- `ui_summary`: per-phase counts (`ok / failed / skipped`) in one aligned block; keep the final screen concept (success or "finished with errors → see log").
- `ui_confirm "<prompt>"`: plain `read -r` y/N (styled prompt), bypassed by `--yes`.
- Review screen: replace the gum-markdown review with plain aligned text — package groups with counts and which are in/out of scope, config dirs with targets, then the confirm.

Keep: `logs/` scheme, `LOG_FILE` naming, `append_log_line`, spinner-title plumbing can be simplified away (labels come from `ui_task`).

## Step 2 — `lib/os.sh`: detection & scoping

- `detect_distro`: source `/etc/os-release`; `DISTRO_FAMILY=arch` if `ID`/`ID_LIKE` contains `arch`, `=debian` if it contains `debian` (covers ubuntu, kubuntu, pop). Otherwise `die` with a clear message. Replaces `ensure_arch_system`.
- `detect_environment` sets:
  - `IS_WSL`: `WSL_DISTRO_NAME` set or `/proc/version` contains `microsoft`.
  - `HAS_GUI`: not WSL **and** (`DISPLAY`/`WAYLAND_DISPLAY` set, or `plasmashell`/`sddm` binary present) — binary check matters so a fresh Kubuntu install over SSH still gets the desktop stack.
  - `HAS_PLASMA6`: `kwriteconfig6` or `plasmashell` major version 6 (`plasmashell --version`).
  - Keep the existing `is_plasma_session` for live-reload gating (unchanged).
- Scope model: two scopes, `cli` (always) and `desktop` (only when `HAS_GUI`).
  - Package groups: `core`, `shell`, `dev` → cli; `desktop`, `gui`, `media` → desktop.
  - Config dirs: `shell`, `nvim`, `apps` → cli; `desktop`, `media` → desktop. Implement as a small mapping table in `install.sh`; unknown new dirs default to cli so the discovery philosophy stays "drop a folder in, it deploys". (Note: `core` group contains a few GUI tools — flameshot, rofi, spectacle; move those three lines to `desktop.txt` so `core` is truly CLI-safe.)
  - Steps: `system.sh` (udev) skipped on WSL; `sddm.sh` + `kde.sh` require `HAS_PLASMA6`; `media.sh`/`editors.sh` keep their existing presence checks.
- CLI flags in `install.sh`: `--yes` (no prompts), `--cli-only` (force cli scope), `--desktop` (force desktop scope), `--skip <phase>` / `--only <phase>` where phase ∈ `packages,configs,system,desktop,media,editors`, `-h/--help`. Keep the all-in default (no picker).

## Step 3 — `lib/pkg.sh`: manifest format & dispatch

New manifest line format (whitespace-separated, `#` comments unchanged):

```
<name> [arch=<value>] [debian=<value>]
```

- `<value>` is one of: a package name, `script:<recipe>` (run `install_app_<recipe>` from `installers.d/<recipe>.sh`), or `skip`.
- No override ⇒ the name itself is the package name on that distro.
- Parser produces, per line: display name + resolved action for `DISTRO_FAMILY`.
- `pkg_install_group` iterates lines: `skip` prints the dim `○ skipped` task line; `script:` sources `installers.d/<recipe>.sh` once and calls its function via `ui_task`; otherwise delegates to the backend's `pkg_backend_install <name>`.

### `lib/pkg/arch.sh`
Extract existing logic unchanged: `ensure_paru`/`install_paru_from_dir`, `pacman -Si` → pacman, else paru (`-Si` check, MISSING warning), `--needed --noconfirm`. Keep `prepare_openai_codex_install` here (Arch-only quirk), triggered by name match as today.

### `lib/pkg/debian.sh`
- `pkg_backend_install`: batch-friendly `sudo DEBIAN_FRONTEND=noninteractive apt-get install -y <pkg>`; availability check via `apt-cache show` (report MISSING like the Arch path).
- Helpers for recipes:
  - `apt_add_repo <name> <key_url> <suite/component line>`: download key to `/etc/apt/keyrings/<name>.gpg` (`gpg --dearmor` when armored), write `/etc/apt/sources.list.d/<name>.list` with `signed-by`, set a "needs apt update" flag; `apt_update_if_needed` runs once before the next install.
  - `install_deb_url <url>`: download to mktemp dir, `apt-get install -y ./pkg.deb` (resolves dependencies).
  - `github_release_asset <owner/repo> <asset-regex>`: generalize the existing Spicetify release-download logic (curl API, resolve tag + asset URL).
  - `install_bin_from_archive`: extract a tar/zip and install a binary to `/usr/local/bin` (or `~/.local/bin` for user-scope tools).
  - `npm_global <pkg…>` and `pipx_install <pkg>` (ensure `pipx` + `python3-venv` installed first).
- One-time `debian_bootstrap`: `apt-get update` + install baseline deps `curl ca-certificates gnupg git unzip fontconfig` before any group.

Sudo: keep `ensure_sudo_ready`, and add a keepalive (`sudo -v` every 60s in a background loop, killed on EXIT trap) since Debian runs involve many long downloads.

## Step 4 — rewrite `packages/*.txt` (the mapping)

Names below marked **(verify)** must be confirmed during implementation against packages.debian.org / Ubuntu archive (`apt-cache show` in a container); where a name differs between Debian 13 and Ubuntu 24.04, prefer a `script:` recipe that tries apt first and falls back.

**core.txt** (CLI-only after moving GUI tools out):
| line | debian override |
|---|---|
| 7zip | — (exists on both) |
| btop, bluez | — |
| bluez-utils | `debian=skip` (tools ship inside Debian's `bluez`) |
| bluetui | `debian=script:bluetui` (GitHub release binary, pythops/bluetui) |
| caligula | `debian=script:caligula` (GitHub release binary, ifd3f/caligula) |
| ttf-jetbrains-mono-nerd | `debian=script:nerd-font-jetbrains` (ryanoasis/nerd-fonts release → `~/.local/share/fonts` + `fc-cache -f`) |
| yazi | `debian=script:yazi` (GitHub release zip, sxyazi/yazi) |
| flameshot, rofi, spectacle | **move to desktop.txt**; spectacle gets `debian=kde-spectacle` |

**shell.txt**: fish, fzf, zsh — plain; `lsd` — plain (in both repos); `catnap debian=script:catnap` (GitHub release / cargo — check upstream assets); `ghostty debian=script:ghostty` (try apt (Debian 13 **(verify)**), else .deb from `mkasberg/ghostty-ubuntu` releases); `gum debian=script:charm-repo` (Charm apt repo `repo.charm.sh` — gum stays a user tool, the installer itself no longer needs it); `oh-my-posh-bin debian=script:oh-my-posh` (official install script → `~/.local/bin`); `starship debian=script:starship` (official `starship.rs/install.sh`).

**dev.txt**:
- Plain on both: cmake, git, extra-cmake-modules.
- `github-cli debian=gh`.
- `neovim debian=script:neovim` — official prebuilt tarball → `/opt/nvim-linux-x86_64` + symlink into `/usr/local/bin` (Ubuntu 24.04's 0.9 is too old for LazyVim; be deterministic on the whole family).
- `npm debian=script:nodejs` — NodeSource Node 22 LTS apt repo (distro node is too old for codex/gemini).
- npm-based tools: `gemini-cli`, `openai-codex`, `tree-sitter-cli`, `typescript`, `opencode` → `debian=script:npm-tools` (single recipe: `npm_global @google/gemini-cli @openai/codex tree-sitter-cli typescript`; opencode via its official curl installer, or opencode-ai npm — check current upstream guidance).
- `claude-code debian=script:claude-code` (official `https://claude.ai/install.sh`).
- `visual-studio-code-bin debian=script:vscode` (Microsoft apt repo, package `code`).
- `antigravity debian=script:antigravity` (Google's official .deb/apt repo per current docs).
- `python-dbus debian=python3-dbus`, `python-gobject debian=python3-gi`.
- **KDE/Qt build libs** (ki18n, kitemmodels, kservice, kwin, libdrm, libplasma, plasma-activities, plasma-workspace, qt6-5compat, qt6-declarative, qt6-svg, kwindowsystem): keep for arch, mark all `debian=skip` — on Debian they exist only to serve the KWin source builds, and each source-build recipe installs its own apt build-deps (see Step 5). This keeps manifests honest and avoids hand-mapping ~14 `libkf6*-dev` names in the manifest.

**gui.txt** (all `debian=script:` unless noted):
brave (official Brave apt repo → `brave-browser`), google-chrome (official .deb), keeper (.deb from keepersecurity.com), megasync (.deb from mega.nz — pick the Debian/Ubuntu variant by `VERSION_ID`), mullvad (official apt repo), obsidian (.deb from obsidianmd GitHub releases), proton-mail (.deb from proton.me), signal (official apt repo), teams-for-linux (official apt repo), vesktop (.deb from Vencord/Vesktop releases), zoom (.deb from zoom.us). `telegram-desktop` — plain apt on Debian. `notion-app-electron debian=skip` (no official Linux build; the AUR package is a repack — print a notice).

**media.txt**: mpv, qbittorrent — plain; `yt-dlp` — plain (apt); `spotify debian=script:spotify` (official Spotify apt repo); `spicetify-cli` → `arch=script:spicetify debian=script:spicetify` (move the existing upstream-release installer into `installers.d/spicetify.sh`, used by both — deletes the AUR special-case branch); `jellyfin-mpv-shim debian=script:jellyfin-mpv-shim` (pipx); `mpv-shim-default-shaders debian=script:jellyfin-mpv-shim` (same recipe: `pipx inject jellyfin-mpv-shim mpv-shim-default-shaders`).

**desktop.txt**:
- Plain/renamed apt: `gst-plugins-bad debian=gstreamer1.0-plugins-bad` (and base/good/ugly likewise), `papirus-icon-theme` plain, `sddm` plain, `sddm-kcm debian=kde-config-sddm`, `kvantum debian=qt6-style-kvantum` **(verify; may need `+ qt6-style-kvantum-themes` or fall back to `kvantum`)**, `qt6-multimedia debian=libqt6multimedia6` **(verify)**, `qt6-multimedia-ffmpeg debian=skip` (ffmpeg backend is the Debian default).
- `capitaine-cursors debian=script:capitaine-cursors` (GitHub release tarball → `/usr/share/icons`).
- `plasma6-applets-arch-update-notifier debian=skip` (pacman-specific by nature).
- Plasma applets → shared kpackagetool recipes (see Step 5): `plasma6-applets-kara-git debian=script:applet-kara`, `plasma6-applets-panel-colorizer debian=script:applet-panel-colorizer`, `plasma6-applets-plasmusic-toolbar debian=script:applet-plasmusic`, `plasma6-applets-window-title debian=script:applet-window-title`, `kwin-scripts-krohnkite debian=script:krohnkite`.
- Source builds: `klassy debian=script:klassy`, `darkly debian=script:darkly`, `kwin-effects-better-blur-dx debian=script:kwin-better-blur`, `kwin-effect-rounded-corners-git debian=script:kwin-rounded-corners`.

## Step 5 — `installers.d/` recipes

Each file defines `install_app_<name>()` and uses only `lib` helpers + `append_log_line`; failures return non-zero and the phase records ✗ but continues (best-effort, per decision). Recipes needed (≈25, most are 5–15 lines on top of the helpers):

- **Release binaries**: yazi, bluetui, caligula, catnap, nerd-font-jetbrains, capitaine-cursors, neovim, spicetify (moved).
- **Vendor apt repos**: brave, signal, spotify, mullvad, teams-for-linux, vscode, charm-repo (gum), nodejs (NodeSource), antigravity.
- **Direct .debs**: google-chrome, keeper, megasync, obsidian, proton-mail, vesktop, zoom, ghostty (fallback path).
- **Script/npm/pipx**: starship, oh-my-posh, claude-code, npm-tools, jellyfin-mpv-shim.
- **Plasma applets (kpackagetool)**: `applet-kara` (dhruv8sh/kara), `applet-panel-colorizer` (luisbocanegra/plasma-panel-colorizer), `applet-plasmusic` (ccatterina/plasmusic-toolbar), `applet-window-title` (check the AUR PKGBUILD of `plasma6-applets-window-title` for the upstream URL), all thin wrappers around the existing `install_plasma_applet_from_repo` (move that function into `lib/steps/kde.sh` or a shared helper). `krohnkite`: download the `.kwinscript` release asset from anametologin/krohnkite and `kpackagetool6 --type KWin/Script -i` (upgrade with `-u` if present).
- **KWin source builds** (Debian only; each: install its apt build-deps listed in the upstream README — roughly `cmake extra-cmake-modules g++ kwin-dev libkf6*-dev qt6-base-dev`… take the exact list from each project's INSTALL/README, then `cmake -B build && cmake --build && sudo cmake --install`): `klassy` (paulmcauley/klassy — it documents Debian deps), `darkly` (Bali10050/Darkly), `kwin-better-blur` (taj-ny/kwin-effects-forceblur), `kwin-rounded-corners` (matinlotfali/KDE-Rounded-Corners). Wrap each build in `ui_task`; on failure warn "theme component X skipped — see log".

## Step 6 — `install.sh` orchestration

```
parse flags → init logs → detect_distro + detect_environment → ui_banner
→ review screen (groups/configs with in-scope markers) → confirm (unless --yes)
→ ensure_sudo_ready (+keepalive) → [debian_bootstrap]
→ phase: packages (in-scope groups) → phase: configs (in-scope dirs)
→ phase: system (skip on WSL) → phase: desktop (sddm.sh + kde.sh, needs HAS_PLASMA6)
→ phase: media → phase: editors → final summary screen, exit 1 on any failure
```

Steps extraction is mechanical: move the existing functions into `lib/steps/*.sh` unchanged except (a) gum calls → `ui_*`, (b) each step file guards on its own tool availability exactly as today. `run_desktop_post_install_steps`' SDDM part moves to `steps/sddm.sh`; note `activate_sddm_display_manager` also handles Debian fine (`systemctl enable sddm --force`), but on Debian the previous DM may be gdm3/lightdm — extend the disable list (`gdm3`, `lightdm`, `plasmalogin`) before enabling sddm, still best-effort.

## Step 7 — README rewrite

Update: supported distros (CachyOS/Arch, Debian 13+, Ubuntu 24.04+), auto-scoping behavior (desktop vs cli, WSL), new manifest line format with the override syntax and `script:`/`skip` semantics, how to add a recipe in `installers.d/`, new flags, removal of gum ("pure-bash UI, zero bootstrap dependencies"), note that on Debian some theming components are compiled from source and are best-effort.

---

## Implementation order (for the executing agent)

1. Extract `lib/log.sh`, `lib/configs.sh`, `lib/steps/*` from `install.sh` verbatim (no behavior change), shrink `install.sh` to the orchestrator; verify on Arch semantics by review only.
2. Write `lib/ui.sh` (gum removal) and swap all call sites; delete gum bootstrap + env theming.
3. Add `lib/os.sh` + flags + phase gating; move flameshot/rofi/spectacle to `desktop.txt`.
4. Add `lib/pkg.sh` + `lib/pkg/arch.sh` (extraction) — Arch path must behave exactly as before for lines without overrides.
5. Add `lib/pkg/debian.sh` helpers + `debian_bootstrap`.
6. Rewrite manifests with overrides; create all `installers.d/` recipes; verify every uncertain Debian package name inside `debian:trixie` and `ubuntu:24.04` containers (`apt-cache show`).
7. README + `.gitignore` (no change needed) + set `EXCLUDE_DIRS+=(lib installers.d)`.

## Verification

- `bash -n` and `shellcheck` on `install.sh`, every `lib/**/*.sh`, every `installers.d/*.sh` (fix all errors; warnings judged case by case).
- **Container smoke tests** (docker): run `./install.sh --yes` in `archlinux:latest`, `debian:trixie`, and `ubuntu:24.04` containers as a sudo-capable non-root user. Expected: cli scope auto-selected (packages for core/shell/dev + configs for shell/nvim/apps), desktop/system/kde/media phases print as skipped, exit code reflects package results. It's acceptable to trim the run (e.g. `--only configs` plus one small group) to keep it fast, but at least one full cli-scope Debian run should complete.
- **Manifest resolution test**: a tiny `--list`-style dry run (or a bash snippet sourcing `lib/pkg.sh`) that prints every manifest line's resolved action for both `DISTRO_FAMILY=arch` and `=debian`, checked by eye — catches parse errors and typo'd overrides without installing anything.
- Review-screen and summary rendering checked in a real TTY and with `NO_COLOR=1` / piped output.
- The full desktop path (Plasma reload, panel colorizer, SDDM) can't run in containers or this WSL machine; it stays validated by design-parity (logic unchanged from today's working Arch flow) and by the owner's next real install on each OS.
