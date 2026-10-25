#!/usr/bin/env bash
# Builds GeoWars locally and ships it to the server (run from Git Bash):
#   bash deploy/deploy.sh
# First time on a new server: bash deploy/deploy.sh --setup
set -euo pipefail

SERVER="${GWARS_SERVER:-root@84.234.99.136}"
APP_DIR=/opt/gwars
cd "$(dirname "$0")/.."

[ -f packages/geo/out/world-r3.json ] || npm run geo:build
npm run build -w @geowars/web

if [ "${1:-}" = "--setup" ]; then
  ssh "$SERVER" "mkdir -p /tmp/gwars-deploy/apache"
  scp -q deploy/server-setup.sh deploy/gwars.service "$SERVER:/tmp/gwars-deploy/"
  scp -q deploy/apache/*.conf "$SERVER:/tmp/gwars-deploy/apache/"
  ssh "$SERVER" "bash /tmp/gwars-deploy/server-setup.sh && rm -rf /tmp/gwars-deploy"
fi

# Source, built client and generated world data; dependencies are installed on the server.
archive="$(mktemp -d)/gwars-release.tgz"
tar -czf "$archive" \
  --exclude=node_modules --exclude=packages/geo/cache --exclude=apps/web/public/geo \
  package.json package-lock.json tsconfig.base.json db packages apps
scp -q "$archive" "$SERVER:/tmp/gwars-release.tgz"
rm -f "$archive"

ssh "$SERVER" "bash -s" <<EOF
set -euo pipefail
cd $APP_DIR
rm -rf apps packages db
tar -xzf /tmp/gwars-release.tgz -C $APP_DIR
rm /tmp/gwars-release.tgz
npm ci --no-fund --no-audit --loglevel=error
npm run db:migrate --silent
npm run db:seed --silent
systemctl restart gwars
sleep 2
systemctl is-active gwars
EOF

echo "Deployed to https://gwars.no-santos.com"
