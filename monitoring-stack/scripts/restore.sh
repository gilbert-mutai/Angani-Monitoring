#!/usr/bin/env bash
# Restore Grafana data from a backup created by backup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE="docker compose -f $STACK_DIR/docker-compose.yml --env-file $STACK_DIR/.env"

BACKUP_FILE="${1:-}"

if [[ -z "$BACKUP_FILE" ]]; then
  echo "Usage: $0 <path-to-backup.tar.gz>"
  echo ""
  echo "Available backups:"
  ls -1t "$STACK_DIR/backups/"*.tar.gz 2>/dev/null | head -10 || echo "  (none found)"
  exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "==> Restoring from: $BACKUP_FILE"
echo "    WARNING: This will replace the current Grafana database."
read -rp "    Are you sure? [y/N] " CONFIRM
[[ "${CONFIRM,,}" == "y" ]] || { echo "Aborted."; exit 0; }

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Extracting backup..."
tar xzf "$BACKUP_FILE" -C "$WORK_DIR"

GRAFANA_ARCHIVE=$(ls "$WORK_DIR"/grafana_data_*.tar.gz 2>/dev/null | head -1)

if [[ -z "$GRAFANA_ARCHIVE" ]]; then
  echo "ERROR: No Grafana data archive found inside the backup."
  exit 1
fi

echo "==> Stopping Grafana..."
$COMPOSE stop grafana

echo "==> Restoring Grafana volume..."
docker run --rm \
  --volumes-from grafana \
  -v "$(dirname "$GRAFANA_ARCHIVE"):/restore" \
  busybox sh -c "cd / && tar xzf /restore/$(basename "$GRAFANA_ARCHIVE")"

echo "==> Starting Grafana..."
$COMPOSE start grafana

echo ""
echo "==> Restore complete. Grafana is starting up."
