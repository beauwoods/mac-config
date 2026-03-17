#!/bin/bash
# bootstrap.sh — one-command Mac setup using geerlingguy/mac-dev-playbook
#
# Usage (curl from a fresh machine):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/beauwoods/mac-config/main/scripts/bootstrap.sh)"
#
# Or from a local clone:
#   bash ~/mac-config/scripts/bootstrap.sh

set -euo pipefail

REPO="https://github.com/beauwoods/mac-config"
LOCAL="$HOME/mac-config"

# ── Xcode CLI tools ────────────────────────────────────────────────────
if ! xcode-select -p &>/dev/null; then
  xcode-select --install 2>/dev/null || true
  echo "Click 'Install' in the dialog that appeared. Waiting..."
  until xcode-select -p &>/dev/null; do sleep 10; done
fi

# ── Clone or update this repo ─────────────────────────────────────────
if [ ! -d "$LOCAL" ]; then
  git clone "$REPO.git" "$LOCAL"
else
  git -C "$LOCAL" pull --ff-only 2>/dev/null || true
fi
# Re-exec from cloned copy so we get the full script.
# Everything above this line runs twice (before and after re-exec).
# Everything below runs once, from the cloned copy.
[ "$0" != "$LOCAL/scripts/bootstrap.sh" ] && exec bash "$LOCAL/scripts/bootstrap.sh" "$@"

# ── Credentials (runs once, after re-exec) ────────────────────────────
# Kill any orphaned sudo keep-alive loops from previous crashed runs
pkill -f 'sudo -n true' 2>/dev/null || true

read -s -r -p "Enter your password once — needed for the entire setup: " SUDO_PASS
echo ""
echo "$SUDO_PASS" | sudo -S -v 2>/dev/null
( while true; do sudo -n true; sleep 60; done ) &
SUDO_PID=$!
trap 'kill $SUDO_PID 2>/dev/null' EXIT

# ── Homebrew ──────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# ── Ansible ───────────────────────────────────────────────────────────
# pip3 installs binaries to a user-local dir not on PATH by default
export PATH="$(python3 -m site --user-base)/bin:$PATH"
if ! command -v ansible-playbook &>/dev/null; then
  pip3 install ansible --break-system-packages 2>/dev/null \
    || pip3 install ansible
fi

# ── Geerling's playbook ───────────────────────────────────────────────
GEERLING="$HOME/mac-dev-playbook"
if [ ! -d "$GEERLING" ]; then
  git clone https://github.com/geerlingguy/mac-dev-playbook.git "$GEERLING"
fi
cd "$GEERLING"
ansible-galaxy install -r "$LOCAL/requirements.yml"

# Symlink our config and task files into Geerling's playbook directory.
# Individual task symlinks (not the whole dir) so Geerling's own task
# files (sudoers.yml, terminal.yml, osx.yml, etc.) remain in place.
ln -sf "$LOCAL/config.yml" "$GEERLING/config.yml"
for f in "$LOCAL/tasks"/*.yml; do
  ln -sf "$f" "$GEERLING/tasks/$(basename "$f")"
done

# Make configs/ accessible for tasks that reference it (e.g. firefox-policy.yml)
ln -sf "$LOCAL/configs" "$GEERLING/configs"

# ── Phase 1 ───────────────────────────────────────────────────────────
LOG="$HOME/.local/share/mac-setup/logs/ansible_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$(dirname "$LOG")"
export ANSIBLE_LOG_PATH="$LOG"

PHASE1_OK=true
ansible-playbook main.yml --skip-tags post-auth \
  --become-password-file <(echo "$SUDO_PASS") \
  || PHASE1_OK=false

if $PHASE1_OK; then
  echo "Phase 1 complete. Log: $LOG"
else
  echo "Phase 1 finished with errors (see above). Log: $LOG"
  echo "Continuing to manual pause — errors will appear in the migration report."
fi

# ── Wireshark (needs interactive sudo for its .pkg) ──────────────────
# Installed here (not in Ansible) because its post-install .pkg calls
# sudo internally and needs a real terminal. Done after Phase 1 so it
# doesn't block anything if it fails.
echo ""
echo "Installing Wireshark (may prompt for password)..."
brew install --cask wireshark || true

# ── Pause ─────────────────────────────────────────────────────────────
open "$LOCAL/docs/MANUAL_PAUSE.md"
echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Steps opened in a separate window."
echo "  Complete them, then press Enter to continue."
echo "══════════════════════════════════════════════════════════"
read -r -p "  Press Enter when ready... "
echo ""

# ── Phase 2 ───────────────────────────────────────────────────────────
PHASE2_OK=true
ansible-playbook main.yml --tags post-auth \
  --become-password-file <(echo "$SUDO_PASS") \
  || PHASE2_OK=false

if ! $PHASE2_OK; then
  echo "Phase 2 finished with errors (see above). Log: $LOG"
fi

# ── Migration Report ────────────────────────────────────────────────
# Disable strict error handling — report must complete even if
# individual checks fail (missing dirs, empty grep, etc.)
set +euo pipefail

PRIVATE_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/dotfiles-private"
OLD_INVENTORY="$PRIVATE_DIR/installed_apps.txt"
REPORT="$HOME/Desktop/migration-report.txt"

{
  echo "Migration Report — $(date)"
  echo "════════════════════════════════════════════════════════════"

  if ! $PHASE1_OK || ! $PHASE2_OK; then
    echo ""
    echo "!! WARNING: Ansible reported errors during setup."
    echo "   Phase 1: $( $PHASE1_OK && echo OK || echo ERRORS )"
    echo "   Phase 2: $( $PHASE2_OK && echo OK || echo ERRORS )"
    echo "   Review the log: $LOG"
  fi
  echo ""

  # Capture current state
  echo "## Currently Installed (/Applications)"
  ls /Applications/ 2>/dev/null | grep '\.app$' | sort || echo "[none]"
  echo ""

  echo "## Currently Installed (/Applications/Setapp)"
  ls "/Applications/Setapp/" 2>/dev/null | grep '\.app$' | sort || echo "[none]"
  echo ""

  echo "## App Store Apps"
  if command -v mas &>/dev/null; then
    mas list 2>/dev/null || echo "[mas list failed]"
  else
    echo "[mas not available]"
  fi
  echo ""

  echo "## Homebrew Casks"
  brew list --cask 2>/dev/null | sort || echo "[none]"
  echo ""

  # Compare against old machine if inventory exists
  if [ -f "$OLD_INVENTORY" ]; then
    echo "════════════════════════════════════════════════════════════"
    echo "## Comparison with Old Machine"
    echo ""

    # Extract .app names from old inventory
    OLD_APPS=$(grep '\.app$' "$OLD_INVENTORY" | sed 's/\.app$//' | sort || true)
    NEW_APPS=$(ls /Applications/ /Applications/Setapp/ ~/Applications/ 2>/dev/null \
               | grep '\.app$' | sed 's/\.app$//' | sort -u || true)

    MISSING=$(comm -23 <(echo "$OLD_APPS") <(echo "$NEW_APPS") || true)
    ADDED=$(comm -13 <(echo "$OLD_APPS") <(echo "$NEW_APPS") || true)

    if [ -n "$MISSING" ]; then
      echo "### On old machine but NOT on new (may need manual install):"
      echo "$MISSING" | while read -r app; do [ -n "$app" ] && echo "  - $app"; done
    else
      echo "### No missing apps — everything from the old machine is present."
    fi
    echo ""

    if [ -n "$ADDED" ]; then
      echo "### On new machine but NOT on old (newly added):"
      echo "$ADDED" | while read -r app; do [ -n "$app" ] && echo "  + $app"; done
    else
      echo "### No new additions beyond what was on the old machine."
    fi
  else
    echo "(No old-machine inventory found at $OLD_INVENTORY — skipping comparison.)"
    echo "Run preflight.sh on the old machine first for a full diff."
  fi

  # ── Settings Post-Check ──────────────────────────────────────────────
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "## Settings Verification"
  echo ""
  echo "Checking macOS defaults against expected values..."
  echo ""

  SETTINGS_OK=0
  SETTINGS_FAIL=0

  check_default() {
    local domain="$1" key="$2" expected="$3" label="$4"
    actual=$(defaults read "$domain" "$key" 2>/dev/null) || actual="[not set]"
    if [ "$actual" = "$expected" ]; then
      echo "  OK  $label: $actual"
      SETTINGS_OK=$((SETTINGS_OK+1))
    else
      echo "  !!  $label: expected=$expected actual=$actual"
      SETTINGS_FAIL=$((SETTINGS_FAIL+1))
    fi
  }

  # Trackpad
  check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "Clicking" "1" "Tap to click (Bluetooth)"
  check_default "com.apple.AppleMultitouchTrackpad" "Clicking" "1" "Tap to click (built-in)"
  check_default "com.apple.AppleMultitouchTrackpad" "FirstClickThreshold" "1" "Light click threshold"
  check_default "com.apple.AppleMultitouchTrackpad" "SecondClickThreshold" "1" "Light force-click threshold"
  check_default "NSGlobalDomain" "com.apple.swipescrolldirection" "0" "Scroll direction (traditional)"

  # Finder
  check_default "NSGlobalDomain" "AppleShowAllExtensions" "1" "Show all file extensions"
  check_default "com.apple.finder" "AppleShowAllFiles" "1" "Show hidden files"
  check_default "com.apple.finder" "ShowPathbar" "1" "Finder path bar"
  check_default "com.apple.finder" "ShowStatusBar" "1" "Finder status bar"
  check_default "com.apple.finder" "FXPreferredViewStyle" "Nlsv" "Finder list view"
  check_default "com.apple.finder" "FXEnableExtensionChangeWarning" "0" "Extension change warning off"
  check_default "com.apple.WindowManager" "EnableStandardClickToShowDesktop" "0" "Click desktop to show off"

  # Clock & units
  check_default "NSGlobalDomain" "AppleICUForce24HourTime" "1" "24-hour clock"
  check_default "NSGlobalDomain" "AppleTemperatureUnit" "Celsius" "Temperature unit"

  # Sound
  check_default "NSGlobalDomain" "com.apple.sound.uiaudio.enabled" "0" "UI sounds disabled"

  # Save & Print dialogs
  check_default "NSGlobalDomain" "NSNavPanelExpandedStateForSaveMode" "1" "Save dialog expanded"
  check_default "NSGlobalDomain" "NSNavPanelExpandedStateForSaveMode2" "1" "Save dialog expanded (v2)"
  check_default "NSGlobalDomain" "PMPrintingExpandedStateForPrint" "1" "Print dialog expanded"
  check_default "NSGlobalDomain" "PMPrintingExpandedStateForPrint2" "1" "Print dialog expanded (v2)"

  # Screen saver & lock
  check_default "com.apple.screensaver" "askForPasswordDelay" "0" "Password required immediately"

  # Calendar (requires Full Disk Access — see MANUAL_PAUSE.md step 1)
  if defaults read com.apple.iCal "Show Week Numbers" &>/dev/null; then
    check_default "com.apple.iCal" "Show Week Numbers" "1" "Cal show week numbers"
    check_default "com.apple.iCal" "TimeZone support enabled" "1" "Cal time zone support"
    check_default "com.apple.iCal" "first day of week" "0" "Cal week starts Sunday"
    check_default "com.apple.iCal" "last calendar view description" "7-day" "Cal default week view"
    check_default "com.apple.iCal" "number of hours displayed" "14" "Cal hours displayed"
    check_default "com.apple.iCal" "display birthdays calendar" "1" "Cal show birthdays"
    check_default "com.apple.iCal" "ShowDeclinedEvents" "0" "Cal hide declined events"
    check_default "com.apple.iCal" "InvitationNotificationsDisabled" "1" "Cal invitation popups off"
    check_default "com.apple.iCal" "CalendarSidebarShown" "1" "Cal sidebar visible"
    check_default "com.apple.iCal" "CalDefaultCalendar" "UseLastSelectedAsDefaultCalendar" "Cal default calendar"
  else
    echo "  --  Calendar: domain not readable — ensure Terminal has Full Disk Access and Calendar has been launched once"
  fi

  # Mail (requires Full Disk Access — see MANUAL_PAUSE.md step 1)
  if defaults read com.apple.mail MoveDiscardedMessagesToArchive &>/dev/null; then
    check_default "com.apple.mail" "MoveDiscardedMessagesToArchive" "1" "Mail archive behavior"
    check_default "com.apple.mail" "ThreadingDefault" "1" "Mail threading on"
    check_default "com.apple.mail" "UserDidCollapseFavoritesSectionKey" "0" "Mail favorites sidebar expanded"
    check_default "com.apple.mail" "FullScreenPreferSplit" "0" "Mail full-screen no split"
    check_default "com.apple.mail" "SwipeAction" "1" "Mail swipe action"
    check_default "com.apple.mail" "ShowCcHeader" "1" "Mail CC header shown"
    check_default "com.apple.mail" "ShowBccHeader" "1" "Mail BCC header shown"
    check_default "com.apple.mail" "ShowComposeFormatInspectorBar" "1" "Mail format bar shown"
    check_default "com.apple.mail" "ShowPriorityControl" "1" "Mail priority control shown"
    check_default "com.apple.mail" "ShowReplyToHeader" "0" "Mail Reply-To hidden"
    check_default "com.apple.mail" "AlwaysIncludeOriginalMessage" "0" "Mail don't include original"
    check_default "com.apple.mail" "PlayMailSounds" "0" "Mail sounds off"
    check_default "com.apple.mail" "NewMessagesSoundName" "" "Mail notification sound none"
    check_default "com.apple.mail" "MailDockBadge" "5" "Mail dock badge style"
    check_default "com.apple.mail" "SpellCheckingBehavior" "InlineSpellCheckingEnabled" "Mail inline spell check"
  else
    echo "  --  Mail: domain not readable — ensure Terminal has Full Disk Access and Mail has been launched once"
  fi

  # Dock
  check_default "com.apple.dock" "tilesize" "41" "Dock tile size (px)"
  check_default "com.apple.dock" "autohide" "0" "Dock autohide off"
  check_default "com.apple.dock" "magnification" "0" "Dock magnification off"
  check_default "com.apple.dock" "mru-spaces" "0" "MRU spaces off"
  check_default "com.apple.dock" "launchanim" "0" "Launch animation off"
  check_default "com.apple.dock" "show-recents" "1" "Dock show recents"

  echo ""
  echo "Settings check: $SETTINGS_OK OK, $SETTINGS_FAIL mismatched"
  if [ "$SETTINGS_FAIL" -gt 0 ]; then
    echo "Items marked !! need attention — some may require logout/restart to take effect."
  fi
} > "$REPORT"

open "$REPORT"
echo ""
echo "Migration report saved to: $REPORT"
echo "Done. SSH keys and remaining manual steps in README.md."
