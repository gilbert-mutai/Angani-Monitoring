#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE="docker compose -f $STACK_DIR/docker-compose.yml --env-file $STACK_DIR/.env"

echo "==> Starting Angani Monitor stack..."
echo ""

# Validate .env exists
if [[ ! -f "$STACK_DIR/.env" ]]; then
  echo "ERROR: .env file not found at $STACK_DIR/.env"
  echo "       Copy .env.example to .env and configure it first."
  exit 1
fi

# Build custom Grafana image if needed
echo "==> Building Grafana image..."
$COMPOSE build --pull grafana

# Start core services
echo "==> Starting services..."
$COMPOSE up -d

# Optionally start logging stack
if [[ "${1:-}" == "--with-logging" ]]; then
  echo "==> Starting Loki + Promtail..."
  $COMPOSE --profile logging up -d
fi

echo ""
echo "==> Waiting for Grafana to become healthy..."
TIMEOUT=60
ELAPSED=0
until docker inspect --format='{{.State.Health.Status}}' grafana 2>/dev/null | grep -q healthy; do
  if [[ $ELAPSED -ge $TIMEOUT ]]; then
    echo "WARNING: Grafana did not become healthy within ${TIMEOUT}s"
    echo "         Check logs with: docker logs grafana"
    break
  fi
  sleep 3
  ELAPSED=$((ELAPSED + 3))
  printf "."
done
echo ""

GRAFANA_PORT=$(grep '^GRAFANA_PORT=' "$STACK_DIR/.env" | cut -d= -f2)
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
HTTP_PORT=$(grep '^HTTP_PORT=' "$STACK_DIR/.env" | cut -d= -f2)
HTTP_PORT="${HTTP_PORT:-80}"

echo ""
echo "==> Stack is running!"
echo "    Grafana (direct):  http://localhost:${GRAFANA_PORT}"
echo "    Grafana (nginx):   http://localhost:${HTTP_PORT}"
echo "    Prometheus:        http://localhost:9090"
echo ""
echo "    Default credentials: admin / (see .env GRAFANA_ADMIN_PASSWORD)"
