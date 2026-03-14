Update NanoClaw and all channel pins to their latest versions, check whether the setup skill has changed, and update entrypoint.sh if the startup sequence needs adjusting.

## Steps

### 1. Fetch latest versions

```
gh api repos/qwibitai/nanoclaw/releases/latest --jq '.tag_name'
gh api repos/qwibitai/nanoclaw-telegram/commits/main --jq '.sha'
gh api repos/qwibitai/nanoclaw-slack/commits/main --jq '.sha'
gh api repos/qwibitai/nanoclaw-discord/commits/main --jq '.sha'
gh api repos/qwibitai/nanoclaw-whatsapp/commits/main --jq '.sha'
gh api repos/1rgs/claude-code-proxy/commits/main --jq '.sha'
```

### 2. Compare against current pins

- `nanoclaw/entrypoint.sh`: `NANOCLAW_VERSION`, `TELEGRAM_SHA`, `SLACK_SHA`, `DISCORD_SHA`, `WHATSAPP_SHA`
- `llm-proxy/Dockerfile`: `PROXY_SHA` ARG

If everything is already up to date, report that and stop.

### 3. Fetch the setup skill at the new NanoClaw version

```
gh api repos/qwibitai/nanoclaw/contents/.claude/skills/setup/SKILL.md \
  --jq '.content' | base64 -d
```

Also fetch the same file at the currently pinned version to diff them:

```
gh api "repos/qwibitai/nanoclaw/contents/.claude/skills/setup/SKILL.md?ref=<current_NANOCLAW_VERSION>" \
  --jq '.content' | base64 -d
```

Compare the two. Focus on changes that affect the startup sequence this repo owns:

- **Bootstrap** (Step 1 in setup skill): `npm install`, `npm run build`, `bash setup.sh` — if the build process changed, update the install/build commands in `entrypoint.sh`
- **Channel merging** (Step 5): how channels are enabled and their branch merge logic — if the merge approach or conflict resolution changed, update the merge steps in `entrypoint.sh`
- **`.env` variables** (Step 4): Claude auth, container config, new or renamed env vars — update the `.env` write block in `entrypoint.sh` and the vars listed in `.env.example`
- **Mount allowlist** (Step 6): if the path or format changed, update the allowlist step in `entrypoint.sh`
- **Auto-registration** (Step 8): if the `npx tsx setup/index.ts --step register` CLI flags changed, update the registration command in `entrypoint.sh`
- **Container image build** (Step 3): if the agent image build step changed, update the `docker build` step in `entrypoint.sh`

Ignore steps that Docker handles outside the entrypoint: git/fork setup, service management (launchd/systemd), interactive authentication.

**WhatsApp note:** WhatsApp requires a QR code scan or pairing code on first run. This is inherently interactive and cannot be automated in Docker. The entrypoint merges the WhatsApp branch and writes `WHATSAPP_ENABLE` to `.env`, but the user must attach to the container and authenticate manually on first boot. Any changes to WhatsApp auth flow in the setup skill are out of scope for the entrypoint — flag them to the user instead.

### 4. Apply updates

- Set `NANOCLAW_VERSION` to the new tag in `nanoclaw/entrypoint.sh`
- Update whichever channel SHAs changed in `nanoclaw/entrypoint.sh`
- Update the date comment on the channel SHAs line to today's date
- Update `PROXY_SHA` in `llm-proxy/Dockerfile` if it changed
- Apply any entrypoint changes identified in step 3

### 5. Report

```
NANOCLAW_VERSION: v1.2.0 → v1.3.0
TELEGRAM_SHA:     662e81f → a1b2c3d  (updated)
SLACK_SHA:        102ea64 → 102ea64  (unchanged)
DISCORD_SHA:      ba9353c → ba9353c  (unchanged)
WHATSAPP_SHA:     2a2ab2a → 9f8e7d6  (updated)
PROXY_SHA:        dd4a29a → f1e2d3c  (updated)

Setup skill: changed
  - <brief description of what changed and what was updated in entrypoint.sh>
  - <any WhatsApp auth changes flagged here if relevant>
```

Remind the user to rebuild with `docker compose up --build` and test before deploying.
