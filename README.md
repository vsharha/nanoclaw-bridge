# nanoclaw-bridge

Runs [NanoClaw](https://github.com/qwibitai/nanoclaw) in Docker and routes its AI requests through [claude-code-proxy](https://github.com/1rgs/claude-code-proxy), so you can use OpenAI, OpenRouter, or Gemini models instead of Anthropic directly.

NanoClaw is a messaging bot (Telegram, Slack, Discord, WhatsApp) that spawns Claude Code agent containers per conversation. Out of the box it requires an Anthropic API key. This setup replaces that requirement with any OpenAI-compatible provider.

## How it works

NanoClaw has a built-in credential proxy that intercepts all API traffic from agent containers. This stack points that proxy at `claude-code-proxy`, which accepts Anthropic-format requests and translates them to your chosen backend. Your real API key never touches NanoClaw.

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

| Provider   | `OPENAI_BASE_URL`                |
| ---------- | -------------------------------- |
| OpenRouter | `https://openrouter.ai/api/v1`   |
| Cerebras   | `https://api.cerebras.ai/v1`     |
| Groq       | `https://api.groq.com/openai/v1` |
| Together   | `https://api.together.xyz/v1`    |

Set `BIG_MODEL` and `SMALL_MODEL` to model names supported by that provider.

```bash
docker compose up --build
```

On first run, NanoClaw clones itself, merges the channel integrations you enabled, builds, and starts. Subsequent restarts are fast.

**WhatsApp:** The entrypoint merges the WhatsApp integration and writes your config, but WhatsApp requires a QR code scan on first boot. Attach to the container after startup to authenticate:

```bash
docker compose logs -f nanoclaw   # watch for the QR code
```

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
