#!/usr/bin/env bash
set -euo pipefail

# Load NANOCLAW_DATA_DIR from .env if present
NANOCLAW_DATA_DIR="${NANOCLAW_DATA_DIR:-/var/lib/nanoclaw}"
if [ -f .env ]; then
    val=$(grep '^NANOCLAW_DATA_DIR=' .env | cut -d= -f2-)
    [ -n "$val" ] && NANOCLAW_DATA_DIR="$val"
fi

docker compose down
sudo rm -rf "${NANOCLAW_DATA_DIR}"
sudo mkdir -p "${NANOCLAW_DATA_DIR}"
sudo chmod 777 "${NANOCLAW_DATA_DIR}"
docker compose up --build
