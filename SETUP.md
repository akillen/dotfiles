**Project Setup Guide**

- **Purpose**: Central reference for automating a macOS developer laptop using Homebrew, dotfiles, and idempotent shell orchestrator scripts.
- **Location**: Root of this repo. See important files below.

**Files Of Interest**
- **Brewfile**: [Brewfile](Brewfile) — Homebrew Bundle list of packages and casks.
- **Bootstrap Script**: [setup.sh](setup.sh) — Orchestrator to run `brew bundle`, symlink dotfiles, and apply macOS defaults.
- **Setup Config**: [setup.conf](setup.conf) — Default identity and behavior flags consumed by `setup.sh`.
- **Xcode Module**: [scripts/setup-xcode.sh](scripts/setup-xcode.sh) — Handles Xcode install/first-launch/license/simulator steps with a spinner for long-running operations.

**Overview**
- Automate install of CLI and GUI apps via Homebrew and `brew bundle`.
- Centralize configuration as a `~/dotfiles` repository and deploy via symlinks.
- Script macOS system preferences using the `defaults` command.
- Make the whole flow idempotent, transparent, and minimally interactive.

**Current Status (Implemented)**
- `setup.sh` is modular and parameterized (`--name`, `--email`, `--dry-run`, `--yes`, `--no-source`, `--no-restart`, `--skip-xcode`, `--skip-simulator`).
- Dotfile symlinking is delegated to `scripts/symlink-dotfiles.sh` with timestamped backups.
- Finder and Dock defaults are delegated to `scripts/defaults-finder.sh` and `scripts/defaults-dock.sh`.
- Xcode/iOS runtime setup is delegated to `scripts/setup-xcode.sh` with spinner-based waits for long-running downloads.

**Architecture**
- **Core Engine**: Homebrew
  - Use `brew` to install packages and `brew bundle` to read the `Brewfile`.
  - Keep the `Brewfile` committed in this repo or in `~/dotfiles` so it can be reused.
- **Dotfiles**
  - Store dotfiles under `~/dotfiles` or a repo subfolder.
  - Provide a `symlink` script that creates backups of existing config (timestamped) and then symlinks new files.
- **macOS Defaults**
  - Group defaults into small, well-documented scripts (e.g., `defaults-finder.sh`, `defaults-dock.sh`).
  - Each script should be safe to re-run and should document the user-visible effect.
- **Orchestrator (`setup.sh`)**
  - Steps: check prerequisites, install Homebrew if missing, run `brew bundle`, run symlink script, run `defaults` scripts, cleanup.
  - Ensure the orchestrator supports `--config`, `--no-restart`, `--dry-run`, and `--yes` flags.
  - CLI flags override values loaded from `setup.conf`.

**Design Decisions & Rationale**
- **Use Homebrew + Brewfile**: single source of truth for packages and GUI apps; widely adopted and scriptable.
- **Idempotency**: Scripts must be safe to re-run to allow incremental improvements and recover from partial runs.
- **Backups before changes**: When replacing existing dotfiles, move originals to a `dotfiles_backup/<timestamp>` folder.
- **Minimal interactivity**: Allow automated runs (CI or remote onboarding) via `--yes` while still supporting interactive modes.
- **Security**: Avoid storing secrets in dotfiles; prompt for App Store sign-in manually when required and document it.

**Minimal Example Workflow**
1. Clone this repo.

```bash
git clone <your-repo> ~/dotfiles
cd ~/dotfiles
# optional first-time template copy
# cp setup.conf.example setup.conf
./setup.sh --dry-run
# review, then
./setup.sh
```

**Recommended `Brewfile` Sections**
- Taps (e.g., `tap "homebrew/bundle"`)
- CLI tools: `brew "git"`, `brew "node"`
- Casks (GUI apps): `cask "visual-studio-code"`, `cask "slack"`
- Mac App Store apps: use `mas` where applicable, documented separately.

**Review: Brewfile & setup.sh**
- **Brewfile findings**: The repo has a `Brewfile` with useful entries, but there are a few issues to address:
  - `visual-studio-code` is listed twice; remove duplicates.
  - Fonts and some casks require taps (e.g., `homebrew/cask-fonts` for `font-fira-code`). Add explicit `tap` lines for required taps.
  - Consider grouping entries (taps / brew / cask / mas) and adding comments for optional items.

- **setup.sh findings**: The current `setup.sh` implements many orchestrator steps (Homebrew install, `brew bundle`, macOS `defaults`, SSH key creation, Git config, symlinking, and Xcode automation). Recommended fixes:
  - Ensure `brew` is available in PATH for both Intel and Apple Silicon (use `eval "$(brew shellenv)"` in a robust way).
  - The spinner implementation has quoting issues and may break the script; replace with a well-tested spinner or remove for reliability.
  - Backgrounding `xcodes install` and then checking `$?` will capture the spinner's exit status, not Xcode's. Use a `pid=$!; spinner $pid; wait $pid; rc=$?` pattern and check `$rc`.
  - Before symlinking dotfiles, back up existing files to `dotfiles_backup/<timestamp>` instead of force-overwriting with `ln -sf`.
  - `source ~/.zshrc` is executed immediately after linking; consider deferring until later or documenting the change, and support a `--no-source` or `--dry-run` flag.
  - Hard-coded Git name/email should be parameterized or prompted for via flags to avoid committing personal values into the script.
  - Several `defaults` keys (and domains) should be documented and grouped into per-area scripts (e.g., `scripts/defaults-finder.sh`, `scripts/defaults-dock.sh`) for easier review and re-run safety.

**Actions taken / next-code changes suggested**
- Remove duplicate casks and add required taps to `Brewfile`.
- Add a `scripts/symlink-dotfiles.sh` that performs timestamped backups and idempotent symlinks.
- Replace or fix the spinner and improve process wait/exit checks around `xcodes` and `xcodebuild` steps.
- Parameterize `git` configuration and add CLI flags to `setup.sh`: `--dry-run`, `--yes`, `--no-restart`, `--no-source`.

- **Default browser**: `setup.sh` now installs `duti` (via the `Brewfile`) and, if `Firefox` is present, uses `duti` to make `Firefox` the default handler for `http`, `https`, and common HTML types. This is done after `brew bundle` completes so the app and `duti` are both installed.


**TODOs (short-term)**
- **Doc**: Finalize this `SETUP.md` and link examples. (done)
- **Brewfile**: Validate the existing `Brewfile` and split by category. (next)
- **Templates**: Add a `setup.sh` starter template with `--dry-run`, `--yes`, and idempotency. (next)
- **Symlink Script**: Add `scripts/symlink-dotfiles.sh` that backs up and symlinks configs.
- **Defaults Scripts**: Create per-area `defaults-*.sh` scripts and document effects.

**TODOs (medium-term)**
- **Testing**: Add a CI job that validates `brew bundle --no-upgrade` and linting for scripts.
- **Security Review**: Document where secrets live and add guidance for `git-crypt` or other secret management.
- **Onboarding Notes**: Add a short checklist for first-run items (App Store login, Xcode license acceptance).

**Operational Notes**
- Keep each script small and well-documented at the top with a one-line summary, flags, and examples.
- Prefer explicit, readable shell (POSIX-ish) and avoid brittle one-liners.
- Document manual steps that can't be fully automated (e.g., App Store login, Touch ID prompts).

**Next Steps I Can Do**
- Generate a starter `Brewfile` and a robust `setup.sh` template.
- Create `scripts/symlink-dotfiles.sh` and `scripts/defaults-finder.sh` templates.

If you'd like, I can generate the starter templates now. Which would you prefer first: a `Brewfile` review/generation or the `setup.sh` starter template?
