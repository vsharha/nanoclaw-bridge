#!/usr/bin/env bash
set -euo pipefail

# Read a value from .env
env_get() { grep -E "^$1=" .env 2>/dev/null | cut -d= -f2- | tr -d ' ' || true; }

# ── Preflight ──────────────────────────────────────────────────────────────
if [ ! -f .env ]; then
    echo "Error: .env not found. Copy .env.example to .env and configure it first."
    exit 1
fi

WHATSAPP_ENABLE=$(env_get WHATSAPP_ENABLE)
if [ -z "${WHATSAPP_ENABLE}" ]; then
    echo "Error: WHATSAPP_ENABLE is not set in .env"
    exit 1
fi

PHONE=$(env_get WHATSAPP_PHONE_NUMBER)

# ── Start the stack ────────────────────────────────────────────────────────
echo "Starting stack..."
docker compose up -d --build

# Wait for nanoclaw to finish its setup (entrypoint prints this line when ready)
echo "Waiting for NanoClaw to start..."
timeout 180 bash -c \
    'until docker compose logs nanoclaw 2>/dev/null | grep -q "NanoClaw running\|Starting NanoClaw"; do sleep 3; done' \
    || { echo "Timed out waiting for NanoClaw. Check: docker compose logs nanoclaw"; exit 1; }

# ── Check existing auth ────────────────────────────────────────────────────
if docker compose exec nanoclaw test -f /workspace/nanoclaw/store/auth/creds.json 2>/dev/null; then
    echo "WhatsApp is already authenticated. Nothing to do."
    echo "To re-authenticate, run: docker compose exec nanoclaw rm -rf /workspace/nanoclaw/store/auth"
    exit 0
fi

# ── Authenticate ───────────────────────────────────────────────────────────
if [ -n "${PHONE}" ]; then
    echo ""
    echo "Using pairing code auth for ${PHONE}."
    echo "Have WhatsApp open on your phone: Settings > Linked Devices > Link a Device"
    echo "Tap 'Link with phone number instead' when the code appears."
    echo ""
    docker compose exec -it nanoclaw bash -c \
        "cd /workspace/nanoclaw && npx tsx setup/index.ts --step whatsapp-auth -- --method pairing-code --phone ${PHONE}"
else
    echo ""
    echo "No WHATSAPP_PHONE_NUMBER set — using QR code auth."
    echo "Scan the QR code below with WhatsApp: Settings > Linked Devices > Link a Device"
    echo ""
    docker compose exec -it nanoclaw bash -c \
        "cd /workspace/nanoclaw && npx tsx setup/index.ts --step whatsapp-auth -- --method qr-terminal"
fi

# ── Restart ────────────────────────────────────────────────────────────────
echo ""
echo "Authentication complete. Restarting NanoClaw..."
docker compose restart nanoclaw

echo ""
echo "Done. Send a message to your registered WhatsApp chat to test."
echo ""
echo "If you haven't registered a chat yet, set NANOCLAW_MAIN_JID in .env:"
echo "  Self-chat JID: YOUR_PHONE_NUMBER@s.whatsapp.net"
echo "  For groups, run: docker compose exec nanoclaw bash -c 'cd /workspace/nanoclaw && npx tsx setup/index.ts --step groups --list'"
