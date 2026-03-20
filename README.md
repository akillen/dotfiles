# Mac Dev Dotfiles Bootstrap

This repository bootstraps a new macOS development machine and keeps your setup reproducible over time.

It is designed to live at:

- `~/dotfiles`

The main flow is:

1. Keep your tooling + config in this repo.
2. Run `./setup.sh` to apply it.
3. When you want changes, update files here and rerun the script.

## What This Project Sets Up

- Homebrew packages and apps from `Brewfile`
- Dotfile symlinks from this repo to your home directory
- Git identity and SSH key setup
- Node.js via `nvm` + npm upgrade + npx availability
- macOS defaults (Finder/Dock)
- Optional Xcode + iOS simulator setup

## New Machine Setup

Clone this repo directly to `~/dotfiles`:

```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
```

Create your local config file:

```bash
cp setup.conf.example setup.conf
```

Edit `setup.conf` with your personal values (name/email and optional flags), then run:

```bash
./setup.sh --dry-run
./setup.sh
```

## Daily/Ongoing Workflow

When you want to change your environment:

1. Edit the relevant files in this repo (`Brewfile`, scripts, `.zshrc`, `setup.conf`, etc.).
2. Rerun setup to apply changes:

```bash
cd ~/dotfiles
./setup.sh --dry-run
./setup.sh
```

This project is intended to be rerun safely as your setup evolves.

## Common Flags

```bash
./setup.sh --dry-run
./setup.sh --skip-xcode
./setup.sh --skip-simulator
./setup.sh --skip-browser-default
./setup.sh --skip-node
./setup.sh --yes
```

## Config-Driven Defaults

`setup.sh` reads `setup.conf` by default.

- Put machine/user-specific values in `setup.conf`.
- Keep a shareable template in `setup.conf.example`.
- CLI flags override config values.
- Optional: set `GOOGLE_DRIVE_ACCOUNT_EMAIL` to show a Google Drive sign-in account hint after install. Google credentials are not preconfigured by script (OAuth in-app login).

You can also use a custom config path:

```bash
./setup.sh --config /path/to/custom.conf --dry-run
```

## Notes

- `setup.conf` is ignored by git and should stay local.
- Script execute permissions are tracked by git.
- Open a new shell after setup to pick up shell changes (or run `exec zsh`).

## Local Customizations (Per-Machine Overrides)

Two escape-hatch files let you add machine-specific steps without touching the repo:

| File | Purpose |
|---|---|
| `~/setup.local` | Sourced at the end of `setup.sh`. Put work-specific installs, license activations, or anything not suitable for the shared repo here. |
| `~/.zshrc.local` | Sourced at the end of `.zshrc`. Tool installers (Android Studio, Conda, etc.) that append to your shell config will write here instead of clobbering the repo-managed `.zshrc`. |

Neither file is committed. Create them as needed — setup will pick them up automatically.

