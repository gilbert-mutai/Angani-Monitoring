#!/usr/bin/env bash
# Safely upgrade Grafana to a new version:
#   1. Backup current data
#   2. Update GRAFANA_VERSION in .env
#   3. Rebuild and restart the Grafana container
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE="docker compose -f $STACK_DIR/docker-compose.yml --env-file $STACK_DIR/.env"
ENV_FILE="$STACK_DIR/.env"

NEW_VERSION="${1:-}"

if [[ -z "$NEW_VERSION" ]]; then
  echo "Usage: $0 <new-grafana-version>"
  echo "Example: $0 11.2.0"
  echo ""
  CURRENT=$(grep '^GRAFANA_VERSION=' "$ENV_FILE" | cut -d= -f2)
  echo "Current version: ${CURRENT:-unknown}"
  exit 1
fi

CURRENT=$(grep '^GRAFANA_VERSION=' "$ENV_FILE" | cut -d= -f2)
echo "==> Upgrading Grafana: $CURRENT --> $NEW_VERSION"
echo ""

# Step 1: backup before touching anything
echo "==> Creating pre-upgrade backup..."
bash "$SCRIPT_DIR/backup.sh"
echo ""

# Step 2: update .env
echo "==> Updating GRAFANA_VERSION in .env..."
sed -i "s/^GRAFANA_VERSION=.*/GRAFANA_VERSION=$NEW_VERSION/" "$ENV_FILE"

# Step 3: rebuild image
echo "==> Pulling and rebuilding Grafana image..."
$COMPOSE build --pull --no-cache grafana

# Step 4: restart only Grafana (Prometheus keeps running — no metric gap)
echo "==> Restarting Grafana..."
$COMPOSE up -d --no-deps grafana

echo ""
echo "==> Upgrade complete."
echo "    Monitor Grafana startup: docker logs -f grafana"
echo "    If something is wrong, restore from backup and revert .env."
