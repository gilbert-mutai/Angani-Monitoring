# Angani Monitor — Production Grafana Stack

A production-ready, branded Docker Compose monitoring platform using Grafana + Prometheus.
Designed for reuse across multiple clients and projects.

## Stack

| Service | Image | Purpose |
|---------|-------|---------|
| **Grafana** | Custom build on `grafana/grafana:11.x` | Visualization |
| **Prometheus** | `prom/prometheus` | Metrics storage |
| **Node Exporter** | `prom/node-exporter` | Host metrics |
| **cAdvisor** | `gcr.io/cadvisor/cadvisor` | Container metrics |
| **Nginx** | `nginx:stable-alpine` | Reverse proxy |
| **Loki** *(optional)* | `grafana/loki` | Log aggregation |
| **Promtail** *(optional)* | `grafana/promtail` | Log shipping |

---

## Quick Start

```bash
# 1. Configure environment
cp .env .env.local    # optional — .env is the live config
nano .env             # set admin password, domain, version

# 2. Start core stack
./scripts/start.sh

# 3. Open Grafana
# Via Nginx:  http://localhost  (port 80)
# Direct:     http://localhost:3000
# Prometheus: http://localhost:9090

# 4. Optional: start with log collection
./scripts/start.sh --with-logging
```

Default credentials: **admin / changeme** (change in `.env` before deploying).

---

## Folder Structure

```
monitoring-stack/
├── docker-compose.yml          Main compose file
├── .env                        Environment variables (one per deployment)
├── nginx/
│   ├── default.conf            Reverse proxy config (HTTP + optional HTTPS)
│   └── ssl/                    Place cert.pem + key.pem here for TLS
├── prometheus/
│   ├── prometheus.yml          Scrape targets
│   └── alerts/
│       └── alerts.yml          Alert rules (CPU, memory, disk, containers)
├── grafana/
│   ├── Dockerfile              Custom Grafana image with branding applied
│   ├── grafana.ini             Grafana server configuration
│   ├── custom/
│   │   ├── logo.svg            Brand logo (replace with your own)
│   │   └── custom.css          Override Grafana colors and layout
│   ├── dashboards/
│   │   ├── system-overview.json   Host metrics dashboard
│   │   └── docker-containers.json Container metrics dashboard
│   └── provisioning/
│       ├── dashboards/dashboards.yaml   Auto-load dashboards
│       └── datasources/
│           ├── prometheus.yaml   Prometheus datasource
│           └── loki.yaml         Loki datasource (when logging profile active)
├── loki/
│   └── loki.yml
├── promtail/
│   └── promtail.yml
└── scripts/
    ├── start.sh    Start the stack
    ├── stop.sh     Stop the stack
    ├── backup.sh   Backup Grafana + Prometheus data
    ├── restore.sh  Restore from backup
    └── upgrade.sh  Safe Grafana upgrade with pre-upgrade backup
```

---

## Deploying for a New Client

1. Clone / copy this directory.
2. Edit `.env`:
   - Set `GRAFANA_ADMIN_PASSWORD` (strong password)
   - Set `GRAFANA_ROOT_URL` to the client's URL
   - Set `APP_TITLE` to the client name, e.g. `Acme Monitor`
   - Optionally update `GRAFANA_DOMAIN`
3. Replace `grafana/custom/logo.svg` with the client's logo.
4. Adjust brand colors in `grafana/custom/custom.css` (edit the `:root` variables).
5. Run `./scripts/start.sh`.

No code changes are needed for different clients — only `.env` and the `custom/` assets.

---

## HTTPS Setup

1. Place your certificate files in `nginx/ssl/`:
   - `nginx/ssl/cert.pem`
   - `nginx/ssl/key.pem`

2. Edit `nginx/default.conf`:
   - Uncomment the `return 301 https://...` redirect in the HTTP server block.
   - Uncomment the entire `HTTPS server` block at the bottom.
   - Set `server_name` to your actual domain.

3. Update `.env`: set `GRAFANA_ROOT_URL=https://your-domain.com`

4. Restart: `./scripts/stop.sh && ./scripts/start.sh`

**Let's Encrypt (certbot):**
```bash
certbot certonly --standalone -d monitor.example.com
cp /etc/letsencrypt/live/monitor.example.com/fullchain.pem nginx/ssl/cert.pem
cp /etc/letsencrypt/live/monitor.example.com/privkey.pem   nginx/ssl/key.pem
```

---

## Enabling Log Collection (Loki + Promtail)

```bash
# Start with logging profile
docker compose --profile logging up -d

# Or use the helper script
./scripts/start.sh --with-logging
```

Loki will be provisioned automatically as a datasource in Grafana.
Logs are available in the **Explore** view (`Loki` datasource).

---

## Backup and Restore

```bash
# Backup (creates timestamped archive in ./backups/)
./scripts/backup.sh

# Restore (interactive, requires confirmation)
./scripts/restore.sh backups/monitor_backup_20240601_120000.tar.gz
```

Backups include:
- Grafana SQLite database (dashboards, users, alerts, API keys)
- Prometheus TSDB snapshot

---

## Upgrading Grafana

```bash
# Safe upgrade — backs up first, then rebuilds and restarts only Grafana
./scripts/upgrade.sh 11.2.0
```

After upgrade:
1. Verify dashboards load correctly.
2. Check `docker logs grafana` for migration warnings.
3. If the logo is missing, the path in the Dockerfile may need updating (see below).

---

## How Grafana OSS Branding Works

### What we do

1. **Logo replacement** — The Dockerfile copies `custom/logo.svg` over Grafana's own SVG icon files at:
   - `/usr/share/grafana/public/img/grafana_icon.svg` (sidebar, login)
   - `/usr/share/grafana/public/img/grafana_com_auth_icon.svg`
   - `/usr/share/grafana/public/img/grafana_mask_icon.svg`

2. **Custom CSS** — `custom/custom.css` is copied into `/usr/share/grafana/public/css/`.
   The Dockerfile then patches every `*.html` file under `public/` to add:
   ```html
   <link rel="stylesheet" href="/public/css/custom.css" />
   ```
   This is the standard OSS approach because Grafana Enterprise is required for
   native CSS injection through configuration.

3. **App title** — Controlled by `GF_APP_TITLE` environment variable. Appears in
   browser tabs, the login page heading, and email notifications.

4. **Color theme** — `GF_USERS_DEFAULT_THEME=dark` sets the default for all users.

### OSS white-labeling limitations

| Feature | OSS | Enterprise |
|---------|-----|-----------|
| Replace logos | Yes (Dockerfile) | Yes (config) |
| Custom CSS | Yes (HTML patch) | Yes (native config) |
| App title | Yes (`GF_APP_TITLE`) | Yes |
| Remove "Grafana" from footer | Partial (CSS `display:none`) | Full |
| Custom login page text | Partial (CSS only) | Full |
| Email template branding | No | Yes |
| Custom OAuth branding | No | Yes |

### Maintaining branding after upgrades

The Dockerfile `sed` command that injects the CSS link is version-agnostic — it
finds `</head>` in any HTML file. The logo file paths have been stable across
Grafana 9.x → 11.x, but they can change in major releases.

**After each upgrade, verify:**
```bash
docker exec grafana ls /usr/share/grafana/public/img/ | grep icon
```
If the path changes, update the `COPY` lines in `grafana/Dockerfile`.

The CSS class names in `custom.css` use `[class*="..."]` substring selectors
which survive Grafana's CSS-module hash rotation. If a style stops working,
inspect the element in the browser to find the new class prefix.

---

## Prometheus Scrape Targets

| Job | Target | Metrics |
|-----|--------|---------|
| `prometheus` | `localhost:9090` | Prometheus internals |
| `node-exporter` | `node-exporter:9100` | CPU, memory, disk, network |
| `cadvisor` | `cadvisor:8080` | Container resource usage |
| `grafana` | `grafana:3000/metrics` | Grafana request rates, errors |

To add more scrape targets, edit `prometheus/prometheus.yml` and run:
```bash
curl -X POST http://localhost:9090/-/reload
```

---

## Adding Dashboards

Drop any Grafana dashboard JSON file into `grafana/dashboards/`. It will be
auto-loaded within 30 seconds (or on next Grafana restart) without rebuilding
the image. The provisioning config in `grafana/provisioning/dashboards/dashboards.yaml`
watches that directory.

---

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `GRAFANA_VERSION` | `11.1.0` | Grafana image version to build |
| `GRAFANA_ADMIN_USER` | `admin` | Admin username |
| `GRAFANA_ADMIN_PASSWORD` | `changeme` | Admin password — **change this** |
| `GRAFANA_ROOT_URL` | `http://localhost` | External URL (used in links) |
| `GRAFANA_PORT` | `3000` | Direct Grafana port |
| `APP_TITLE` | `Angani Monitor` | Browser tab title and login heading |
| `GRAFANA_THEME` | `dark` | Default theme (`dark` / `light`) |
| `PROMETHEUS_RETENTION` | `30d` | How long Prometheus keeps metrics |
| `HTTP_PORT` | `80` | Nginx HTTP port |
| `HTTPS_PORT` | `443` | Nginx HTTPS port |
| `GRAFANA_DOMAIN` | `monitor.example.com` | Domain name (for Nginx config) |
| `LOKI_PORT` | `3100` | Loki HTTP port |
