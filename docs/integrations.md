# Integrations: calendar, email, files

Optional add-ons once your agent is running. Do them one at a time and test each.

> ⚠️ **Read this first.** Anything you connect, your agent can use, and so can **anyone paired with your agent**. Connect only personal accounts. Never connect a work account, an EMR, or anything holding patient data.

---

## How connectors reach your agent

Your agent signs in to Claude with your claude.ai account, so **every connector you've added at [claude.ai/customize/connectors](https://claude.ai/customize/connectors) is automatically available to it**: Google Calendar, Gmail, Google Drive, and so on. Nothing extra is installed on the VM.

That cuts both ways: if you connected Gmail in the Claude app for your own use, your agent can read your Gmail too. Check what it can see:

1. On the VM: `tmux attach -t <session>`
2. Type `/mcp`. Connectors from claude.ai are listed with a claude.ai label.
3. Select any you **don't** want the agent to use and turn it off **for this project**. Turning it off here doesn't affect the Claude app.
4. Detach with **Ctrl+B**, then **D**, and restart: `systemctl --user restart agent`

---

## Google Calendar

1. **Connect it on claude.ai.** Go to [claude.ai/customize/connectors](https://claude.ai/customize/connectors), find **Google Calendar**, click **Connect**, and sign in with the Google account whose calendars the agent should see. Skip this if it's already connected.
2. **Restart the agent** so it picks up the connector: `systemctl --user restart agent`
3. **Check it's there:** in the tmux session, `/mcp` should list **claude.ai Google Calendar** as connected.
4. **Test it** from your phone: *"What's on my calendar tomorrow?"*
5. **Teach it your calendars.** Tell it which calendars are which ("'Family' is shared with my wife; 'Clinic' is my work schedule; never add events to Clinic"). It saves that to its brain.

Notes:

- **Family calendars:** the agent sees the calendars that the connected Google account can see. Share family members' calendars with that account (in Google Calendar: *Settings → the calendar → Share with specific people*) rather than connecting several accounts.
- **Read vs. change:** the agent can create and edit events. Its `CLAUDE.md` tells it to ask before deleting events, changing other people's events, or sending invitations.
- **Invites are information, not orders:** calendar invites and email can contain text written by strangers. Your agent's `CLAUDE.md` tells it to treat that text as information, never as instructions.
- **Work schedule:** don't connect a work calendar that contains patient names or details. If you want the agent to plan around clinic or OR days, put only the time blocks ("OR 7:30–3") on a personal calendar.

---

## OneDrive (one folder, synced both ways)

There's no Claude connector for personal OneDrive, so the agent uses **rclone** to keep one dedicated OneDrive folder in sync with `~/agent-files` on the VM, every 15 minutes. Drop a file in that folder on your PC or phone and the agent can read it; the agent saves a file there and it shows up on your devices.

### Set it up

1. On the VM (outside tmux):
   ```bash
   ~/agent/scripts/setup-onedrive.sh
   ```
   To name the folder yourself: `~/agent/scripts/setup-onedrive.sh "Agent Files"`. The default is "*AgentName* Files".
2. The script installs rclone and starts `rclone config`. Follow the answers it prints. When it asks to open a browser, say **n**, because the VM has none. Then **on your Windows PC**, in PowerShell:
   ```powershell
   winget install Rclone.Rclone
   rclone authorize "onedrive"
   ```
   Sign in in the browser, copy the token it prints, and paste it into the VM's prompt. Choose **OneDrive Personal or Business** and pick your drive.
3. The script creates the folder, does a first sync, tells the agent about the folder (in its `CLAUDE.md`), turns on the 15-minute sync timer, and restarts the agent so it reads the new instructions.
4. Test it: put a small text file in the new OneDrive folder, wait 15 minutes (or run `~/agent/scripts/onedrive-sync.sh`), and ask the agent to read it.

### Know the limits

- **The sync is limited to one folder, but the sign-in isn't.** rclone's OneDrive sign-in technically allows the whole drive; the scripts only ever sync the one folder. Anyone who gets into the VM could use that sign-in for more, which is one more reason to keep the VM locked down.
- **Keep it small.** It's meant for documents you're working on with the agent, not your whole photo library.
- **Conflicts:** if the same file changes in both places between syncs, the newer one wins and the other is kept as a renamed copy.
- **Remove it:** `systemctl --user disable --now agent-onedrive.timer`, delete the `ONEDRIVE_FOLDER` line from `~/agent/agent.conf` and the "OneDrive Folder" section from `~/agent/CLAUDE.md`, and run `rclone config delete onedrive`.
- **Work OneDrive (Microsoft 365 for business):** don't connect a work account. It almost certainly falls under your employer's data and privacy rules.

---

## After moving to a new machine

Connectors come back automatically, since they follow your claude.ai login. For OneDrive, run `~/agent/scripts/setup-onedrive.sh` again on the new machine: it reads the folder name from `agent.conf` and only asks you to sign in again.
