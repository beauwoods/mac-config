# mac-config

Beau's Mac setup. One command, deterministic, repeatable.

Built on [geerlingguy/mac-dev-playbook](https://github.com/geerlingguy/mac-dev-playbook)
with iCloud Drive for private data. This repo contains zero secrets.

## Architecture

Three components:

- **Geerling's playbook** — cloned at bootstrap time, never forked
- **iCloud Drive** (`dotfiles-private/`) — syncs automatically once you sign
  into Apple ID; holds shell dotfiles, SSH config, iTerm2 prefs, signatures
- **This repo** — holds `config.yml`, custom task files, Firefox policy,
  bootstrap scripts, and the `mac-config` CLI

## Quick Start (new machine)

Complete macOS Setup Assistant and sign into Apple ID first, then:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/beauwoods/mac-config/main/scripts/bootstrap.sh)"
```

This runs in two phases:

1. **Phase 1 (~2 hours, unattended)** — Xcode CLI tools, Homebrew, Ansible,
   all packages/casks/App Store apps, macOS preferences, Dock layout
2. **Pause** — a window opens with manual steps (Full Disk Access, Adobe CC,
   SetApp, Little Snitch license, 1Password SSH agent, scroll direction, Mail)
3. **Phase 2 (~5 min)** — SSH config restore, Firefox policy, Little Snitch
   prefs, Calendar/Mail preferences (via FDA), Dock folders

## Day-to-Day Commands

After initial setup, use the `mac-config` CLI for targeted operations.
Run from a local clone or directly via curl:

```bash
# From local clone (if ~/mac-config/scripts is in PATH)
mac-config <command>

# Or via curl (auto-clones repo on first run)
bash <(curl -fsSL https://raw.githubusercontent.com/beauwoods/mac-config/main/scripts/mac-config) <command>
```

| Command | What it does |
|---|---|
| `mac-config check` | Verify all macOS settings match expected values |
| `mac-config defaults` | Apply macOS defaults only (no package installs) |
| `mac-config status` | Show installed vs. expected packages |
| `mac-config install` | Install only missing packages (skips what's present) |
| `mac-config bootstrap` | Full first-time setup (calls bootstrap.sh) |

**Typical workflows:**

```bash
# After a macOS update resets settings
mac-config check        # see what drifted
mac-config defaults     # re-apply just the settings

# Adding a new app to config.yml
mac-config install      # installs only what's missing

# Full audit
mac-config check && mac-config status
```

## Preflight (on the old machine)

Before deployment day, capture private configs to iCloud:

```bash
~/mac-config/scripts/preflight.sh
```

This copies shell dotfiles, SSH config, mail signatures, iTerm2/iStat prefs,
and a defaults snapshot to `~/Library/Mobile Documents/com~apple~CloudDocs/dotfiles-private/`.
Everything syncs to the new machine via iCloud.

## Repo Layout

```
mac-config/                          (this repo)
├── README.md
├── config.yml                       ← overrides Geerling's default.config.yml
├── requirements.yml                 ← Ansible Galaxy dependencies
├── scripts/
│   ├── mac-config                   ← CLI for check/defaults/status/install
│   ├── bootstrap.sh                 ← curl-able one-command first-time setup
│   └── preflight.sh                 ← run on old machine before deployment
├── tasks/
│   ├── extra-packages.yml           ← dispatcher (Geerling imports this)
│   ├── osx-defaults.yml             ← all macOS preferences (fully commented)
│   ├── remove-bundled-apps.yml      ← removes GarageBand, iMovie, etc.
│   ├── firefox-policy.yml           ← deploys policies.json
│   ├── little-snitch.yml            ← write-preference commands
│   ├── ssh-config.yml               ← restores SSH + dotfiles from iCloud
│   └── dock-folders.yml             ← adds Timing, Desktop, Downloads to Dock
├── configs/
│   └── firefox/
│       └── policies.json            ← Firefox enterprise policy
└── docs/
    └── MANUAL_PAUSE.md              ← steps shown during the pause

dotfiles-private/                    (iCloud Drive, never in this repo)
├── ssh/config
├── shell/                           ← .zshrc, .gitconfig, etc.
├── iterm2/                          ← iTerm2 profile
├── istat/                           ← iStat Menus preferences
└── mail/signatures.md
```

## How It Works

Bootstrap clones Geerling's playbook and symlinks our `config.yml` and
individual task files into it. Geerling's `main.yml` loads our config
(overriding his defaults) and imports our `tasks/extra-packages.yml`
(which dispatches to our custom task files).

Phase separation uses Ansible tags:
- `--skip-tags post-auth` runs everything except post-auth tasks
- `--tags post-auth` runs only the tasks that need manual setup first

## What's Automated

| Area | How |
|---|---|
| CLI tools | Homebrew packages via Geerling's homebrew role |
| GUI apps | Homebrew casks via Geerling's homebrew role |
| App Store apps | `mas` CLI via Geerling's mas role |
| Dock layout | Geerling's dock role + `dock-folders.yml` |
| macOS preferences | `osx_defaults` module in `osx-defaults.yml` — trackpad, Finder, clock, sound, save/print dialogs, screensaver lock, menu bar |
| Calendar prefs | `osx_defaults` for `com.apple.iCal` (requires FDA) |
| Mail prefs | `osx_defaults` for `com.apple.mail` (requires FDA) |
| Shell dotfiles | Copied from iCloud private via `ssh-config.yml` |
| SSH config | Copied from iCloud private via `ssh-config.yml` |
| Firefox policy | `policies.json` deployed to `/Library/Application Support/Mozilla/` |
| Little Snitch prefs | `littlesnitch write-preference` commands |
| iTerm2 | `PrefsCustomFolder` pointed at iCloud private |
| Bundled app removal | GarageBand, iMovie, Pages, Numbers, Keynote |
| Settings verification | `mac-config check` audits all defaults against expected values |
| Package verification | `mac-config status` compares installed packages against config.yml |

## What's Manual (and Why)

| Step | Why it can't be automated |
|---|---|
| Full Disk Access for Terminal | macOS requires GUI interaction in Privacy settings |
| Adobe Creative Cloud sign-in | Interactive auth + per-app installs inside CC |
| SetApp sign-in + app installs | Interactive auth, apps installed through SetApp UI |
| Little Snitch license key | No CLI for license entry |
| Little Snitch rule subscriptions | No CLI to subscribe; could use `export-model`/`restore-model` but fragile |
| 1Password sign-in + SSH agent | Interactive auth required |
| Trackpad scroll direction | `defaults write` doesn't persist on macOS Tahoe — must toggle in System Settings |
| Mail account setup | Must launch Mail and add accounts before preferences can be written |

## SSH Keys (post-bootstrap)

Not automated — inherently interactive and one-per-machine:

```bash
ssh-keygen -t ed25519 -C "$(hostname)-$(date +%Y-%m)"
# Store private key in 1Password → New Item → SSH Key → import ~/.ssh/id_ed25519
rm ~/.ssh/id_ed25519
# Add ~/.ssh/id_ed25519.pub to GitHub Settings → SSH Keys
ssh -T git@github.com
git -C ~/mac-config remote set-url origin git@github.com:beauwoods/mac-config.git
```

## Re-running

Use the `mac-config` CLI (recommended), or run Ansible directly:

```bash
# Re-apply just macOS defaults
mac-config defaults

# Install only missing packages
mac-config install

# Or via Ansible directly from ~/mac-dev-playbook:
ansible-playbook main.yml --ask-become-pass --skip-tags post-auth   # Phase 1
ansible-playbook main.yml --ask-become-pass --tags post-auth        # Phase 2
ansible-playbook main.yml --ask-become-pass --tags dock             # Just Dock
```

## Logs

Every bootstrap run writes a timestamped log:

```
~/.local/share/mac-setup/logs/ansible_YYYYMMDD_HHMMSS.log
```
