#!/bin/bash
# run-playbook.sh
# Wrapper for manual ansible-playbook runs.
# Handles log path, verbosity, and binary resolution automatically.
# Usage:
#   ./scripts/run-playbook.sh --tags config
#   ./scripts/run-playbook.sh --tags mas,config
#   ./scripts/run-playbook.sh           # runs all tags

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$HOME/.local/share/dotfiles/logs"
mkdir -p "$LOG_DIR"

# Resolve tags label for log filename
TAGS_LABEL="all"
for arg in "$@"; do
  if [[ "$arg" == --tags ]]; then
    : # next arg is the value
  elif [[ "${prev_arg:-}" == --tags ]]; then
    TAGS_LABEL="${arg//,/_}"
  fi
  prev_arg="$arg"
done

ANSIBLE_LOG_PATH="$LOG_DIR/ansible_$(date +%Y%m%d_%H%M%S)_${TAGS_LABEL}.log"
export ANSIBLE_LOG_PATH

# Resolve ansible-playbook binary
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
  echo "ERROR: ansible-playbook not found."
  exit 1
fi

echo ""
echo "==> Running playbook"
echo "    Binary:  $PLAYBOOK_BIN"
echo "    Tags:    ${TAGS_LABEL}"
echo "    Log:     $ANSIBLE_LOG_PATH"
echo ""

cd "$DOTFILES_DIR/ansible"
"$PLAYBOOK_BIN" main.yml \
  -i inventory/localhost \
  --ask-become-pass \
  -v \
  "$@"

echo ""
echo "==> Done. Full log at: $ANSIBLE_LOG_PATH"
