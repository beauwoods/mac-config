#!/bin/bash
# bootstrap.sh
# Run this once on a fresh Mac. Installs everything that doesn't require
# a commercial account login. Walk away after entering your password.
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/beauwoods/dotfiles/main/scripts/bootstrap.sh)"
#
# Prerequisites: complete macOS Setup Assistant and sign into Apple ID first.
# That signs you into the App Store automatically — no separate step needed.

set -euo pipefail

echo "This script needs sudo access. Enter your password once, then walk away."
sudo -v
( while true; do sudo -n true; sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 1: Install Xcode Command Line Tools"
echo "    (provides git, python3, and compiler tools)"

if xcode-select -p &>/dev/null; then
  echo "    Already installed at: $(xcode-select -p)"
else
  xcode-select --install 2>/dev/null || true
  echo ""
  echo "    A dialog has appeared. Click 'Install' — NOT 'Get Xcode'."
  echo "    Waiting for installation to complete..."
  WAIT=0; TIMEOUT=600
  until xcode-select -p &>/dev/null; do
    sleep 10; WAIT=$((WAIT+10)); echo -n "."
    if [ "$WAIT" -ge "$TIMEOUT" ]; then
      echo ""; echo "ERROR: Timed out. Run 'xcode-select --install' manually then re-run this script."; exit 1
    fi
  done
  echo ""; echo "    Xcode CLI tools installed."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 2: Clone dotfiles repo"
DOTFILES_DIR="$HOME/Documents/GitHub/dotfiles"
REPO_URL="https://github.com/beauwoods/dotfiles.git"

if [ -d "$DOTFILES_DIR/.git" ]; then
  echo "    Repo already exists — pulling latest..."
  git -C "$DOTFILES_DIR" pull --ff-only
else
  mkdir -p "$HOME/Documents/GitHub"
  git clone "$REPO_URL" "$DOTFILES_DIR"
  echo "    Clone complete."
fi

# Re-exec from cloned copy if running via curl
SELF="$DOTFILES_DIR/scripts/bootstrap.sh"
if [ "$0" != "$SELF" ] && [ -f "$SELF" ]; then
  echo "    Re-running from cloned repo..."
  exec bash "$SELF" "$@"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 3: Install pending macOS software updates"

UPDATE_OUTPUT=$(softwareupdate --install --all 2>&1 || true)
echo "$UPDATE_OUTPUT"

if echo "$UPDATE_OUTPUT" | grep -qi "restart"; then
  echo ""
  echo "  *** A restart is required. Restart now, then re-run: ***"
  echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/beauwoods/dotfiles/main/scripts/bootstrap.sh)\""
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 4: Install Ansible"

if python3 -m pip install --user ansible --break-system-packages 2>/dev/null; then
  echo "    Ansible installed."
elif python3 -m pip install --user ansible 2>/dev/null; then
  echo "    Ansible installed."
else
  echo "ERROR: pip install failed."; exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 5: Install Ansible Galaxy roles"

GALAXY_BIN=""
for candidate in \
    ~/Library/Python/3.9/bin/ansible-galaxy \
    ~/Library/Python/3.13/bin/ansible-galaxy \
    ~/Library/Python/3.12/bin/ansible-galaxy \
    ~/Library/Python/3.11/bin/ansible-galaxy \
    ~/Library/Python/3.10/bin/ansible-galaxy \
    ~/.local/bin/ansible-galaxy \
    /usr/local/bin/ansible-galaxy; do
  [ -x "$candidate" ] && GALAXY_BIN="$candidate" && break
done
[ -z "$GALAXY_BIN" ] && \
  GALAXY_BIN=$(python3 -c "import shutil; print(shutil.which('ansible-galaxy') or '')" 2>/dev/null || true)

if [ -z "$GALAXY_BIN" ]; then
  echo "WARNING: ansible-galaxy not found — skipping Galaxy roles."
else
  "$GALAXY_BIN" install -r "$DOTFILES_DIR/ansible/requirements.yml"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 6: Run Ansible — installing all apps and applying settings"
echo "    This takes 30-60 minutes. You can walk away."
echo ""

PLAYBOOK_BIN=""
for candidate in \
    ~/Library/Python/3.9/bin/ansible-playbook \
    ~/Library/Python/3.13/bin/ansible-playbook \
    ~/Library/Python/3.12/bin/ansible-playbook \
    ~/Library/Python/3.11/bin/ansible-playbook \
    ~/Library/Python/3.10/bin/ansible-playbook \
    ~/.local/bin/ansible-playbook \
    /usr/local/bin/ansible-playbook; do
  [ -x "$candidate" ] && PLAYBOOK_BIN="$candidate" && break
done
[ -z "$PLAYBOOK_BIN" ] && \
  PLAYBOOK_BIN=$(python3 -c "import shutil; print(shutil.which('ansible-playbook') or '')" 2>/dev/null || true)

if [ -z "$PLAYBOOK_BIN" ]; then
  echo "ERROR: ansible-playbook not found."; exit 1
fi

cd "$DOTFILES_DIR/ansible"

# Set up timestamped log file for this run
LOG_DIR="$HOME/.local/share/dotfiles/logs"
mkdir -p "$LOG_DIR"
ANSIBLE_LOG_PATH="$LOG_DIR/ansible_$(date +%Y%m%d_%H%M%S)_bootstrap.log"
export ANSIBLE_LOG_PATH
echo "    Ansible log: $ANSIBLE_LOG_PATH"

# Run everything except 'config' — config needs Little Snitch licensed first
# and 1Password SSH agent set up. Run it manually after those two things are done.
"$PLAYBOOK_BIN" main.yml \
  -i inventory/localhost \
  --ask-become-pass \
  --tags apps,defaults,mas \
  -v

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  Bootstrap complete. Three things left — see MANUAL_STEPS.md:      ║"
echo "║                                                                      ║"
echo "║  1. Adobe CC (installed) — open, sign in, install Acrobat/PS/LR    ║"
echo "║  2. SetApp (installed)   — open, sign in, install sub-apps          ║"
echo "║  3. Little Snitch (installed) — open, enter license from 1Password  ║"
echo "║  4. 1Password            — open, sign in, enable SSH agent          ║"
echo "║                                                                      ║"
echo "║  Then run this ONE final command:                                    ║"
echo "║    cd $DOTFILES_DIR/ansible"
echo "║    $PLAYBOOK_BIN main.yml -i inventory/localhost \\"
echo "║      --ask-become-pass --tags config -v"
echo "║                                                                      ║"
echo "║  Full log from this run:                                             ║"
echo "║    $ANSIBLE_LOG_PATH"
echo "╚══════════════════════════════════════════════════════════════════════╝"