# nanoclaw-bridge

Runs [NanoClaw](https://github.com/qwibitai/nanoclaw) in Docker and routes its AI requests through [claude-code-proxy](https://github.com/1rgs/claude-code-proxy), so you can use OpenAI, OpenRouter, or Gemini models instead of Anthropic directly.

NanoClaw is a messaging bot (Telegram, Slack, Discord, WhatsApp) that spawns Claude Code agent containers per conversation. Out of the box it requires an Anthropic API key. This setup replaces that requirement with any OpenAI-compatible provider.

## How it works

NanoClaw has a built-in credential proxy that intercepts all API traffic from agent containers. This stack points that proxy at `claude-code-proxy`, which accepts Anthropic-format requests and translates them to your chosen backend. Your real API key never touches NanoClaw.

Normally, setting up NanoClaw involves cloning the repo and running Claude Code with the `/setup` skill, which walks through installing dependencies, merging channel integrations, authenticating, and registering chats — all interactively. This project replaces that flow with a Docker entrypoint that handles everything automatically on startup: cloning and pinning NanoClaw, merging the channel branches you've enabled, building, and writing the required config. The only step that remains interactive is WhatsApp, which requires linking to your account via QR code or pairing code regardless of how NanoClaw is run.

## Setup

**Prerequisites:** Docker with Compose, a bot token for at least one channel, and an API key for your chosen LLM provider.

```bash
git clone https://github.com/your-username/nanoclaw-proxy.git
cd nanoclaw-proxy
cp .env.example .env
```

Edit `.env`:

1. Set `PREFERRED_PROVIDER` to `openai`, `google`, or `anthropic`
2. Set `BIG_MODEL` and `SMALL_MODEL` to models your provider supports
3. Fill in the API key for your provider (`OPENAI_API_KEY`, `GEMINI_API_KEY`, or `ANTHROPIC_API_KEY`)
4. Add at least one channel token (`TELEGRAM_BOT_TOKEN`, `SLACK_BOT_TOKEN`, etc.)

For any OpenAI-compatible provider (OpenRouter, Cerebras, Groq, Together, Fireworks, etc.), set `PREFERRED_PROVIDER=openai`, point `OPENAI_BASE_URL` at the provider's API, and use its key as `OPENAI_API_KEY`. Examples:

| Provider   | `OPENAI_BASE_URL`                       |
| ---------- | --------------------------------------- |
| OpenRouter | `https://openrouter.ai/api/v1`          |
| Cerebras   | `https://api.cerebras.ai/v1`            |
| Groq       | `https://api.groq.com/openai/v1`        |
| Together   | `https://api.together.xyz/v1`           |
| Ollama     | `http://host.docker.internal:11434/v1`  |

Set `BIG_MODEL` and `SMALL_MODEL` to model names supported by that provider. For Ollama, use the model names as they appear in `ollama list` (e.g. `llama3.2`, `qwen2.5-coder`). `OPENAI_API_KEY` can be set to any non-empty string — Ollama doesn't validate it.

```bash
docker compose up --build
```

On first run, NanoClaw clones itself, merges the channel integrations you enabled, builds, and starts. Subsequent restarts are fast.

### WhatsApp

WhatsApp requires a one-time authentication step that cannot be automated — you need to link the container to your WhatsApp account using either a pairing code or a QR scan.

1. Set `WHATSAPP_ENABLE=true` in `.env`
2. Optionally set `WHATSAPP_PHONE_NUMBER` (country code, no `+`, e.g. `1234567890`) to use pairing code instead of QR
3. Run the setup script:

```bash
bash scripts/whatsapp-setup.sh
```

The script starts the stack, waits for NanoClaw to be ready, walks you through auth, and restarts. Auth credentials are stored in the `nanoclaw-code` volume and persist across restarts — you only need to do this once.

For chat registration, set `NANOCLAW_MAIN_JID` in `.env` before running the script:
- Self-chat: `YOUR_NUMBER@s.whatsapp.net`
- Groups: run `docker compose exec nanoclaw bash -c 'cd /workspace/nanoclaw && npx tsx setup/index.ts --step groups --list'` after auth to get JIDs

## Upgrading NanoClaw

Update `NANOCLAW_VERSION` and the channel SHAs in `nanoclaw/entrypoint.sh`, then rebuild:

```bash
docker compose up --build
```

The entrypoint detects the version mismatch, re-clones, and rebuilds. Also check whether the `.env` write block or startup steps in `entrypoint.sh` need updating for the new version.

> If you have Claude Code, run `/update-nanoclaw` from this directory. It fetches the latest versions, diffs the upstream setup process, and updates `entrypoint.sh` automatically.

## Verifying

```bash
# Check the proxy received requests
docker compose logs llm-proxy

# Check NanoClaw started correctly
docker compose logs nanoclaw | grep -E "\[setup\]|Credential proxy"
# Expect: {"port":3001,"host":"0.0.0.0","authMode":"api-key"}
```

Send a message to your bot. Agent containers will appear in `docker ps` as siblings of the NanoClaw container.

## Contributing

The main things that need keeping up with:

- **NanoClaw releases** — when a new version drops, update `NANOCLAW_VERSION` and the channel SHAs in `nanoclaw/entrypoint.sh`, check the upstream setup skill for changes to the startup sequence, and update `entrypoint.sh` accordingly
- **claude-code-proxy** — if the proxy gains new features or the startup command changes, update `llm-proxy/Dockerfile`
- **New channels** — NanoClaw channels are separate repos. Adding one follows the same pattern as the existing four: add a pinned SHA constant, a merge step conditioned on the token env var, and the token to the `.env` write block

If you find that the entrypoint diverges from what a fresh NanoClaw install expects, the upstream `/setup` skill at `.claude/skills/setup/SKILL.md` in the NanoClaw repo is the reference for what the startup sequence should do.

Feel free to open a pull request.
