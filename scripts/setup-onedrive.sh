#!/usr/bin/env bash
# Optional: gives the agent ONE OneDrive folder, synced both ways every 15 minutes
# with ~/agent-files. The agent never sees the rest of your OneDrive through this sync.
# Usage: scripts/setup-onedrive.sh ["OneDrive folder name"]   (default: "<AgentName> Files")
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$REPO/agent.conf"
FOLDER="${1:-${ONEDRIVE_FOLDER:-$AGENT_NAME Files}}"
LOCAL="$HOME/agent-files"

if ! command -v rclone >/dev/null 2>&1; then
  echo "==> Installing rclone"
  curl -fsSL https://rclone.org/install.sh | sudo bash
fi

if ! rclone listremotes | grep -qx 'onedrive:'; then
  cat <<'EOF'

==> Connecting rclone to your OneDrive
rclone will ask a series of questions. Answer:
  n) New remote          name> onedrive
  Storage>               onedrive  (or the number shown for Microsoft OneDrive)
  client_id / client_secret / region: press Enter (defaults; region = global)
  Edit advanced config?  n
  Use web browser to automatically authenticate?  n   <- the VM has no browser
Then, on your WINDOWS PC, open PowerShell and run:
    winget install Rclone.Rclone
    rclone authorize "onedrive"
Sign in in the browser that opens, copy the token it prints (between the
"Paste the following" and "End paste" lines), and paste it back here.
Finally choose "OneDrive Personal or Business", pick your drive, and confirm with y.

EOF
  rclone config
fi

rclone listremotes | grep -qx 'onedrive:' || { echo "No 'onedrive' remote was created; nothing changed." >&2; exit 1; }

echo "==> Creating OneDrive folder '$FOLDER' (if needed) and syncing it to $LOCAL"
rclone mkdir "onedrive:$FOLDER"
mkdir -p "$LOCAL"
rclone bisync "onedrive:$FOLDER" "$LOCAL" --resync --create-empty-src-dirs

# Remember the folder so the timer (and a future restore) know about it
if grep -q '^ONEDRIVE_FOLDER=' "$REPO/agent.conf"; then
  python3 -I - "$REPO/agent.conf" "$FOLDER" <<'PY'
import sys, re
path, folder = sys.argv[1:3]
s = open(path).read()
s = re.sub(r'^ONEDRIVE_FOLDER=.*$', 'ONEDRIVE_FOLDER="%s"' % folder.replace('"', ''), s, flags=re.M)
open(path, "w").write(s)
PY
else
  echo "ONEDRIVE_FOLDER=\"${FOLDER//\"/}\"" >> "$REPO/agent.conf"
fi

# Tell the agent about the folder (replacing any earlier OneDrive section)
python3 -I - "$REPO/CLAUDE.md" <<'PY'
import sys, re
path = sys.argv[1]
s = open(path).read()
s = re.sub(r'\n*## OneDrive Folder\n.*?(?=\n## |\Z)', '', s, flags=re.S)
open(path, "w").write(s.rstrip("\n") + "\n")
PY
{
  cat <<EOF

## OneDrive Folder

- \`~/agent-files\` is a two-way synced copy of the OneDrive folder "$FOLDER" (every 15 minutes, via \`agent-onedrive.timer\`). Files $USER_NAME puts there appear for you; files you put there appear on $USER_NAME's devices.
- Put documents meant for $USER_NAME there. Never put your brain, passwords, tokens or patient data there.
- To sync immediately: \`~/agent/scripts/onedrive-sync.sh\`.
EOF
} >> "$REPO/CLAUDE.md"

"$REPO/scripts/install-services.sh"
echo "==> Done. '$FOLDER' in OneDrive <-> $LOCAL, synced every 15 minutes."
