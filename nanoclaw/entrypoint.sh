#!/usr/bin/env bash
set -euo pipefail

# ── Pinned channel SHAs (last updated 2026-03-14) ─────────────────────────
TELEGRAM_SHA=662e81fc9e9858be5135078585ce643e97ef14fc
SLACK_SHA=102ea645803fde18f8e3694d2a338f2a677aaf6a
DISCORD_SHA=ba9353c5ee7deb6011f308f45417f6a38917dd0e
WHATSAPP_SHA=2a2ab2a2f000d41ea60b76445a99fa47138a67b1

NANOCLAW_DIR=/workspace/nanoclaw
NANOCLAW_VERSION=v1.2.0
NANOCLAW_REPO_URL=https://github.com/qwibitai/nanoclaw.git

NEEDS_REBUILD=false

# ── 1. Clone or upgrade to pinned version ─────────────────────────────────
if [ ! -d "${NANOCLAW_DIR}/.git" ]; then
    echo "[setup] Cloning nanoclaw ${NANOCLAW_VERSION}..."
    git clone --depth=1 --branch "${NANOCLAW_VERSION}" "${NANOCLAW_REPO_URL}" "${NANOCLAW_DIR}"
    NEEDS_REBUILD=true
else
    CURRENT_TAG=$(git -C "${NANOCLAW_DIR}" describe --tags 2>/dev/null || echo "unknown")
    if [ "${CURRENT_TAG}" != "${NANOCLAW_VERSION}" ]; then
        echo "[setup] Version mismatch (have ${CURRENT_TAG}, want ${NANOCLAW_VERSION}). Re-cloning..."
        rm -rf "${NANOCLAW_DIR}"
        git clone --depth=1 --branch "${NANOCLAW_VERSION}" "${NANOCLAW_REPO_URL}" "${NANOCLAW_DIR}"
        NEEDS_REBUILD=true
    else
        echo "[setup] nanoclaw ${NANOCLAW_VERSION} already present."
    fi
fi

cd "${NANOCLAW_DIR}"

# ── 2. Merge channel branches (only for enabled channels) ──────────────────
merge_channel() {
    local channel="$1"
    local repo_url="$2"
    local sha="$3"
    local marker="src/channels/${channel}.ts"

    if [ -f "${marker}" ]; then
        echo "[setup] Channel ${channel} already merged, skipping."
        return
    fi

    echo "[setup] Merging channel: ${channel} (${sha})..."
    git fetch "${repo_url}" "${sha}"
    git merge FETCH_HEAD --no-edit || true

    # Auto-resolve package-lock.json conflicts by taking theirs
    if git ls-files --unmerged | grep -q "package-lock.json"; then
        git checkout --theirs package-lock.json
        git add package-lock.json
        git commit --no-edit || true
    fi

    NEEDS_REBUILD=true
}

if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
    merge_channel "telegram" "https://github.com/qwibitai/nanoclaw-telegram.git" "${TELEGRAM_SHA}"
fi

if [ -n "${SLACK_BOT_TOKEN:-}" ]; then
    merge_channel "slack" "https://github.com/qwibitai/nanoclaw-slack.git" "${SLACK_SHA}"
fi

if [ -n "${DISCORD_BOT_TOKEN:-}" ]; then
    merge_channel "discord" "https://github.com/qwibitai/nanoclaw-discord.git" "${DISCORD_SHA}"
fi

if [ -n "${WHATSAPP_ENABLE:-}" ]; then
    merge_channel "whatsapp" "https://github.com/qwibitai/nanoclaw-whatsapp.git" "${WHATSAPP_SHA}"
fi

# ── 3. Install & build ─────────────────────────────────────────────────────
if [ ! -f "dist/index.js" ] || [ "${NEEDS_REBUILD}" = "true" ]; then
    echo "[setup] Installing dependencies..."
    npm install --unsafe-perm
    echo "[setup] Building..."
    npm run build
else
    echo "[setup] Build already up to date."
fi

# ── 4. Write NanoClaw's .env ───────────────────────────────────────────────
echo "[setup] Writing .env..."
cat > .env <<EOF
ANTHROPIC_API_KEY=nanoclaw-placeholder
ANTHROPIC_BASE_URL=http://llm-proxy:8082
ASSISTANT_NAME=${ASSISTANT_NAME:-Andy}
CONTAINER_IMAGE=${CONTAINER_IMAGE:-nanoclaw-agent:latest}
CREDENTIAL_PROXY_PORT=3001
EOF

[ -n "${TELEGRAM_BOT_TOKEN:-}" ]      && echo "TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}"           >> .env
[ -n "${SLACK_BOT_TOKEN:-}" ]         && echo "SLACK_BOT_TOKEN=${SLACK_BOT_TOKEN}"                 >> .env
[ -n "${SLACK_APP_TOKEN:-}" ]         && echo "SLACK_APP_TOKEN=${SLACK_APP_TOKEN}"                 >> .env
[ -n "${DISCORD_BOT_TOKEN:-}" ]       && echo "DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN}"             >> .env
[ -n "${WHATSAPP_ENABLE:-}" ]         && echo "WHATSAPP_ENABLE=${WHATSAPP_ENABLE}"                 >> .env
[ -n "${CONTAINER_TIMEOUT:-}" ]       && echo "CONTAINER_TIMEOUT=${CONTAINER_TIMEOUT}"             >> .env
[ -n "${IDLE_TIMEOUT:-}" ]            && echo "IDLE_TIMEOUT=${IDLE_TIMEOUT}"                       >> .env
[ -n "${MAX_CONCURRENT_CONTAINERS:-}" ] && echo "MAX_CONCURRENT_CONTAINERS=${MAX_CONCURRENT_CONTAINERS}" >> .env

# ── 5. Sync .env → data/env/env (read by channel modules inside agents) ───
mkdir -p data/env
cp .env data/env/env
echo "[setup] Synced .env → data/env/env"

# ── 6. Mount allowlist ─────────────────────────────────────────────────────
ALLOWLIST_DIR="${HOME}/.config/nanoclaw"
ALLOWLIST_FILE="${ALLOWLIST_DIR}/mount-allowlist.json"
if [ ! -f "${ALLOWLIST_FILE}" ]; then
    mkdir -p "${ALLOWLIST_DIR}"
    echo "[]" > "${ALLOWLIST_FILE}"
    echo "[setup] Created empty mount-allowlist.json"
fi

# ── 7. Build agent image ───────────────────────────────────────────────────
CONTAINER_IMAGE="${CONTAINER_IMAGE:-nanoclaw-agent:latest}"
if ! docker image inspect "${CONTAINER_IMAGE}" > /dev/null 2>&1; then
    echo "[setup] Building agent image ${CONTAINER_IMAGE}..."
    docker build -t "${CONTAINER_IMAGE}" container/
else
    echo "[setup] Agent image ${CONTAINER_IMAGE} already exists."
fi

# ── 8. Optional auto-registration ─────────────────────────────────────────
if [ -n "${NANOCLAW_MAIN_JID:-}" ]; then
    echo "[setup] Registering main chat: ${NANOCLAW_MAIN_JID}..."
    npx tsx setup/index.ts --step register \
        --jid "${NANOCLAW_MAIN_JID}" \
        --name "${NANOCLAW_MAIN_NAME:-Main}" \
        --folder main \
        --channel "${NANOCLAW_MAIN_CHANNEL:-telegram}" \
        --is-main
fi

# ── 9. Start NanoClaw ──────────────────────────────────────────────────────
echo "[setup] Starting NanoClaw..."
exec node dist/index.js
