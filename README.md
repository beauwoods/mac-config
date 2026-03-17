# dotfiles

Beau's Mac setup. Deterministic, repeatable, no Homebrew.

## Philosophy

This repo is the source of truth for a new machine setup. The old machine
is a *reference*, not a source of truth. Everything here was written
intentionally, not migrated.

## Preflight (on the OLD machine)

Before deployment day, run this on the old machine to capture configs:

```bash
~/Documents/GitHub/dotfiles/scripts/preflight.sh
```

Then commit and push the results.

## Deployment (on the NEW machine)

```bash
# 1. Bootstrap: installs OS updates, Xcode CLI tools, Ansible
~/Documents/GitHub/dotfiles/scripts/bootstrap.sh

# 2. Follow MANUAL_STEPS.md Stage 2 (auth: App Store, 1Password, Adobe, SetApp, Little Snitch)

# 3. Run the playbook
cd ~/Documents/GitHub/dotfiles/ansible
ansible-playbook main.yml -i inventory/localhost --ask-become-pass
```

### Partial runs (useful for re-running after failures)

```bash
# Available tags: defaults, apps, mas, config
ansible-playbook main.yml -i inventory/localhost --ask-become-pass --tags defaults
ansible-playbook main.yml -i inventory/localhost --ask-become-pass --tags mas
ansible-playbook main.yml -i inventory/localhost --ask-become-pass --tags apps,config
```

## Repo layout

```
dotfiles/
├── DECISIONS.md              # Why things are the way they are
├── MANUAL_STEPS.md           # Human runbook for deployment day
├── ansible/
│   ├── ansible.cfg           # Interpreter config, output settings
│   ├── main.yml              # Top-level playbook (tagged by role)
│   ├── requirements.yml      # Ansible Galaxy role dependencies
│   ├── inventory/
│   ├── vars/main.yml         # Apps, URLs, osx_defaults — edit this
│   └── roles/
│       ├── system_defaults/  # osx_defaults settings
│       ├── app_installs/     # Direct-download .dmg/.pkg/.zip installs
│       ├── mas/              # App Store installs via mas CLI
│       └── app_config/       # SSH, dotfiles, Firefox, Little Snitch rules
├── configs/
│   ├── defaults_capture.txt  # defaults read output from old machine
│   ├── firefox/              # policies.json (enterprise policy)
│   ├── iterm2/               # Profile .plist (exported from old machine)
│   ├── istat/                # iStat Menus preferences
│   ├── mail/                 # Signature HTML captured by preflight
│   └── ssh/                  # config + public keys (private keys → 1Password)
└── scripts/
    ├── bootstrap.sh           # Runs first: OS updates, Xcode, Ansible install
    └── preflight.sh           # Runs on old machine: captures all configs
```

## What's automated

| Area | How |
|---|---|
| App Store apps | `mas` CLI via `mas_apps` in vars/main.yml |
| Direct-download apps | `get_url` + `hdiutil`/`installer`/`unarchive` |
| macOS settings | `osx_defaults` module — see vars/main.yml for full list with rationale |
| Shell dotfiles | Copied from `configs/shell/` |
| SSH config | Copied from `configs/ssh/` (keys live in 1Password SSH agent) |
| Firefox | `policies.json` deployed to `/Library/Application Support/Mozilla/` |
| Little Snitch | Rule subscriptions via `littlesnitch subscribe` |
| iTerm2 | `defaults write` points it at `configs/iterm2/` |

## osx_defaults catalogue

All automated system settings are in `ansible/vars/main.yml` under `osx_defaults`,
each with an inline comment explaining what it does and what macOS defaults to
without it. The full list is grouped by area:

- **Trackpad** — tap to click, scroll direction, click force thresholds
- **Finder** — show all file extensions
- **Clock & Units** — 24-hour clock, Celsius temperature
- **Sound** — UI sounds off, Tink alert sound
- **Mail** — no remote image loading, archive on delete
- **iTerm2** — prefs folder location

Settings intentionally *not* automated (and why) are documented at the bottom
of the `osx_defaults` section in vars/main.yml.

## See also

- `DECISIONS.md` — tooling choices and rationale
- `MANUAL_STEPS.md` — everything that can't be automated
- `configs/defaults_capture.txt` — full defaults dump from old machine
