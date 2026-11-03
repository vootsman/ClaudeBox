#!/usr/bin/env bash
# Two-way sync of the agent's OneDrive folder with ~/agent-files.
# Run every 15 minutes by agent-onedrive.timer; safe to run by hand any time.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$REPO/agent.conf"
[ -n "${ONEDRIVE_FOLDER:-}" ] || { echo "ONEDRIVE_FOLDER is not set in agent.conf; run scripts/setup-onedrive.sh" >&2; exit 1; }

rclone bisync "onedrive:$ONEDRIVE_FOLDER" "$HOME/agent-files" \
  --create-empty-src-dirs --resilient --recover --max-lock 2m --conflict-resolve newer
