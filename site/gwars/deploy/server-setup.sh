#!/usr/bin/env bash
# One-time setup of the GeoWars host (Ubuntu 20.04 + Apache + MariaDB). Safe to re-run.
# Run on the server as root, from a copy of the deploy/ folder:
#   bash server-setup.sh
set -euo pipefail

DOMAIN=gwars.no-santos.com
APP_DIR=/opt/gwars
HERE="$(cd "$(dirname "$0")" && pwd)"

# Node.js 22 LTS
if ! command -v node >/dev/null || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 22 ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

id gwars >/dev/null 2>&1 || useradd --system --home-dir "$APP_DIR" --shell /usr/sbin/nologin gwars
mkdir -p "$APP_DIR/apps/web/dist"

# Dedicated database and user. The password is generated once and only stored in .env.
if [ ! -f "$APP_DIR/.env" ]; then
  DB_PASS="$(openssl rand -hex 24)"
  mysql <<SQL
CREATE DATABASE IF NOT EXISTS geowars CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'geowars'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS 'geowars'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
ALTER USER 'geowars'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER 'geowars'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON geowars.* TO 'geowars'@'localhost';
GRANT ALL PRIVILEGES ON geowars.* TO 'geowars'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
  cat > "$APP_DIR/.env" <<ENV
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=geowars
DB_PASSWORD=$DB_PASS
DB_NAME=geowars
PORT=3000
COOKIE_SECURE=true
ENV
  chown root:gwars "$APP_DIR/.env"
  chmod 640 "$APP_DIR/.env"
fi

install -m 644 "$HERE/gwars.service" /etc/systemd/system/gwars.service
systemctl daemon-reload
systemctl enable gwars

# Apache site + HTTPS certificate
install -m 644 "$HERE/apache/$DOMAIN.conf" "/etc/apache2/sites-available/$DOMAIN.conf"
a2enmod -q proxy proxy_http proxy_wstunnel
a2ensite -q "$DOMAIN"
apache2ctl configtest
systemctl reload apache2
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  certbot --apache -d "$DOMAIN" --non-interactive --agree-tos --redirect
fi

echo "Server setup done. Deploy the app with deploy/deploy.sh from a dev machine."
