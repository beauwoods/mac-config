# Manual Steps — Deployment Day Runbook

Steps marked **[VERIFY]** are handled by Ansible or a config file — your
job is to confirm they took effect, not to do them by hand. Steps marked
**[MANUAL]** have no automation path and must be done by hand.

Check each box as you go. Do not skip ahead — some steps gate others.

---

## Before the Machine Arrives (Pre-flight)

Run on your OLD machine. These gate everything else.

- [ ] Grant Terminal Full Disk Access (for Mail signatures):
      System Settings > Privacy & Security > Full Disk Access > + Terminal
- [ ] Run `scripts/preflight.sh` and resolve all warnings
      *(generates `configs/installed_apps.txt`, `configs/defaults_capture.txt`,
      and `configs/mail/signatures.md` — will prompt for sudo password for Ansible dry run)*
- [ ] Review `configs/installed_apps.txt` — any apps missing from the playbook?
- [ ] Review `configs/defaults_capture.txt` — do the keys in `ansible/vars/main.yml` match?
- [ ] Fill in account assignments in `configs/mail/signatures.md`
- [ ] Export Termius keys via Termius UI > Preferences > Keychain → save to 1Password
- [ ] iTerm2: save current settings to dotfiles folder:
      iTerm2 > Settings > General > Preferences > "Save Current Settings to Folder"
- [ ] iStat Menus: GUI export:
      iStat Menus menu bar icon > Preferences > Export Settings
      Save as `configs/istat/iStatMenusSettings.ismp`
- [ ] Set config freeze date in `DECISIONS.md`
- [ ] `git add . && git commit -m "preflight capture" && git push`

---

## Stage 1: First Boot & Foundation (~45 min)

### macOS Setup Assistant
- [ ] **[MANUAL]** Complete setup assistant (language, region, Apple ID)
- [ ] **[MANUAL]** Do NOT enable iCloud Desktop & Documents yet (enable in Stage 7)
- [ ] **[MANUAL]** Do NOT migrate from old Mac

### Bootstrap
- [ ] **[MANUAL]** Run bootstrap — clones the dotfiles repo, installs OS updates,
      Xcode CLI tools, Ansible, and Galaxy roles. You'll be prompted for your
      password once at the start, then can walk away.
      ```bash
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/beauwoods/dotfiles/main/scripts/bootstrap.sh)"
      ```
      Or if you prefer to clone first manually:
      ```bash
      mkdir -p ~/Documents/GitHub
      git clone https://github.com/beauwoods/dotfiles.git ~/Documents/GitHub/dotfiles
      ~/Documents/GitHub/dotfiles/scripts/bootstrap.sh
      ```
      **Note:** If bootstrap reports that a restart is required for OS updates,
      restart and re-run bootstrap.sh before continuing.
- [ ] **[VERIFY]** Bootstrap completed without errors
- [ ] **[VERIFY]** Dotfiles repo cloned to `~/Documents/GitHub/dotfiles`
- [ ] **[VERIFY]** Ansible found: bootstrap prints the path at the end

---

## Stage 2: First Ansible Run — Apps & Defaults (~45 min, unattended)

No auth required for this stage. Start it and walk away.

```bash
cd ~/Documents/GitHub/dotfiles/ansible
ansible-playbook main.yml -i inventory/localhost --ask-become-pass --tags apps,defaults
```

This installs all direct-download apps (Chrome, Firefox, Little Snitch, iTerm2, etc.)
and applies all system settings (trackpad, scroll, clock, sounds, Finder, Mail, iTerm2).
App Store apps and per-app config run in Stage 4 after auth.

- [ ] Run completed with no failed tasks
- [ ] Note any failed tasks here: ___________________

---

## Stage 3: Auth Session (~30 min)

Complete all logins. These gate the Stage 4 Ansible run.

- [ ] **[MANUAL]** App Store — sign in *(gates: all mas installs)*
- [ ] **[MANUAL]** 1Password — open app, sign into account
- [ ] **[MANUAL]** Adobe Creative Cloud — sign in as Nuri *(gates: Acrobat, PS, LR)*
- [ ] **[MANUAL]** SetApp — sign in *(gates: Paste, CleanMyMac, Timing, iStat Menus)*
- [ ] **[MANUAL]** Little Snitch — enter license key
      *(retrieve from 1Password — store it there if you haven't already)*

*Defer until after Stage 4:*
Tailscale, Backblaze, Google Drive, Slack, Discord, Teams, Zoom, Chrome sync,
Microsoft 365 activation

---

## Stage 4: Second Ansible Run — App Store & Config (~30 min, mostly unattended)

```bash
cd ~/Documents/GitHub/dotfiles/ansible
ansible-playbook main.yml -i inventory/localhost --ask-become-pass --tags mas,config
```

This installs all App Store apps and deploys per-app configs (SSH config, dotfiles,
Firefox policies, Little Snitch rule subscriptions).

- [ ] Run completed with no failed tasks
- [ ] Note any failed tasks here: ___________________

---

## Stage 5: Verify Automated Configuration

### System Settings — Trackpad
- [ ] **[VERIFY]** Point & Click: "Tap to click" is ON
- [ ] **[VERIFY]** Scroll & Zoom: "Natural scrolling" is OFF

### System Settings — General
- [ ] **[VERIFY]** Date & Time: Clock shows 24-hour format (e.g. 14:30 not 2:30 PM)
- [ ] **[VERIFY]** Language & Region: Temperature shows Celsius

### System Settings — Sound
- [ ] **[VERIFY]** Sound Effects: UI sound effects are OFF
- [ ] **[VERIFY]** Sound Effects: Alert sound is "Tink" (not Funk/Basso/etc.)

### Finder
- [ ] **[VERIFY]** File extensions are visible (e.g. files show as "report.docx" not "report")
      If not visible: Finder > Settings > Advanced > "Show all filename extensions"

### Mail
- [ ] **[VERIFY]** Mail > Settings > Viewing: "Load remote content in messages" is OFF
- [ ] **[VERIFY]** Mail > Settings > Viewing: "Move discarded messages to" shows Archive

### Firefox
- [ ] **[VERIFY]** Open `about:policies` — all entries show green checkmarks
- [ ] **[VERIFY]** Extensions: NoScript is installed and enabled
- [ ] **[VERIFY]** Settings > Privacy: Strict tracking protection is on
- [ ] **[VERIFY]** Settings > Privacy: "Always use private browsing mode" is on
- [ ] **[VERIFY]** Settings > Privacy: "Ask to save logins" is off
- [ ] **[VERIFY]** Settings > General: "Always check if Firefox is your default browser" is off
- [ ] **[VERIFY]** HTTPS-Only Mode is enabled

### Little Snitch
- [ ] **[VERIFY]** Network Monitor shows all 6 rule group subscriptions loaded
- [ ] **[VERIFY]** Alert Detail shows "Port and Protocol Details"

### iTerm2
- [ ] **[VERIFY]** Settings > General > Preferences: custom folder points to `~/Documents/GitHub/dotfiles/configs/iterm2`
- [ ] **[VERIFY]** Your profile and color scheme loaded correctly
- [ ] **[MANUAL]** If profile didn't load: click "Save Current Settings to Folder" in that pane,
      then restart iTerm2

---

## Stage 6: Post-Ansible Manual Steps

### System Preferences
- [ ] **[MANUAL]** Security & Privacy: Enable Apple Watch unlock
- [ ] **[MANUAL]** Internet Accounts: Add each account, select services (Mail, Calendar, Contacts)

### Mail
- [ ] **[MANUAL]** Add signatures from `configs/mail/signatures.md`:
      1. Mail > Settings > Signatures
      2. Click + for each signature, paste HTML content from the file
      3. Drag each signature to its account on the left
      4. Set the default for each account

### Browsers
- [ ] **[MANUAL]** Chrome: sign in, enable sync (installs extensions + settings automatically)
- [ ] **[MANUAL]** 1Password: install browser extensions for Safari, Firefox, Chrome

### Microsoft 365
- [ ] **[MANUAL]** Open Word (or any Office app) and sign into M365 account to activate
      *(All Office apps install via App Store in Stage 4, but need M365 sign-in to unlock
      editing. One sign-in activates all five apps.)*
- [ ] **[MANUAL]** Windows App (Remote Desktop): configure connections

### Adobe Creative Cloud
- [ ] **[MANUAL]** Open CC app (should be logged in as Nuri from Stage 2)
- [ ] **[MANUAL]** Install Acrobat
- [ ] **[MANUAL]** Install Photoshop
- [ ] **[MANUAL]** Install Lightroom

### SetApp
- [ ] **[MANUAL]** Open SetApp (should be logged in from Stage 2)
- [ ] **[MANUAL]** Install Paste
- [ ] **[MANUAL]** Install CleanMyMac
- [ ] **[MANUAL]** Install Timing
- [ ] **[MANUAL]** Install iStat Menus

### iStat Menus
- [ ] **[MANUAL]** Import settings: open `configs/istat/iStatMenusSettings.ismp`
      (or iStat Menus > Preferences > Import if the Ansible task didn't fire)

### SSH Keys

SSH keys on the new machine should be **freshly generated**, not copied from
the old machine. A key should represent this specific device's identity. If
the old laptop is ever lost or decommissioned, you can revoke exactly one key
per service and know that device is fully cut off.

- [ ] **[MANUAL]** Enable 1Password SSH agent first:
      1Password > Settings > Developer > "Use the SSH agent"
- [ ] **[VERIFY]** `~/.ssh/config` restored by Ansible with IdentityAgent line:
      `cat ~/.ssh/config` — should show the 1Password agent socket path
- [ ] **[MANUAL]** Generate a new key on this machine:
      ```bash
      ssh-keygen -t ed25519 -C "$(hostname)-$(date +%Y-%m)"
      # e.g. MacBookPro-2026-03
      ```
- [ ] **[MANUAL]** Store the new private key in 1Password:
      1Password > New Item > SSH Key > import `~/.ssh/id_ed25519`
- [ ] **[MANUAL]** Delete the key file from disk (1Password agent serves it):
      ```bash
      rm ~/.ssh/id_ed25519
      # Keep ~/.ssh/id_ed25519.pub — it's public, no risk
      ```
- [ ] **[MANUAL]** Add the new public key to each service:
      - GitHub: github.com > Settings > SSH Keys > New SSH key
      - Any VPS/lab machines: `ssh-copy-id` or manually add to `~/.ssh/authorized_keys`
- [ ] **[MANUAL]** Test agent is serving the new key: `ssh-add -l`
- [ ] **[MANUAL]** Test GitHub: `ssh -T git@github.com`
- [ ] **[MANUAL]** Switch dotfiles remote to SSH:
      ```bash
      git remote set-url origin git@github.com:beauwoods/dotfiles.git
      ```
- [ ] **[MANUAL]** Import Termius keys: Termius > Preferences > Keychain > Use SSH agent
- [ ] **[MANUAL]** Test SSH connections to other key hosts (VPS, lab machines, etc.)
- [ ] **[MANUAL]** Once everything works: revoke the old machine's key from each service
      *(GitHub: Settings > SSH Keys > delete the old one)*

### Remaining Account Logins
- [ ] **[MANUAL]** Tailscale — open app, authenticate via browser
- [ ] **[MANUAL]** Backblaze — sign in, configure backup folders and schedule
- [ ] **[MANUAL]** Google Drive — sign in, configure sync folders
- [ ] **[MANUAL]** Slack — sign into all workspaces
- [ ] **[MANUAL]** Discord — sign in
- [ ] **[MANUAL]** Microsoft Teams — sign in
- [ ] **[MANUAL]** Zoom — sign in

### Logitech
- [ ] **[MANUAL]** If Logitech Options+ is installed: open preferences and disable Logi Flow
      *(Flow hammers Tailscale IPs with ~28k connection attempts/week when enabled;
      Little Snitch rules deny the traffic but disabling Flow stops it at the source)*

### Privacy Permissions
Grant these in System Settings > Privacy & Security proactively rather than
waiting for each app to prompt.

- [ ] **[MANUAL]** Full Disk Access: Backblaze, iTerm2
- [ ] **[MANUAL]** Screen Recording: Zoom, Microsoft Teams
- [ ] **[MANUAL]** Accessibility: Magnet (window manager — prompts on first use)
- [ ] **[MANUAL]** Accessibility: [check which other apps request this on first launch]
- [ ] **[MANUAL]** Network Extension: Little Snitch (prompted on first launch)
- [ ] **[MANUAL]** Wireshark: add user to `access_bpf` group:
      ```bash
      sudo dseditgroup -o edit -a $(whoami) -t user access_bpf
      ```

---

## Stage 7: Final Steps

- [ ] **[MANUAL]** iCloud: enable Desktop & Documents sync
      System Settings > Apple ID > iCloud Drive > Desktop & Documents
- [ ] Restart Mac
- [ ] Smoke test:
  - [ ] Finder shows file extensions
  - [ ] Clock shows 24-hour format
  - [ ] Temperature shows Celsius
  - [ ] UI sounds are off, alert sound is Tink
  - [ ] Scroll direction is correct (non-natural)
  - [ ] Browser extensions working in Safari, Firefox, Chrome
  - [ ] 1Password prompting in all three browsers
  - [ ] Tailscale connects
  - [ ] Backblaze backup initializing
  - [ ] Little Snitch alerting (test by opening a new app)
  - [ ] iTerm2 profile looks correct
  - [ ] iStat Menus visible in menu bar with correct layout
  - [ ] Magnet window snapping works
  - [ ] `ssh -T git@github.com` still works after restart
- [ ] `git add . && git commit -m "post-deployment notes" && git push`

---

## Notes / Issues Encountered

*Fill in on deployment day.*

---

## Time Estimate

| Stage | Estimated time |
|---|---|
| Pre-flight (before machine arrives) | 2-3 hours |
| Stage 1: First boot + bootstrap | 45 min |
| Stage 2: Apps & defaults (unattended) | 45 min |
| Stage 3: Auth session | 30 min |
| Stage 4: App Store & config (unattended) | 30 min |
| Stage 5: Verify automated config | 20 min |
| Stage 6: Manual steps | 60-90 min |
| Stage 7: Final steps + smoke test | 30 min |
| **Total on deployment day** | **~3.5-4.5 hours** |
