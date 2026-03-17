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

echo "Enter your password once — needed for app installs:"
sudo -v
( while true; do sudo -n true; sleep 60; done ) &
trap 'kill $! 2>/dev/null' EXIT

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
# Re-exec from cloned copy so we get the full script
[ "$0" != "$LOCAL/scripts/bootstrap.sh" ] && exec bash "$LOCAL/scripts/bootstrap.sh" "$@"

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

ansible-playbook main.yml --ask-become-pass --skip-tags post-auth
echo "Phase 1 complete. Log: $LOG"

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
ansible-playbook main.yml --ask-become-pass --tags post-auth
echo ""
echo "Done. SSH keys and remaining manual steps in README.md."
