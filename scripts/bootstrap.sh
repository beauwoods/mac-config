#!/bin/bash
# bootstrap.sh
# Run this once on a fresh Mac before the Ansible playbook.
# Installs the minimum prerequisites needed to run Ansible.

set -euo pipefail

# Cache sudo credentials upfront — several steps need root (Xcode tools install,
# Ansible become tasks, Galaxy role install). Doing this once at the start means
# you can walk away after entering your password.
echo "This script needs sudo access. Please enter your password now."
sudo -v
# Keep-alive: refresh sudo timestamp every 60s until script exits
( while true; do sudo -n true; sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 1: Clone dotfiles repo"
DOTFILES_DIR="$HOME/Documents/GitHub/dotfiles"
REPO_URL="https://github.com/beauwoods/dotfiles.git"

if [ -d "$DOTFILES_DIR/.git" ]; then
  echo "    Repo already exists at $DOTFILES_DIR — pulling latest..."
  git -C "$DOTFILES_DIR" pull --ff-only
  echo "    Up to date."
else
  echo "    Cloning $REPO_URL → $DOTFILES_DIR"
  mkdir -p "$HOME/Documents/GitHub"
  git clone "$REPO_URL" "$DOTFILES_DIR"
  echo "    Clone complete."
fi

# If this script was invoked via curl | bash, re-exec from the cloned copy
# so the rest of the script benefits from any updates in the repo.
SELF="$DOTFILES_DIR/scripts/bootstrap.sh"
if [ "$(realpath "$0" 2>/dev/null || echo "$0")" != "$(realpath "$SELF" 2>/dev/null || echo "$SELF")" ] \
   && [ -f "$SELF" ]; then
  echo ""
  echo "    Re-running from cloned repo: $SELF"
  exec bash "$SELF" "$@"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo "==> Step 2: Install pending macOS software updates"
echo "    This ensures the OS is fully patched before setup begins."
echo ""

# softwareupdate exits non-zero if there's nothing to install on some macOS
# versions, so we append || true to prevent aborting under set -e.
# We do NOT pass --restart: if a restart is required, softwareupdate will
# say so and we handle it explicitly below rather than rebooting mid-script.
UPDATE_OUTPUT=$(softwareupdate --install --all 2>&1 || true)
echo "$UPDATE_OUTPUT"

if echo "$UPDATE_OUTPUT" | grep -qi "restart"; then
  echo ""
  echo "  *** A restart is required to finish installing updates. ***"
  echo "  Please restart now, then re-run bootstrap.sh to continue."
  echo "  (Run: ~/Documents/GitHub/dotfiles/scripts/bootstrap.sh)"
  exit 0
else
  echo "  Updates complete (or none needed)."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 3: Install Xcode Command Line Tools..."
if xcode-select -p &>/dev/null; then
  echo "    Already installed at: $(xcode-select -p)"
else
  xcode-select --install 2>/dev/null || true
  echo ""
  echo "    A dialog has appeared asking you to install the Command Line Tools."
  echo "    Click 'Install' and wait for it to finish, then press Enter here."
  echo "    (Do not click 'Get Xcode' — just 'Install')"
  echo ""
  WAIT=0
  TIMEOUT=600
  until xcode-select -p &>/dev/null; do
    sleep 10
    WAIT=$((WAIT+10))
    echo -n "."
    if [ "$WAIT" -ge "$TIMEOUT" ]; then
      echo ""
      echo "ERROR: Timed out waiting for Xcode CLI tools after ${TIMEOUT}s."
      echo "Install manually: xcode-select --install — then re-run this script."
      exit 1
    fi
  done
  echo ""
  echo "    Xcode CLI tools installed."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 4: Install Ansible via pip3..."
# --break-system-packages is required on macOS Sequoia (15+) where the system
# Python is marked as externally managed. Harmless on earlier versions.
python3 -m pip install --user ansible --break-system-packages

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 5: Install Ansible Galaxy roles..."
GALAXY_BIN=""
for candidate in \
    ~/.local/bin/ansible-galaxy \
    ~/Library/Python/3.9/bin/ansible-galaxy \
    ~/Library/Python/3.13/bin/ansible-galaxy \
    ~/Library/Python/3.12/bin/ansible-galaxy \
    ~/Library/Python/3.11/bin/ansible-galaxy \
    ~/Library/Python/3.10/bin/ansible-galaxy \
    /usr/local/bin/ansible-galaxy; do
  [ -x "$candidate" ] && GALAXY_BIN="$candidate" && break
done
if [ -z "$GALAXY_BIN" ]; then
  GALAXY_BIN=$(python3 -c "import shutil; print(shutil.which('ansible-galaxy') or '')" 2>/dev/null || true)
fi

if [ -z "$GALAXY_BIN" ]; then
  echo "WARNING: ansible-galaxy not found — skipping Galaxy role install."
  echo "Run manually: ansible-galaxy install -r ansible/requirements.yml"
else
  "$GALAXY_BIN" install -r "$DOTFILES_DIR/ansible/requirements.yml"
  echo "    Galaxy roles installed."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 6: Verify Ansible install..."
PLAYBOOK_BIN=""
for candidate in \
    ~/.local/bin/ansible-playbook \
    ~/Library/Python/3.9/bin/ansible-playbook \
    ~/Library/Python/3.13/bin/ansible-playbook \
    ~/Library/Python/3.12/bin/ansible-playbook \
    ~/Library/Python/3.11/bin/ansible-playbook \
    ~/Library/Python/3.10/bin/ansible-playbook \
    /usr/local/bin/ansible-playbook; do
  [ -x "$candidate" ] && PLAYBOOK_BIN="$candidate" && break
done
if [ -z "$PLAYBOOK_BIN" ]; then
  PLAYBOOK_BIN=$(python3 -c "import shutil; print(shutil.which('ansible-playbook') or '')" 2>/dev/null || true)
fi

if [ -z "$PLAYBOOK_BIN" ]; then
  echo "WARNING: ansible-playbook not found in common locations."
  echo "Try: python3 -m pip show ansible | grep Location"
else
  echo "Found: $PLAYBOOK_BIN"
  "$PLAYBOOK_BIN" --version | head -1
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Bootstrap complete."
echo ""
echo "Next steps:"
echo "  1. Sign into the App Store (required for mas)"
echo "  2. Complete the auth session in MANUAL_STEPS.md Stage 2"
echo "  3. Run the playbook:"
echo "       cd ~/Documents/GitHub/dotfiles/ansible"
echo "       ${PLAYBOOK_BIN:-ansible-playbook} main.yml -i inventory/localhost --ask-become-pass"
echo ""
echo "  To run a subset of the playbook, use tags:"
echo "       ${PLAYBOOK_BIN:-ansible-playbook} main.yml -i inventory/localhost --ask-become-pass --tags defaults"
echo "       ${PLAYBOOK_BIN:-ansible-playbook} main.yml -i inventory/localhost --ask-become-pass --tags mas"
echo "       ${PLAYBOOK_BIN:-ansible-playbook} main.yml -i inventory/localhost --ask-become-pass --tags apps,config"
