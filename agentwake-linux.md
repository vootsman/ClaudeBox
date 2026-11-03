# AgentWake (Linux / VM edition): Discord + Telegram AI Agent Setup

<!-- Adapted from AgentWake by Benjamin Banwart (MIT): https://github.com/BenjaminBanwart/agentwake
     This edition targets Ubuntu Server 26.04 LTS (in a VM, on TrueNAS, or a cloud server) and keeps
     everything in one git repo so the agent can be rebuilt on any machine. -->

You are Claude Code. The user has put the AgentWake-Linux files in `~/agent` and asked you to read this file and run the setup. Work through it section by section, interactively. Wait for user input where indicated. Be warm, confident, and clear. Do not dump everything at once.

The repo already contains scripts that do the heavy lifting: `bootstrap.sh`, `scripts/init-agent.sh`, `scripts/install-services.sh`, `scripts/backup.sh`. Use them instead of doing the steps by hand.

If `~/agent/agent.conf` already exists, this is a **rebuild on a new machine**. Skip to "Restore Mode" at the bottom.

---

## Phase 0: Welcome and Consent

Display:

```
==========================================================
  AGENTWAKE (Linux/VM) — Persistent AI Agent Setup
==========================================================

  Over the next ~15-20 minutes I'll build a persistent AI
  agent on this machine: a name, a brain, a chat presence
  on Discord and/or Telegram, and backups so it can move
  to any machine.

  ⚠️  BEFORE WE START
  -------------------------------------------------------
  The agent gets FULL ACCESS to this machine (files,
  terminal, network) without asking per action. Running
  it in a dedicated VM is the right call:
  • Take a VM snapshot now, before setup
  • Keep sensitive data (and anything patient-related)
    off this VM
  • Only pair people you trust

  PREREQUISITES
  • Ubuntu Server 26.04 LTS (this VM)
  • Claude Pro or Max subscription
  • A Discord account and/or a Telegram account
  • A GitHub account (for the private backup repo)

  STEPS
  1. Install tools (automated)
  2. Name your agent and pick chat apps
  3. Set up the bot(s) (guided, ~5 min each)
  4. Build the brain + system config (automated)
  5. Private GitHub backup repo
  6. Install the always-on service
  7. Launch and pair
==========================================================
```

Ask: "Ready to get started? Type **yes** to continue." Wait for confirmation.

---

## Phase 1: Prerequisites

1. Check `which tmux gh bun claude`. If any are missing, tell the user to run this in a separate terminal (it needs their sudo password, which you should not ask for):
   ```
   bash ~/agent/bootstrap.sh
   ```
   Wait until they confirm it finished, then re-check.
2. Run `gh auth status`. If not signed in, ask the user to run `gh auth login` in a separate terminal (choose GitHub.com, HTTPS, and "Login with a web browser"; it gives a code to enter on their phone or PC). Wait for confirmation.
3. Confirm you are running inside the Claude Code CLI (you are, if they started you with `claude`). If not, tell them to run `claude` from `~/agent` and paste this file in, then stop.

Say: "All prerequisites are in place. Let's personalize your agent."

---

## Phase 2: Name Your Agent and Pick Chat Apps

Ask one at a time:

1. "What would you like to name your agent? It's the name in your chats, on its brain files, and how it thinks of itself." Store as `{AgentName}`.
2. "And what should I call you? This is how your agent will know its creator." Store as `{UserName}`.
3. "How do you want to talk to {AgentName}: **Discord**, **Telegram**, or **both**? With both, it's the same agent with the same memory, reachable from either app." Store the answer as `{channels}`: exactly `discord`, `telegram`, or `both`.

Say: "Got it. I'm building **{AgentName}** for **{UserName}**."

(No OS settings are needed: Ubuntu Server doesn't sleep, and security updates are fine because the service restarts the agent automatically after any reboot.)

---

## Phase 3: Bot Setup

Do **3A** if `{channels}` is `discord` or `both`. Do **3B** if it is `telegram` or `both`. Finish one completely before starting the other.

### Installing a channel plugin (used by 3A and 3B)

Ask the user to type into this session: `/plugin install <name>@claude-plugins-official` (where `<name>` is `discord` or `telegram`). If asked for an installation scope, choose **user**. If the install fails:
- `Marketplace "claude-plugins-official" not found` → have them run `/plugin marketplace add anthropics/claude-plugins-official`, then retry.
- `Plugin ... not found in marketplace` → have them run `/plugin marketplace update claude-plugins-official`, then retry.

If the plugin prints its own status message, ignore it and continue.

### 3A: Discord

Display: "Let's create {AgentName}'s Discord bot. Do these steps in a browser on any device."

1. **Create the application.** "Go to **https://discord.com/developers/applications**, click **New Application**, name it **{AgentName}**, accept the terms and click **Create**. Tell me when you're on the application page." Wait.
2. **Installation settings.** "Click **Installation** in the sidebar. Under **Installation Contexts**, uncheck **User Install** so only **Guild Install** is checked. Under **Install Link**, choose **None**. Click **Save Changes**." Wait.
3. **Bot settings.** "Click **Bot**. Make sure the username is {AgentName}. Uncheck **Public Bot**. Under **Privileged Gateway Intents**, turn on **Presence**, **Server Members**, and **Message Content**. Save." Wait.
4. **Token.** "On the **Bot** page, click **Reset Token** and copy it (it's shown once). **Also save it in your password manager as '{AgentName} Discord token'**: you'll need it if you ever move {AgentName} to another machine. Paste it here." Store as `{DiscordToken}`. It should be a long string (roughly 50-80 characters) containing periods; if not, ask again.
5. **Invite the bot.** "Click **OAuth2** → **OAuth2 URL Generator**. Under **Scopes** check **bot**. Under **Bot Permissions** check View Channels, Send Messages, Send Messages in Threads, Read Message History, Attach Files, Add Reactions. Integration Type: **Guild Install**. Open the generated URL, pick your server, click **Authorize**. Tell me when {AgentName} has joined." Wait.
6. **Plugin + token.** Install the `discord` plugin (see above). Then write the token yourself (do not echo it back or write it anywhere else):
   ```bash
   mkdir -p ~/.claude/channels/discord
   (umask 077; printf 'DISCORD_BOT_TOKEN=%s\n' '{DiscordToken}' > ~/.claude/channels/discord/.env)
   ```

Say: "Discord is configured."

### 3B: Telegram

Display: "Let's create {AgentName}'s Telegram bot. Do this in the Telegram app on your phone or computer."

1. **Create the bot.** "In Telegram, open a chat with **@BotFather** (look for the blue checkmark) and send `/newbot`. For the display name, use **{AgentName}**. For the username, pick something unique that ends in `bot`, with no spaces, like `{AgentName without spaces}Bot`. If it's taken, try a variation." Wait.
2. **Token.** "BotFather replies with a token that looks like `123456789:ABC...`. **Save it in your password manager as '{AgentName} Telegram token'**, then paste it here." Store as `{TelegramToken}`. It should be digits, a colon, then a long string; if not, ask again.
3. **Lock down your Telegram account.** "Whoever controls your Telegram account can command {AgentName}, so please: Settings → Privacy and Security → **Two-Step Verification** → turn it on. And Settings → Privacy and Security → **Phone Number** → set 'Who can see my phone number' to **Nobody**. Tell me when done, or 'skip' to do it later." Wait.
4. **Plugin + token.** Install the `telegram` plugin (see above). Then write the token yourself (do not echo it back or write it anywhere else):
   ```bash
   mkdir -p ~/.claude/channels/telegram
   (umask 077; printf 'TELEGRAM_BOT_TOKEN=%s\n' '{TelegramToken}' > ~/.claude/channels/telegram/.env)
   ```

Say: "Telegram is configured."

When all chosen apps are done, say: "We'll bring {AgentName} online after the brain is built."

---

## Phase 4: Build the Brain and System Config

Run:
```bash
~/agent/scripts/init-agent.sh "{AgentName}" "{UserName}" "{channels}"
```

This creates `~/agent/agent.conf` (including which chat apps to use), the brain at `~/agent/brain/` (Index, Identity, Memory, Skills, Projects, People, Journal, Inbox), and `~/agent/CLAUDE.md`, and symlinks `~/.claude/CLAUDE.md` to it. Show the user the script's output and the tmux session name it reports (`{session}`).

Mention: "The brain is plain markdown. If you use Obsidian, you can open a synced copy of the backup repo as a vault to browse it."

---

## Phase 5: Private GitHub Backup Repo

Explain: "Everything that makes {AgentName} *{AgentName}* (brain, config, setup scripts) lives in `~/agent`. I'll back it up to a **private** GitHub repo so you can rebuild on any machine in about 15 minutes."

Ask what to name the repo (suggest `{session}-agent`). Then:

```bash
cd ~/agent
[ -d .git ] || git init -b main
git config user.name  >/dev/null || git config user.name  "{AgentName}"
git config user.email >/dev/null || git config user.email "{session}@localhost"
git remote remove origin 2>/dev/null || true
git add -A
git commit -m "Initial setup of {AgentName}"
gh repo create <repo-name> --private --source=. --remote=origin --push
```

Verify the repo is private with `gh repo view <repo-name> --json visibility`. If it is not `PRIVATE`, stop and tell the user.

Confirm `.gitignore` is present and that `git ls-files` contains no `.env` files or tokens.

---

## Phase 6: Install the Always-On Service

Run:
```bash
~/agent/scripts/install-services.sh --no-start
```

This installs:
- `agent.service`: starts {AgentName} in tmux session `{session}` at boot with the chosen chat apps, and restarts it within ~15 seconds if it exits.
- `agent-backup.timer`: commits and pushes `~/agent` every hour.

Check with `systemctl --user list-timers | grep agent-backup` and `grep channels ~/.config/systemd/user/agent.service`.

---

## Phase 7: Launch and Pair

Tell the user to do this in a **separate terminal** (keep this setup session open):

```
systemctl --user start agent
tmux attach -t {session}
```

"The first launch may ask you to confirm the folder trust prompt and the 'bypass permissions' warning. Accept both; you only do this once per machine. Then {AgentName} reads its brain and starts listening."

Then pair each chosen app, still inside that tmux session:

**Discord**
1. In Discord, find **{AgentName}** in your server's member list and send it a **Direct Message**.
2. It replies with a **pairing code**.
3. In the tmux session type: `/discord:access pair <CODE>`
4. Then lock it down: `/discord:access policy allowlist`

**Telegram**
1. In Telegram, search for the bot's username and send it any message.
2. It replies with a **pairing code**.
3. In the tmux session type: `/telegram:access pair <CODE>`
4. Then lock it down: `/telegram:access policy allowlist`

Finally: detach without stopping it with **Ctrl+B**, then **D**.

Each family member who should be able to use {AgentName} pairs the same way, with the user's approval. Remind the user that everyone paired shares the same agent, memory, and machine access.

Wait for confirmation, then run `~/agent/scripts/backup.sh` once.

Then tell the user: "Any connectors you've added on claude.ai (like Google Calendar or Gmail) are already available to me. Type `/mcp` here to see them, and turn off any you don't want me to use. See docs/integrations.md."

---

## Phase 8: Final Summary

Display:

```
==========================================================
  Setup Complete — {AgentName} is Alive
==========================================================
  Agent:        {AgentName}       Creator: {UserName}
  Chat:         {ChatApps}
  Repo/brain:   ~/agent  (backed up hourly to GitHub)
  Service:      agent.service  (starts on boot)
  tmux session: {session}

  QUICK REFERENCE
  -------------------------------------------------------
  Watch/talk in the terminal:  tmux attach -t {session}
  Detach:                      Ctrl+B, then D
  Restart:                     systemctl --user restart agent
  Stop:                        systemctl --user stop agent
  Logs:                        journalctl --user -u agent
  Back up now:                 ~/agent/scripts/backup.sh

  OPTIONAL: CALENDAR, EMAIL, ONEDRIVE
  -------------------------------------------------------
  See docs/integrations.md. Check /mcp first: your
  claude.ai connectors are already available to me.

  ADD OR REMOVE A CHAT APP LATER
  -------------------------------------------------------
  Do Phase 3A/3B for the new app, edit CHANNELS and
  CHAT_APPS in ~/agent/agent.conf, then run
  ~/agent/scripts/install-services.sh and pair.

  MOVING TO ANOTHER MACHINE (TrueNAS, cloud, new PC)
  -------------------------------------------------------
  See README.md → "Moving your agent". Short version:
  stop it here, clone the private repo there, run
  bootstrap.sh, then `claude` and say "read
  agentwake-linux.md" — it will run Restore Mode.
==========================================================
```

(`{ChatApps}` is the `CHAT_APPS` value in `~/agent/agent.conf`.)

Stop here.

---

## Restore Mode (rebuilding on a new machine)

Use this when `~/agent/agent.conf` already exists (the user cloned their private backup repo onto a fresh Ubuntu machine).

1. Read `~/agent/agent.conf` for `AGENT_NAME`, `USER_NAME`, `SESSION`, and `CHANNELS` (if `CHANNELS` is missing, it is `discord`). Greet the user: "Looks like we're moving **{AgentName}** to a new home."
2. **Make sure the old copy is stopped.** Ask: "Is {AgentName} stopped on the old machine? (`systemctl --user stop agent` and `systemctl --user disable agent` there.) Two copies on the same bot token will both answer messages." Wait for a yes.
3. Run Phase 1 (prerequisites).
4. For each app in `CHANNELS`: install its plugin, ask the user for that bot's token from their password manager, and write it as in step 6 of 3A (Discord) or step 4 of 3B (Telegram). If a token is lost, walk them through getting a new one: **Reset Token** on the Discord Bot page, or `/revoke` then `/token` with @BotFather on Telegram.
5. Link the config: `mkdir -p ~/.claude && ln -sfn ~/agent/CLAUDE.md ~/.claude/CLAUDE.md`
6. Check that `git remote -v` shows their private repo and `git pull` works.
7. Run Phase 6 and Phase 7. Pairing must be redone on the new machine.
7b. If `agent.conf` has an `ONEDRIVE_FOLDER` line, run `~/agent/scripts/setup-onedrive.sh` so the user can sign in to OneDrive again.
8. Add a Conversation Log entry noting the move (date and new host), run `scripts/backup.sh`, and show the Phase 8 summary.
