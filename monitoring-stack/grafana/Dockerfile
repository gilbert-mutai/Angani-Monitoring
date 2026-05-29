ARG GRAFANA_VERSION=11.1.0
FROM grafana/grafana:${GRAFANA_VERSION}

# Switch to root for asset replacement
USER root

# Copy custom logo — replaces the default Grafana SVG icon.
# This file is served at /public/img/grafana_icon.svg and used
# in the sidebar, login screen, and loading splash.
COPY custom/logo.svg /usr/share/grafana/public/img/grafana_icon.svg
COPY custom/logo.svg /usr/share/grafana/public/img/grafana_com_auth_icon.svg
COPY custom/logo.svg /usr/share/grafana/public/img/grafana_mask_icon.svg

# Copy custom CSS into the public directory
COPY custom/custom.css /usr/share/grafana/public/css/custom.css

# Inject the custom CSS link into all HTML templates.
# The sed command appends a <link> tag before </head> in every .html
# file under the public directory. This is the standard OSS approach
# since Grafana Enterprise is required for native CSS injection support.
RUN find /usr/share/grafana/public -name "*.html" -exec \
      sed -i 's|</head>|<link rel="stylesheet" type="text/css" href="/public/css/custom.css" /></head>|g' {} + \
    2>/dev/null || true

# Fix permissions
RUN chown -R grafana:root /usr/share/grafana/public/css/ \
    && chown -R grafana:root /usr/share/grafana/public/img/

USER grafana
