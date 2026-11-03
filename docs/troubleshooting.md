# Troubleshooting

Real problems people have hit with this setup, and the fixes.

## Can't connect to the VM

| Symptom | Cause | Fix |
|---|---|---|
| `ssh: ... Connection refused` | Often you're connecting to the **wrong address**, possibly your own PC. | In the VM console run `hostname -I`. Compare with `ipconfig` on Windows. If they're the **same**, see the next row. |
| The VM has the **same IP as your PC**, and the PC's network is flaky | Hyper-V **External switch on Wi-Fi**. Wi-Fi makes the VM borrow the PC's identity, so the router gives both the same IP. | VM **Settings → Network Adapter → Default Switch**, reboot the VM, then remove the External switch in **Virtual Switch Manager**. Connect with `ssh yourname@agent-vm.mshome.net`. |
| `Connection refused` and the IP is right | SSH isn't running (for example, after an upgrade plus a reboot). | In the VM console: `sudo systemctl enable --now ssh`. (Not installed? `sudo apt install -y openssh-server` first.) |
| `Connection timed out` | Wrong IP, or the VM is off. | Hyper-V Manager → is the VM running? Then `hostname -I` in its console. |
| Address changes after every reboot | Normal with the Default Switch. | Use `ssh yourname@agent-vm.mshome.net` instead of the number. |
| Can't find the VM's IP | | Admin PowerShell: `(Get-VMNetworkAdapter agent-vm).IPAddresses`, or `hostname -I` in the VM console. |

## Typing and pasting

- **The Hyper-V console window has no copy/paste**, and *Clipboard → Type clipboard text* is unreliable. Use the console only to log in and fix SSH, then work over SSH from **Windows Terminal**, where pasting works.
- **PowerShell won't paste:** try **right-click**, **Ctrl+Shift+V**, or use **Windows Terminal** instead of the old PowerShell window.
- **Typing your password shows nothing:** that's normal in Linux. Type it and press Enter.

## Install problems

| Symptom | Fix |
|---|---|
| `git: command not found` | Minimized Ubuntu installs leave out git: `sudo apt update && sudo apt install -y git` |
| `cd: ~/agent: No such file or directory` | You haven't cloned yet. See README step 2. |
| Claude installer says `~/.local/bin is not in your PATH` | Safe to ignore: `bootstrap.sh` fixes it a moment later. Run `source ~/.bashrc` (or reconnect), then `which claude` should print a path. |
| `cat /etc/netplan/...: Permission denied` | Network config files need `sudo`: `sudo cat /etc/netplan/*.yaml` |
| Setup warns about uncommitted changes in the `.sh` files | Those are permission-only changes from `bootstrap.sh`. Current versions of `bootstrap.sh` tell git to ignore them; on older copies, run `git -C ~/agent config core.fileMode false`. |
| `bootstrap.sh` prints a red **IP conflict** warning | See "same IP as your PC" above. |

## Agent problems

| Symptom | Fix |
|---|---|
| The bot doesn't answer at all | `systemctl --user status agent`, then `tmux attach -t <session>` to see what it's doing. It may be waiting on a first-run prompt (folder trust or bypass-permissions warning); accept it. |
| The agent doesn't come back after a reboot | `loginctl show-user $USER -p Linger` should say `yes`. If not: `sudo loginctl enable-linger $USER`, then `systemctl --user enable agent`. |
| Messages from strangers | Check `/discord:access` or `/telegram:access` in the tmux session; the policy should be **allowlist**. |
| A connector (calendar, Gmail) is missing | `/status` in the tmux session should show a claude.ai login. Then `/mcp`. See [integrations.md](integrations.md). |
| Backups not happening | `systemctl --user list-timers` (look for agent-backup), and `cd ~/agent && git push` to see the error (often `gh auth login` expired). |

## Starting over

You took Hyper-V checkpoints, right? Hyper-V Manager → the VM → **Checkpoints** → right-click one → **Apply**. Your agent's memory is safe in its private GitHub repo either way; see "Moving your agent" in the README to restore it.
