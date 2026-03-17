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

  # ── Settings & Package Verification ─────────────────────────────────
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "## Settings Verification"
  echo ""
  # Strip ANSI color codes for the plain-text report
  "$LOCAL/scripts/mac-config" check 2>&1 | sed 's/\x1b\[[0-9;]*m//g' || true
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "## Package Status"
  echo ""
  "$LOCAL/scripts/mac-config" status 2>&1 | sed 's/\x1b\[[0-9;]*m//g' || true
} > "$REPORT"

open "$REPORT"
echo ""
echo "Migration report saved to: $REPORT"
echo "Done. SSH keys and remaining manual steps in README.md."
