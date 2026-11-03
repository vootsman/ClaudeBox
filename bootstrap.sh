#!/usr/bin/env bash
# ClaudeBox bootstrap: installs everything the agent needs on a fresh
# Ubuntu Server 26.04 LTS machine. Safe to run more than once.
set -euo pipefail

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user (it will ask for sudo when needed), not as root." >&2
  exit 1
fi

REPO="$(cd "$(dirname "$0")" && pwd)"

# Files uploaded through GitHub's website lose their executable bit; restore it,
# and tell git to ignore permission-only changes so setup doesn't flag them.
chmod +x "$REPO"/bootstrap.sh "$REPO"/scripts/*.sh
if command -v git >/dev/null 2>&1 && [ -d "$REPO/.git" ]; then
  git -C "$REPO" config core.fileMode false
fi

say "Installing system packages (tmux, git, curl, unzip, GitHub CLI, python3, SSH server)"
sudo apt-get update -y
sudo apt-get install -y tmux git curl unzip ca-certificates gh python3 openssh-server iputils-arping
[ -d "$REPO/.git" ] && git -C "$REPO" config core.fileMode false

say "Making sure SSH starts at every boot"
sudo systemctl enable --now ssh

say "Checking for an IP address conflict"
IFACE="$(ip route show default 2>/dev/null | awk '{print $5; exit}')"
MYIP="$(ip -4 -o addr show dev "$IFACE" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)"
if [ -n "$IFACE" ] && [ -n "$MYIP" ]; then
  if sudo arping -D -q -c 3 -I "$IFACE" "$MYIP"; then
    echo "OK: this VM ($MYIP) is the only device using its address."
  else
    printf '\n\033[1;31m!! WARNING: another device is also using %s.\033[0m\n' "$MYIP"
    echo "   On Hyper-V this usually means an External switch on Wi-Fi."
    echo "   Fix: set the VM's network adapter to 'Default Switch' (see docs/hyper-v-ubuntu-vm.md, step 4)."
  fi
fi

say "Installing Bun (runtime for the Discord/Telegram plugins)"
if ! command -v bun >/dev/null 2>&1 && [ ! -x "$HOME/.bun/bin/bun" ]; then
  curl -fsSL https://bun.sh/install | bash
else
  echo "Bun already installed."
fi

say "Installing Claude Code CLI (native installer)"
if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
  curl -fsSL https://claude.ai/install.sh | bash
else
  echo "Claude Code already installed."
fi

say "Making sure ~/.local/bin and ~/.bun/bin are on PATH"
PATH_LINE='export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"'
grep -qxF "$PATH_LINE" "$HOME/.bashrc" || echo "$PATH_LINE" >> "$HOME/.bashrc"
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

say "Letting your user services run without being logged in (needed for always-on)"
sudo loginctl enable-linger "$USER"

say "Versions"
echo "tmux:   $(tmux -V)"
echo "git:    $(git --version)"
echo "gh:     $(gh --version | head -1)"
echo "bun:    $(bun --version 2>/dev/null || echo 'open a new shell to see')"
echo "claude: $(claude --version 2>/dev/null || echo 'open a new shell to see')"
echo "ssh:    $(systemctl is-enabled ssh 2>/dev/null) / $(systemctl is-active ssh 2>/dev/null)"
echo
echo "(If the Claude installer above said ~/.local/bin is not in your PATH, ignore it: this script already fixed that.)"

say "Bootstrap complete. Open a new terminal (or run: source ~/.bashrc) before continuing."
