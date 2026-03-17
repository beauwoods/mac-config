# dotfiles

Beau's Mac setup. Deterministic, repeatable, no Homebrew.

## Philosophy

This repo is the source of truth for a new machine setup. The old machine
is a *reference*, not a source of truth. Everything here was written
intentionally, not migrated.

## Preflight (on the OLD machine)

Before deployment day, run preflight to capture configs to iCloud:

```bash
~/Documents/GitHub/dotfiles/scripts/preflight.sh
```

Then commit and push any repo changes (`configs/firefox/`, `configs/ssh/README.md`).
Personal data (shell dotfiles, SSH config, signatures, iTerm2/iStat prefs) goes to
iCloud Drive automatically — not to the repo.

## Deployment (on the NEW machine)

**Step 1 — Bootstrap.** Paste this into Terminal on the new machine. It installs
Xcode CLI tools, clones this repo, updates macOS, installs Ansible, and runs
the full playbook unattended:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/beauwoods/dotfiles/main/scripts/bootstrap.sh)"
```

If bootstrap reports that a restart is required for OS updates, restart and re-run the same command.

**Steps 2–7 — Follow MANUAL_STEPS.md.** The full deployment runbook is there,
including auth sessions and manual steps. The short version of the final run:

```bash
~/Documents/GitHub/dotfiles/scripts/run-playbook.sh --tags config
```

### Re-running specific parts

Always use `run-playbook.sh` — it handles the binary path, working directory,
verbosity, and writes a timestamped log to `~/.local/share/dotfiles/logs/`.

```bash
~/Documents/GitHub/dotfiles/scripts/run-playbook.sh --tags defaults
~/Documents/GitHub/dotfiles/scripts/run-playbook.sh --tags apps
~/Documents/GitHub/dotfiles/scripts/run-playbook.sh --tags mas
~/Documents/GitHub/dotfiles/scripts/run-playbook.sh --tags config
~/Documents/GitHub/dotfiles/scripts/run-playbook.sh --tags apps,config
```

## Repo layout

Only deliberately-authored, non-personal files are in this repo.
Everything generated from your machine lives in iCloud Drive at
`~/Library/Mobile Documents/com~apple~CloudDocs/dotfiles-private/`.

```
dotfiles/                         ← public repo (github.com/beauwoods/dotfiles)
├── DECISIONS.md                  # Why things are the way they are
├── MANUAL_STEPS.md               # Full deployment day runbook
├── ansible/
│   ├── ansible.cfg               # Interpreter config, cleaner output, log path
│   ├── main.yml                  # Top-level playbook (tagged by role)
│   ├── requirements.yml          # Ansible Galaxy dependencies
│   ├── inventory/
│   ├── vars/main.yml             # Apps, URLs, osx_defaults — edit this
│   └── roles/
│       ├── system_defaults/      # osx_defaults settings
│       ├── app_installs/         # Direct-download .dmg/.pkg/.zip installs
│       ├── mas/                  # App Store installs via mas CLI
│       └── app_config/           # Reads from iCloud private + deploys Firefox policy
├── configs/
│   ├── firefox/                  # policies.json (enterprise policy, no personal data)
│   └── ssh/README.md             # 1Password SSH agent setup docs
└── scripts/
    ├── bootstrap.sh              # Run first on new machine (curl-able)
    ├── preflight.sh              # Run on old machine before deployment day
    └── run-playbook.sh           # Wrapper for all manual Ansible re-runs

dotfiles-private/                 ← iCloud Drive (never in this repo)
├── ssh/config                    # SSH config with host aliases
├── ssh/*.pub                     # Old machine's public keys (reference)
├── shell/                        # .gitconfig, .zshrc, etc.
├── mail/signatures.md            # Email signature HTML
├── iterm2/                       # iTerm2 profile (.plist)
├── istat/                        # iStat Menus preferences
├── defaults_capture.txt          # System settings reference from old machine
└── installed_apps.txt            # App inventory from old machine
```

## What's automated

| Area | How |
|---|---|
| App Store apps | `mas` CLI via `mas_apps` in `vars/main.yml` |
| Direct-download apps | `get_url` + `hdiutil`/`installer`/`unarchive` |
| macOS settings | `osx_defaults` module — see `vars/main.yml` for full list with rationale |
| Shell dotfiles | Copied from iCloud private → `~/` |
| SSH config | Copied from iCloud private → `~/.ssh/config` |
| Firefox | `policies.json` deployed to `/Library/Application Support/Mozilla/` |
| Little Snitch prefs | `littlesnitch write-preference` via app_config role |
| Little Snitch rules | Subscriptions added manually via GUI (LS6 has no CLI subscribe command) |
| iTerm2 | `PrefsCustomFolder` pointed at iCloud private `iterm2/` directory |

## osx_defaults catalogue

All automated system settings are in `ansible/vars/main.yml` under `osx_defaults`,
each with an inline comment explaining what it does and what macOS defaults to
without it. Settings are grouped by area:

- **Trackpad** — tap to click, scroll direction, click force thresholds
- **Finder** — show all file extensions
- **Clock & Units** — 24-hour clock, Celsius temperature
- **Sound** — UI sounds off, Tink alert sound
- **Mail** — archive on delete (remote image loading is set manually — requires Mail open)
- **iTerm2** — prefs folder location (iCloud private)

Settings intentionally *not* automated are documented at the bottom of the
`osx_defaults` section in `vars/main.yml`.

## Logs

Every run via `run-playbook.sh` or `bootstrap.sh` writes a timestamped log:

```
~/.local/share/dotfiles/logs/ansible_YYYYMMDD_HHMMSS_<tags>.log
```

To tail a run in progress:
```bash
tail -f ~/.local/share/dotfiles/logs/$(ls -t ~/.local/share/dotfiles/logs/ | head -1)
```

## See also

- `DECISIONS.md` — tooling choices and rationale
- `MANUAL_STEPS.md` — everything that can't be automated
