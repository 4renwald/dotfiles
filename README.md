# Dotfiles

One installer for a CLI or KDE Plasma workstation on:

- Arch Linux and CachyOS
- Debian 13 or newer
- Ubuntu 24.04 or newer (including Debian/Ubuntu derivatives identified through `ID_LIKE`)

The installer has a pure-Bash Catppuccin UI and no UI bootstrap dependency. Package output is kept in a timestamped file under `logs/`; the terminal shows concise task results and a per-phase summary.

## Quick start

```bash
git clone git@github.com:4renwald/dotfiles.git
cd dotfiles
./install.sh
```

By default, the installer detects the distribution and environment, presents the complete plan, and asks once before making changes. A desktop scope is selected when a local graphical environment is detected—even over SSH when Plasma or SDDM is installed. WSL and headless systems receive the CLI scope.

CLI scope installs `core`, `shell`, and `dev`, then deploys `shell`, `nvim`, and `apps`. Desktop scope additionally installs `desktop`, `gui`, and `media`, deploys `desktop` and `media`, and applies the KDE/SDDM/media follow-up steps. New config trees default to CLI scope.

## Options

```text
--yes                 do not prompt
--cli-only            force CLI-only scope
--desktop             force desktop scope
--skip PHASE          skip a phase
--only PHASE          run only one phase
--list                resolve every manifest for Arch and Debian without installing
-h, --help            show help
```

Valid phases are `packages`, `configs`, `system`, `desktop`, `media`, and `editors`. `system` is always skipped under WSL; KDE/SDDM work additionally requires Plasma 6.

## Repository layout

```text
install.sh            argument parsing, detection, review, and orchestration
lib/                  logging, UI, OS, configs, and package-manager modules
lib/pkg/              pacman/paru and apt backends
lib/steps/            system, SDDM, KDE, media, and editor follow-up steps
installers.d/         custom application recipes
packages/             grouped package manifests
shell/ nvim/ apps/    CLI config trees
desktop/ media/       desktop config trees
```

Every config tree contains a `.target`. Its remaining files and directories are copied below that target. Add another top-level directory with a `.target` and the installer discovers it automatically.

## Package manifests

Each non-comment manifest line has a display/default package name and optional distro overrides:

```text
name [arch=value] [debian=value]
```

The value can be another package name, `skip`, or `script:recipe`. With no override, the first name is passed unchanged to the active backend.

```text
github-cli debian=gh
bluez-utils debian=skip
neovim debian=script:neovim
spicetify-cli arch=script:spicetify debian=script:spicetify
```

Arch packages are resolved through the official repositories first and then installed through `paru` when they are AUR-only. Debian-family packages are checked with `apt-cache` and installed non-interactively with apt. Debian bootstraps only baseline download/archive tools; application recipes add official vendor repositories or install official release artifacts.

To add a custom recipe, create `installers.d/my-tool.sh` and define a function whose dashes become underscores:

```bash
install_app_my_tool() {
    # use run_logged_command, install_deb_url, github_release_asset, etc.
}
```

Then use `debian=script:my-tool` (or the corresponding Arch override) in a manifest. Recipes return nonzero on failure; the installer records the failure, continues with independent tasks, and exits nonzero at the end.

## Desktop notes

KDE settings, Plasma widgets, SDDM activation, and Spicetify retain the existing post-install behavior. On Debian, Klassy, Darkly, Force Blur, and Rounded Corners are built from their upstream sources because equivalent packages are not consistently available. These builds are best-effort: a failed component is reported and logged without preventing unrelated setup.

Some live Plasma changes require an active session, and a logout/login may still be needed for new shortcuts or widgets. As always with personal dotfiles, review the plan and use at your own risk.
