#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE="docker compose -f $STACK_DIR/docker-compose.yml --env-file $STACK_DIR/.env"

echo "==> Stopping Angani Monitor stack..."
$COMPOSE --profile logging down 2>/dev/null || true
$COMPOSE down

echo "==> Stack stopped. Data volumes are preserved."
echo "    To remove volumes too: docker compose down -v"
