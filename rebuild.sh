#!/usr/bin/env bash
set -euo pipefail
docker compose down
docker volume rm nanoclaw-bridge_nanoclaw-code
docker compose up --build
