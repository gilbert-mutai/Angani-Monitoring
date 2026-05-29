#!/usr/bin/env bash
# Backup Grafana data (dashboards, users, settings stored in grafana.db)
# and Prometheus data to a timestamped tar archive.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-$STACK_DIR/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/monitor_backup_$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "==> Backing up Angani Monitor stack to $BACKUP_FILE"

# Grafana: copy the SQLite database out of the volume
echo "    Exporting Grafana data..."
docker run --rm \
  --volumes-from grafana \
  -v "$BACKUP_DIR:/backup" \
  busybox tar czf "/backup/grafana_data_$TIMESTAMP.tar.gz" /var/lib/grafana

# Prometheus: snapshot via the admin API (non-destructive)
echo "    Creating Prometheus snapshot..."
SNAPSHOT_RESPONSE=$(curl -s -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot)
SNAPSHOT_NAME=$(echo "$SNAPSHOT_RESPONSE" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)

if [[ -n "$SNAPSHOT_NAME" ]]; then
  docker run --rm \
    --volumes-from prometheus \
    -v "$BACKUP_DIR:/backup" \
    busybox tar czf "/backup/prometheus_snapshot_$TIMESTAMP.tar.gz" \
      "/prometheus/snapshots/$SNAPSHOT_NAME"
  echo "    Prometheus snapshot: $SNAPSHOT_NAME"
else
  echo "    WARNING: Could not create Prometheus snapshot (is the stack running?)"
fi

# Bundle both into one archive
echo "    Bundling archives..."
cd "$BACKUP_DIR"
tar czf "monitor_backup_$TIMESTAMP.tar.gz" \
  "grafana_data_$TIMESTAMP.tar.gz" \
  "prometheus_snapshot_$TIMESTAMP.tar.gz" 2>/dev/null || true

rm -f "$BACKUP_DIR/grafana_data_$TIMESTAMP.tar.gz" \
      "$BACKUP_DIR/prometheus_snapshot_$TIMESTAMP.tar.gz" 2>/dev/null || true

echo ""
echo "==> Backup complete: $BACKUP_FILE"
echo "    Size: $(du -sh "$BACKUP_FILE" | cut -f1)"
