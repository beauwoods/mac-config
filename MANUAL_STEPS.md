# Manual Steps — Deployment Day Runbook

The goal is maximum automation. There are only two moments that require
your attention: the initial setup, and a short post-install auth session.
Everything else runs unattended.

---

## Step 1: macOS Setup Assistant (~10 min)

- [ ] Complete language, region, accessibility setup
- [ ] **Sign into Apple ID when prompted** — this simultaneously signs you into
      the App Store and iCloud. iCloud will begin syncing your private configs
      (shell dotfiles, SSH config, signatures, iTerm2 profile) in the background.
- [ ] Do NOT enable iCloud Desktop & Documents yet (do this at the end)
- [ ] Do NOT migrate from old Mac

---

## Step 2: Run Bootstrap (~2 hours, unattended after one interaction)

Open Terminal and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/beauwoods/dotfiles/main/scripts/bootstrap.sh)"
```

You'll be asked for your password once, then asked to click "Install" for
the Xcode CLI tools dialog. After that, walk away. Bootstrap will:

- Install Xcode CLI tools
- Clone this repo
- Install pending macOS updates
- Install Ansible
- Install all direct-download apps (Chrome, Firefox, Little Snitch, iTerm2, etc.)
- Install all App Store apps via `mas` (works because you signed into Apple ID above)
- Apply all system settings (trackpad, Finder, clock, sound, etc.)

**If bootstrap reports a restart is required** for OS updates, restart and
re-run the same curl command — it picks up where it left off.

**If it fails mid-run**, check the output for the error, fix it, then re-run
with the specific tag that failed:

```bash
~/Documents/GitHub/dotfiles/scripts/run-playbook.sh --tags apps
```

The log from the failed run is in `~/.local/share/dotfiles/logs/` — check the
most recent file for details.

---

## Step 3: Four Auth Tasks (~15 min)

When bootstrap finishes, these apps are already installed. Just open each one and sign in:

- [ ] **Adobe Creative Cloud** — open, sign in as Nuri, then install:
      Acrobat, Photoshop, Lightroom
- [ ] **SetApp** — open, sign in, then install:
      Paste, CleanMyMac, Timing, iStat Menus
- [ ] **Little Snitch** — open, enter license key from 1Password
- [ ] **1Password** — open, sign into account, then:
      Settings > Developer > enable "Use the SSH agent"

That's the complete list of things that can't be automated. Everything else
is already done.

---

## Step 4: Final Ansible Run (~5 min)

This deploys SSH config, shell dotfiles, Firefox policy, and Little Snitch
preferences. Needs Little Snitch licensed and 1Password running.

```bash
~/Documents/GitHub/dotfiles/scripts/run-playbook.sh --tags config
```

The log will be at `~/.local/share/dotfiles/logs/ansible_*_config.log`.

---

## Step 5: Verify (~20 min)

### System Settings
- [ ] Trackpad > "Tap to click" is ON
- [ ] Scroll direction is non-natural (traditional)
- [ ] Clock shows 24-hour format (e.g. 14:30)
- [ ] Temperature shows Celsius
- [ ] Sound effects are OFF, alert sound is Tink

### Finder
- [ ] File extensions visible ("report.docx" not "report")
- [ ] Hidden files visible, path bar and status bar showing
- [ ] Default view is List

### Mail
- [ ] Settings > Viewing > "Move discarded messages to" shows Archive
- [ ] **[MANUAL]** Settings > Viewing: turn OFF "Load remote content in messages"
      *(must be done with Mail open — can't be automated)*

### Firefox
- [ ] `about:policies` — all entries show green checkmarks
- [ ] NoScript installed, private browsing mode on, HTTPS-only on

### Little Snitch
- [ ] All 6 rule group subscriptions loaded in Network Monitor

### iTerm2
- [ ] Settings > General > Preferences: custom folder points to iCloud private `iterm2/`
- [ ] Profile and color scheme loaded correctly

---

## Step 6: Remaining Logins

These don't gate anything — do them when convenient after Step 4.

- [ ] Tailscale — open, authenticate via browser
- [ ] Backblaze — sign in, configure backup folders
- [ ] Google Drive — sign in, configure sync
- [ ] Slack — sign into all workspaces
- [ ] Discord — sign in
- [ ] Microsoft Teams — sign in
- [ ] Zoom — sign in
- [ ] Chrome — sign in, enable sync

### Microsoft 365
- [ ] Open Word, sign into M365 account to activate (activates all five Office apps)
- [ ] Windows App — configure Remote Desktop connections

---

## Step 7: SSH Keys

Generate a fresh key for this machine — one key per device means precise revocation.

```bash
ssh-keygen -t ed25519 -C "$(hostname)-$(date +%Y-%m)"
```

- [ ] Store private key in 1Password: New Item > SSH Key > import `~/.ssh/id_ed25519`
- [ ] Delete key file: `rm ~/.ssh/id_ed25519` (1Password agent serves it)
- [ ] Add public key to GitHub: Settings > SSH Keys > New SSH key
- [ ] Add to any VPS or lab machines
- [ ] Test: `ssh -T git@github.com`
- [ ] Switch dotfiles remote to SSH:

```bash
git remote set-url origin git@github.com:beauwoods/dotfiles.git
```

- [ ] Configure Termius: Preferences > Keychain > Use SSH agent
- [ ] Revoke old machine's key from GitHub and servers

---

## Step 8: Privacy Permissions

Grant in System Settings > Privacy & Security. Do this proactively.

- [ ] Full Disk Access: Backblaze, iTerm2
- [ ] Screen Recording: Zoom, Microsoft Teams
- [ ] Accessibility: Magnet (prompts on first use)
- [ ] Network Extension: Little Snitch (prompted on first launch)
- [ ] Wireshark:

```bash
sudo dseditgroup -o edit -a $(whoami) -t user access_bpf
```

---

## Step 9: Final Tweaks

- [ ] Keyboard: Remap Caps Lock → Escape (System Settings > Keyboard > Key Mappings)
- [ ] Keyboard: Key Repeat → Fast, Delay Until Repeat → Short
- [ ] iCloud: enable Desktop & Documents (System Settings > Apple ID > iCloud Drive)
- [ ] Logitech Options+: disable Logi Flow (stops ~28k/week connection retries to Tailscale IPs)
- [ ] Import iStat Menus settings: open `dotfiles-private/istat/iStatMenusSettings.ismp`
- [ ] Add signatures: Mail > Settings > Signatures (content in `dotfiles-private/mail/signatures.md`)
- [ ] Internet Accounts: add each account (Mail, Calendar, Contacts)
- [ ] Security: enable Apple Watch unlock

---

## Step 10: Smoke Test, then Done

- [ ] Finder: extensions visible, hidden files showing, path bar present
- [ ] Clock: 24-hour, Celsius temperature
- [ ] Sound: UI sounds off, Tink alert
- [ ] Scroll direction correct (non-natural)
- [ ] Click-to-show Desktop disabled (click desktop — windows should NOT hide)
- [ ] 1Password prompting in Safari, Firefox, Chrome
- [ ] Tailscale connects
- [ ] Backblaze initializing backup
- [ ] Little Snitch alerting on new connections
- [ ] iTerm2 profile correct
- [ ] iStat Menus visible in menu bar
- [ ] Magnet window snapping works
- [ ] `ssh -T git@github.com` works

```bash
git add . && git commit -m "post-deployment notes" && git push
```

---

## Time Estimate

| Step | Time |
|---|---|
| Step 1: macOS Setup Assistant | 10 min |
| Step 2: Bootstrap (unattended) | ~2 hours |
| Step 3: Four auth tasks | 15 min |
| Step 4: Final Ansible run | 5 min |
| Steps 5–10: Verify + misc | 45 min |
| **Total active time** | **~75 min** |
| **Total elapsed time** | **~3 hours** |
