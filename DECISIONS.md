# Decisions

Architectural and tooling choices for this setup, with rationale.
Last updated: 2025

---

## Automation framework: Ansible + shell scripts

**Chosen:** Ansible, with shell scripts for gaps.

**Alternatives considered:**
- **Nix/nix-darwin** — Most reproducible option by far, but high learning
  curve and macOS ecosystem maturity lags Linux. Worth revisiting in future.
- **Shell scripts only** — Lower friction but not idempotent by default.
  Ansible's `osx_defaults` module and idempotency checks are worth the
  small overhead.
- **Puppet/Chef** — Enterprise overhead not appropriate for personal use.

**Why not Homebrew:**
This Mac is not a development workstation. Dev work happens in VMs or VPS.
Homebrew adds a package manager that encourages local tool sprawl. All
installs use direct download URLs or the App Store via `mas`.

**Ansible install method:**
`pip3 install --user ansible` — ships with Xcode CLI tools' Python 3.
No additional package manager needed.

---

## App installs: Mac App Store preferred over direct downloads

**Chosen:** Use `mas` for any app available on the Mac App Store.
Direct downloads only for apps with no App Store presence, or where the
direct version is meaningfully different (Little Snitch, Adobe CC).

**Why App Store preferred:**
- No URL maintenance — no broken download links between now and deployment day
- Updates are handled automatically by macOS
- Install is clean and Gatekeeper-verified
- Simpler playbook tasks

**Apps moved to mas vs. original plan:**
Discord, Zoom, Microsoft Teams, Signal, 1Password, Figma, DaVinci Resolve,
Cyberduck, GeForce NOW, ChatGPT, Claude

**Apps that must remain direct downloads:**
Firefox, Chrome, GitHub Desktop, VS Code, iTerm2, Backblaze, Google Drive,
Adobe CC, Elgato Camera Hub, Wireshark, VLC, Bambu Studio, Little Snitch,
SetApp

---

## Settings backup/restore: Manual export via preflight.sh, not Mackup

**Chosen:** Manual export of specific config files via `scripts/preflight.sh`.

**Why not Mackup:**
Mackup via iCloud risks carrying forward configuration bugs from the old
machine — exactly the problem this setup is designed to avoid. `preflight.sh`
exports configs explicitly and deliberately; each file is inspectable before
committing.

**Apps with captured configs:**
- iTerm2 — `configs/iterm2/`
- iStat Menus — `configs/istat/`
- Shell dotfiles — `configs/shell/`
- SSH keys — `configs/ssh/`

**VS Code:** Settings Sync via GitHub account handles this with zero scripting.

---

## Firefox configuration: policies.json

**Chosen:** Enterprise policy file at
`/Library/Application Support/Mozilla/policies.json`

**Why:** Captures nearly all desired Firefox settings in a single
human-readable file checked into this repo. Also pre-installs extensions
by ID, so NoScript is deployed automatically.

**Extension IDs managed via policy:**
- NoScript: `{73a6fe31-595d-460b-a920-fcc0f8843232}`

---

## Privacy permissions: Manual

**Chosen:** Grant privacy permissions manually in System Settings after
deployment.

**Why not Apple Configurator 2 supervision:**
Configurator 2 + PPPC profiles would allow pre-granting Full Disk Access,
Accessibility, and Screen Recording to specific apps without touching
the GUI. However, the supervision process (erase + restore through
Configurator) is significant overhead for a personal machine, and the
privacy permission grants are a one-time step on deployment day.
Not worth the cost.

**Permission checklist is in MANUAL_STEPS.md Stage 5.**

---

## SSH key management: 1Password SSH Agent

**Chosen:** Store private keys in 1Password as SSH Key items. Use the
1Password SSH Agent to serve keys rather than keeping key files on disk.

**Why not file-based:**
Even in a private repo, committing private keys is a weaker security
boundary than a dedicated secrets manager. The 1Password agent approach
means no key files ever need to touch the new machine's filesystem.

**How it works:**
- `~/.ssh/config` contains `IdentityAgent` pointing to the 1Password
  agent socket — this is committed to the repo
- Public keys (`*.pub`) committed to `configs/ssh/`
- Private keys stored as SSH Key items in 1Password
- On new machine: install 1Password, enable SSH agent, run Ansible to
  restore config — `ssh-add -l` confirms keys are available

**Termius keys:**
Termius can use the 1Password SSH agent directly via
Preferences > Keychain > Use SSH agent, avoiding any key file handling.

**Setup instructions:** `configs/ssh/README.md`

---

## Mail signatures: configs/mail/signatures.md

Captured by `preflight.sh` from `~/Library/Mail/V*/MailData/Signatures/`.
Re-entered manually on new machine via Mail > Settings > Signatures.
Signatures change rarely; update the file and commit when they do.

---

## Little Snitch rule subscriptions: Manual GUI

**Chosen:** Rule subscriptions are added manually via the Little Snitch GUI:
Rule Groups (sidebar) > + > Subscribe to Rule Group.

**Why not CLI:** LS6 does not have a `subscribe` command. The `littlesnitch`
CLI has no mechanism for adding rule group subscriptions non-interactively.
The URLs to subscribe to are listed in `vars/main.yml` under
`little_snitch_rule_subscriptions` for reference.

**Alert settings and preferences:** Managed via `littlesnitch write-preference`,
run as Ansible tasks in the `app_config` role (requires sudo). Keys and values
are defined in `vars/main.yml` under `little_snitch_preferences`. Verified
against `littlesnitch list-preferences` output — these are NOT `defaults write`
keys; Little Snitch stores preferences in its own encrypted config store.

**License entry:** Manual (GUI only).

---

## iCloud Desktop & Documents sync: Enable last

**Rationale:** Enabling this mid-setup causes sync to propagate a
half-configured Desktop to other devices. Enable only after the machine
is fully set up and the Desktop is clean.

---

## Freeze date

<!-- Update this when you stop making reference captures from the old machine -->
**Config freeze date:** TBD

After this date, no new settings from the old machine are captured into
this repo. Changes after the freeze are made directly on the new machine
and committed here.
